// v6 쓰기 API의 성공 응답과 모든 오류 응답이 쓰는 공통 형식입니다. result는 API마다 달라 제네릭으로 둡니다.
class CommonResponse<T> {
  const CommonResponse({
    required this.isSuccess,
    required this.code,
    required this.message,
    this.result,
  });

  final bool isSuccess;
  final String code;
  final String message;
  final T? result;

  factory CommonResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? value) parseResult,
  ) {
    final rawResult = json['result'];
    return CommonResponse<T>(
      isSuccess: json['isSuccess'] as bool,
      code: json['code'] as String,
      message: json['message'] as String,
      result: rawResult == null ? null : parseResult(rawResult),
    );
  }

  // 오류 응답 body가 공통 형식이 아니면(네트워크 오류 등) null을 돌려줍니다.
  static CommonResponse<Object?>? tryParseError(Object? data) {
    if (data is! Map<String, dynamic>) return null;
    if (data['code'] is! String || data['message'] is! String) return null;
    return CommonResponse<Object?>.fromJson({
      'isSuccess': data['isSuccess'] ?? false,
      ...data,
    }, (value) => value);
  }
}
