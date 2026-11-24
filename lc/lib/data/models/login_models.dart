/// POST /v8/auth/login 요청 body. 비밀번호는 입력 그대로 보내고 어디에도 저장하지 않는다.
class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {'email': email.trim(), 'password': password};

  /// 비밀번호가 로그에 남지 않도록 toString에는 포함하지 않는다.
  @override
  String toString() => 'LoginRequest(email: $email)';
}

/// 로그인 성공 응답의 result. memberId는 없다. (문서에 없는 field나 JWT claim을 추정하지 않는다.)
class LoginResult {
  const LoginResult({required this.nickname, required this.accessToken});

  final String nickname;
  final String accessToken;

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      nickname: json['nickname'] as String,
      accessToken: json['accessToken'] as String,
    );
  }

  /// 토큰 원문이 로그에 남지 않도록 toString에는 포함하지 않는다.
  @override
  String toString() => 'LoginResult(nickname: $nickname)';
}
