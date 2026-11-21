import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/rating_dto.dart';
import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'auth_view_model.dart';
import 'session_rating_store.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty }

class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(
    this._service,
    this._movieService,
    this._sessionRatings,
    this._auth,
  );

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final SessionRatingStore _sessionRatings;
  final AuthViewModel _auth;
  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _requestVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;

  final Set<int> selectedRatingIds = {};
  bool isSelectionMode = false;
  bool isDeletingSelected = false;
  int failedDeleteCount = 0;

  void startSelection() {
    isSelectionMode = true;
    notifyListeners();
  }

  void cancelSelection() {
    isSelectionMode = false;
    selectedRatingIds.clear();
    notifyListeners();
  }

  void toggleSelected(int ratingId) {
    if (!selectedRatingIds.remove(ratingId)) selectedRatingIds.add(ratingId);
    notifyListeners();
  }

  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    notifyListeners();

    bool isStale() => _disposed || version != _requestVersion;

    for (final rating in _sessionRatings.ratings) {
      if (isStale()) return;
      if (_movieCache.containsKey(rating.movieId)) continue;
      try {
        _movieCache[rating.movieId] = await _movieService.findMovieById(
          rating.movieId,
        );
      } on DioException {
        // 일시적인 실패는 캐시하지 않고 다음 로딩에서 다시 조회한다.
      }
    }
    if (isStale()) return;

    _rebuild();
    if (ratings.any((entry) => entry.movie == null)) {
      message = '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.';
    }
    notifyListeners();
  }

  void _rebuild() {
    ratings = [
      for (final rating in _sessionRatings.ratings)
        RatingWithMovie(rating: rating, movie: _movieCache[rating.movieId]),
    ];
    status = ratings.isEmpty
        ? MyRatingsLoadStatus.empty
        : MyRatingsLoadStatus.success;
  }

  // 화면 갱신까지 처리한 뒤 사용자에게 보여줄 문구를 담아 던진다.
  Future<Never> _handleWriteError(DioException error, int ratingId) async {
    final failureMessage = ratingErrorMessage(error);
    if (isSessionExpired(error)) {
      await _auth.expireSession();
      throw ActionFailure(failureMessage);
    }
    if (apiErrorCode(error) == 'RATING404_1') {
      _sessionRatings.remove(ratingId);
      selectedRatingIds.remove(ratingId);
      _rebuild();
    }
    message = failureMessage;
    if (!_disposed) notifyListeners();
    throw ActionFailure(failureMessage);
  }

  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final version = _auth.sessionVersion;
    final RatingDto updated;
    try {
      updated = await _service.updateRating(
        ratingId: ratingId,
        score: score,
        comment: comment,
      );
    } on DioException catch (error) {
      if (_disposed || version != _auth.sessionVersion) rethrow;
      await _handleWriteError(error, ratingId);
    }
    if (_disposed || version != _auth.sessionVersion) return;
    _sessionRatings.replace(updated);
    message = null;
    _rebuild();
    notifyListeners();
  }

  Future<void> deleteRating(int ratingId) async {
    final version = _auth.sessionVersion;
    try {
      await _service.deleteRating(ratingId);
    } on DioException catch (error) {
      if (_disposed || version != _auth.sessionVersion) rethrow;
      await _handleWriteError(error, ratingId);
    }
    if (_disposed || version != _auth.sessionVersion) return;
    _sessionRatings.remove(ratingId);
    selectedRatingIds.remove(ratingId);
    message = null;
    _rebuild();
    notifyListeners();
  }

  Future<void> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) return;
    final version = _auth.sessionVersion;
    isDeletingSelected = true;
    failedDeleteCount = 0;
    message = null;
    notifyListeners();

    var failed = 0;
    var expired = false;
    for (final ratingId in selectedRatingIds.toList()) {
      try {
        await _service.deleteRating(ratingId);
        if (_disposed || version != _auth.sessionVersion) return;
        _sessionRatings.remove(ratingId);
        selectedRatingIds.remove(ratingId);
      } on DioException catch (error) {
        if (_disposed || version != _auth.sessionVersion) return;
        if (isSessionExpired(error)) {
          expired = true;
          break;
        }
        if (apiErrorCode(error) == 'RATING404_1') {
          _sessionRatings.remove(ratingId);
          selectedRatingIds.remove(ratingId);
        } else {
          failed++;
        }
      }
    }

    isDeletingSelected = false;
    if (expired) {
      await _auth.expireSession();
      return;
    }
    if (_disposed) return;
    failedDeleteCount = failed;
    _rebuild();
    if (selectedRatingIds.isEmpty) isSelectionMode = false;
    if (failed > 0) {
      message = '$failed개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
