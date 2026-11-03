import 'package:flutter/foundation.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_error_message.dart';

enum MovieHomeLoadStatus { idle, loading, success, empty, error }

class MovieHomeViewModel extends ChangeNotifier {
  MovieHomeViewModel(this._service);

  static const popularCount = 5;

  final TmdbMovieService _service;

  List<TmdbMovieDto> popularMovies = const [];
  MovieHomeLoadStatus status = MovieHomeLoadStatus.idle;
  String? message;

  bool _disposed = false;

  Future<void> loadPopular() async {
    if (status == MovieHomeLoadStatus.loading) return;
    status = MovieHomeLoadStatus.loading;
    notifyListeners();

    try {
      final page = await _service.fetchPopular();
      // 결과가 5개보다 적어도 take는 있는 만큼만 돌려주므로 범위 오류가 나지 않습니다.
      popularMovies = page.results.take(popularCount).toList();
      status = popularMovies.isEmpty
          ? MovieHomeLoadStatus.empty
          : MovieHomeLoadStatus.success;
    } catch (error) {
      debugPrint('인기 영화 로드 실패: $error');
      status = MovieHomeLoadStatus.error;
      message = loadErrorMessage(
        error,
        fallback: '인기 영화를 불러오지 못했어요.\n잠시 후 다시 시도해 주세요.',
      );
    }

    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
