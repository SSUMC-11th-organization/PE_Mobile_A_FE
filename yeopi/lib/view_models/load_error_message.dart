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

// 빈 배열은 실패가 아니므로 여기 오지 않습니다. 400·404·그 외 실패를 서로 다른 문구로 나눕니다.
String myRatingsErrorMessage(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == 400) return 'memberId 형식을 다시 확인해 주세요.';
    if (status == 404) return '존재하지 않는 회원입니다.';
  }
  return loadErrorMessage(error, fallback: '평점을 불러오지 못했습니다.\n잠시 후 다시 시도해 주세요.');
}
