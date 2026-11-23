import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/safe_notify.dart';
import '../data/services/favorite_api_service.dart';

class FavoriteDetailViewModel extends ChangeNotifier with SafeNotify {
  FavoriteDetailViewModel({
    required this.movieId,
    required this.favoriteApi,
    required this.sessionGuard,
    required this.accountId,
    required this.onSessionExpired,
  });

  final int movieId;
  final FavoriteApiService favoriteApi;
  final SessionGuard sessionGuard;
  final String accountId;
  final Future<void> Function() onSessionExpired;

  bool isFavorite = false;
  bool hasLoadedStatus = false;
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  ({int generation, bool ok}) _snapshot() {
    final generation = sessionGuard.generation;
    return (
      generation: generation,
      ok: sessionGuard.isCurrent(generation, accountId) && !isDisposed,
    );
  }

  bool _isLive(int generation) =>
      sessionGuard.isCurrent(generation, accountId) && !isDisposed;

  Future<void> load() async {
    if (isLoading || isSaving) return;
    final snap = _snapshot();
    if (!snap.ok) return;
    isLoading = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      final result = await favoriteApi.checkFavorite(movieId: movieId);
      if (!_isLive(snap.generation)) return;
      isFavorite = result.isFavorite;
      hasLoadedStatus = true;
    } on DioException catch (error) {
      if (!_isLive(snap.generation)) return;
      if (isSessionExpired(error)) {
        await onSessionExpired();
        return;
      }
      errorMessage = '즐겨찾기 여부를 확인하지 못했습니다.';
    } catch (_) {
      if (!_isLive(snap.generation)) return;
      errorMessage = '즐겨찾기 여부를 확인하지 못했습니다.';
    } finally {
      if (_isLive(snap.generation)) {
        isLoading = false;
        notifyIfAlive();
      }
    }
  }

  // 서버 성공을 확인한 뒤에만 북마크를 바꾼다(optimistic update 사용 안 함).
  Future<void> toggle() async {
    if (isSaving || isLoading || !hasLoadedStatus) return;
    final snap = _snapshot();
    if (!snap.ok) return;
    final before = isFavorite;
    final failMessage = before ? '즐겨찾기 해제에 실패했습니다.' : '즐겨찾기 등록에 실패했습니다.';
    isSaving = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      if (before) {
        await favoriteApi.deleteFavorite(movieId: movieId);
      } else {
        await favoriteApi.addFavorite(movieId: movieId);
      }
      if (!_isLive(snap.generation)) return;
      isFavorite = !before;
    } on DioException catch (error) {
      if (!_isLive(snap.generation)) return;
      if (isSessionExpired(error)) {
        await onSessionExpired();
        return;
      }
      final code = apiErrorCode(error);
      if (code == 'FAVORITE409_1' || code == 'FAVORITE404_1') {
        await _syncFromServer(snap.generation, before);
      } else {
        isFavorite = before;
        errorMessage = failMessage;
      }
    } catch (_) {
      if (!_isLive(snap.generation)) return;
      isFavorite = before;
      errorMessage = failMessage;
    } finally {
      if (_isLive(snap.generation)) {
        isSaving = false;
        notifyIfAlive();
      }
    }
  }

  // 이미 등록(409)·이미 해제(404)면 POST/DELETE를 반복하지 않고 현재 여부로 맞춘다.
  Future<void> _syncFromServer(int generation, bool before) async {
    try {
      final synced = await favoriteApi.checkFavorite(movieId: movieId);
      if (!_isLive(generation)) return;
      isFavorite = synced.isFavorite;
    } catch (_) {
      if (!_isLive(generation)) return;
      isFavorite = before;
      errorMessage = '서버 상태를 다시 확인하지 못했습니다.';
    }
  }
}
