import 'package:flutter/foundation.dart';
import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';

enum MovieListLoadStatus { idle, loading, success, empty, error }

class MovieListViewModel extends ChangeNotifier {
  MovieListViewModel(this._service);

  final TmdbMovieService _service;

  // 목록에 보여줄 최대 영화 개수 (화면 정책)
  static const _maxMovies = 30;

  List<TmdbMovieDto> movies = const [];
  List<TmdbGenreDto> genres = const [];
  int? selectedGenreId; // null이면 "전체"
  MovieListLoadStatus status = MovieListLoadStatus.idle;
  String? message;

  int _requestVersion = 0;
  bool _disposed = false;

  bool get isLoading => status == MovieListLoadStatus.loading;

  /// 화면이 처음 열릴 때: 장르 목록과 전체 영화를 불러온다
  Future<void> loadInitial() => _load(loadGenres: true);

  /// 장르 선택: with_genres 조건으로 page 1부터 다시 요청한다
  Future<void> selectGenre(int? genreId) async {
    // 요청 중에는 장르를 바꿀 수 없다
    if (isLoading) return;
    // 이미 보고 있는 장르를 다시 누르면 요청하지 않는다
    if (genreId == selectedGenreId && status == MovieListLoadStatus.success) {
      return;
    }

    selectedGenreId = genreId;
    await _load();
  }

  /// 다시 시도: 지금 선택된 장르 그대로 처음부터 다시 요청한다
  Future<void> retry() => _load(loadGenres: genres.isEmpty);

  Future<void> _load({bool loadGenres = false}) async {
    final version = ++_requestVersion; // 이 요청의 번호
    status = MovieListLoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      final fetchedGenres = loadGenres ? await _service.fetchGenres() : null;
      final discovered = await _fetchMovies(
        genreId: selectedGenreId,
        version: version,
      );

      // 기다리는 사이 화면이 사라졌거나 더 새로운 요청이 시작됐다면 무시
      if (_isStale(version)) return;

      if (fetchedGenres != null) genres = fetchedGenres;
      movies = discovered;
      status = movies.isEmpty
          ? MovieListLoadStatus.empty
          : MovieListLoadStatus.success;
      debugPrint(
        '[MovieListViewModel] 영화 ${movies.length}개 (장르 ID: $selectedGenreId)',
      );
    } catch (exception) {
      if (_isStale(version)) return;

      debugPrint('[MovieListViewModel] 영화 로드 실패: $exception');
      status = MovieListLoadStatus.error;
      message = selectedGenreId == null
          ? '영화를 불러오지 못했어요. 다시 시도해 주세요.'
          : '해당 장르 영화를 불러오지 못했어요.';
    }

    notifyListeners();
  }

  /// page 1부터 요청해서, TMDB id 기준으로 중복 없이 최대 30개를 만든다
  Future<List<TmdbMovieDto>> _fetchMovies({
    int? genreId,
    required int version,
  }) async {
    final byId = <int, TmdbMovieDto>{};
    var pageNumber = 1;
    var hasNextPage = true;

    while (byId.length < _maxMovies && hasNextPage) {
      // 더 새로운 요청이 시작됐다면 남은 페이지는 요청하지 않는다
      if (_isStale(version)) break;

      final page = await _service.discoverMovies(
        page: pageNumber,
        genreId: genreId,
      );

      for (final movie in page.results) {
        byId.putIfAbsent(movie.id, () => movie); // 같은 id는 하나만 남김
        if (byId.length == _maxMovies) break;
      }

      hasNextPage = pageNumber < page.totalPages && page.results.isNotEmpty;
      pageNumber++;
    }

    return byId.values.take(_maxMovies).toList();
  }

  bool _isStale(int version) => _disposed || version != _requestVersion;

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}