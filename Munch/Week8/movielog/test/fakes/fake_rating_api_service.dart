import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/services/rating_api_service.dart';

import 'fake_auth.dart';

RatingDto ratingFixture(
  int ratingId,
  int movieId, {
  int score = 4,
  String? comment,
}) {
  return RatingDto(
    ratingId: ratingId,
    movieId: movieId,
    score: score,
    comment: comment,
    createdAt: DateTime.utc(2026, 11, 1),
  );
}

class FakeRatingApiService extends RatingApiService {
  FakeRatingApiService() : super(Dio(), Dio());

  DioException? writeFailure;
  final movieIdsByRatingId = <int, int>{};
  int nextRatingId = 100;
  final createdRequests = <CreateRatingRequest>[];
  final updates = <({int ratingId, int score, String? comment})>[];
  final deletedRatingIds = <int>[];
  Set<int> failingDeleteIds = {};
  Completer<void>? deletePending;

  void _throwIfWriteFails() {
    final failure = writeFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    _throwIfWriteFails();
    createdRequests.add(request);
    return ratingFixture(
      nextRatingId++,
      request.movieId,
      score: request.score,
      comment: request.comment,
    );
  }

  @override
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    _throwIfWriteFails();
    updates.add((ratingId: ratingId, score: score, comment: comment));
    return ratingFixture(
      ratingId,
      movieIdsByRatingId[ratingId] ?? 0,
      score: score,
      comment: comment,
    );
  }

  @override
  Future<void> deleteRating(int ratingId) async {
    await deletePending?.future;
    _throwIfWriteFails();
    if (failingDeleteIds.contains(ratingId)) throw connectionError();
    deletedRatingIds.add(ratingId);
  }
}
