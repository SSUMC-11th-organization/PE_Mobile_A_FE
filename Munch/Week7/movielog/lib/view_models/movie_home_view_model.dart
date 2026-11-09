import 'package:flutter/foundation.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';

enum MovieHomeLoadStatus { idle, loading, success, empty, error }

class MovieHomeViewModel extends ChangeNotifier {
  MovieHomeViewModel(this._service);

  static const popularCount = 5;

  final TmdbMovieService _service;

  List<TmdbMovieDto> _popularMovies = const [];
  MovieHomeLoadStatus _status = MovieHomeLoadStatus.idle;
  String? _message;
  bool _disposed = false;

  List<TmdbMovieDto> get popularMovies => _popularMovies;
  MovieHomeLoadStatus get status => _status;
  String? get message => _message;

  Future<void> loadPopular() async {
    if (_status == MovieHomeLoadStatus.loading) return;
    _status = MovieHomeLoadStatus.loading;
    _message = null;
    notifyListeners();

    try {
      final page = await _service.fetchPopular();
      _popularMovies = page.results.take(popularCount).toList();
      _status = _popularMovies.isEmpty
          ? MovieHomeLoadStatus.empty
          : MovieHomeLoadStatus.success;
    } catch (error) {
      if (kDebugMode) debugPrint('인기 영화 로드 실패: $error');
      _status = MovieHomeLoadStatus.error;
      _message = '인기 영화를 불러오지 못했어요.';
    }

    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
