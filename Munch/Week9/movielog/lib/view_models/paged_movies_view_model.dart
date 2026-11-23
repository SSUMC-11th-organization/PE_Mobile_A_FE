import 'package:flutter/foundation.dart';

import '../core/utils/safe_notify.dart';
import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/models/tmdb_movie_page_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_phase.dart';

typedef MovieQuery = ({List<int>? genreIds, String query});

// 영화 목록과 검색 화면이 각자 별도 인스턴스로 사용한다.
class PagedMoviesViewModel extends ChangeNotifier with SafeNotify {
  PagedMoviesViewModel({required this.tmdbApi});

  static const maxTmdbPage = 500;

  final TmdbMovieService tmdbApi;

  LoadPhase phase = LoadPhase.idle;
  final List<TmdbMovieDto> movies = [];
  int nextPage = 1;
  int totalPages = 1;
  bool isLoadingMore = false;
  String? errorMessage;
  String? loadMoreError;

  List<TmdbGenreDto> genres = const [];
  Map<int, String> genreNames = const {};
  bool genresFailed = false;

  int _requestGeneration = 0;
  MovieQuery _condition = (genreIds: null, query: '');

  bool get hasMore => nextPage <= totalPages;
  bool get isBusy => phase == LoadPhase.loading;
  List<int>? get selectedGenreIds => _condition.genreIds;
  String get query => _condition.query;

  Future<void> loadGenres() async {
    genresFailed = false;
    notifyIfAlive();
    try {
      final result = await tmdbApi.fetchGenres();
      if (isDisposed) return;
      genres = result;
      genreNames = {for (final genre in result) genre.id: genre.name};
    } catch (_) {
      if (isDisposed) return;
      genresFailed = true;
    }
    notifyIfAlive();
  }

  Future<void> loadInitial({List<int>? genreIds, String query = ''}) async {
    if (isDisposed) return;
    _condition = (
      genreIds: genreIds == null || genreIds.isEmpty
          ? null
          : List.unmodifiable(genreIds),
      query: query.trim(),
    );
    final generation = ++_requestGeneration;
    phase = LoadPhase.loading;
    errorMessage = null;
    loadMoreError = null;
    isLoadingMore = false;
    movies.clear();
    nextPage = 1;
    totalPages = 1;
    notifyIfAlive();
    try {
      final page = await _fetchPage(1, _condition);
      if (generation != _requestGeneration || isDisposed) return;
      movies.addAll(_dedupe(page.results));
      _applyPaging(page);
      phase = movies.isEmpty ? LoadPhase.empty : LoadPhase.ready;
    } catch (_) {
      if (generation != _requestGeneration || isDisposed) return;
      phase = LoadPhase.error;
      errorMessage = _condition.query.isEmpty
          ? '영화 목록을 불러오지 못했습니다.'
          : '검색 결과를 불러오지 못했습니다.';
    } finally {
      if (generation == _requestGeneration) notifyIfAlive();
    }
  }

  Future<void> reload() =>
      loadInitial(genreIds: _condition.genreIds, query: _condition.query);

  // 실패해도 nextPage를 올리지 않아 같은 page를 다시 요청한다.
  Future<void> loadNextPage() async {
    if (isDisposed || isLoadingMore || !hasMore || phase != LoadPhase.ready) {
      return;
    }
    final generation = _requestGeneration;
    final pageToLoad = nextPage;
    isLoadingMore = true;
    loadMoreError = null;
    notifyIfAlive();
    try {
      final page = await _fetchPage(pageToLoad, _condition);
      if (generation != _requestGeneration || isDisposed) return;
      movies.addAll(_dedupe(page.results));
      _applyPaging(page);
    } catch (_) {
      if (generation != _requestGeneration || isDisposed) return;
      loadMoreError = '추가 영화 조회에 실패했습니다.';
    } finally {
      if (generation == _requestGeneration && !isDisposed) {
        isLoadingMore = false;
        notifyIfAlive();
      }
    }
  }

  Future<TmdbMoviePageDto> _fetchPage(int page, MovieQuery condition) async {
    final result = condition.query.isNotEmpty
        ? await tmdbApi.searchMovies(page: page, query: condition.query)
        : await tmdbApi.discoverMovies(
            page: page,
            genreIds: condition.genreIds,
          );
    if (result.page != page || result.totalPages < 0) {
      throw const FormatException('TMDB page metadata is inconsistent.');
    }
    return result;
  }

  void _applyPaging(TmdbMoviePageDto page) {
    totalPages = page.totalPages > maxTmdbPage ? maxTmdbPage : page.totalPages;
    nextPage = page.page + 1;
  }

  // TMDB는 page가 달라도 같은 영화를 다시 내려줄 수 있다.
  List<TmdbMovieDto> _dedupe(List<TmdbMovieDto> incoming) {
    final seen = movies.map((movie) => movie.id).toSet();
    return incoming.where((movie) => seen.add(movie.id)).toList();
  }
}
