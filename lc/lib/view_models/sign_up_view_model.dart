import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/create_member_request.dart';
import '../data/services/sign_up_service.dart';
import 'submit_status.dart';

export 'submit_status.dart' show SubmitStatus;

enum CheckStatus { idle, checking, available, duplicated, error }

/// 입력칸 하나의 중복 확인 상태. 닉네임과 이메일이 서로 영향을 주지 않도록 필드마다 하나씩 가진다.
class _FieldCheck {
  _FieldCheck({
    required this.targetName,
    required this.request,
    required this.onChanged,
    required this.isDisposed,
  });

  final String targetName;
  final Future<bool> Function(String value) request;
  final VoidCallback onChanged;
  final bool Function() isDisposed;

  CheckStatus status = CheckStatus.idle;
  String? errorText;

  /// 마지막으로 서버가 "중복"이라고 답한 값. 같은 값을 다시 입력하면 서버에 묻지 않고 복원한다.
  String? _duplicatedValue;
  String _currentValue = '';
  int _requestVersion = 0;

  bool get canCheck =>
      status != CheckStatus.checking && status != CheckStatus.duplicated;

  String get _duplicatedMessage => '이미 사용 중인 $targetName입니다.';

  void onValueChanged(String value) {
    final trimmed = value.trim();
    _currentValue = trimmed;
    _requestVersion++; // 이전 요청의 응답을 무효화한다.
    if (_duplicatedValue != null && trimmed == _duplicatedValue) {
      status = CheckStatus.duplicated;
      errorText = _duplicatedMessage;
    } else {
      status = CheckStatus.idle;
      errorText = null;
    }
    if (!isDisposed()) onChanged();
  }

  Future<void> check(String value) async {
    final requested = value.trim();
    if (requested.isEmpty || requested != _currentValue || !canCheck) return;

    final version = ++_requestVersion;
    status = CheckStatus.checking;
    errorText = null;
    onChanged();

    try {
      final available = await request(requested);
      if (_isStale(version, requested)) return;
      if (available) {
        status = CheckStatus.available;
        errorText = null;
      } else {
        status = CheckStatus.duplicated;
        errorText = _duplicatedMessage;
        _duplicatedValue = requested;
      }
    } catch (_) {
      // DioException뿐 아니라 응답 파싱 오류도 "checking"에 멈추지 않게 같은 실패로 다룬다.
      if (_isStale(version, requested)) return;
      // 통신 실패는 "중복"이 아니므로 다른 상태와 문구로 구분한다.
      status = CheckStatus.error;
      errorText = '중복 확인에 실패했습니다. 다시 시도해 주세요.';
    }
    if (!isDisposed() && version == _requestVersion) onChanged();
  }

  void invalidatePending() => _requestVersion++;

  bool _isStale(int version, String requested) =>
      isDisposed() || version != _requestVersion || _currentValue != requested;
}

class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._service) {
    _nickname = _FieldCheck(
      targetName: '닉네임',
      request: _service.checkNickname,
      onChanged: notifyListeners,
      isDisposed: () => _disposed,
    );
    _email = _FieldCheck(
      targetName: '이메일',
      request: _service.checkEmail,
      onChanged: notifyListeners,
      isDisposed: () => _disposed,
    );
  }

  final SignUpService _service;
  late final _FieldCheck _nickname;
  late final _FieldCheck _email;
  bool _disposed = false;

  CheckStatus get nicknameCheckStatus => _nickname.status;
  String? get nicknameErrorText => _nickname.errorText;
  bool get canCheckNickname => _nickname.canCheck;
  void onNicknameChanged(String value) => _nickname.onValueChanged(value);
  Future<void> checkNickname(String value) => _nickname.check(value);

  CheckStatus get emailCheckStatus => _email.status;
  String? get emailErrorText => _email.errorText;
  bool get canCheckEmail => _email.canCheck;
  void onEmailChanged(String value) => _email.onValueChanged(value);
  Future<void> checkEmail(String value) => _email.check(value);

  // ───────── 회원가입 제출 ─────────

  SubmitStatus submitStatus = SubmitStatus.idle;

  /// 가입 성공 응답(result.memberId)에서 읽은 실제 ID다.
  int? createdMemberId;

  /// 비밀번호 입력칸에 바로 붙일 수 있는 필드 단위 오류.
  String? passwordErrorText;

  /// 어느 입력칸에도 붙지 않는 화면 단위 오류(최종 중복 409 등). 화면이 한 번 꺼내 보여준다.
  String? snackbarMessage;

  bool get isSubmitting => submitStatus == SubmitStatus.submitting;

  /// 가입 조건 중 서버 확인에 해당하는 부분: 현재 닉네임·이메일이 모두 "사용 가능"으로 확인됐고
  /// 제출 중이 아니다. 로컬 Form 검증은 화면이 따로 확인한다.
  bool get isRemoteChecksPassed =>
      nicknameCheckStatus == CheckStatus.available &&
      emailCheckStatus == CheckStatus.available &&
      !isSubmitting;

  void onPasswordChanged() {
    passwordErrorText = null;
    if (!_disposed) notifyListeners();
  }

  /// 화면이 snackbarMessage를 보여준 뒤 같은 문구가 다시 뜨지 않도록 비운다.
  void consumeSnackbarMessage() => snackbarMessage = null;

  Future<void> submit(CreateMemberRequest request) async {
    if (isSubmitting) return;
    submitStatus = SubmitStatus.submitting;
    createdMemberId = null;
    passwordErrorText = null;
    snackbarMessage = null;
    notifyListeners();

    try {
      final response = await _service.signUp(request);
      final id = response.result?.memberId;
      // memberId가 없으면 가입을 완료한 것으로 표시하지 않고 계약 오류로 처리한다.
      if (id == null) throw StateError('회원가입 결과에 memberId가 없습니다.');
      createdMemberId = id;
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      submitStatus = SubmitStatus.error;
      final message = writeSignUpErrorMessage(error);
      // 400이라고 모두 비밀번호 문제는 아니다. 메시지에 비밀번호가 명시된 경우에만 입력칸에 붙인다.
      if (error.response?.statusCode == 400 && message.contains('비밀번호')) {
        passwordErrorText = message;
      } else {
        snackbarMessage = message;
      }
    } catch (_) {
      // StateError나 응답 파싱 오류에도 "제출 중"에 멈추지 않는다.
      submitStatus = SubmitStatus.error;
      snackbarMessage = '가입 결과를 확인하지 못했습니다. 새 요청 전에 서버 상태를 확인해 주세요.';
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _nickname.invalidatePending();
    _email.invalidatePending();
    super.dispose();
  }
}
