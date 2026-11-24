import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/map_bounded.dart';
import '../core/utils/safe_notify.dart';
import '../data/models/favorite_list_item.dart';
import '../data/models/favorite_response_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/favorite_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_phase.dart';

/// "내 즐겨찾기" 목록. 서버에서 movieId 목록을 받고, TMDB에서 영화 정보를 최대 5개씩 동시에 조회한다.
class FavoritesViewModel extends ChangeNotifier with SafeNotify {
  FavoritesViewModel({
    required this.favoriteApi,
    required this.movieService,
    required this.sessionGuard,
    required this.accountId,
    this.onSessionExpired,
  });

  static const tmdbConcurrency = 5;

  final FavoriteApiService favoriteApi;
  final TmdbMovieService movieService;
  final SessionGuard sessionGuard;
  final String accountId;
  final Future<void> Function()? onSessionExpired;

  List<FavoriteListItem> items = const [];
  LoadPhase phase = LoadPhase.idle;
  String? message;

  /// 같은 TMDB id는 한 번만 조회한다. 실패(null)는 캐시하지 않는다.
  final Map<int, TmdbMovieDto> _movieCache = {};

  Future<void> load() async {
    final generation = sessionGuard.generation;
    if (!sessionGuard.isCurrent(generation, accountId)) return;
    bool stale() =>
        isDisposed || !sessionGuard.isCurrent(generation, accountId);

    if (items.isEmpty) {
      phase = LoadPhase.loading;
      notifyIfAlive();
    }
    message = null;
    try {
      final favorites = await favoriteApi.fetchMyFavorites();
      if (stale()) return;
      final built = await mapBounded<FavoriteResponseDto, FavoriteListItem>(
        favorites,
        tmdbConcurrency,
        (favorite) async {
          try {
            final cached = _movieCache[favorite.movieId];
            final movie =
                cached ?? await movieService.findMovieById(favorite.movieId);
            if (movie == null) {
              return FavoriteListItem(
                favorite: favorite,
                errorMessage: '영화 정보를 찾을 수 없어요.',
              );
            }
            _movieCache[favorite.movieId] = movie;
            return FavoriteListItem(
              favorite: favorite,
              movie: movie,
            );
          } catch (_) {
            return FavoriteListItem(
              favorite: favorite,
              errorMessage: '영화 정보를 불러오지 못했어요.',
            );
          }
        },
      );
      if (stale()) return;
      items = built;
      phase = built.isEmpty ? LoadPhase.empty : LoadPhase.ready;
    } on DioException catch (error) {
      if (stale()) return;
      if (isSessionExpiredError(error)) {
        await onSessionExpired?.call();
        return;
      }
      phase = items.isEmpty ? LoadPhase.error : LoadPhase.ready;
      message = '즐겨찾기를 불러오지 못했어요.';
    } catch (_) {
      if (stale()) return;
      phase = items.isEmpty ? LoadPhase.error : LoadPhase.ready;
      message = '즐겨찾기를 불러오지 못했어요.';
    }
    notifyIfAlive();
  }
}
