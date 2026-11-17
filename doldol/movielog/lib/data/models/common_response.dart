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
  final T? result; // 값이 없거나 실패 응답이면 null

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
}

/// 오류 응답 body에서 사용자에게 보여줄 message를 꺼낸다.
/// 형식이 달라도 오류 처리 중에 또 오류가 나지 않도록 안전하게 읽는다.
String? readServerMessage(Object? data) {
  if (data is! Map) return null;
  final message = data['message'];

  if (message is String && message.isNotEmpty) return message;
  if (message is List) {
    for (final item in message) {
      if (item is String && item.isNotEmpty) return item;
    }
  }
  return null;
}

/// 오류 응답 body의 code (예: COMMON403)
String? readServerCode(Object? data) {
  if (data is! Map) return null;
  final code = data['code'];
  return code is String ? code : null;
}