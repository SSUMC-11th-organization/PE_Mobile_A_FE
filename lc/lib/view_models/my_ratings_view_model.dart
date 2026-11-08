import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'submit_status.dart';

export 'submit_status.dart' show RatingWriteException;

/// 6주차의 학습용 고정 회원. 7주차부터는 회원가입으로 얻은 memberId(LearningMemberSession)를 쓴다.
const int sampleMemberId = 1;

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._movieService, this.memberId);

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final int memberId;

  /// 같은 movieId는 한 번만 조회한다. 404(null)도 캐시하지만 네트워크 실패는 캐시하지 않는다.
  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _requestVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;

  /// 저장(수정·삭제)은 성공했는데 그 뒤 목록 GET만 실패했을 때의 안내. 저장 실패와 구분한다.
  String? refreshWarning;

  // ───────── 다중 선택(편집) 모드 ─────────

  bool isEditMode = false;
  final Set<int> selectedRatingIds = {};
  bool isDeletingSelected = false;

  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    notifyListeners();
    try {
      final rawRatings = await _service.fetchMyRatings(memberId);
      if (_isStale(version)) return;

      final entries = <RatingWithMovie>[];
      var missingMovies = 0;
      for (final rating in rawRatings) {
        if (_isStale(version)) return;
        if (!_movieCache.containsKey(rating.movieId)) {
          try {
            _movieCache[rating.movieId] = await _movieService.findMovieById(
              rating.movieId,
            );
          } on DioException {
            // 영화 정보 조회 실패가 평점 목록 전체를 지우지 않는다. 다음 로딩에서 다시 시도한다.
          }
        }
        final movie = _movieCache[rating.movieId];
        if (movie == null) missingMovies++;
        entries.add(RatingWithMovie(rating: rating, movie: movie));
      }
      if (_isStale(version)) return;

      ratings = entries;
      // 서버에서 사라진 평점은 선택 상태에서도 뺀다.
      final liveIds = {for (final entry in entries) entry.rating.ratingId};
      selectedRatingIds.removeWhere((id) => !liveIds.contains(id));
      status = entries.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
      if (entries.isEmpty) isEditMode = false;
      refreshWarning = null;
      if (missingMovies > 0) {
        message = '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.';
      }
    } catch (error) {
      if (_isStale(version)) return;
      status = MyRatingsLoadStatus.error;
      // 응답 파싱 오류도 Error 상태로 보이게 하되, 상태 코드는 DioException일 때만 구분한다.
      message = error is DioException
          ? writeErrorMessage(error)
          : '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
    if (!_isStale(version)) notifyListeners();
  }

  /// 저장이 끝난 뒤 목록을 서버 상태와 맞춘다. GET 실패는 저장 실패가 아니므로
  /// 예외로 다시 던지지 않고 refreshWarning으로만 알린다.
  Future<void> _refreshAfterWrite() async {
    await load();
    if (_disposed) return;
    if (status == MyRatingsLoadStatus.error) {
      refreshWarning = '저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해 주세요.';
      notifyListeners();
    } else {
      refreshWarning = null;
    }
  }

  /// 쓰기 실패를 Dialog가 그대로 보여줄 수 있는 RatingWriteException으로 바꿔 던진다.
  Future<void> _runWrite(Future<void> Function() write) async {
    try {
      await write();
    } on DioException catch (error) {
      final writeMessage = writeErrorMessage(error);
      // 화면의 목록이 서버와 어긋났을 수 있는 오류(403·404)는 다시 조회해 맞춘다.
      if (shouldRefreshAfterRatingError(error) && !_disposed) await load();
      throw RatingWriteException(writeMessage);
    } on StateError {
      throw const RatingWriteException(
        '저장 결과를 확인하지 못했습니다. 목록을 다시 확인해 주세요.',
      );
    }
    await _refreshAfterWrite();
  }

  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) {
    return _runWrite(
      () => _service.updateRating(
        memberId: memberId,
        ratingId: ratingId,
        score: score,
        comment: comment,
      ),
    );
  }

  Future<void> deleteRating(int ratingId) {
    return _runWrite(
      () => _service.deleteRating(memberId: memberId, ratingId: ratingId),
    );
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
  /// 성공한 항목만 목록에서 사라지게 한 뒤, 실패 개수를 message로 알린다.
  /// 실패한 개수를 돌려준다.
  Future<int> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) return 0;
    isDeletingSelected = true;
    notifyListeners();
    var failed = 0;
    try {
      // 원본 Set을 순회하면서 지우면 ConcurrentModificationError가 나므로 복사본을 순회한다.
      for (final ratingId in selectedRatingIds.toList()) {
        try {
          await _service.deleteRating(memberId: memberId, ratingId: ratingId);
          selectedRatingIds.remove(ratingId);
        } on DioException {
          failed++;
        } on StateError {
          failed++;
        }
      }
    } finally {
      isDeletingSelected = false;
      if (!_disposed) notifyListeners(); // 예상하지 못한 오류에도 로딩을 해제한다.
    }
    if (_disposed) return failed;
    await _refreshAfterWrite(); // GET 실패는 삭제 성공 여부와 분리한다.
    if (failed == 0 && status != MyRatingsLoadStatus.error) {
      isEditMode = false;
      selectedRatingIds.clear();
    }
    if (failed > 0) {
      message = '$failed개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.';
    }
    if (!_disposed) notifyListeners();
    return failed;
  }

  bool _isStale(int version) => _disposed || version != _requestVersion;

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
