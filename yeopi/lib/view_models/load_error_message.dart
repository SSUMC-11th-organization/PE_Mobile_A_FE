import 'package:dio/dio.dart';

import '../data/models/common_response.dart';

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

// v6 오류의 message는 이미 사용자에게 보여줄 문장입니다. 같은 COMMON404라도 등록은 '유저', 수정·삭제는 '평점'을
// 가리키므로 code로 문구를 새로 만들지 않고 서버 message를 그대로 씁니다.
String serverErrorMessage(Object error, {required String fallback}) {
  if (error is DioException) {
    final common = CommonResponse.tryParseError(error.response?.data);
    if (common != null) return common.message;
  }
  return loadErrorMessage(error, fallback: fallback);
}

String? serverErrorCode(Object error) {
  if (error is! DioException) return null;
  return CommonResponse.tryParseError(error.response?.data)?.code;
}

// code는 문구가 아니라 다음 행동에만 씁니다. 403·404는 화면 목록이 서버와 어긋났다는 뜻이라 다시 조회합니다.
bool shouldRefreshAfterRatingError(Object error) {
  final code = serverErrorCode(error);
  return code == 'COMMON403' || code == 'COMMON404';
}

// 쓰기 요청이 실패했을 때 Dialog가 입력을 유지한 채 안내 문구를 보여주도록 던지는 예외입니다.
class WriteFailure implements Exception {
  const WriteFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
