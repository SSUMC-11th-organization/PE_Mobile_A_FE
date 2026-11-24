import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/safe_notify.dart';
import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/models/tmdb_movie_page.dart';
import '../data/services/tmdb_movie_service.dart';
import '../utils/tmdb_movie_format.dart';
import 'load_phase.dart';

/// 영화 목록(장르 필터)과 검색 결과가 함께 쓰는 "더 보기" 페이지네이션 ViewModel.
///
/// - [query]가 비어 있으면 discover(장르 필터), 아니면 search를 호출한다.
/// - 조건(장르·검색어)이 바뀌면 [_generation]을 올려 이전 요청의 응답을 버린다.
/// - 같은 영화가 페이지 사이에 겹쳐도 TMDB id 기준으로 하나만 남긴다.
/// - TMDB는 page를 최대 500까지만 받으므로 그 이상은 요청하지 않는다.
class PagedMoviesViewModel extends ChangeNotifier with SafeNotify {
  PagedMoviesViewModel(
    this._service, {
    this.debounce = const Duration(milliseconds: 400),
  });

  static const maxTmdbPage = 500;

  final TmdbMovieService _service;

  /// 검색어 입력 후 요청을 보내기까지 기다리는 시간. (Challenge A)
  final Duration debounce;

  final List<TmdbMovieDto> _movies = [];
  final Set<int> _ids = {};

  List<TmdbMovieDto> get movies => List.unmodifiable(_movies);
  List<TmdbGenreDto> genres = const [];
  Map<int, String> _genreNames = const {};
  Map<int, String> get genreNames => _genreNames;

  /// null이면 '전체'.
  int? selectedGenreId;
  String query = '';

  LoadPhase phase = LoadPhase.idle;
  bool isLoadingMore = false;
  String? loadMoreError;
  String? message;

  int _page = 0;
  int _totalPages = 0;
  int _generation = 0;
  Timer? _timer;

  bool get isSearching => query.trim().isNotEmpty;

  bool get hasMore =>
      _page > 0 && _page < _totalPages && _page < maxTmdbPage;

  bool get isInitialLoading =>
      phase == LoadPhase.idle || phase == LoadPhase.loading;

  List<String> genreNamesOf(TmdbMovieDto movie) =>
      movie.genreNamesIn(_genreNames);

  /// 처음 화면 진입: 장르 목록과 1페이지를 함께 요청한다.
  Future<void> loadInitial() => _reload();

  Future<void> retry() => _reload();

  Future<void> selectGenre(int? genreId) async {
    if (isInitialLoading || genreId == selectedGenreId) return;
    selectedGenreId = genreId;
    await _reload();
  }

  /// 검색창 입력. debounce 후 마지막 입력으로만 요청한다.
  void onQueryChanged(String value) {
    _timer?.cancel();
    final next = value.trim();
    if (next == query) return;
    // 입력이 바뀌는 순간 이전 요청의 응답은 쓸모가 없다.
    _generation++;
    if (next.isEmpty) {
      query = '';
      _clear();
      phase = LoadPhase.idle;
      isLoadingMore = false;
      notifyIfAlive();
      return;
    }
    query = next;
    _clear();
    phase = LoadPhase.loading;
    isLoadingMore = false;
    notifyIfAlive();
    _timer = Timer(debounce, () => _reload(searchOnly: true));
  }

  void _clear() {
    _movies.clear();
    _ids.clear();
    _page = 0;
    _totalPages = 0;
    loadMoreError = null;
    message = null;
  }

  Future<void> _reload({bool searchOnly = false}) async {
    final generation = ++_generation;
    final currentQuery = query;
    _clear();
    phase = LoadPhase.loading;
    isLoadingMore = false;
    notifyIfAlive();
    try {
      final needGenres = !searchOnly && genres.isEmpty;
      final results = await Future.wait<Object>([
        _fetchPage(1, currentQuery),
        if (needGenres) _service.fetchGenres(),
      ]);
      if (_isStale(generation)) return;
      final page = results[0] as TmdbMoviePageDto;
      if (needGenres) {
        genres = results[1] as List<TmdbGenreDto>;
        _genreNames = {for (final g in genres) g.id: g.name};
      }
      _append(page);
      _page = 1;
      _totalPages = page.totalPages;
      phase = _movies.isEmpty ? LoadPhase.empty : LoadPhase.ready;
    } catch (error) {
      if (_isStale(generation)) return;
      debugPrint('영화 목록 로드 실패: $error');
      phase = LoadPhase.error;
      message = '영화를 불러오지 못했어요. 다시 시도해 주세요.';
    }
    notifyIfAlive();
  }

  /// 다음 페이지를 이어 붙인다. 이미 요청 중이거나 더 없으면 무시한다.
  /// 실패해도 기존 목록은 그대로 두고 [loadMoreError]만 남긴다.
  Future<void> loadMore() async {
    if (phase != LoadPhase.ready || isLoadingMore || !hasMore) return;
    final generation = _generation;
    final next = _page + 1;
    isLoadingMore = true;
    loadMoreError = null;
    notifyIfAlive();
    try {
      final page = await _fetchPage(next, query);
      if (_isStale(generation)) return;
      _append(page);
      _page = next;
      _totalPages = page.totalPages;
    } catch (error) {
      if (_isStale(generation)) return;
      debugPrint('다음 페이지 로드 실패: $error');
      loadMoreError = '다음 영화를 불러오지 못했어요.';
    }
    isLoadingMore = false;
    notifyIfAlive();
  }

  Future<TmdbMoviePageDto> _fetchPage(int page, String q) {
    if (q.trim().isNotEmpty) {
      return _service.searchMovies(page: page, query: q.trim());
    }
    return _service.discoverMovies(page: page, genreId: selectedGenreId);
  }

  void _append(TmdbMoviePageDto page) {
    for (final movie in page.results) {
      if (_ids.add(movie.id)) _movies.add(movie);
    }
  }

  bool _isStale(int generation) => isDisposed || generation != _generation;

  @override
  void dispose() {
    _timer?.cancel();
    _generation++;
    super.dispose();
  }
}
