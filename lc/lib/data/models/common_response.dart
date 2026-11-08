import 'package:dio/dio.dart';

/// v6의 공통 응답 { isSuccess, code, message, result }.
/// result는 API마다 담기는 값이 다르므로 제네릭 T로 표현하고, 값이 없거나 실패 응답이면 null이다.
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
}

/// 실패 응답 body에서 서버가 준 안내 문구(message)를 꺼낸다. 읽을 수 없으면 null이다.
/// v6 공통 형식이 아닌 프레임워크 기본 오류({message, error, statusCode})도 message만 읽는다.
String? readServerMessage(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  try {
    return CommonResponse<Object?>.fromJson(data, (value) => value).message;
  } catch (_) {
    final message = data['message'];
    return message is String && message.isNotEmpty ? message : null;
  }
}

/// 실패 응답 body에서 공통 오류 code(예: COMMON409)를 꺼낸다. 없으면 null이다.
String? readServerCode(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final code = data['code'];
  return code is String ? code : null;
}
