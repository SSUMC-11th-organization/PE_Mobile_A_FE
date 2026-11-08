import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_error_message.dart';

// 로그인한 '내 계정'이 아니라 v5 학습용 공개 데이터의 회원 ID입니다. 실제 회원 식별은 JWT 주차에서 바뀝니다.
const int sampleMemberId = 1;

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._movieService, this.memberId);

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final int memberId;

  // 같은 movieId는 한 번만 조회합니다. TMDB에 없는 영화(null)도 결과로 기억합니다.
  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _requestVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;

  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      final rawRatings = await _service.fetchMyRatings(memberId);
      if (_isStale(version)) return;

      final entries = <RatingWithMovie>[];
      var missingMovies = 0;
      for (final rating in rawRatings) {
        if (!_movieCache.containsKey(rating.movieId)) {
          try {
            _movieCache[rating.movieId] = await _movieService.findMovieById(
              rating.movieId,
            );
          } on DioException catch (error) {
            // 일시적인 실패는 캐시하지 않고 다음 로딩에서 다시 시도합니다. 평점 목록은 지우지 않습니다.
            debugPrint('영화 정보 조회 실패 movieId=${rating.movieId}: $error');
          }
          if (_isStale(version)) return;
        }
        final movie = _movieCache[rating.movieId];
        if (movie == null) missingMovies++;
        entries.add(RatingWithMovie(rating: rating, movie: movie));
      }

      ratings = entries;
      status = entries.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
      if (missingMovies > 0) {
        message = '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.';
      }
    } catch (error) {
      if (_isStale(version)) return;
      debugPrint('평점 조회 실패: $error');
      status = MyRatingsLoadStatus.error;
      message = myRatingsErrorMessage(error);
    }

    if (!_isStale(version)) notifyListeners();
  }

  // 화면을 벗어났거나 새 요청이 시작됐다면 늦게 도착한 응답은 버립니다.
  bool _isStale(int version) => _disposed || version != _requestVersion;

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
