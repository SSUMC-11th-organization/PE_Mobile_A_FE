import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/storage/token_storage.dart';
import '../data/models/login_models.dart';
import '../data/models/member_info.dart';
import '../data/services/auth_api_service.dart';
import '../data/services/member_api_service.dart';

enum AuthStatus {
  initializing,
  signedOut,
  authenticating,
  signedIn,
  retryRequired,
}

enum MemberLoadStatus { idle, loading, success, error }

// 앱 전체의 로그인 상태입니다. 화면 이동은 하지 않고 상태만 바꾸며, Router가 상태를 보고 이동합니다.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._authApi, this._memberApi, this._storage);

  final AuthApiService _authApi;
  final MemberApiService _memberApi;
  final TokenStorage _storage;

  AuthStatus status = AuthStatus.initializing;
  MemberInfo? member;
  MemberLoadStatus memberStatus = MemberLoadStatus.idle;
  String? message;

  // 로그인·로그아웃·만료로 세션이 바뀔 때마다 올립니다. 이전 세션에서 늦게 온 응답을 버리는 기준입니다.
  int _sessionVersion = 0;
  int get sessionVersion => _sessionVersion;

  // 만료로 쫓겨난 경우에만 켜집니다. 로그인 화면이 Snackbar를 한 번 보여주고 끕니다.
  bool sessionExpired = false;
  bool storageCleanupInProgress = false;
  bool _disposed = false;
  Future<void>? _tokenWrite;

  bool _isCurrent(int version) => !_disposed && version == _sessionVersion;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // 앱 시작 시 저장된 토큰을 읽고, GET me로 서버 검증이 끝난 뒤에만 signedIn으로 바꿉니다.
  Future<void> restoreSession() async {
    if (storageCleanupInProgress || _disposed) return;
    final version = ++_sessionVersion;
    status = AuthStatus.initializing;
    message = null;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    _notify();
    try {
      final token = await _storage.readAccessToken();
      if (!_isCurrent(version)) return;
      if (token == null || token.isEmpty) {
        status = AuthStatus.signedOut;
      } else {
        final verified = await _memberApi.fetchMe();
        if (!_isCurrent(version)) return;
        member = verified;
        memberStatus = MemberLoadStatus.success;
        status = AuthStatus.signedIn;
      }
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      if (isSessionExpiredError(error)) {
        await _clearCurrentSession(expired: true);
        return;
      }
      // 네트워크가 잠깐 끊긴 것만으로 유효한 토큰을 지우지 않고 재시도하게 합니다.
      status = AuthStatus.retryRequired;
      message = '로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.';
    } catch (_) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.retryRequired;
      message = '인증 저장소를 읽지 못했어요. 다시 시도해 주세요.';
    }
    if (_isCurrent(version)) _notify();
  }

  // 신규 로그인: 로그인 성공 → 토큰 저장 → signedIn. 내 정보는 MainScreen이 loadMember()로 불러옵니다.
  Future<void> login(String email, String password) async {
    if (_disposed ||
        storageCleanupInProgress ||
        status == AuthStatus.authenticating) {
      return;
    }
    final version = ++_sessionVersion;
    status = AuthStatus.authenticating;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    sessionExpired = false;
    message = null;
    _notify();
    try {
      final result = await _authApi.login(
        LoginRequest(email: email, password: password),
      );
      if (!_isCurrent(version)) return;
      final writing = _storage.saveAccessToken(result.accessToken);
      _tokenWrite = writing;
      try {
        await writing;
      } finally {
        if (identical(_tokenWrite, writing)) _tokenWrite = null;
      }
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedIn;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedOut;
      // 로그인 입력 오류(AUTH401_1)는 Form 오류일 뿐, 만료 처리를 하지 않습니다.
      message = switch (apiErrorCode(error)) {
        'AUTH401_1' => '이메일 또는 비밀번호를 확인해 주세요.',
        'COMMON400' => apiErrorMessage(error) ?? '입력 형식을 확인해 주세요.',
        _ => '로그인 요청에 실패했어요. 잠시 후 다시 시도해 주세요.',
      };
    } catch (_) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedOut;
      message = '로그인 정보를 안전하게 저장하지 못했어요.';
    }
    _notify();
  }

  Future<void> loadMember({bool force = false}) async {
    if (status != AuthStatus.signedIn) return;
    if (memberStatus == MemberLoadStatus.loading) return;
    if (member != null && !force) return;

    final version = _sessionVersion;
    memberStatus = MemberLoadStatus.loading;
    message = null;
    _notify();
    try {
      final me = await _memberApi.fetchMe();
      if (!_isCurrent(version)) return;
      member = me;
      memberStatus = MemberLoadStatus.success;
    } catch (error) {
      if (!_isCurrent(version)) return;
      if (isSessionExpiredError(error)) {
        await _clearCurrentSession(expired: true);
        return;
      }
      // 네트워크 실패는 로그아웃하지 않고 재시도할 수 있게 남깁니다.
      memberStatus = MemberLoadStatus.error;
      message = '내 정보를 불러오지 못했어요.';
    }
    _notify();
  }

  // 프로필 수정 성공 result로 메모리의 내 정보만 교체합니다.
  void updateMember(MemberInfo updated) {
    if (_disposed || status != AuthStatus.signedIn) return;
    member = updated;
    memberStatus = MemberLoadStatus.success;
    _notify();
  }

  // 다른 ViewModel이 보호 요청에서 AUTH401_2/3/4를 받았을 때 부르는 공개 진입점입니다.
  // 요청을 시작한 세션 버전을 넘기면, 이미 다른 세션으로 바뀐 뒤 늦게 온 401은 무시합니다.
  // 동시에 여러 요청이 401을 받아도 이미 signedOut이면 다시 정리하지 않아 안내·이동이 한 번만 일어납니다.
  Future<void> expireSession({int? version}) async {
    if (version != null && version != _sessionVersion) return;
    if (status != AuthStatus.signedIn) return;
    await _clearCurrentSession(expired: true);
  }

  // 직접 로그아웃은 만료 Snackbar를 켜지 않습니다. 서버의 토큰 폐기를 보장하지는 않습니다.
  Future<void> logout() => _clearCurrentSession(expired: false);

  void consumeSessionExpired() {
    sessionExpired = false;
  }

  Future<void> _clearCurrentSession({required bool expired}) async {
    if (_disposed || storageCleanupInProgress) return;
    final version = ++_sessionVersion;
    storageCleanupInProgress = true;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    sessionExpired = expired;
    status = AuthStatus.signedOut;
    message = null;
    _notify();
    try {
      // 진행 중이던 토큰 저장이 끝난 뒤 지워야 삭제 후 다시 써지는 일이 없습니다.
      try {
        await _tokenWrite;
      } catch (_) {
        // 저장이 실패했어도 삭제는 시도합니다.
      }
      await _storage.deleteAccessToken();
    } catch (_) {
      if (_isCurrent(version)) {
        message = '저장된 인증 정보를 지우지 못했어요. 앱을 다시 실행하기 전에 확인해 주세요.';
      }
    } finally {
      storageCleanupInProgress = false;
      if (_isCurrent(version)) _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionVersion++;
    super.dispose();
  }
}
