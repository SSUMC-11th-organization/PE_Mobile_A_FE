import 'package:flutter/foundation.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';

enum MovieHomeLoadStatus { idle, loading, success, empty, error }

class MovieHomeViewModel extends ChangeNotifier {
  MovieHomeViewModel(this._service);

  final TmdbMovieService _service;

  // 홈에 보여줄 인기 영화 개수 (화면 정책이라 ViewModel이 관리)
  static const _popularCount = 5;

  List<TmdbMovieDto> popularMovies = const [];
  MovieHomeLoadStatus status = MovieHomeLoadStatus.idle;
  String? message;

  bool _disposed = false;

  Future<void> loadPopular() async {
    status = MovieHomeLoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      final page = await _service.fetchPopular();
      if (_disposed) return;

      // take(5): 5개보다 적게 와도 있는 만큼만 가져온다 (범위 오류 없음)
      popularMovies = page.results.take(_popularCount).toList();
      status = popularMovies.isEmpty
          ? MovieHomeLoadStatus.empty
          : MovieHomeLoadStatus.success;
      debugPrint('[MovieHomeViewModel] 인기 영화 ${popularMovies.length}개');
    } catch (exception) {
      if (_disposed) return;

      debugPrint('[MovieHomeViewModel] 인기 영화 로드 실패: $exception');
      status = MovieHomeLoadStatus.error;
      message = '인기 영화를 불러오지 못했어요.';
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}