import 'package:dio/dio.dart';

import '../core/network/api_error.dart';
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

// 서버 오류의 message는 이미 사용자에게 보여줄 문장이라, 공통 형식이면 그대로 씁니다.
String serverErrorMessage(Object error, {required String fallback}) {
  if (error is DioException) {
    final common = CommonResponse.tryParseError(error.response?.data);
    if (common != null) return common.message;
  }
  return loadErrorMessage(error, fallback: fallback);
}

String? serverErrorCode(Object error) =>
    error is DioException ? apiErrorCode(error) : null;

// v7 평점 쓰기 오류를 code별로 다음 행동이 드러나는 문구로 바꿉니다.
// 403은 권한 부족이라 안내만 하고 로그아웃하지 않습니다. (401 만료 처리는 호출한 쪽이 먼저 합니다.)
String ratingWriteErrorMessage(Object error, {required String fallback}) {
  return switch (serverErrorCode(error)) {
    'RATING403_1' => '본인이 작성한 평점만 수정하거나 삭제할 수 있어요.',
    'RATING404_1' => '이미 삭제됐거나 존재하지 않는 평점이에요.',
    'RATING409_1' => '이미 평점을 남긴 영화예요. 마이페이지의 "내가 등록한 평점"에서 확인해 주세요.',
    'MEMBER404_1' => '회원 정보를 찾을 수 없어요. 다시 로그인해 주세요.',
    _ => serverErrorMessage(error, fallback: fallback),
  };
}

// 쓰기 요청이 실패했을 때 Dialog가 입력을 유지한 채 안내 문구를 보여주도록 던지는 예외입니다.
class WriteFailure implements Exception {
  const WriteFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
