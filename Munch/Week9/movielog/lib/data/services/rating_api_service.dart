import 'package:dio/dio.dart';

import '../../core/network/api_error.dart';
import '../models/common_response.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';

RatingDto parseRatingResult(Object? data) {
  if (data is! Map<String, dynamic>) {
    throw StateError('평점 응답 형식이 올바르지 않습니다.');
  }
  final common = CommonResponse<RatingDto>.fromJson(
    data,
    (value) => RatingDto.fromJson(value as Map<String, dynamic>),
  );
  final rating = common.result;
  if (rating == null) throw StateError('평점 result가 없습니다.');
  return rating;
}

List<RatingDto> parseRatingList(Object? data) {
  if (data is! List) throw StateError('평점 목록 응답은 배열이어야 합니다.');
  return data
      .map((value) => RatingDto.fromJson(value as Map<String, dynamic>))
      .toList();
}

class RatingApiService {
  RatingApiService(this._publicDio, this._authDio);

  final Dio _publicDio;
  final Dio _authDio;

  Future<List<RatingDto>> fetchMemberRatings(int memberId) async {
    final response = await _publicDio.get('/v8/members/$memberId/ratings');
    return parseRatingList(response.data);
  }

  Future<RatingDto> createRating(CreateRatingRequest request) async {
    final response = await _authDio.post('/v8/ratings', data: request.toJson());
    return parseRatingResult(response.data);
  }

  // PATCH는 전체 교체이므로 comment를 생략하면 기존 후기가 null이 된다.
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final response = await _authDio.patch(
      '/v8/ratings/$ratingId',
      data: {'score': score, 'comment': comment},
    );
    return parseRatingResult(response.data);
  }

  Future<void> deleteRating(int ratingId) async {
    final response = await _authDio.delete('/v8/ratings/$ratingId');
    if (response.statusCode != 200) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

String ratingErrorMessage(DioException error) {
  return switch (apiErrorCode(error)) {
    'AUTH401_2' || 'AUTH401_3' || 'AUTH401_4' => '로그인이 만료됐어요. 다시 로그인해 주세요.',
    'RATING403_1' => '본인이 작성한 평점만 수정하거나 삭제할 수 있어요.',
    'RATING404_1' => '이미 삭제된 평점이에요.',
    'RATING409_1' => '이미 이 영화에 평점을 남겼어요. 내가 등록한 평점에서 확인해 주세요.',
    'MEMBER404_1' => '회원 정보를 찾을 수 없어요.',
    'COMMON400' => apiErrorMessage(error) ?? '입력값을 다시 확인해 주세요.',
    _ => '요청에 실패했어요. 잠시 후 다시 시도해 주세요.',
  };
}
