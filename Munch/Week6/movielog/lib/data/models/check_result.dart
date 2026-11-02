/// v5 닉네임·이메일 중복 체크 응답 `{ "available": true }`.
///
/// v5는 공통 Wrapper가 없으므로 응답 body를 그대로 파싱한다.
class CheckResult {
  const CheckResult({required this.available});

  final bool available;

  factory CheckResult.fromJson(Map<String, dynamic> json) {
    return CheckResult(available: json['available'] as bool);
  }
}
