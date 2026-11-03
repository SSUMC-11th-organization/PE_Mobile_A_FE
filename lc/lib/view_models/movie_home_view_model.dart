import 'package:flutter/foundation.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/models/tmdb_movie_page.dart';
import '../data/services/tmdb_movie_service.dart';
import '../utils/tmdb_movie_format.dart';

enum MovieHomeLoadStatus { idle, loading, success, empty, error }

/// 홈 화면의 상태와 데이터를 가진다. 화면(View)은 이 상태를 읽어서 그리기만 한다.
class MovieHomeViewModel extends ChangeNotifier {
  MovieHomeViewModel(this._service);

  static const popularCount = 5;

  final TmdbMovieService _service;

  List<TmdbMovieDto> popularMovies = const [];
  MovieHomeLoadStatus status = MovieHomeLoadStatus.idle;
  String? message;

  Map<int, String> _genreNames = const {};
  int _requestVersion = 0;
  bool _disposed = false;

  List<String> genreNamesOf(TmdbMovieDto movie) =>
      movie.genreNamesIn(_genreNames);

  Future<void> loadPopular() async {
    final version = ++_requestVersion;
    status = MovieHomeLoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      final results = await Future.wait<Object>([
        _service.fetchPopular(),
        _loadGenreNames(),
      ]);
      if (_isStale(version)) return;

      final page = results[0] as TmdbMoviePageDto;
      // 5개보다 적게 와도 범위 오류 없이 있는 만큼만 쓴다.
      popularMovies = page.results.take(popularCount).toList();
      _genreNames = results[1] as Map<int, String>;
      status = popularMovies.isEmpty
          ? MovieHomeLoadStatus.empty
          : MovieHomeLoadStatus.success;
    } catch (error, stackTrace) {
      if (_isStale(version)) return;
      debugPrint('인기 영화 로드 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      status = MovieHomeLoadStatus.error;
      message = '인기 영화를 불러오지 못했어요.';
    }

    notifyListeners();
  }

  /// 장르 이름은 보조 정보라서, 실패해도 인기 영화 표시는 막지 않는다.
  Future<Map<int, String>> _loadGenreNames() async {
    try {
      final List<TmdbGenreDto> genres = await _service.fetchGenres();
      return {for (final genre in genres) genre.id: genre.name};
    } catch (error) {
      debugPrint('장르 이름 로드 실패(장르 표시만 생략): $error');
      return const {};
    }
  }

  bool _isStale(int version) => _disposed || version != _requestVersion;

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
