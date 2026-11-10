import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_error_message.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._movieService, this.memberId);

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  // 회원가입 결과로 받은 학습용 회원 ID입니다. 인증 수단이 아닙니다.
  final int memberId;

  // 같은 movieId는 한 번만 조회합니다. TMDB에 없는 영화(null)도 결과로 기억합니다.
  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _requestVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;

  // 저장은 성공했지만 그 뒤 목록 GET만 실패했을 때의 안내입니다. 저장 실패와는 다른 상태입니다.
  String? refreshWarning;

  bool isEditing = false;
  final Set<int> selectedRatingIds = {};
  bool isDeletingSelected = false;

  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    _notify();

    try {
      final rawRatings = await _service.fetchMyRatings(memberId);
      if (_isStale(version)) return;

      final entries = <RatingWithMovie>[];
      var missingMovies = 0;
      for (final rating in rawRatings) {
        if (!_movieCache.containsKey(rating.movieId)) {
          try {
            _movieCache[rating.movieId] = await _movieService.findMovieById(
              rating.movieId,
            );
          } on DioException catch (error) {
            // 일시적인 실패는 캐시하지 않고 다음 로딩에서 다시 시도합니다. 평점 목록은 지우지 않습니다.
            debugPrint('영화 정보 조회 실패 movieId=${rating.movieId}: $error');
          }
          if (_isStale(version)) return;
        }
        final movie = _movieCache[rating.movieId];
        if (movie == null) missingMovies++;
        entries.add(RatingWithMovie(rating: rating, movie: movie));
      }

      ratings = entries;
      refreshWarning = null;
      // 목록에서 사라진 평점은 선택에서도 뺍니다.
      selectedRatingIds.removeWhere(
        (id) => !entries.any((entry) => entry.rating.ratingId == id),
      );
      status = entries.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
      if (entries.isEmpty) isEditing = false;
      if (missingMovies > 0) {
        message = '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.';
      }
    } catch (error) {
      if (_isStale(version)) return;
      debugPrint('평점 조회 실패: $error');
      status = MyRatingsLoadStatus.error;
      message = myRatingsErrorMessage(error);
    }

    if (!_isStale(version)) notifyListeners();
  }

  // 수정 Dialog가 기다리는 작업입니다. 쓰기 자체가 실패할 때만 WriteFailure를 던지고,
  // 쓰기 성공 뒤 GET만 실패하면 저장 성공으로 끝내고 목록에 재조회 안내만 남깁니다.
  Future<void> updateRating({
    required int ratingId,
    required int score,
    required String? comment,
  }) async {
    try {
      await _service.updateRating(
        memberId: memberId,
        ratingId: ratingId,
        score: score,
        comment: comment,
      );
    } catch (error) {
      await _handleWriteError(error, fallback: '평점을 수정하지 못했습니다.');
    }
    await _refreshAfterWrite();
  }

  Future<void> deleteRating(int ratingId) async {
    try {
      await _service.deleteRating(memberId: memberId, ratingId: ratingId);
    } catch (error) {
      await _handleWriteError(error, fallback: '평점을 삭제하지 못했습니다.');
    }
    await _refreshAfterWrite();
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

  // 확인 Dialog가 닫힌 뒤 화면에서 시작합니다. 실패한 개수를 돌려주고, 실패한 항목은 선택된 채로 남겨 다시 시도할 수 있게 합니다.
  Future<int> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) return 0;
    isDeletingSelected = true;
    _notify();

    var failed = 0;
    try {
      // 순회 중인 Set을 직접 지우면 오류가 나므로 복사본을 돌며 성공한 것만 뺍니다.
      for (final ratingId in selectedRatingIds.toList()) {
        try {
          await _service.deleteRating(memberId: memberId, ratingId: ratingId);
          selectedRatingIds.remove(ratingId);
        } catch (error) {
          debugPrint('다중 삭제 실패 ratingId=$ratingId: $error');
          failed++;
        }
      }
    } finally {
      isDeletingSelected = false;
      if (selectedRatingIds.isEmpty) isEditing = false;
      _notify();
    }
    await _refreshAfterWrite();
    return failed;
  }

  Future<void> _handleWriteError(
    Object error, {
    required String fallback,
  }) async {
    final failure = WriteFailure(serverErrorMessage(error, fallback: fallback));
    // 403·404는 화면 목록이 서버와 어긋났다는 뜻이라 다시 조회해서 맞춥니다.
    if (shouldRefreshAfterRatingError(error)) await load();
    throw failure;
  }

  Future<void> _refreshAfterWrite() async {
    await load();
    if (status == MyRatingsLoadStatus.error) {
      refreshWarning = '저장은 완료됐지만 목록을 불러오지 못했습니다.\n조회만 다시 시도해 주세요.';
      _notify();
    }
  }

  // 화면을 벗어났거나 새 요청이 시작됐다면 늦게 도착한 응답은 버립니다.
  bool _isStale(int version) => _disposed || version != _requestVersion;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
