import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'auth_view_model.dart';
import 'session_rating_store.dart';
import 'submit_status.dart';

export 'submit_status.dart' show RatingWriteException;

enum MyRatingsLoadStatus { idle, loading, success, empty }

/// "내가 등록한 평점" 화면의 상태. 이번 세션에서 등록한 평점([SessionRatingStore])을
/// TMDB 영화 정보와 묶어 보여주고, v8 토큰 기반 API로 수정·삭제한다.
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(
    this._service,
    this._movieService,
    this._store,
    this._auth,
  );

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final SessionRatingStore _store;
  final AuthViewModel _auth;

  /// 같은 movieId는 한 번만 조회한다. 404(null)도 캐시하지만 네트워크 실패는 캐시하지 않는다.
  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _requestVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;

  // ───────── 다중 선택(편집) 모드 ─────────

  bool isEditMode = false;
  final Set<int> selectedRatingIds = {};
  bool isDeletingSelected = false;

  /// 세션의 평점에 TMDB 영화 정보를 붙여 목록을 만든다.
  /// 영화 정보를 찾지 못해도 평점은 지우지 않고 placeholder로 보여준다.
  Future<void> load() async {
    final version = ++_requestVersion;
    if (ratings.isEmpty) {
      status = MyRatingsLoadStatus.loading;
      notifyListeners();
    }
    message = null;

    final entries = <RatingWithMovie>[];
    var missingMovies = 0;
    for (final rating in _store.ratings) {
      if (_isStale(version)) return;
      if (!_movieCache.containsKey(rating.movieId)) {
        try {
          _movieCache[rating.movieId] = await _movieService.findMovieById(
            rating.movieId,
          );
        } on DioException {
          // 영화 정보 조회 실패가 평점 목록을 지우지 않는다. 다음 로딩에서 다시 시도한다.
        }
      }
      final movie = _movieCache[rating.movieId];
      if (movie == null) missingMovies++;
      entries.add(RatingWithMovie(rating: rating, movie: movie));
    }
    if (_isStale(version)) return;

    ratings = entries;
    final liveIds = {for (final entry in entries) entry.rating.ratingId};
    selectedRatingIds.removeWhere((id) => !liveIds.contains(id));
    status = entries.isEmpty
        ? MyRatingsLoadStatus.empty
        : MyRatingsLoadStatus.success;
    if (entries.isEmpty) isEditMode = false;
    if (missingMovies > 0) {
      message = '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.';
    }
    notifyListeners();
  }

  /// 쓰기 실패를 Dialog가 그대로 보여줄 수 있는 RatingWriteException으로 바꿔 던진다.
  ///
  /// - AUTH401_2/3/4: 세션을 정리한다. (Router가 로그인 화면으로 보낸다.)
  /// - RATING403_1: 권한 부족이다. 안내만 하고 로그아웃하지 않는다.
  /// - RATING404_1: 이미 없는 평점이다. 안내하고 목록에서 뺀다.
  Future<T> _runWrite<T>(int ratingId, Future<T> Function() write) async {
    final version = _auth.sessionVersion;
    try {
      final result = await write();
      if (_isSessionChanged(version)) {
        throw const RatingWriteException('로그인 상태가 바뀌어 결과를 반영하지 않았어요.');
      }
      return result;
    } on DioException catch (error) {
      if (_isSessionChanged(version)) {
        throw const RatingWriteException('로그인 상태가 바뀌어 결과를 반영하지 않았어요.');
      }
      if (isSessionExpiredError(error)) {
        await _auth.expireSession();
        throw const RatingWriteException('로그인이 만료됐어요. 다시 로그인해 주세요.');
      }
      final writeMessage = writeErrorMessage(error);
      if (apiErrorCode(error) == 'RATING404_1') {
        _store.remove(ratingId);
        if (!_disposed) await load();
      }
      throw RatingWriteException(writeMessage);
    } on StateError {
      throw const RatingWriteException('저장 결과를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
  }

  /// 수정 응답의 Rating 객체로 카드를 갱신한다. (목록을 다시 조회하지 않는다.)
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final updated = await _runWrite(
      ratingId,
      () => _service.updateRating(
        ratingId: ratingId,
        score: score,
        comment: comment,
      ),
    );
    _store.replace(updated);
    if (!_disposed) await load();
  }

  Future<void> deleteRating(int ratingId) async {
    await _runWrite(ratingId, () => _service.deleteRating(ratingId));
    _store.remove(ratingId);
    if (!_disposed) await load();
  }

  // ───────── 편집 모드 ─────────

  void enterEditMode() {
    if (status != MyRatingsLoadStatus.success) return;
    isEditMode = true;
    selectedRatingIds.clear();
    notifyListeners();
  }

  void cancelEditMode() {
    if (isDeletingSelected) return;
    isEditMode = false;
    selectedRatingIds.clear();
    notifyListeners();
  }

  void toggleSelection(int ratingId) {
    if (!isEditMode || isDeletingSelected) return;
    if (!selectedRatingIds.add(ratingId)) selectedRatingIds.remove(ratingId);
    notifyListeners();
  }

  /// 선택한 평점을 순서대로 삭제한다. 일부만 실패하면 실패한 항목의 선택은 유지하고
  /// 성공한 항목만 목록에서 사라지게 한다. 실패한 개수를 돌려준다.
  Future<int> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) return 0;
    final version = _auth.sessionVersion;
    isDeletingSelected = true;
    notifyListeners();
    var failed = 0;
    try {
      // 원본 Set을 순회하면서 지우면 ConcurrentModificationError가 나므로 복사본을 순회한다.
      for (final ratingId in selectedRatingIds.toList()) {
        try {
          await _service.deleteRating(ratingId);
          if (_isSessionChanged(version)) return failed;
          selectedRatingIds.remove(ratingId);
          _store.remove(ratingId);
        } on DioException catch (error) {
          if (_isSessionChanged(version)) return failed;
          if (isSessionExpiredError(error)) {
            await _auth.expireSession();
            return failed;
          }
          if (apiErrorCode(error) == 'RATING404_1') {
            // 이미 없는 평점이므로 목록에서도 뺀다.
            selectedRatingIds.remove(ratingId);
            _store.remove(ratingId);
          } else {
            failed++;
          }
        } on StateError {
          failed++;
        }
      }
    } finally {
      isDeletingSelected = false;
      if (!_disposed) notifyListeners(); // 예상하지 못한 오류에도 로딩을 해제한다.
    }
    if (_disposed) return failed;
    await load();
    if (failed == 0) {
      isEditMode = false;
      selectedRatingIds.clear();
    } else {
      message = '$failed개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.';
    }
    if (!_disposed) notifyListeners();
    return failed;
  }

  bool _isStale(int version) => _disposed || version != _requestVersion;

  bool _isSessionChanged(int version) =>
      _disposed || version != _auth.sessionVersion;

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
