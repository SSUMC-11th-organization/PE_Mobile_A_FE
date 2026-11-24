import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'auth_view_model.dart';
import 'load_error_message.dart';
import 'session_rating_store.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty }

// 이번 로그인 세션에서 등록한 평점(SessionRatingStore)을 TMDB 영화 정보와 묶어 보여주고 수정·삭제합니다.
// v7에는 토큰 기반 내 평점 목록 GET이 없어서 서버에서 다시 조회하지 않고, 쓰기 응답으로 목록을 갱신합니다.
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(
    this._service,
    this._movieService,
    this._auth,
    this._store,
  ) {
    _store.addListener(_onStoreChanged);
  }

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final AuthViewModel _auth;
  final SessionRatingStore _store;

  // 같은 movieId는 한 번만 조회합니다. TMDB에 없는 영화(null)도 결과로 기억합니다.
  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _loadVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  // TMDB 정보 일부를 못 가져왔을 때의 안내입니다.
  String? message;

  bool isEditing = false;
  final Set<int> selectedRatingIds = {};
  bool isDeletingSelected = false;

  void _onStoreChanged() => load();

  Future<void> load() async {
    final version = ++_loadVersion;
    final source = _store.ratings;
    if (status == MyRatingsLoadStatus.idle) {
      status = MyRatingsLoadStatus.loading;
      _notify();
    }

    final entries = <RatingWithMovie>[];
    var missingMovies = 0;
    for (final rating in source) {
      if (!_movieCache.containsKey(rating.movieId)) {
        try {
          _movieCache[rating.movieId] = await _movieService.findMovieById(
            rating.movieId,
          );
        } on DioException catch (error) {
          // 일시적인 실패는 캐시하지 않고 다음에 다시 시도합니다. 평점은 지우지 않고 placeholder로 보여줍니다.
          debugPrint(
            '영화 정보 조회 실패 movieId=${rating.movieId}: ${error.type.name}',
          );
        }
        if (_isStale(version)) return;
      }
      final movie = _movieCache[rating.movieId];
      if (movie == null) missingMovies++;
      entries.add(RatingWithMovie(rating: rating, movie: movie));
    }
    if (_isStale(version)) return;

    ratings = entries;
    // 목록에서 사라진 평점은 선택에서도 뺍니다.
    selectedRatingIds.removeWhere(
      (id) => !entries.any((entry) => entry.rating.ratingId == id),
    );
    status = entries.isEmpty
        ? MyRatingsLoadStatus.empty
        : MyRatingsLoadStatus.success;
    if (entries.isEmpty) isEditing = false;
    message = missingMovies > 0
        ? '일부 영화 정보를 가져오지 못해 "영화 #번호"로 대신 표시합니다.'
        : null;
    _notify();
  }

  // 수정 Dialog가 기다리는 작업입니다. 실패하면 WriteFailure를 던져 Dialog가 입력을 유지하게 합니다.
  Future<void> updateRating({
    required int ratingId,
    required int score,
    required String? comment,
  }) async {
    final version = _auth.sessionVersion;
    try {
      final updated = await _service.updateRating(
        ratingId: ratingId,
        score: score,
        comment: comment,
      );
      _store.replace(updated, version: version);
    } catch (error) {
      await _handleWriteError(
        error,
        ratingId: ratingId,
        version: version,
        fallback: '평점을 수정하지 못했습니다.',
      );
    }
  }

  Future<void> deleteRating(int ratingId) async {
    final version = _auth.sessionVersion;
    try {
      await _service.deleteRating(ratingId);
      _store.remove(ratingId, version: version);
    } catch (error) {
      await _handleWriteError(
        error,
        ratingId: ratingId,
        version: version,
        fallback: '평점을 삭제하지 못했습니다.',
      );
    }
  }

  void startEditing() {
    isEditing = true;
    selectedRatingIds.clear();
    _notify();
  }

  void cancelEditing() {
    if (isDeletingSelected) return;
    isEditing = false;
    selectedRatingIds.clear();
    _notify();
  }

  void toggleSelection(int ratingId) {
    if (isDeletingSelected) return;
    if (!selectedRatingIds.remove(ratingId)) selectedRatingIds.add(ratingId);
    _notify();
  }

  // 확인 Dialog가 닫힌 뒤 시작합니다. 실패한 개수를 돌려주고, 실패한 항목은 선택된 채로 남깁니다.
  Future<int> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) return 0;
    final version = _auth.sessionVersion;
    isDeletingSelected = true;
    _notify();

    var failed = 0;
    try {
      // 순회 중인 Set을 직접 지우면 오류가 나므로 복사본을 돌며 성공한 것만 뺍니다.
      for (final ratingId in selectedRatingIds.toList()) {
        if (version != _auth.sessionVersion) break; // 도중에 만료되면 멈춥니다.
        try {
          await _service.deleteRating(ratingId);
          selectedRatingIds.remove(ratingId);
          _store.remove(ratingId, version: version);
        } catch (error) {
          if (isSessionExpiredError(error)) {
            await _auth.expireSession(version: version);
            break;
          }
          // 이미 지워진 평점(404)은 목록에서 빼고 실패로 세지 않습니다.
          if (serverErrorCode(error) == 'RATING404_1') {
            selectedRatingIds.remove(ratingId);
            _store.remove(ratingId, version: version);
            continue;
          }
          debugPrint('다중 삭제 실패 ratingId=$ratingId: ${serverErrorCode(error)}');
          failed++;
        }
      }
    } finally {
      isDeletingSelected = false;
      if (selectedRatingIds.isEmpty) isEditing = false;
      _notify();
    }
    return failed;
  }

  Future<void> _handleWriteError(
    Object error, {
    required int ratingId,
    required int version,
    required String fallback,
  }) async {
    if (isSessionExpiredError(error)) {
      await _auth.expireSession(version: version);
      throw const WriteFailure('로그인이 만료됐어요. 다시 로그인해 주세요.');
    }
    // 서버에 없는 평점은 화면 목록에서도 빼서 서버와 맞춥니다.
    if (serverErrorCode(error) == 'RATING404_1') {
      _store.remove(ratingId, version: version);
    }
    throw WriteFailure(ratingWriteErrorMessage(error, fallback: fallback));
  }

  // 화면을 벗어났거나 새 로딩이 시작됐다면 늦게 끝난 결과는 버립니다.
  bool _isStale(int version) => _disposed || version != _loadVersion;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadVersion++;
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }
}
