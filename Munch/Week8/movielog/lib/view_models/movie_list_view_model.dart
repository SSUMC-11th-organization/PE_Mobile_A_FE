import 'package:flutter/foundation.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';

enum MovieListLoadStatus { idle, loading, success, empty, error }

enum MovieListLoadResult { success, failedWithPrevious, failed, ignored }

class MovieListViewModel extends ChangeNotifier {
  MovieListViewModel(this._service);

  static const maxMovies = 30;

  final TmdbMovieService _service;

  List<TmdbMovieDto> _movies = const [];
  List<TmdbMovieDto> _lastSuccessMovies = const [];
  List<TmdbGenreDto> _genres = const [];
  Map<int, String> _genreNames = const {};
  List<int>? _selectedGenreIds;
  MovieListLoadStatus _status = MovieListLoadStatus.idle;
  bool _isRefreshing = false;
  String? _message;

  int _requestVersion = 0;
  bool _disposed = false;

  List<TmdbMovieDto> get movies => _movies;
  List<TmdbGenreDto> get genres => _genres;
  Map<int, String> get genreNames => _genreNames;

  List<int>? get selectedGenreIds => _selectedGenreIds;
  MovieListLoadStatus get status => _status;
  bool get isRefreshing => _isRefreshing;
  String? get message => _message;

  bool get isBusy => _status == MovieListLoadStatus.loading || _isRefreshing;

  Future<List<TmdbMovieDto>> fetchUpToThirtyMovies({
    List<int>? genreIds,
  }) async {
    final byId = <int, TmdbMovieDto>{};
    var pageNumber = 1;
    var hasNextPage = true;

    while (byId.length < maxMovies && hasNextPage) {
      final page = await _service.discoverMovies(
        page: pageNumber,
        genreIds: genreIds,
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

  Future<MovieListLoadResult> loadInitial() async {
    final version = _startLoading();

    try {
      final (genres, movies) = await (
        _service.fetchGenres(),
        fetchUpToThirtyMovies(genreIds: _selectedGenreIds),
      ).wait;
      if (_isStale(version)) return MovieListLoadResult.ignored;

      _genres = genres;
      _genreNames = {for (final genre in genres) genre.id: genre.name};
      _applyMovies(movies);
      return MovieListLoadResult.success;
    } catch (error) {
      if (_isStale(version)) return MovieListLoadResult.ignored;
      return _handleFailure(error);
    }
  }

  Future<MovieListLoadResult> selectGenres(List<int>? genreIds) async {
    if (isBusy) return MovieListLoadResult.ignored;

    final next = genreIds == null || genreIds.isEmpty
        ? null
        : List<int>.unmodifiable(genreIds);
    if (listEquals(next, _selectedGenreIds)) {
      return MovieListLoadResult.ignored;
    }

    _selectedGenreIds = next;
    final version = _startLoading();
    return _loadMovies(version);
  }

  Future<MovieListLoadResult> refresh() async {
    if (isBusy) return MovieListLoadResult.ignored;

    final version = ++_requestVersion;
    _isRefreshing = true;
    notifyListeners();
    return _loadMovies(version);
  }

  Future<MovieListLoadResult> retry() => refresh();

  int _startLoading() {
    final version = ++_requestVersion;
    _status = MovieListLoadStatus.loading;
    _movies = const [];
    _message = null;
    notifyListeners();
    return version;
  }

  Future<MovieListLoadResult> _loadMovies(int version) async {
    try {
      final movies = await fetchUpToThirtyMovies(genreIds: _selectedGenreIds);
      if (_isStale(version)) return MovieListLoadResult.ignored;

      _applyMovies(movies);
      return MovieListLoadResult.success;
    } catch (error) {
      if (_isStale(version)) return MovieListLoadResult.ignored;
      return _handleFailure(error);
    }
  }

  void _applyMovies(List<TmdbMovieDto> movies) {
    _movies = movies;
    _lastSuccessMovies = movies;
    _isRefreshing = false;
    _message = null;
    _status = movies.isEmpty
        ? MovieListLoadStatus.empty
        : MovieListLoadStatus.success;
    notifyListeners();
  }

  MovieListLoadResult _handleFailure(Object error) {
    if (kDebugMode) debugPrint('영화 목록 로드 실패: $error');
    _isRefreshing = false;

    if (_lastSuccessMovies.isNotEmpty) {
      _movies = _lastSuccessMovies;
      _status = MovieListLoadStatus.success;
      notifyListeners();
      return MovieListLoadResult.failedWithPrevious;
    }

    _movies = const [];
    _status = MovieListLoadStatus.error;
    _message = '영화를 불러오지 못했어요.\n다시 시도해 주세요.';
    notifyListeners();
    return MovieListLoadResult.failed;
  }

  bool _isStale(int version) => _disposed || version != _requestVersion;

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
