import 'package:flutter/foundation.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';

enum MovieListLoadStatus { idle, loading, success, empty, error }

/// View가 요청 결과에 따라 무엇을 보여줄지 판단할 때 쓴다.
enum MovieListLoadResult {
  success,

  /// 실패했지만 최근 성공 목록을 유지했다. 재시도 Dialog를 띄운다.
  failedWithPrevious,

  /// 보여줄 목록이 없어 Error 화면으로 전환했다.
  failed,

  /// 이미 요청 중이거나 더 새로운 요청에 밀려 결과를 버렸다.
  ignored,
}

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

  /// null이면 "전체"다. Service에서 OR(`|`)로 연결해 `with_genres`로 보낸다.
  List<int>? get selectedGenreIds => _selectedGenreIds;
  MovieListLoadStatus get status => _status;
  bool get isRefreshing => _isRefreshing;
  String? get message => _message;

  /// Discover 요청 중에는 장르 변경과 Pull to Refresh를 막는다.
  bool get isBusy => _status == MovieListLoadStatus.loading || _isRefreshing;

  /// 결과가 [maxMovies]개가 되거나 더 이상 페이지가 없을 때까지 page 1부터 요청한다.
  /// TMDB id를 key로 써서 페이지 사이 중복을 제거한다.
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

  /// 장르 목록과 영화 목록을 처음부터 불러온다. Error 화면의 재시도에도 쓴다.
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

  /// 장르 선택이 바뀌면 목록을 비우고 `with_genres` 조건으로 page 1부터 다시 요청한다.
  /// null 또는 빈 목록이면 "전체"로 보고 `with_genres` 없이 요청한다.
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

  /// 현재 장르를 유지한 채 page 1부터 다시 요청한다. 완료 전까지 기존 목록을 그대로 둔다.
  Future<MovieListLoadResult> refresh() async {
    if (isBusy) return MovieListLoadResult.ignored;

    final version = ++_requestVersion;
    _isRefreshing = true;
    notifyListeners();
    return _loadMovies(version);
  }

  /// 재시도 Dialog에서 호출한다. 마지막으로 선택한 장르로 최대 30개 로딩 전체를 다시 실행한다.
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
