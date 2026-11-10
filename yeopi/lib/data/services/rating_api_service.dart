import 'package:dio/dio.dart';

import '../models/rating_dto.dart';
import '../models/rating_request.dart';

class RatingApiService {
  RatingApiService(this._dio);

  final Dio _dio;

  // 조회 성공은 직접 배열로 오고, 오류(400·404)만 공통 형식으로 옵니다.
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _dio.get('/v6/members/$memberId/ratings');
    final list = response.data as List<dynamic>;
    return list
        .map((item) => RatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // 명세 설명은 result가 ratingId라고 하지만 예시는 null이라, result를 파싱하지 않고 201만 성공으로 봅니다.
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    final response = await _dio.post(
      '/v6/members/$memberId/ratings',
      data: request.toJson(),
    );
    if (response.statusCode != 201) {
      throw StateError('예상하지 못한 등록 응답: ${response.statusCode}');
    }
  }

  // PATCH지만 comment를 생략하면 기존 후기가 null로 덮이므로, 유지하려면 기존 값을 그대로 보내야 합니다.
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required int score,
    required String? comment,
  }) async {
    await _dio.patch(
      '/v6/members/$memberId/ratings/$ratingId',
      data: {'score': score, 'comment': comment},
    );
  }

  // 성공은 204라 body가 없으므로 JSON으로 파싱하지 않습니다.
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
