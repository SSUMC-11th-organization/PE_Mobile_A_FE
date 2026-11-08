import 'package:dio/dio.dart';

import '../models/common_response.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';

class RatingApiService {
  RatingApiService(this._dio);

  final Dio _dio;

  /// 성공(200)은 공통 응답이 아니라 직접 배열이다. 빈 배열은 실패가 아니다.
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _dio.get('/v6/members/$memberId/ratings');
    final list = response.data as List<dynamic>;
    return list
        .map((item) => RatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    final response = await _dio.post(
      '/v6/members/$memberId/ratings',
      data: request.toJson(),
    );
    // 201을 성공으로 처리한다. result가 숫자인지 null인지는 명세가 엇갈려 파싱하지 않고,
    // 성공 뒤 GET으로 목록을 다시 확인한다.
    if (response.statusCode != 201) {
      throw StateError('예상하지 못한 등록 응답: ${response.statusCode}');
    }
  }

  /// score는 필수이고, comment를 생략하면 기존 후기가 null로 덮인다.
  /// 그래서 유지/삭제 의도와 상관없이 comment 키를 항상 명시해서 보낸다.
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    await _dio.patch(
      '/v6/members/$memberId/ratings/$ratingId',
      data: {'score': score, 'comment': comment},
    );
  }

  /// 성공은 204라 body가 없다. response.data를 파싱하지 않는다.
  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    final response = await _dio.delete(
      '/v6/members/$memberId/ratings/$ratingId',
    );
    if (response.statusCode != 204) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

/// 서버 응답 body를 읽을 수 없을 때(통신 실패 등) 쓰는 상태 코드별 기본 문구.
String writeMyRatingsErrorMessage(DioException error) {
  final status = error.response?.statusCode;
  if (status == 400) return '요청 형식을 다시 확인해 주세요.';
  if (status == 403) return '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.';
  if (status == 404) return '존재하지 않는 회원입니다.';
  if (status == 409) return '이미 처리된 요청입니다. 목록을 다시 확인해 주세요.';
  return '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
}

/// 서버가 준 message를 우선 쓴다. 같은 COMMON404라도 등록에서는 "유저", 수정·삭제에서는
/// "평점"을 가리키므로 code만 보고 문구를 새로 만들지 않는다.
String writeErrorMessage(DioException error) {
  return readServerMessage(error) ?? writeMyRatingsErrorMessage(error);
}

/// 403·404는 화면의 목록이 서버 상태와 어긋났다는 뜻이므로 다시 조회해서 맞춘다.
/// 400(값 오류)과 409(중복 등록)는 같은 화면에서 값만 고치면 되므로 다시 조회하지 않는다.
bool shouldRefreshAfterRatingError(DioException error) {
  final code = readServerCode(error);
  return code == 'COMMON403' || code == 'COMMON404';
}
