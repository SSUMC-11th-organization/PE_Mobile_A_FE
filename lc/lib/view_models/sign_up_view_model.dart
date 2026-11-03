import 'package:flutter/foundation.dart';

import '../data/services/member_check_service.dart';

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

  final MemberCheckService _service;
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

  @override
  void dispose() {
    _disposed = true;
    _nickname.invalidatePending();
    _email.invalidatePending();
    super.dispose();
  }
}
