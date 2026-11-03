import 'package:flutter/foundation.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import '../utils/tmdb_movie_format.dart';

enum MovieListLoadStatus { idle, loading, success, empty, error }

/// 영화 목록 화면의 상태와 정책(최대 30개, 장르 재조회)을 가진다.
class MovieListViewModel extends ChangeNotifier {
  MovieListViewModel(this._service);

  static const maxMovies = 30;

  final TmdbMovieService _service;

  List<TmdbMovieDto> movies = const [];
  List<TmdbGenreDto> genres = const [];

  /// null이면 '전체'. 이때는 with_genres를 보내지 않는다.
  int? selectedGenreId;
  MovieListLoadStatus status = MovieListLoadStatus.idle;
  String? message;

  Map<int, String> _genreNames = const {};
  int _requestVersion = 0;
  bool _disposed = false;

  /// 요청이 끝나기 전에는 장르를 바꾸지 못하게 화면이 이 값을 본다.
  bool get isLoading =>
      status == MovieListLoadStatus.idle ||
      status == MovieListLoadStatus.loading;

  Map<int, String> get genreNames => _genreNames;

  List<String> genreNamesOf(TmdbMovieDto movie) =>
      movie.genreNamesIn(_genreNames);

  Future<void> loadInitial() => _load();

  /// 마지막으로 고른 장르를 유지한 채 처음(page 1)부터 다시 요청한다.
  Future<void> retry() => _load();

  Future<void> selectGenre(int? genreId) async {
    // 요청 중에는 장르를 바꾸지 않는다. (화면에서도 막지만 ViewModel이 마지막으로 지킨다.)
    if (isLoading || genreId == selectedGenreId) return;

    selectedGenreId = genreId;
    await _load();
  }

  Future<void> _load() async {
    final version = ++_requestVersion;
    status = MovieListLoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      // 장르 목록은 한 번 받아두면 다시 받지 않는다.
      final results = await Future.wait<Object>([
        genres.isEmpty ? _service.fetchGenres() : Future.value(genres),
        _fetchUpToMaxMovies(genreId: selectedGenreId),
      ]);
      // 더 새로운 요청이 시작됐거나 화면이 사라졌다면 이 결과는 버린다.
      if (_isStale(version)) return;

      genres = results[0] as List<TmdbGenreDto>;
      movies = results[1] as List<TmdbMovieDto>;
      _genreNames = {for (final genre in genres) genre.id: genre.name};
      status = movies.isEmpty
          ? MovieListLoadStatus.empty
          : MovieListLoadStatus.success;
      debugPrint('영화 목록 로드 완료: ${movies.length}개 (장르 id: $selectedGenreId)');
    } catch (error, stackTrace) {
      if (_isStale(version)) return;
      debugPrint('영화 목록 로드 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      status = MovieListLoadStatus.error;
      message = '영화를 불러오지 못했어요. 다시 시도해 주세요.';
    }

    notifyListeners();
  }

  /// 한 페이지의 개수를 가정하지 않고, 30개가 되거나 더 이상 페이지가 없을 때까지 요청한다.
  /// 페이지 사이에 같은 영화가 겹쳐도 TMDB id 기준으로 하나만 남긴다.
  Future<List<TmdbMovieDto>> _fetchUpToMaxMovies({int? genreId}) async {
    final byId = <int, TmdbMovieDto>{};
    var pageNumber = 1;
    var hasNextPage = true;

    while (byId.length < maxMovies && hasNextPage) {
      final page = await _service.discoverMovies(
        page: pageNumber,
        genreId: genreId,
      );

      for (final movie in page.results) {
        byId[movie.id] = movie;
        if (byId.length == maxMovies) break;
      }

      hasNextPage = pageNumber < page.totalPages && page.results.isNotEmpty;
      pageNumber++;
    }

    return byId.values.take(maxMovies).toList();
  }

  bool _isStale(int version) => _disposed || version != _requestVersion;

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
