import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/services/member_check_service.dart';

/// 중복 확인 한 건의 상태.
/// - idle: 아직 확인하지 않았거나, 입력이 바뀌어 이전 결과가 무효화됨
/// - checking: 요청 진행 중
/// - available: 서버가 사용 가능하다고 응답
/// - duplicated: 서버가 이미 사용 중이라고 응답 (정상 응답)
/// - error: 통신 자체가 실패 (DioException)
enum CheckStatus { idle, checking, available, duplicated, error }

/// 회원가입 화면 전용 ViewModel.
///
/// 닉네임과 이메일은 서로 영향을 주지 않도록 상태·요청 버전·현재 입력값을
/// 필드별로 따로 관리한다.
class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._service);

  final MemberCheckService _service;

  bool _disposed = false;

  // ---------------------------------------------------------------- 닉네임
  CheckStatus nicknameCheckStatus = CheckStatus.idle;
  String? nicknameErrorText;

  /// 마지막으로 서버가 "중복"이라고 응답한 닉네임 (챌린지 미션).
  String? _duplicatedNickname;
  String _currentNickname = '';
  int _nicknameRequestVersion = 0;

  /// 통신 중이거나, 현재 값이 이미 중복으로 확인된 값이면 누를 수 없다.
  bool get canCheckNickname =>
      nicknameCheckStatus != CheckStatus.checking &&
      nicknameCheckStatus != CheckStatus.duplicated;

  bool get isNicknameAvailable => nicknameCheckStatus == CheckStatus.available;

  void onNicknameChanged(String value) {
    final trimmed = value.trim();
    // 공백만 바뀐 경우는 같은 값이므로 기존 결과를 유지한다.
    if (trimmed == _currentNickname) return;

    _currentNickname = trimmed;
    _nicknameRequestVersion++; // 기다리던 이전 요청의 응답을 무효화한다.

    if (_duplicatedNickname != null && trimmed == _duplicatedNickname) {
      // 방금 중복이었던 값과 같으면 서버에 다시 묻지 않고 즉시 에러로 복원한다.
      nicknameCheckStatus = CheckStatus.duplicated;
      nicknameErrorText = _nicknameDuplicatedMessage;
    } else {
      nicknameCheckStatus = CheckStatus.idle;
      nicknameErrorText = null;
    }
    _notify();
  }

  Future<void> checkNickname(String value) async {
    final requested = value.trim();
    if (requested.isEmpty ||
        requested != _currentNickname ||
        !canCheckNickname) {
      return;
    }

    final version = ++_nicknameRequestVersion;
    nicknameCheckStatus = CheckStatus.checking;
    nicknameErrorText = null;
    _notify();

    bool isStale() =>
        _disposed ||
        version != _nicknameRequestVersion ||
        _currentNickname != requested;

    try {
      final available = await _service.checkNickname(requested);
      if (isStale()) return;
      if (available) {
        nicknameCheckStatus = CheckStatus.available;
        nicknameErrorText = null;
      } else {
        nicknameCheckStatus = CheckStatus.duplicated;
        nicknameErrorText = _nicknameDuplicatedMessage;
        _duplicatedNickname = requested;
      }
    } on DioException {
      if (isStale()) return;
      nicknameCheckStatus = CheckStatus.error;
      nicknameErrorText = _networkErrorMessage;
    }
    _notify();
  }

  // ---------------------------------------------------------------- 이메일
  CheckStatus emailCheckStatus = CheckStatus.idle;
  String? emailErrorText;

  /// 마지막으로 서버가 "중복"이라고 응답한 이메일 (챌린지 미션).
  String? _duplicatedEmail;
  String _currentEmail = '';
  int _emailRequestVersion = 0;

  bool get canCheckEmail =>
      emailCheckStatus != CheckStatus.checking &&
      emailCheckStatus != CheckStatus.duplicated;

  bool get isEmailAvailable => emailCheckStatus == CheckStatus.available;

  void onEmailChanged(String value) {
    final trimmed = value.trim();
    if (trimmed == _currentEmail) return;

    _currentEmail = trimmed;
    _emailRequestVersion++;

    if (_duplicatedEmail != null && trimmed == _duplicatedEmail) {
      emailCheckStatus = CheckStatus.duplicated;
      emailErrorText = _emailDuplicatedMessage;
    } else {
      emailCheckStatus = CheckStatus.idle;
      emailErrorText = null;
    }
    _notify();
  }

  Future<void> checkEmail(String value) async {
    final requested = value.trim();
    if (requested.isEmpty || requested != _currentEmail || !canCheckEmail) {
      return;
    }

    final version = ++_emailRequestVersion;
    emailCheckStatus = CheckStatus.checking;
    emailErrorText = null;
    _notify();

    bool isStale() =>
        _disposed ||
        version != _emailRequestVersion ||
        _currentEmail != requested;

    try {
      final available = await _service.checkEmail(requested);
      if (isStale()) return;
      if (available) {
        emailCheckStatus = CheckStatus.available;
        emailErrorText = null;
      } else {
        emailCheckStatus = CheckStatus.duplicated;
        emailErrorText = _emailDuplicatedMessage;
        _duplicatedEmail = requested;
      }
    } on DioException {
      if (isStale()) return;
      emailCheckStatus = CheckStatus.error;
      emailErrorText = _networkErrorMessage;
    }
    _notify();
  }

  // ---------------------------------------------------------------- 공통
  static const _nicknameDuplicatedMessage = '이미 사용 중인 닉네임입니다.';
  static const _emailDuplicatedMessage = '이미 사용 중인 이메일입니다.';
  static const _networkErrorMessage = '중복 확인에 실패했습니다. 다시 시도해 주세요.';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // 화면을 떠난 뒤 도착한 응답도 무시되도록 버전을 올린다.
    _nicknameRequestVersion++;
    _emailRequestVersion++;
    super.dispose();
  }
}
