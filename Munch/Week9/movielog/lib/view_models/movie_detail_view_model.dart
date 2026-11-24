import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/movie_record_models.dart';
import '../data/models/rating_dto.dart';
import '../data/models/rating_request.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/movie_record_api_service.dart';
import '../data/services/rating_api_service.dart';
import 'auth_view_model.dart';
import 'session_rating_store.dart';
import 'sign_up_view_model.dart';

// 이 코드는 Dialog를 닫고 Snackbar로 안내한다. 그 외 실패는 Dialog 안에 표시한다.
const _dismissCodes = {'RATING409_1', 'FAVORITE409_1', 'MEMBER404_1'};

class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(
    this._ratingService,
    this._movieRecordService,
    this._sessionRatings,
    this._auth,
    this.movie,
  );

  final RatingApiService _ratingService;
  final MovieRecordApiService _movieRecordService;
  final SessionRatingStore _sessionRatings;
  final AuthViewModel _auth;
  final TmdbMovieDto movie;

  SubmitStatus submitStatus = SubmitStatus.idle;
  bool _disposed = false;

  // 즐겨찾기하지 않은 영화는 movie-records로, 이미 즐겨찾기한 영화는 평점만 저장한다.
  // 실패하면 ActionFailure(Dialog 유지) 또는 DismissFailure(Dialog 닫기)를 던진다.
  Future<void> saveRating({
    required int score,
    String? comment,
    required bool useMovieRecord,
    bool addToFavorites = false,
  }) async {
    if (submitStatus == SubmitStatus.submitting) return;

    final version = _auth.sessionVersion;
    submitStatus = SubmitStatus.submitting;
    notifyListeners();

    bool isStale() => _disposed || version != _auth.sessionVersion;

    try {
      final RatingDto saved;
      if (useMovieRecord) {
        final record = await _movieRecordService.saveRecord(
          MovieRecordRequest(
            movieId: movie.id,
            score: score,
            comment: comment,
            addToFavorites: addToFavorites,
          ),
        );
        saved = record.rating;
      } else {
        saved = await _ratingService.createRating(
          CreateRatingRequest(
            movieId: movie.id,
            score: score,
            comment: comment,
          ),
        );
      }
      if (isStale()) return;
      _sessionRatings.add(saved);
      _finish(SubmitStatus.success);
    } on DioException catch (error) {
      if (isStale()) return;
      _finish(SubmitStatus.error);
      final message = ratingErrorMessage(error);
      if (isSessionExpired(error)) {
        await _auth.expireSession();
        throw DismissFailure(message);
      }
      if (_dismissCodes.contains(apiErrorCode(error))) {
        throw DismissFailure(message);
      }
      throw ActionFailure(
        error.response == null ? '네트워크 연결을 확인하고 다시 시도해 주세요.' : message,
      );
    } catch (_) {
      if (isStale()) return;
      _finish(SubmitStatus.error);
      throw const ActionFailure('저장 결과를 확인하지 못했어요. 내가 등록한 평점을 확인해 주세요.');
    }
  }

  void _finish(SubmitStatus status) {
    submitStatus = status;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
