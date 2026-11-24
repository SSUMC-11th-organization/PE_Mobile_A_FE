import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/rating_request.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/models/movie_record_models.dart';
import '../data/services/movie_record_api_service.dart';
import '../data/services/rating_api_service.dart';
import 'auth_view_model.dart';
import 'session_rating_store.dart';
import 'submit_status.dart';

export 'submit_status.dart' show SubmitStatus;

/// 영화 상세 화면의 상태. 이 화면은 평점 "등록"만 맡고, 수정·삭제는 마이페이지 화면이 맡는다.
/// 누가 등록하는지는 요청에 넣지 않는다. 서버가 Authorization 토큰으로 식별한다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(
    this._ratingService,
    this._store,
    this._auth,
    this.movie, {
    this.recordService,
  });

  final RatingApiService _ratingService;
  final SessionRatingStore _store;
  final AuthViewModel _auth;
  final MovieRecordApiService? recordService;

  /// 평점을 남길 영화. 서버 movieId는 이 DTO의 TMDB id를 그대로 쓴다.
  final TmdbMovieDto movie;

  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;
  bool _disposed = false;

  Future<void> createRating({required int score, String? comment}) async {
    if (submitStatus == SubmitStatus.submitting) return;
    final version = _auth.sessionVersion;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    dismissOnError = false;
    notifyListeners();

    try {
      final created = await _ratingService.createRating(
        CreateRatingRequest(movieId: movie.id, score: score, comment: comment),
      );
      // 로그아웃·회원 전환 뒤 늦게 도착한 응답은 새 세션에 반영하지 않는다.
      if (_isStale(version)) return;
      _store.add(created); // 등록 응답의 Rating으로 이번 세션의 목록을 갱신한다.
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      if (_isStale(version)) return;
      submitStatus = SubmitStatus.error;
      if (isSessionExpiredError(error)) {
        // 안내와 화면 이동은 로그인 화면과 Router가 맡는다.
        submitMessage = '로그인이 만료됐어요. 다시 로그인해 주세요.';
        await _auth.expireSession();
      } else {
        // RATING409_1(이미 평점을 남긴 영화), COMMON400 등: 안내만 하고 로그인 상태는 유지한다.
        submitMessage = writeErrorMessage(error);
      }
    } catch (_) {
      if (_isStale(version)) return;
      submitStatus = SubmitStatus.error;
      submitMessage = '저장 결과를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
    if (!_disposed) notifyListeners();
  }

  /// 마지막 저장 실패가 "Dialog를 닫고 Snackbar로 안내"해야 하는 종류인지.
  bool dismissOnError = false;

  /// 평점과 즐겨찾기를 `POST /v8/movie-records`로 한 번에 저장한다. (Challenge C)
  /// 오류 코드별로 Dialog를 유지할지([RatingWriteException.dismissDialog])를 나눈다.
  Future<void> saveRecord({
    required int score,
    String? comment,
    required bool addToFavorites,
  }) async {
    final service = recordService;
    if (service == null) throw StateError('movie-records Service가 없습니다.');
    if (submitStatus == SubmitStatus.submitting) return;
    final version = _auth.sessionVersion;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    dismissOnError = false;
    notifyListeners();

    try {
      final result = await service.createRecord(
        MovieRecordRequest(
          movieId: movie.id,
          score: score,
          comment: comment,
          addToFavorites: addToFavorites,
        ),
      );
      if (_isStale(version)) return;
      _store.add(result.rating);
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      if (_isStale(version)) return;
      submitStatus = SubmitStatus.error;
      final code = apiErrorCode(error);
      if (isSessionExpiredError(error)) {
        submitMessage = '로그인이 만료됐어요. 다시 로그인해 주세요.';
        await _auth.expireSession();
      } else if (code == 'RATING409_1') {
        submitMessage = apiErrorMessage(error) ?? '이미 평점을 남긴 영화예요.';
        dismissOnError = true;
      } else if (code == 'FAVORITE409_1') {
        submitMessage =
            apiErrorMessage(error) ?? '이미 즐겨찾기한 영화예요. 평점은 저장되지 않았어요.';
        dismissOnError = true;
      } else if (code == 'MEMBER404_1') {
        submitMessage = apiErrorMessage(error) ?? '회원 정보를 찾을 수 없어요.';
        dismissOnError = true;
      } else {
        // COMMON400과 네트워크 실패: Dialog를 유지하고 입력을 보존한다.
        submitMessage = writeErrorMessage(error);
      }
    } catch (_) {
      if (_isStale(version)) return;
      submitStatus = SubmitStatus.error;
      submitMessage = '저장 결과를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
    if (!_disposed) notifyListeners();
  }

  bool _isStale(int version) => _disposed || version != _auth.sessionVersion;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
