abstract final class Validators {
  static final _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _lower = RegExp(r'[a-z]');
  static final _upper = RegExp(r'[A-Z]');
  static final _digit = RegExp(r'[0-9]');
  static final _special = RegExp(r'[!@#$%^&*]');

  static String? nickname(String? value) {
    final nickname = value?.trim() ?? '';
    if (nickname.isEmpty) return '닉네임을 입력해주세요.';
    if (nickname.length < 2 || nickname.length > 12) {
      return '닉네임은 2~12자로 입력해주세요.';
    }
    return null;
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return '이메일을 입력해주세요.';
    if (!_emailRegExp.hasMatch(email)) return '올바른 이메일 형식이 아닙니다.';
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return '비밀번호를 입력해주세요.';
    if (password != password.trim()) return '비밀번호 앞뒤에 공백을 넣을 수 없습니다.';

    final valid = password.length >= 8 &&
        _lower.hasMatch(password) &&
        _upper.hasMatch(password) &&
        _digit.hasMatch(password) &&
        _special.hasMatch(password);
    if (!valid) {
      return r'비밀번호는 8자 이상이며 대문자·소문자·숫자·특수문자(!@#$%^&*)를 각각 포함해야 합니다.';
    }
    return null;
  }
}