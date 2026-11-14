/// POST /v6/members 요청 body.
class CreateMemberRequest {
  const CreateMemberRequest({
    required this.email,
    required this.password,
    required this.nickname,
  });

  final String email;
  final String password;
  final String nickname;

  /// 비밀번호는 사용자가 입력한 문자가 의미 있으므로 trim하지 않는다.
  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password,
    'nickname': nickname.trim(),
  };

  /// 비밀번호가 로그에 남지 않도록 toString에는 포함하지 않는다.
  @override
  String toString() => 'CreateMemberRequest(email: $email, nickname: $nickname)';
}
