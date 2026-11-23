import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/map_bounded.dart';
import '../core/utils/safe_notify.dart';
import '../data/models/favorite_list_item.dart';
import '../data/models/favorite_response_dto.dart';
import '../data/services/favorite_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_phase.dart';

class FavoritesViewModel extends ChangeNotifier with SafeNotify {
  FavoritesViewModel({
    required this.favoriteApi,
    required this.tmdbApi,
    required this.sessionGuard,
    required this.accountId,
    required this.onSessionExpired,
    this.enrichmentConcurrency = 5,
  });

  final FavoriteApiService favoriteApi;
  final TmdbMovieService tmdbApi;
  final SessionGuard sessionGuard;
  final String accountId;
  final Future<void> Function() onSessionExpired;
  final int enrichmentConcurrency;

  LoadPhase phase = LoadPhase.idle;
  List<FavoriteListItem> items = const [];
  String? errorMessage;
  int _refreshGeneration = 0;

  bool _isLive(int sessionGeneration, int refreshGeneration) =>
      sessionGuard.isCurrent(sessionGeneration, accountId) &&
      refreshGeneration == _refreshGeneration &&
      !isDisposed;

  // 목록이 이미 있으면 화면을 비우지 않고 조용히 다시 조회한다.
  Future<void> refresh() async {
    final sessionGeneration = sessionGuard.generation;
    if (!sessionGuard.isCurrent(sessionGeneration, accountId) || isDisposed) {
      return;
    }
    final refreshGeneration = ++_refreshGeneration;
    if (phase != LoadPhase.ready) {
      phase = LoadPhase.loading;
      errorMessage = null;
      notifyIfAlive();
    }
    try {
      final favorites = await favoriteApi.fetchMyFavorites();
      if (!_isLive(sessionGeneration, refreshGeneration)) return;
      final enriched = await mapBounded(
        favorites,
        enrichmentConcurrency,
        _enrich,
      );
      if (!_isLive(sessionGeneration, refreshGeneration)) return;
      items = enriched;
      phase = items.isEmpty ? LoadPhase.empty : LoadPhase.ready;
    } on DioException catch (error) {
      if (!_isLive(sessionGeneration, refreshGeneration)) return;
      if (isSessionExpired(error)) {
        await onSessionExpired();
        return;
      }
      _failList();
    } catch (_) {
      if (!_isLive(sessionGeneration, refreshGeneration)) return;
      _failList();
    } finally {
      if (_isLive(sessionGeneration, refreshGeneration)) notifyIfAlive();
    }
  }

  // 영화 정보 한 건만 실패한 카드는 그 카드만 다시 조회한다.
  Future<void> retryMovie(int movieId) async {
    final sessionGeneration = sessionGuard.generation;
    final refreshGeneration = _refreshGeneration;
    final index = items.indexWhere(
      (item) => item.favorite.movieId == movieId && !item.hasMovie,
    );
    if (index < 0 || items[index].isRetrying || isDisposed) return;

    _replace(movieId, (item) => item.copyWith(isRetrying: true));
    final result = await _enrich(items[index].favorite);
    if (!_isLive(sessionGeneration, refreshGeneration)) return;
    _replace(movieId, (_) => result);
  }

  Future<FavoriteListItem> _enrich(FavoriteResponseDto favorite) async {
    try {
      final movie = await tmdbApi.fetchMovieDetail(favorite.movieId);
      return FavoriteListItem(favorite: favorite, movie: movie);
    } catch (_) {
      return FavoriteListItem(favorite: favorite);
    }
  }

  void _replace(
    int movieId,
    FavoriteListItem Function(FavoriteListItem item) update,
  ) {
    items = [
      for (final item in items)
        item.favorite.movieId == movieId ? update(item) : item,
    ];
    notifyIfAlive();
  }

  void _failList() {
    items = const [];
    phase = LoadPhase.error;
    errorMessage = '즐겨찾기를 불러오지 못했습니다.';
  }
}
