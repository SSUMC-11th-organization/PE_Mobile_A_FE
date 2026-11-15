import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._movieService, this.memberId);

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final int memberId;

  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _requestVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;

  /// 저장은 성공했지만 목록 재조회가 실패했을 때의 안내 (조회만 다시 시도하면 된다)
  String? refreshWarning;

  bool _isStale(int version) => _disposed || version != _requestVersion;

  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    refreshWarning = null;
    notifyListeners();

    try {
      final rawRatings = await _service.fetchMyRatings(memberId);
      if (_isStale(version)) return;

      final entries = <RatingWithMovie>[];
      var missingMovies = 0;

      for (final rating in rawRatings) {
        if (_isStale(version)) return;

        // 같은 movieId는 한 번만 조회하고 캐시한다
        if (!_movieCache.containsKey(rating.movieId)) {
          try {
            _movieCache[rating.movieId] =
                await _movieService.findMovieById(rating.movieId);
          } catch (error) {
            // 일시적 실패는 캐시하지 않는다. 평점 목록은 지우지 않는다.
            debugPrint(
              '[MyRatingsViewModel] 영화 ${rating.movieId} 조회 실패: $error',
            );
          }
        }

        final movie = _movieCache[rating.movieId];
        if (movie == null) missingMovies++;
        entries.add(RatingWithMovie(rating: rating, movie: movie));
      }

      if (_isStale(version)) return;

      ratings = entries;
      status = entries.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
      if (missingMovies > 0) {
        message = '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.';
      }
    } catch (error) {
      if (_isStale(version)) return;

      debugPrint('[MyRatingsViewModel] 평점 조회 실패: $error');
      status = MyRatingsLoadStatus.error;
      message = error is DioException
          ? writeMyRatingsErrorMessage(error)
          : '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }

    notifyListeners();
  }

  /// 저장이 끝난 뒤 목록을 서버 상태와 맞춘다. 재조회 실패는 저장 실패가 아니다.
  Future<void> _refreshAfterWrite() async {
    await load();
    if (_disposed) return;

    if (status == MyRatingsLoadStatus.error) {
      refreshWarning = '저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해 주세요.';
      notifyListeners();
    }
  }

  /// 쓰기 실패는 rethrow해서 Dialog가 실패로 처리하게 한다.
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    try {
      await _service.updateRating(
        memberId: memberId,
        ratingId: ratingId,
        score: score,
        comment: comment,
      );
    } on DioException catch (error) {
      if (shouldRefreshAfterRatingError(error)) await load();
      rethrow;
    }

    await _refreshAfterWrite(); // GET 실패는 저장 실패로 다시 던지지 않는다
  }

  Future<void> deleteRating(int ratingId) async {
    try {
      await _service.deleteRating(memberId: memberId, ratingId: ratingId);
    } on DioException catch (error) {
      if (shouldRefreshAfterRatingError(error)) await load();
      rethrow;
    }

    await _refreshAfterWrite();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}