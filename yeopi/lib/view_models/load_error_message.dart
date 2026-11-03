import 'package:dio/dio.dart';

// 예외 내용 대신 사용자가 할 수 있는 행동을 알려주는 문구로 바꿉니다.
String loadErrorMessage(Object error, {required String fallback}) {
  return switch (error) {
    DioException(
      type: DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout,
    ) =>
      '응답이 늦어지고 있어요.\n네트워크 상태를 확인하고 다시 시도해 주세요.',
    DioException(type: DioExceptionType.connectionError) =>
      '네트워크에 연결할 수 없어요.\n연결 상태를 확인하고 다시 시도해 주세요.',
    _ => fallback,
  };
}
