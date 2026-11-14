import 'dart:async';

import 'package:dio/dio.dart';

import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';

import 'test_helpers.dart';

DioException dioFailure(String path, {int? statusCode, Object? body}) {
  final options = RequestOptions(path: path);
  return DioException(
    requestOptions: options,
    type: statusCode == null
        ? DioExceptionType.connectionError
        : DioExceptionType.badResponse,
    response: statusCode == null
        ? null
        : Response<dynamic>(
            requestOptions: options,
            statusCode: statusCode,
            data: body,
          ),
  );
}

/// v6 공통 오류 응답 { isSuccess: false, code, message } 형태의 실패.
DioException commonError(int statusCode, String code, String message) {
  return dioFailure(
    '/v6/x',
    statusCode: statusCode,
    body: {'isSuccess': false, 'code': code, 'message': message},
  );
}

RatingDto ratingDto(
  int ratingId,
  int movieId, {
  int score = 4,
  String? comment,
}) {
  return RatingDto(
    ratingId: ratingId,
    movieId: movieId,
    score: score,
    comment: comment,
    createdAt: DateTime.utc(2026, 9, 6, 12, 14, 3),
  );
}

/// 회원가입과 닉네임·이메일 중복 확인을 네트워크 없이 흉내 낸다.
class FakeSignUpService extends SignUpService {
  FakeSignUpService() : super(Dio());

  /// 여기에 들어 있는 값은 "이미 사용 중"으로 답한다.
  final Set<String> takenNicknames = {};
  final Set<String> takenEmails = {};

  bool fail = false;

  /// 이 Completer가 완료될 때까지 응답을 붙잡아 "통신 중" 상태를 만든다.
  Completer<void>? gate;

  final List<String> nicknameCalls = [];
  final List<String> emailCalls = [];

  // ───────── 회원가입 POST ─────────

  /// null이 아니면 이 오류로 실패한다.
  DioException? signUpError;
  Completer<void>? signUpGate;

  /// 가입 성공 응답의 memberId. 계약이 깨진 응답(result 없음)을 흉내 내려면 [signUpWithoutResult].
  int signUpMemberId = 101;
  bool signUpWithoutResult = false;
  final List<CreateMemberRequest> signUpCalls = [];

  @override
  Future<bool> checkNickname(String nickname) async {
    nicknameCalls.add(nickname.trim());
    await gate?.future;
    if (fail) throw dioFailure('/v6/members/nickname/$nickname');
    return !takenNicknames.contains(nickname.trim());
  }

  @override
  Future<bool> checkEmail(String email) async {
    emailCalls.add(email.trim());
    await gate?.future;
    if (fail) throw dioFailure('/v6/members/email/$email');
    return !takenEmails.contains(email.trim());
  }

  @override
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    signUpCalls.add(request);
    await signUpGate?.future;
    final error = signUpError;
    if (error != null) throw error;
    return CommonResponse<SignUpResult>(
      isSuccess: true,
      code: 'COMMON201',
      message: '성공입니다.',
      result: signUpWithoutResult
          ? null
          : SignUpResult(
              memberId: signUpMemberId,
              email: request.email.trim(),
              nickname: request.nickname.trim(),
            ),
    );
  }
}

class RecordedCreate {
  const RecordedCreate(this.memberId, this.request);

  final int memberId;
  final CreateRatingRequest request;
}

class RecordedUpdate {
  const RecordedUpdate(this.memberId, this.ratingId, this.score, this.comment);

  final int memberId;
  final int ratingId;
  final int score;
  final String? comment;
}

/// 메모리 안의 평점 목록으로 v6 평점 API(조회·등록·수정·삭제)를 흉내 낸다.
class FakeRatingApiService extends RatingApiService {
  FakeRatingApiService({List<RatingDto> ratings = const []})
    : ratings = [...ratings],
      super(Dio());

  List<RatingDto> ratings;

  // ───────── 조회(GET) ─────────

  /// null이 아니면 이 상태 코드로 조회가 실패한다. 0이면 통신 자체가 실패한다.
  int? failWithStatus;

  /// 앞으로 N번의 조회만 통신 실패로 만든다. (저장은 성공했는데 GET만 실패하는 상황)
  int failFetchTimes = 0;
  Completer<void>? gate;
  int calls = 0;
  final List<int> fetchedMemberIds = [];

  // ───────── 쓰기(POST·PATCH·DELETE) ─────────

  /// null이 아니면 모든 쓰기 요청이 이 오류로 실패한다.
  DioException? writeError;
  Completer<void>? writeGate;

  /// 이 ratingId의 삭제만 실패한다. (다중 삭제의 일부 실패)
  final Set<int> failDeleteIds = {};

  final List<RecordedCreate> createCalls = [];
  final List<RecordedUpdate> updateCalls = [];
  final List<int> deleteCalls = [];
  int _nextRatingId = 1000;

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    calls++;
    fetchedMemberIds.add(memberId);
    await gate?.future;
    if (failFetchTimes > 0) {
      failFetchTimes--;
      throw dioFailure('/v6/members/$memberId/ratings');
    }
    final status = failWithStatus;
    if (status != null) {
      throw dioFailure(
        '/v6/members/$memberId/ratings',
        statusCode: status == 0 ? null : status,
      );
    }
    return [...ratings];
  }

  @override
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    createCalls.add(RecordedCreate(memberId, request));
    await writeGate?.future;
    final error = writeError;
    if (error != null) throw error;
    ratings.insert(
      0,
      RatingDto(
        ratingId: _nextRatingId++,
        movieId: request.movieId,
        score: request.score,
        comment: request.comment?.trim().isEmpty ?? true
            ? null
            : request.comment!.trim(),
        createdAt: DateTime.utc(2026, 11, 8, 3),
      ),
    );
  }

  @override
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    updateCalls.add(RecordedUpdate(memberId, ratingId, score, comment));
    await writeGate?.future;
    final error = writeError;
    if (error != null) throw error;
    final index = ratings.indexWhere((r) => r.ratingId == ratingId);
    if (index < 0) throw commonError(404, 'COMMON404', '존재하지 않는 평점입니다.');
    final old = ratings[index];
    ratings[index] = RatingDto(
      ratingId: old.ratingId,
      movieId: old.movieId,
      score: score,
      comment: comment,
      createdAt: old.createdAt,
    );
  }

  @override
  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    deleteCalls.add(ratingId);
    await writeGate?.future;
    final error = writeError;
    if (error != null) throw error;
    if (failDeleteIds.contains(ratingId)) {
      throw dioFailure('/v6/x', statusCode: 500);
    }
    ratings.removeWhere((r) => r.ratingId == ratingId);
  }
}

/// FakeTmdbMovieService에 영화 상세 조회(findMovieById)를 얹는다.
class FakeDetailTmdbService extends FakeTmdbMovieService {
  FakeDetailTmdbService({
    Map<int, TmdbMovieDto>? known,
    Set<int>? networkFailIds,
  }) : known = known ?? {},
       networkFailIds = networkFailIds ?? {};

  /// id → 영화. 여기에 없는 id는 404(null)로 답한다.
  final Map<int, TmdbMovieDto> known;

  /// 이 id들은 네트워크 오류로 실패한다.
  Set<int> networkFailIds;
  final List<int> detailCalls = [];

  @override
  Future<TmdbMovieDto?> findMovieById(int movieId) async {
    detailCalls.add(movieId);
    if (networkFailIds.contains(movieId)) throw dioFailure('/movie/$movieId');
    return known[movieId];
  }
}
