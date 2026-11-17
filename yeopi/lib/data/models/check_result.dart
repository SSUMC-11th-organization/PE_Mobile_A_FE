// v5는 공통 응답 Wrapper가 없어서 { "available": true } 같은 body를 그대로 파싱합니다.
class CheckResult {
  const CheckResult({required this.available});

  final bool available;

  factory CheckResult.fromJson(Map<String, dynamic> json) {
    return CheckResult(available: json['available'] as bool);
  }
}
