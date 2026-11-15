import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/storage/token_storage.dart';
import '../data/models/login_models.dart';
import '../data/models/member_info.dart';
import '../data/services/auth_api_service.dart';
import '../data/services/member_api_service.dart';

/// initializing: 앱 시작 후 저장된 토큰을 확인하는 중
/// signedOut: 로그인 안 됨 / authenticating: 로그인 요청 중 / signedIn: 로그인됨
/// retryRequired: 세션 확인에 실패(네트워크 등). 토큰은 지우지 않고 다시 시도하게 한다.
enum AuthStatus {
  initializing,
  signedOut,
  authenticating,
  signedIn,
  retryRequired,
}

enum MemberLoadStatus { idle, loading, success, error }

/// 앱 전체의 인증 상태. 화면 이동은 직접 하지 않고, Router가 이 상태를 보고 결정한다.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._authApi, this._memberApi, this._storage);

  final AuthApiService _authApi;
  final MemberApiService _memberApi;
  final TokenStorage _storage;

  AuthStatus status = AuthStatus.initializing;
  MemberInfo? member;
  MemberLoadStatus memberStatus = MemberLoadStatus.idle;
  String? message;

  /// 로그인·로그아웃·만료마다 올라간다. 이전 세션에서 늦게 온 응답을 버리는 기준이다.
  int _sessionVersion = 0;
  int get sessionVersion => _sessionVersion;

  /// 토큰 만료·무효로 로그아웃됐을 때만 켜진다. 로그인 화면이 한 번 안내하고 끈다.
  bool sessionExpired = false;
  bool storageCleanupInProgress = false;
  bool _disposed = false;
  Future<void>? _tokenWrite;

  bool _isCurrent(int version) => !_disposed && version == _sessionVersion;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// 앱 시작 시: 저장된 토큰을 읽고 GET me로 서버 검증이 끝난 뒤에만 signedIn으로 확정한다.
  /// 토큰 문자열이 있다는 이유만으로 로그인 상태로 보지 않는다.
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
        final verifiedMember = await _memberApi.fetchMe();
        if (!_isCurrent(version)) return;
        member = verifiedMember;
        memberStatus = MemberLoadStatus.success;
        status = AuthStatus.signedIn;
      }
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      if (isSessionExpiredError(error)) {
        await _clearCurrentSession(expired: true);
        return;
      }
      // 네트워크가 잠시 끊겼다고 유효한 토큰을 지우지 않는다.
      status = AuthStatus.retryRequired;
      message = '로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.';
    } catch (_) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.retryRequired;
      message = '인증 저장소를 읽지 못했어요. 다시 시도해 주세요.';
    }
    if (_isCurrent(version)) _notify();
  }

  /// 신규 로그인: 로그인 API 성공 → 토큰 저장 → signedIn. 내 정보는 MainScreen이 loadMember()로 불러온다.
  Future<void> login(String email, String password) async {
    if (_disposed ||
        storageCleanupInProgress ||
        status == AuthStatus.authenticating) {
      return;
    }
    status = AuthStatus.authenticating;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    sessionExpired = false;
    message = null;
    final version = ++_sessionVersion;
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
      // AUTH401_1은 로그인 입력 오류다. 세션 만료 처리(전역 로그아웃 안내)와 섞지 않는다.
      message = apiErrorCode(error) == 'AUTH401_1'
          ? '이메일 또는 비밀번호를 확인해 주세요.'
          : '로그인 요청에 실패했어요. 잠시 후 다시 시도해 주세요.';
    } catch (_) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedOut;
      message = '로그인 정보를 안전하게 저장하지 못했어요.';
    }
    _notify();
  }

  /// 내 정보를 불러와 보관한다. 이미 들고 있으면([force]가 아니면) 다시 호출하지 않는다.
  Future<void> loadMember({bool force = false}) async {
    if (_disposed || status != AuthStatus.signedIn) return;
    if (memberStatus == MemberLoadStatus.loading) return;
    if (member != null && !force) return;

    final version = _sessionVersion;
    memberStatus = MemberLoadStatus.loading;
    _notify();

    try {
      final me = await _memberApi.fetchMe();
      if (!_isCurrent(version)) return; // 로그아웃·계정 전환 뒤 늦게 온 응답은 버린다.
      member = me;
      memberStatus = MemberLoadStatus.success;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      if (isSessionExpiredError(error)) {
        await _clearCurrentSession(expired: true);
        return;
      }
      memberStatus = MemberLoadStatus.error; // 네트워크 실패: 로그아웃하지 않고 재시도 가능
      message = '내 정보를 불러오지 못했어요.';
    } catch (_) {
      if (!_isCurrent(version)) return;
      memberStatus = MemberLoadStatus.error;
      message = '내 정보를 불러오지 못했어요.';
    }
    _notify();
  }

  /// 프로필 수정 성공 응답으로 메모리의 내 정보를 교체한다. GET me를 다시 호출하지 않는다.
  void updateMember(MemberInfo updated) {
    if (_disposed || status != AuthStatus.signedIn) return;
    member = updated;
    _notify();
  }

  /// 다른 ViewModel이 보호 요청에서 AUTH401_2/3/4를 받았을 때 세션 정리를 요청하는 진입점.
  /// 동시에 여러 요청이 401을 받아도 정리·안내는 한 번만 일어난다.
  Future<void> expireSession() => _clearCurrentSession(expired: true);

  /// 직접 로그아웃. 저장소와 메모리를 함께 비우지만 만료 안내는 켜지 않는다.
  /// 클라이언트 세션만 비우며, 서버에서 토큰이 즉시 폐기된다고 보장하지는 않는다.
  Future<void> logout() => _clearCurrentSession(expired: false);

  void consumeSessionExpired() {
    sessionExpired = false;
  }

  Future<void> _clearCurrentSession({required bool expired}) async {
    if (_disposed || storageCleanupInProgress) return;
    // 이미 로그아웃됐거나 새 로그인이 진행 중이면, 이전 세션에서 늦게 도착한 401이
    // 만료 안내를 다시 켜거나 새 세션을 지우지 않게 한다.
    if (status == AuthStatus.signedOut || status == AuthStatus.authenticating) {
      return;
    }
    final version = ++_sessionVersion;
    storageCleanupInProgress = true;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    sessionExpired = expired;
    status = AuthStatus.signedOut;
    message = null;
    _notify();
    try {
      // 진행 중이던 토큰 저장을 기다린 뒤 삭제한다. 정리 중에는 새 로그인을 막는다.
      try {
        await _tokenWrite;
      } catch (_) {
        // 저장이 실패했더라도 삭제는 시도한다.
      }
      await _storage.deleteAccessToken();
    } catch (_) {
      if (_isCurrent(version)) {
        message = '저장된 인증 정보를 지우지 못했어요. 앱 재실행 전에 저장소 상태를 확인해 주세요.';
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
