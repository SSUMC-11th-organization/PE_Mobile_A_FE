import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/rating_request.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import 'auth_view_model.dart';
import 'session_rating_store.dart';
import 'sign_up_view_model.dart';

class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(
    this._ratingService,
    this._sessionRatings,
    this._auth,
    this.movie,
  );

  final RatingApiService _ratingService;
  final SessionRatingStore _sessionRatings;
  final AuthViewModel _auth;
  final TmdbMovieDto movie;

  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;
  bool _disposed = false;

  Future<void> createRating({required int score, String? comment}) async {
    if (submitStatus == SubmitStatus.submitting) return;

    final version = _auth.sessionVersion;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    notifyListeners();

    bool isStale() => _disposed || version != _auth.sessionVersion;

    try {
      final created = await _ratingService.createRating(
        CreateRatingRequest(movieId: movie.id, score: score, comment: comment),
      );
      if (isStale()) return;
      _sessionRatings.add(created);
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      if (isStale()) return;
      submitStatus = SubmitStatus.error;
      submitMessage = ratingErrorMessage(error);
      if (isSessionExpired(error)) {
        await _auth.expireSession();
        return;
      }
    } catch (_) {
      if (isStale()) return;
      submitStatus = SubmitStatus.error;
      submitMessage = '등록 결과를 확인하지 못했어요. 내가 등록한 평점을 확인해 주세요.';
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
