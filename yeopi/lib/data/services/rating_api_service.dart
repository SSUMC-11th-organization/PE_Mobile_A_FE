import 'package:dio/dio.dart';

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

// 조회(공개)와 등록·수정·삭제(보호)가 쓰는 Client가 달라서 Dio를 두 개 받습니다.
// ViewModel은 이 Service 하나만 알고, 어느 Client로 보낼지는 메서드별로 여기서 정합니다.
class RatingApiService {
  RatingApiService(this._publicDio, this._authDio);

  final Dio _publicDio;
  final Dio _authDio;

  // 공개 유저별 평점 조회는 memberId path를 유지합니다. 직접 배열로 오고 토큰이 필요 없습니다.
  // v7 로그인·내 정보 응답에는 memberId가 없어서, 로그인한 '내' 목록을 이 API로 복원할 수는 없습니다.
  Future<List<RatingDto>> fetchMemberRatings(int memberId) async {
    final response = await _publicDio.get('/v7/members/$memberId/ratings');
    return parseRatingList(response.data);
  }

  // v7은 토큰으로 회원을 식별하므로 path·body 어디에도 memberId를 넣지 않습니다.
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    final response = await _authDio.post('/v7/ratings', data: request.toJson());
    return parseRatingResult(response.data);
  }

  // PATCH는 부분 수정이 아니라 전체 교체라 comment를 빼면 기존 후기가 null이 됩니다. 항상 두 값을 함께 보냅니다.
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    required String? comment,
  }) async {
    final response = await _authDio.patch(
      '/v7/ratings/$ratingId',
      data: {'score': score, 'comment': comment},
    );
    return parseRatingResult(response.data);
  }

  // v6의 204와 달리 v7 삭제 성공은 200 + result null입니다.
  Future<void> deleteRating(int ratingId) async {
    final response = await _authDio.delete('/v7/ratings/$ratingId');
    if (response.statusCode != 200) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}
