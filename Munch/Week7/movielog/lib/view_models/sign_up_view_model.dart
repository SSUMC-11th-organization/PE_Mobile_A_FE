import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/create_member_request.dart';
import '../data/services/sign_up_service.dart';

enum CheckStatus { idle, checking, available, duplicated, error }

enum SubmitStatus { idle, submitting, success, error }

class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._service);

  final SignUpService _service;

  bool _disposed = false;

  CheckStatus nicknameCheckStatus = CheckStatus.idle;
  String? nicknameErrorText;

  String? _duplicatedNickname;
  String _currentNickname = '';
  int _nicknameRequestVersion = 0;

  bool get canCheckNickname =>
      nicknameCheckStatus != CheckStatus.checking &&
      nicknameCheckStatus != CheckStatus.duplicated;

  bool get isNicknameAvailable => nicknameCheckStatus == CheckStatus.available;

  void onNicknameChanged(String value) {
    final trimmed = value.trim();
    if (trimmed == _currentNickname) return;

    _currentNickname = trimmed;
    snackbarMessage = null;
    _nicknameRequestVersion++; // 기다리던 이전 요청의 응답을 무효화한다.

    if (_duplicatedNickname != null && trimmed == _duplicatedNickname) {
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

  CheckStatus emailCheckStatus = CheckStatus.idle;
  String? emailErrorText;

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
    snackbarMessage = null;
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

  SubmitStatus submitStatus = SubmitStatus.idle;
  int? createdMemberId;
  String? passwordErrorText;
  String? snackbarMessage;

  void onPasswordChanged() {
    passwordErrorText = null;
    _notify();
  }

  Future<void> submit(CreateMemberRequest request) async {
    if (submitStatus == SubmitStatus.submitting) return;

    submitStatus = SubmitStatus.submitting;
    createdMemberId = null;
    passwordErrorText = null;
    snackbarMessage = null;
    _notify();

    try {
      final response = await _service.signUp(request);
      if (_disposed) return;
      final id = response.result?.memberId;
      if (id == null) throw StateError('회원가입 결과에 memberId가 없습니다.');
      createdMemberId = id;
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      final message = writeSignUpErrorMessage(error);
      if (error.response?.statusCode == 400 && message.contains('비밀번호')) {
        passwordErrorText = message;
      } else {
        snackbarMessage = message;
      }
    } on StateError {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      snackbarMessage = '가입 결과를 확인하지 못했습니다. 새 요청 전에 서버 상태를 확인해 주세요.';
    }
    _notify();
  }

  static const _nicknameDuplicatedMessage = '이미 사용 중인 닉네임입니다.';
  static const _emailDuplicatedMessage = '이미 사용 중인 이메일입니다.';
  static const _networkErrorMessage = '중복 확인에 실패했습니다. 다시 시도해 주세요.';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _nicknameRequestVersion++;
    _emailRequestVersion++;
    super.dispose();
  }
}
