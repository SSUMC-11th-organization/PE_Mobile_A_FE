class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  // 비밀번호는 공백까지 그대로 보내고, 이 객체를 로그로 찍지 않습니다.
  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password,
  };
}

// v7 로그인 result에는 memberId가 없습니다. JWT payload에서 꺼내는 것도 명세에 없어서 하지 않습니다.
class LoginResult {
  const LoginResult({required this.nickname, required this.accessToken});

  final String nickname;
  final String accessToken;

  factory LoginResult.fromJson(Map<String, dynamic> json) => LoginResult(
    nickname: json['nickname'] as String,
    accessToken: json['accessToken'] as String,
  );
}
