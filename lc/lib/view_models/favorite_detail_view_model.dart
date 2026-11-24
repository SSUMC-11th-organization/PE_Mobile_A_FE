import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/safe_notify.dart';
import '../data/services/favorite_api_service.dart';

/// 영화 상세 화면의 즐겨찾기 버튼 상태.
/// 서버 성공을 확인한 뒤에만 북마크를 바꾼다. (결과를 기다리지 않고 먼저 바꾸는 optimistic update는 쓰지 않는다.)
class FavoriteDetailViewModel extends ChangeNotifier with SafeNotify {
  FavoriteDetailViewModel({
    required this.movieId,
    required this.favoriteApi,
    required this.sessionGuard,
    required this.accountId,
    this.onSessionExpired,
  });

  /// 상세 화면의 TMDB 영화 id. 즐겨찾기 경로에는 favoriteId가 아니라 이 값을 쓴다.
  final int movieId;
  final FavoriteApiService favoriteApi;
  final SessionGuard sessionGuard;
  final String accountId;

  /// AUTH401_2/3/4를 받았을 때 현재 세션을 정리하도록 요청한다. (8주차 expireSession)
  final Future<void> Function()? onSessionExpired;

  bool isFavorite = false;

  /// 서버에서 여부를 한 번이라도 확인했는지. 확인 전에는 버튼을 누를 수 없다.
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

  bool _stale(int generation) =>
      !sessionGuard.isCurrent(generation, accountId) || isDisposed;

  Future<void> load() async {
    if (isLoading || isSaving) return;
    final snap = _snapshot();
    if (!snap.ok) return;
    isLoading = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      final result = await favoriteApi.checkFavorite(movieId: movieId);
      if (_stale(snap.generation)) return;
      isFavorite = result.isFavorite;
      hasLoadedStatus = true;
    } on DioException catch (error) {
      if (_stale(snap.generation)) return;
      if (isSessionExpiredError(error)) {
        await onSessionExpired?.call();
        return;
      }
      errorMessage = '즐겨찾기 여부를 확인하지 못했습니다.';
    } catch (_) {
      if (_stale(snap.generation)) return;
      errorMessage = '즐겨찾기 여부를 확인하지 못했습니다.';
    } finally {
      if (!_stale(snap.generation)) {
        isLoading = false;
        notifyIfAlive();
      }
    }
  }

  /// 등록·해제를 토글한다. 요청 중에는 중복 탭을 막는다. 성공했으면 true를 돌려준다.
  Future<bool> toggle() async {
    if (isSaving || isLoading || !hasLoadedStatus) return false;
    final snap = _snapshot();
    if (!snap.ok) return false;
    final before = isFavorite;
    var succeeded = false;
    isSaving = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      if (before) {
        await favoriteApi.deleteFavorite(movieId: movieId);
        if (_stale(snap.generation)) return false;
        isFavorite = false;
      } else {
        await favoriteApi.addFavorite(movieId: movieId);
        if (_stale(snap.generation)) return false;
        isFavorite = true;
      }
      succeeded = true;
    } on DioException catch (error) {
      if (_stale(snap.generation)) return false;
      final code = apiErrorCode(error);
      if (isSessionExpiredError(error)) {
        isFavorite = before;
        errorMessage = '로그인이 만료됐어요. 다시 로그인해 주세요.';
        await onSessionExpired?.call();
      } else if (code == 'FAVORITE409_1' || code == 'FAVORITE404_1') {
        // 이미 등록(409)이거나 이미 해제(404)이면 POST·DELETE를 반복하지 않고
        // 서버의 현재 여부를 GET으로 확인해 화면을 맞춘다.
        await _syncWithServer(snap.generation, before);
      } else {
        isFavorite = before;
        errorMessage = before ? '즐겨찾기 해제에 실패했습니다.' : '즐겨찾기 등록에 실패했습니다.';
      }
    } catch (_) {
      if (_stale(snap.generation)) return false;
      isFavorite = before;
      errorMessage = before ? '즐겨찾기 해제에 실패했습니다.' : '즐겨찾기 등록에 실패했습니다.';
    } finally {
      if (!_stale(snap.generation)) {
        isSaving = false;
        notifyIfAlive();
      }
    }
    return succeeded;
  }

  Future<void> _syncWithServer(int generation, bool before) async {
    try {
      final synced = await favoriteApi.checkFavorite(movieId: movieId);
      if (_stale(generation)) return;
      isFavorite = synced.isFavorite;
      errorMessage = null;
    } catch (_) {
      if (_stale(generation)) return;
      isFavorite = before;
      errorMessage = '서버 상태를 다시 확인하지 못했습니다.';
    }
  }
}
