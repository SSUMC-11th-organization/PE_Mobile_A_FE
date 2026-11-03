import 'package:flutter/foundation.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import '../services/movie_list_preferences.dart';
import 'load_error_message.dart';

enum MovieListLoadStatus { idle, loading, success, empty, error }

enum MovieSort {
  popular('인기순'),
  latest('최신순'),
  title('제목순');

  const MovieSort(this.label);
  final String label;

  static MovieSort fromName(String? name) => MovieSort.values.firstWhere(
    (sort) => sort.name == name,
    orElse: () => MovieSort.popular,
  );
}

class MovieListViewModel extends ChangeNotifier {
  MovieListViewModel(this._service, this._preferences);

  static const maxMovies = 30;

  final TmdbMovieService _service;
  final MovieListPreferences _preferences;

  List<TmdbMovieDto> movies = const [];
  List<TmdbGenreDto> genres = const [];
  int? selectedGenreId;
  MovieSort sort = MovieSort.popular;
  MovieListLoadStatus status = MovieListLoadStatus.idle;
  bool isRefreshing = false;
  String? message;

  // TMDB가 준 인기 순서를 보관해 두고, 정렬을 바꿀 때마다 이 목록에서 다시 정렬합니다.
  List<TmdbMovieDto> _fetchedMovies = const [];
  int _requestVersion = 0;
  bool _disposed = false;

  // Discover 요청 중에는 장르를 바꾸지 못하게 화면과 ViewModel 양쪽에서 막습니다.
  bool get isBusy => status == MovieListLoadStatus.loading || isRefreshing;

  String? get selectedGenreName {
    for (final genre in genres) {
      if (genre.id == selectedGenreId) return genre.name;
    }
    return null;
  }

  Future<void> loadInitial() async {
    final version = _beginRequest(refreshing: false);
    try {
      final savedSort = await _preferences.readSort();
      final savedGenreId = await _preferences.readGenreId();
      final fetchedGenres = await _service.fetchGenres();
      if (_isStale(version)) return;

      genres = fetchedGenres;
      sort = MovieSort.fromName(savedSort);
      // 장르 목록에서 사라진 ID가 저장돼 있으면 전체로 돌아갑니다.
      selectedGenreId = fetchedGenres.any((genre) => genre.id == savedGenreId)
          ? savedGenreId
          : null;
      notifyListeners();

      final discovered = await _fetchUpToThirtyMovies(genreId: selectedGenreId);
      _complete(version, discovered);
    } catch (error) {
      _fail(version, error);
    }
  }

  Future<void> selectGenre(int? genreId) async {
    if (isBusy || genreId == selectedGenreId) return;
    selectedGenreId = genreId;
    // 로딩 상태를 먼저 걸어 두고 저장해야, 저장을 기다리는 사이 다른 칩을 누를 수 없습니다.
    final reload = _reloadMovies(refreshing: false);
    await _preferences.saveGenreId(genreId);
    await reload;
  }

  Future<void> retry() async {
    if (isBusy) return;
    if (genres.isEmpty) return loadInitial();
    await _reloadMovies(refreshing: false);
  }

  // 새로고침 중에는 기존 목록을 그대로 두고, 완료되면 최신 목록으로 바꿉니다.
  Future<void> refresh() async {
    if (isBusy) return;
    if (genres.isEmpty) return loadInitial();
    await _reloadMovies(refreshing: true);
  }

  Future<void> changeSort(MovieSort newSort) async {
    if (newSort == sort) return;
    sort = newSort;
    movies = _sorted(_fetchedMovies);
    notifyListeners();
    await _preferences.saveSort(newSort.name);
  }

  Future<void> _reloadMovies({required bool refreshing}) async {
    final version = _beginRequest(refreshing: refreshing);
    try {
      final discovered = await _fetchUpToThirtyMovies(genreId: selectedGenreId);
      _complete(version, discovered);
    } catch (error) {
      _fail(version, error);
    }
  }

  // 페이지 크기를 가정하지 않고, 30개가 모이거나 마지막 페이지가 될 때까지 page 1부터 요청합니다.
  Future<List<TmdbMovieDto>> _fetchUpToThirtyMovies({int? genreId}) async {
    final byId = <int, TmdbMovieDto>{};
    var pageNumber = 1;
    var hasNextPage = true;

    while (byId.length < maxMovies && hasNextPage) {
      final page = await _service.discoverMovies(
        page: pageNumber,
        genreId: genreId,
      );

      // 페이지 사이에 같은 영화가 다시 와도 TMDB id를 key로 써서 하나만 남깁니다.
      for (final movie in page.results) {
        byId.putIfAbsent(movie.id, () => movie);
        if (byId.length == maxMovies) break;
      }

      hasNextPage = pageNumber < page.totalPages && page.results.isNotEmpty;
      pageNumber++;
    }

    return byId.values.toList();
  }

  int _beginRequest({required bool refreshing}) {
    final version = ++_requestVersion;
    if (refreshing) {
      isRefreshing = true;
    } else {
      status = MovieListLoadStatus.loading;
    }
    notifyListeners();
    return version;
  }

  void _complete(int version, List<TmdbMovieDto> discovered) {
    if (_isStale(version)) return;
    _fetchedMovies = discovered;
    movies = _sorted(discovered);
    status = discovered.isEmpty
        ? MovieListLoadStatus.empty
        : MovieListLoadStatus.success;
    isRefreshing = false;
    notifyListeners();
  }

  void _fail(int version, Object error) {
    if (_isStale(version)) return;
    debugPrint('영화 목록 로드 실패: $error');
    status = MovieListLoadStatus.error;
    message = loadErrorMessage(
      error,
      fallback: selectedGenreId == null
          ? '영화를 불러오지 못했어요.\n잠시 후 다시 시도해 주세요.'
          : '해당 장르 영화를 불러오지 못했어요.\n잠시 후 다시 시도해 주세요.',
    );
    isRefreshing = false;
    notifyListeners();
  }

  // 화면을 벗어났거나 더 최근 요청이 시작됐다면 늦게 도착한 응답은 버립니다.
  bool _isStale(int version) => _disposed || version != _requestVersion;

  List<TmdbMovieDto> _sorted(List<TmdbMovieDto> source) {
    if (sort == MovieSort.popular) return source;

    final popularOrder = {
      for (var i = 0; i < source.length; i++) source[i].id: i,
    };
    int compare(TmdbMovieDto a, TmdbMovieDto b) => switch (sort) {
      MovieSort.latest => (b.releaseDate ?? '').compareTo(a.releaseDate ?? ''),
      MovieSort.title => a.title.compareTo(b.title),
      MovieSort.popular => 0,
    };

    return [...source]..sort((a, b) {
      final result = compare(a, b);
      // 기준 값이 같으면 원래 인기 순서를 유지합니다.
      return result != 0
          ? result
          : popularOrder[a.id]!.compareTo(popularOrder[b.id]!);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
