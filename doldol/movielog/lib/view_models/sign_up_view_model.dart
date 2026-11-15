import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../data/models/create_member_request.dart';
import '../data/services/sign_up_service.dart';
import '../utils/validators.dart';
import 'submit_status.dart';

enum CheckStatus { idle, checking, available, duplicated, error }

/// 입력 필드 하나의 중복 확인 상태 (닉네임, 이메일이 각각 따로 가진다)
class _FieldState {
  _FieldState({required this.validator, required this.duplicatedMessage});

  final String? Function(String?) validator;
  final String duplicatedMessage;

  CheckStatus status = CheckStatus.idle;
  String? errorText;
  String currentValue = '';
  String? duplicatedValue; // 마지막으로 "중복"이었던 값
  int requestVersion = 0;

  bool get canCheck =>
      status != CheckStatus.checking &&
      status != CheckStatus.duplicated &&
      validator(currentValue) == null;
}

class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._service);

  final SignUpService _service;

  final _nickname = _FieldState(
    validator: Validators.nickname,
    duplicatedMessage: '이미 사용 중인 닉네임입니다.',
  );
  final _email = _FieldState(
    validator: Validators.email,
    duplicatedMessage: '이미 사용 중인 이메일입니다.',
  );

  SubmitStatus submitStatus = SubmitStatus.idle;
  int? createdMemberId; // 가입 성공 응답에서 읽은 실제 ID
  String? passwordErrorText; // 400 중 비밀번호 오류 (필드 단위)
  String? snackbarMessage; // 그 외 400, 409 (화면 단위)

  bool _disposed = false;

  CheckStatus get nicknameCheckStatus => _nickname.status;
  String? get nicknameErrorText => _nickname.errorText;
  bool get canCheckNickname => _nickname.canCheck;

  CheckStatus get emailCheckStatus => _email.status;
  String? get emailErrorText => _email.errorText;
  bool get canCheckEmail => _email.canCheck;

  void onNicknameChanged(String value) => _onChanged(_nickname, value);
  void onEmailChanged(String value) => _onChanged(_email, value);

  void onPasswordChanged() {
    passwordErrorText = null;
    _clearSubmitFailure();
    _notify();
  }

  Future<void> checkNickname(String value) =>
      _check(_nickname, value, _service.checkNickname, '닉네임');
  Future<void> checkEmail(String value) =>
      _check(_email, value, _service.checkEmail, '이메일');

  Future<void> submit(CreateMemberRequest request) async {
    if (submitStatus == SubmitStatus.submitting) return; // 중복 탭 방지

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

      // 400 중 비밀번호 오류로 확인된 경우만 입력칸에 붙이고, 나머지는 Snackbar
      if (error.response?.statusCode == 400 && message.contains('비밀번호')) {
        passwordErrorText = message;
      } else {
        snackbarMessage = message;
      }
    } catch (error) {
      if (_disposed) return;

      debugPrint('[SignUpViewModel] 회원가입 결과 처리 실패: $error');
      submitStatus = SubmitStatus.error;
      snackbarMessage = '가입 결과를 확인하지 못했습니다. 새 요청 전에 서버 상태를 확인해 주세요.';
    }

    _notify();
  }

  void _onChanged(_FieldState field, String value) {
    final trimmed = value.trim();
    field.currentValue = trimmed;
    field.requestVersion++; // 기다리던 이전 응답을 무효화

    if (field.duplicatedValue != null && trimmed == field.duplicatedValue) {
      // 중복이었던 값을 다시 입력하면 API 재호출 없이 즉시 에러 상태
      field.status = CheckStatus.duplicated;
      field.errorText = field.duplicatedMessage;
    } else {
      field.status = CheckStatus.idle;
      field.errorText = null;
    }

    _clearSubmitFailure(); // 이전 제출 오류도 함께 무효화
    _notify();
  }

  Future<void> _check(
    _FieldState field,
    String value,
    Future<bool> Function(String) request,
    String name,
  ) async {
    final requested = value.trim();
    if (requested.isEmpty || requested != field.currentValue) return;
    if (!field.canCheck) return;

    final version = ++field.requestVersion;
    field.status = CheckStatus.checking;
    field.errorText = null;
    _notify();

    try {
      final available = await request(requested);
      if (_isStale(field, version, requested)) return;

      if (available) {
        field.status = CheckStatus.available;
        field.errorText = null;
      } else {
        field.status = CheckStatus.duplicated; // 서버의 정상 응답 (available: false)
        field.errorText = field.duplicatedMessage;
        field.duplicatedValue = requested;
      }
    } catch (error) {
      if (_isStale(field, version, requested)) return;

      debugPrint('[SignUpViewModel] $name 중복 확인 실패: $error');
      field.status = CheckStatus.error; // 통신 실패
      field.errorText = '중복 확인에 실패했습니다. 다시 시도해 주세요.';
    }
    _notify();
  }

  void _clearSubmitFailure() {
    if (submitStatus == SubmitStatus.error) {
      submitStatus = SubmitStatus.idle;
      snackbarMessage = null;
    }
  }

  bool _isStale(_FieldState field, int version, String requested) {
    return _disposed ||
        version != field.requestVersion ||
        field.currentValue != requested;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _nickname.requestVersion++;
    _email.requestVersion++;
    super.dispose();
  }
}