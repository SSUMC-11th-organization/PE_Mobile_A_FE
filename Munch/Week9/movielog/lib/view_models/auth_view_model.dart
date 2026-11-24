import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/storage/token_storage.dart';
import '../data/models/login_models.dart';
import '../data/models/member_info.dart';
import '../data/services/auth_api_service.dart';
import '../data/services/member_api_service.dart';
import 'session_rating_store.dart';

enum AuthStatus {
  initializing,
  signedOut,
  authenticating,
  signedIn,
  retryRequired,
}

enum MemberLoadStatus { idle, loading, success, error }

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(
    this._authApi,
    this._memberApi,
    this._storage,
    this._sessionRatings,
  );

  final AuthApiService _authApi;
  final MemberApiService _memberApi;
  final TokenStorage _storage;
  final SessionRatingStore _sessionRatings;

  AuthStatus status = AuthStatus.initializing;
  MemberInfo? member;
  MemberLoadStatus memberStatus = MemberLoadStatus.idle;
  String? message;
  bool sessionExpired = false;
  bool storageCleanupInProgress = false;

  int _sessionVersion = 0;
  int get sessionVersion => _sessionVersion;
  bool _disposed = false;
  Future<void>? _tokenWrite;

  bool _isCurrent(int version) => !_disposed && version == _sessionVersion;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

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
      if (isSessionExpired(error)) {
        await _clearCurrentSession(expired: true);
        return;
      }
      // 네트워크 실패로 유효한 토큰을 지우지 않고 재시도 상태로 둔다.
      status = AuthStatus.retryRequired;
      message = '로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.';
    } catch (_) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.retryRequired;
      message = '인증 저장소를 읽지 못했어요. 다시 시도해 주세요.';
    }
    if (_isCurrent(version)) _notify();
  }

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
    _sessionRatings.clear();
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
      // 신규 로그인은 토큰 저장 후 signedIn, 내 정보는 MainScreen의 loadMember()가 불러온다.
      status = AuthStatus.signedIn;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedOut;
      message = switch (apiErrorCode(error)) {
        'AUTH401_1' => '이메일 또는 비밀번호를 확인해 주세요.',
        'COMMON400' => apiErrorMessage(error) ?? '입력값을 다시 확인해 주세요.',
        _ => '로그인 요청에 실패했어요. 잠시 후 다시 시도해 주세요.',
      };
    } catch (_) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedOut;
      message = '로그인 정보를 안전하게 저장하지 못했어요.';
    }
    _notify();
  }

  void clearMessage() {
    if (message == null) return;
    message = null;
    _notify();
  }

  Future<void> loadMember({bool force = false}) async {
    if (_disposed || status != AuthStatus.signedIn) return;
    if (memberStatus == MemberLoadStatus.loading) return;
    if (member != null && !force) return;

    final version = _sessionVersion;
    memberStatus = MemberLoadStatus.loading;
    _notify();

    try {
      final me = await _memberApi.fetchMe();
      if (!_isCurrent(version)) return;
      member = me;
      memberStatus = MemberLoadStatus.success;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      if (isSessionExpired(error)) {
        await _clearCurrentSession(expired: true);
        return;
      }
      memberStatus = MemberLoadStatus.error;
    } catch (_) {
      if (!_isCurrent(version)) return;
      memberStatus = MemberLoadStatus.error;
    }
    _notify();
  }

  void updateMember(MemberInfo updated) {
    if (_disposed || status != AuthStatus.signedIn) return;
    member = updated;
    _notify();
  }

  Future<void> expireSession() => _clearCurrentSession(expired: true);

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
    _sessionRatings.clear();
    _notify();
    try {
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
