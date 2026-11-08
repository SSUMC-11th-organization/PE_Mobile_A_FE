import 'package:flutter/foundation.dart';

import '../data/services/member_check_service.dart';
import '../utils/sign_up_validators.dart';

enum CheckStatus { idle, checking, available, duplicated, error }

// 닉네임과 이메일이 서로의 결과에 영향을 주지 않도록 입력란마다 상태를 따로 둡니다.
class _CheckField {
  _CheckField({
    required this.validator,
    required this.request,
    required this.duplicatedMessage,
  });

  final String? Function(String?) validator;
  final Future<bool> Function(String value) request;
  final String duplicatedMessage;

  CheckStatus status = CheckStatus.idle;
  String? errorText;
  String current = '';
  int requestVersion = 0;

  // '마지막으로 확인한 값'과 별개로, 서버가 마지막으로 중복이라고 답한 값을 기억합니다.
  String? duplicatedValue;

  // 형식이 맞지 않는 값은 물어볼 필요가 없고, 중복이었던 값은 바꾸기 전까지 다시 묻지 않습니다.
  bool get canCheck =>
      status != CheckStatus.checking &&
      status != CheckStatus.duplicated &&
      validator(current) == null;
}

class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(MemberCheckService service) {
    _nickname = _CheckField(
      validator: SignUpValidators.nickname,
      request: service.checkNickname,
      duplicatedMessage: '이미 사용 중인 닉네임입니다.',
    );
    _email = _CheckField(
      validator: SignUpValidators.email,
      request: service.checkEmail,
      duplicatedMessage: '이미 사용 중인 이메일입니다.',
    );
  }

  late final _CheckField _nickname;
  late final _CheckField _email;
  bool _disposed = false;

  CheckStatus get nicknameCheckStatus => _nickname.status;
  String? get nicknameErrorText => _nickname.errorText;
  bool get canCheckNickname => _nickname.canCheck;

  CheckStatus get emailCheckStatus => _email.status;
  String? get emailErrorText => _email.errorText;
  bool get canCheckEmail => _email.canCheck;

  bool get isNicknameAvailable => _nickname.status == CheckStatus.available;
  bool get isEmailAvailable => _email.status == CheckStatus.available;

  void onNicknameChanged(String value) => _onChanged(_nickname, value);
  void onEmailChanged(String value) => _onChanged(_email, value);

  Future<void> checkNickname(String value) => _check(_nickname, value);
  Future<void> checkEmail(String value) => _check(_email, value);

  // 입력이 바뀌면 이전 확인 결과는 더 이상 이 값에 대한 결과가 아니므로 바로 지웁니다.
  // 단, 방금 중복이었던 값으로 되돌아오면 서버에 묻지 않고 중복 에러를 즉시 복원합니다.
  // (서버 상태가 바뀌었을 수 있으므로 최종 판단은 회원가입 POST의 409입니다.)
  void _onChanged(_CheckField field, String value) {
    final trimmed = value.trim();
    if (trimmed == field.current) return;
    field.current = trimmed;
    field.requestVersion++; // 기다리던 이전 요청의 응답을 무효화합니다.
    if (trimmed == field.duplicatedValue) {
      field.status = CheckStatus.duplicated;
      field.errorText = field.duplicatedMessage;
    } else {
      field.status = CheckStatus.idle;
      field.errorText = null;
    }
    _notify();
  }

  Future<void> _check(_CheckField field, String value) async {
    final requested = value.trim();
    if (requested != field.current || !field.canCheck) return;

    final version = ++field.requestVersion;
    field.status = CheckStatus.checking;
    field.errorText = null;
    _notify();

    try {
      final available = await field.request(requested);
      if (_isStale(field, version, requested)) return;
      field.status = available ? CheckStatus.available : CheckStatus.duplicated;
      field.errorText = available ? null : field.duplicatedMessage;
      if (!available) field.duplicatedValue = requested;
    } catch (error) {
      if (_isStale(field, version, requested)) return;
      // 서버가 '중복'이라고 답한 것과 통신 자체가 실패한 것은 다른 상태·문구로 구분합니다.
      debugPrint('중복 확인 실패: $error');
      field.status = CheckStatus.error;
      field.errorText = '중복 확인에 실패했습니다. 다시 시도해 주세요.';
    }
    _notify();
  }

  bool _isStale(_CheckField field, int version, String requested) =>
      _disposed ||
      version != field.requestVersion ||
      field.current != requested;

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
