import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/services/rating_api_service.dart';

RatingDto ratingFixture(int ratingId, int movieId, {String? comment}) {
  return RatingDto(
    ratingId: ratingId,
    movieId: movieId,
    score: 4,
    comment: comment,
    createdAt: DateTime.utc(2026, 11, 1),
  );
}

class FakeRatingApiService extends RatingApiService {
  FakeRatingApiService({List<RatingDto>? ratings})
    : ratings = ratings ?? [],
      super(Dio());

  List<RatingDto> ratings;
  int? failStatus;
  Completer<void>? pending;
  final requestedMemberIds = <int>[];

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    requestedMemberIds.add(memberId);
    await pending?.future;
    final status = failStatus;
    if (status != null) {
      final options = RequestOptions(path: '/v5/members/$memberId/ratings');
      throw DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: status),
        type: DioExceptionType.badResponse,
      );
    }
    return ratings;
  }
}
