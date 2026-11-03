// 입력창 validator와 가입 버튼 활성화 조건이 같은 규칙을 쓰도록 한 곳에서 관리합니다.
abstract final class SignUpValidators {
  static const nicknameMinLength = 2;
  static const passwordMinLength = 8;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? nickname(String? value) {
    final nickname = value?.trim() ?? '';
    if (nickname.isEmpty) return '닉네임을 입력해주세요.';
    if (nickname.length < nicknameMinLength) {
      return '닉네임은 두 글자 이상 입력해주세요.';
    }
    return null;
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return '이메일을 입력해주세요.';
    if (!_emailPattern.hasMatch(email)) return '올바른 이메일 형식이 아닙니다.';
    return null;
  }

  // 비밀번호는 공백도 문자로 취급하므로 trim 하지 않습니다.
  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return '비밀번호를 입력해주세요.';
    if (password.length < passwordMinLength) {
      return '비밀번호는 8자 이상 입력해주세요.';
    }
    return null;
  }
}
