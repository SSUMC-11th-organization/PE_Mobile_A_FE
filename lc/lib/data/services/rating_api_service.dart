import 'package:dio/dio.dart';

import '../../core/network/api_error.dart';
import '../models/common_response.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';

/// v8의 등록·수정 성공 응답은 공통 응답의 result에 Rating 객체가 들어 있다.
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

/// 유저별 평점 조회 성공 응답은 공통 응답이 아니라 직접 배열이다.
List<RatingDto> parseRatingList(Object? data) {
  if (data is! List) throw StateError('평점 목록 응답은 배열이어야 합니다.');
  return data
      .map((value) => RatingDto.fromJson(value as Map<String, dynamic>))
      .toList();
}

/// 공개 조회는 공개 Client로, 등록·수정·삭제는 보호 Client로 보낸다.
/// v8 보호 요청은 path·body 어디에도 memberId가 없고, 서버가 토큰으로 회원을 식별한다.
class RatingApiService {
  RatingApiService(this._publicDio, this._authDio);

  final Dio _publicDio;
  final Dio _authDio;

  /// 공개 API라 토큰 없이 조회한다. (v8에는 토큰 기반 "내 평점 목록" API가 없다.)
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _publicDio.get('/v8/members/$memberId/ratings');
    return parseRatingList(response.data);
  }

  Future<RatingDto> createRating(CreateRatingRequest request) async {
    final response = await _authDio.post('/v8/ratings', data: request.toJson());
    return parseRatingResult(response.data);
  }

  /// PATCH는 전체 교체다. comment를 생략하면 기존 후기가 null로 덮이므로 항상 두 값을 함께 보낸다.
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

  /// v8 삭제 성공은 204가 아니라 result가 null인 200이다.
  Future<void> deleteRating(int ratingId) async {
    final response = await _authDio.delete('/v8/ratings/$ratingId');
    if (response.statusCode != 200) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

/// 서버가 준 message를 우선 쓰고, body를 읽을 수 없을 때(통신 실패 등)만 기본 문구를 쓴다.
String writeErrorMessage(DioException error) {
  return apiErrorMessage(error) ??
      readServerMessage(error) ??
      '요청에 실패했습니다. 네트워크 상태를 확인하고 다시 시도해 주세요.';
}
