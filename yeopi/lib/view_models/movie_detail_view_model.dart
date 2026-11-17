import 'package:flutter/foundation.dart';

import '../data/models/rating_request.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import 'load_error_message.dart';
import 'submit_status.dart';

export 'submit_status.dart';

// 영화 상세에서는 평점 등록만 합니다. 조회·수정·삭제는 마이페이지의 '내가 등록한 평점'에서 합니다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(this._ratingService, this.memberId, this.movie);

  final RatingApiService _ratingService;
  // 학습용 현재 회원입니다. 로그인 인증이 아닙니다.
  final int? memberId;
  final TmdbMovieDto movie;

  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;
  bool _disposed = false;

  bool get canRate => memberId != null;

  // 실패하면 WriteFailure를 던져서 Dialog가 입력을 유지한 채 안내 문구를 보여주게 합니다.
  Future<void> createRating({required int score, String? comment}) async {
    final id = memberId;
    if (id == null) {
      throw const WriteFailure('먼저 학습용 회원가입을 완료해 주세요.');
    }
    if (submitStatus == SubmitStatus.submitting) return;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    _notify();

    try {
      await _ratingService.createRating(
        memberId: id,
        request: CreateRatingRequest(
          // 영화 배열 index가 아니라 TMDB 영화 id를 그대로 보냅니다.
          movieId: movie.id,
          score: score,
          comment: comment,
        ),
      );
      submitStatus = SubmitStatus.success;
      _notify();
    } catch (error) {
      submitStatus = SubmitStatus.error;
      submitMessage = serverErrorMessage(
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
