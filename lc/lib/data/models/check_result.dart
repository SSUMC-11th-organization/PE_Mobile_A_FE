/// 닉네임·이메일 중복 확인 응답. v5는 공통 Wrapper가 없어 body가 곧 이 모양이다.
class CheckResult {
  const CheckResult({required this.available});

  final bool available;

  factory CheckResult.fromJson(Map<String, dynamic> json) {
    return CheckResult(available: json['available'] as bool);
  }
}
