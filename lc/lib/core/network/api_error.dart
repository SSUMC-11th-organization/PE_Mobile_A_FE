import 'package:dio/dio.dart';

/// 실패 응답 body에서 서버 오류 code(예: AUTH401_3, RATING409_1)를 꺼낸다. 없으면 null이다.
String? apiErrorCode(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final code = data['code'];
  return code is String ? code : null;
}

/// 실패 응답 body에서 서버 안내 문구(message)를 꺼낸다. 없으면 null이다.
String? apiErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final message = data['message'];
  return message is String ? message : null;
}

/// 보호 요청에서 토큰이 없거나(2) 무효이거나(3) 만료된(4) 경우. 현재 세션을 정리해야 한다.
/// 로그인 입력 오류인 AUTH401_1과 권한 부족인 403은 여기에 포함하지 않는다.
bool isSessionExpiredError(DioException error) {
  final code = apiErrorCode(error);
  return code == 'AUTH401_2' || code == 'AUTH401_3' || code == 'AUTH401_4';
}
