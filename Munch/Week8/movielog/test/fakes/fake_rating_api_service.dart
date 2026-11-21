import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
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
  ({int status, String code, String message})? writeFailure;
  final createdRequests = <CreateRatingRequest>[];
  final updates = <({int ratingId, int score, String? comment})>[];
  final deletedRatingIds = <int>[];
  Set<int> failingDeleteIds = {};
  Completer<void>? deletePending;

  void _throwIfWriteFails() {
    final failure = writeFailure;
    if (failure == null) return;
    final options = RequestOptions(path: '/v6/members/ratings');
    throw DioException(
      requestOptions: options,
      response: Response(
        requestOptions: options,
        statusCode: failure.status,
        data: {
          'isSuccess': false,
          'code': failure.code,
          'message': failure.message,
          'result': null,
        },
      ),
      type: DioExceptionType.badResponse,
    );
  }

  @override
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    _throwIfWriteFails();
    createdRequests.add(request);
  }

  @override
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    _throwIfWriteFails();
    updates.add((ratingId: ratingId, score: score, comment: comment));
  }

  @override
  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    await deletePending?.future;
    _throwIfWriteFails();
    if (failingDeleteIds.contains(ratingId)) {
      throw DioException(
        requestOptions: RequestOptions(path: '/v6/members/ratings/$ratingId'),
        type: DioExceptionType.connectionError,
      );
    }
    deletedRatingIds.add(ratingId);
    ratings = ratings.where((r) => r.ratingId != ratingId).toList();
  }

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    requestedMemberIds.add(memberId);
    await pending?.future;
    final status = failStatus;
    if (status != null) {
      final options = RequestOptions(path: '/v6/members/$memberId/ratings');
      throw DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: status),
        type: DioExceptionType.badResponse,
      );
    }
    return ratings;
  }
}
