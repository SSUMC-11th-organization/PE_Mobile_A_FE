import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/rating_request.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import 'auth_view_model.dart';
import 'load_error_message.dart';
import 'session_rating_store.dart';
import 'submit_status.dart';

export 'submit_status.dart';

// 영화 상세에서는 평점 등록만 합니다. 수정·삭제는 마이페이지의 '내가 등록한 평점'에서 합니다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(
    this._ratingService,
    this._auth,
    this._store,
    this.movie,
  );

  final RatingApiService _ratingService;
  final AuthViewModel _auth;
  final SessionRatingStore _store;
  final TmdbMovieDto movie;

  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;
  bool _disposed = false;

  // 보호 화면은 Router가 로그인한 경우에만 보여주지만, 만료 처리 중일 수도 있어 한 번 더 확인합니다.
  bool get canRate => _auth.status == AuthStatus.signedIn;

  // 실패하면 WriteFailure를 던져서 Dialog가 입력을 유지한 채 안내 문구를 보여주게 합니다.
  Future<void> createRating({required int score, String? comment}) async {
    if (!canRate) throw const WriteFailure('먼저 로그인해 주세요.');
    if (submitStatus == SubmitStatus.submitting) return;
    final version = _auth.sessionVersion;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    _notify();

    try {
      final created = await _ratingService.createRating(
        CreateRatingRequest(
          // 영화 배열 index가 아니라 TMDB 영화 id를 그대로 보냅니다.
          movieId: movie.id,
          score: score,
          comment: comment,
        ),
      );
      // 등록 result의 Rating 객체를 이번 세션 목록에 넣어 바로 수정·삭제할 수 있게 합니다.
      _store.add(created, version: version);
      submitStatus = SubmitStatus.success;
      _notify();
    } catch (error) {
      submitStatus = SubmitStatus.error;
      if (isSessionExpiredError(error)) {
        submitMessage = '로그인이 만료됐어요. 다시 로그인해 주세요.';
        _notify();
        await _auth.expireSession(version: version);
        throw WriteFailure(submitMessage!);
      }
      submitMessage = ratingWriteErrorMessage(
        error,
        fallback: '평점을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
      _notify();
      throw WriteFailure(submitMessage!);
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
