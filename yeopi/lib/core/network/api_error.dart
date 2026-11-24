import 'package:dio/dio.dart';

// 서버 오류 body({isSuccess, code, message, result})에서 code·message만 꺼냅니다.
// 네트워크 오류처럼 body가 없거나 형식이 다르면 null입니다.
String? apiErrorCode(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final code = data['code'];
  return code is String ? code : null;
}

String? apiErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final message = data['message'];
  return message is String ? message : null;
}

// 보호 요청에서 토큰이 없거나(2)·무효하거나(3)·만료된(4) 경우만 세션 만료로 봅니다.
// 로그인 입력 오류 AUTH401_1은 여기 포함하지 않습니다.
const sessionExpiredCodes = {'AUTH401_2', 'AUTH401_3', 'AUTH401_4'};

bool isSessionExpiredError(Object error) =>
    error is DioException && sessionExpiredCodes.contains(apiErrorCode(error));
