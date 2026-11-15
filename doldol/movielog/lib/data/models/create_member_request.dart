class CreateMemberRequest {
  const CreateMemberRequest({
    required this.email,
    required this.password,
    required this.nickname,
  });

  final String email;
  final String password;
  final String nickname;

  Map<String, dynamic> toJson() => {
        'email': email.trim(),
        'password': password, // 비밀번호는 값을 바꾸지 않는다
        'nickname': nickname.trim(),
      };
}