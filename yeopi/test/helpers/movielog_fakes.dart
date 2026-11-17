import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';

// message를 넘기면 v6 공통 오류 형식(CommonResponse) body를 함께 담습니다.
DioException httpError(
  String path,
  int statusCode, {
  String? message,
  String? code,
}) {
  final options = RequestOptions(path: path);
  return DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: statusCode,
      data: message == null
          ? null
          : {
              'isSuccess': false,
              'code': code ?? 'COMMON$statusCode',
              'message': message,
              'result': null,
            },
    ),
    type: DioExceptionType.badResponse,
  );
}

DioException networkError(String path) => DioException(
  requestOptions: RequestOptions(path: path),
  type: DioExceptionType.connectionError,
);

// takenNicknames·takenEmails에 있는 값만 '중복'으로 응답하는 테스트용 Service입니다.
class FakeSignUpService implements SignUpService {
  FakeSignUpService({
    this.takenNicknames = const {'무비러버'},
    this.takenEmails = const {'taken@movielog.com'},
  });

  final Set<String> takenNicknames;
  final Set<String> takenEmails;

  Object? error;
  Completer<void>? gate;
  final nicknameRequests = <String>[];
  final emailRequests = <String>[];

  Future<void> _respond() async {
    final pending = gate;
    if (pending != null) await pending.future;
    final failure = error;
    if (failure != null) throw failure;
  }

  @override
  Future<bool> checkNickname(String nickname) async {
    nicknameRequests.add(nickname);
    await _respond();
    return !takenNicknames.contains(nickname.trim());
  }

  @override
  Future<bool> checkEmail(String email) async {
    emailRequests.add(email);
    await _respond();
    return !takenEmails.contains(email.trim());
  }

  // 회원가입 POST 결과입니다. signUpError가 있으면 그 오류를 던집니다.
  int signUpMemberId = 42;
  Object? signUpError;
  Completer<void>? signUpGate;
  final signUpRequests = <CreateMemberRequest>[];

  @override
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    signUpRequests.add(request);
    final pending = signUpGate;
    if (pending != null) await pending.future;
    final failure = signUpError;
    if (failure != null) throw failure;
    return CommonResponse(
      isSuccess: true,
      code: 'COMMON201',
      message: '회원가입 성공',
      result: SignUpResult(
        memberId: signUpMemberId,
        email: request.email.trim(),
        nickname: request.nickname.trim(),
      ),
    );
  }
}

RatingDto ratingFixture(
  int ratingId, {
  required int movieId,
  int score = 4,
  String? comment = '좋았어요',
}) {
  return RatingDto(
    ratingId: ratingId,
    movieId: movieId,
    score: score,
    comment: comment,
    createdAt: DateTime.utc(2026, 9, 6, 12),
  );
}

// 두 번째 평점은 후기(comment)가 없습니다.
List<RatingDto> defaultRatingFixtures() => [
  ratingFixture(1, movieId: 1, score: 5, comment: '최고의 영화!'),
  ratingFixture(2, movieId: 2, score: 3, comment: null),
];

class FakeRatingApiService implements RatingApiService {
  FakeRatingApiService({List<RatingDto>? ratings})
    : ratings = ratings ?? defaultRatingFixtures();

  List<RatingDto> ratings;
  Object? error;
  Completer<void>? gate;
  final requestedMemberIds = <int>[];

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    requestedMemberIds.add(memberId);
    final pending = gate;
    if (pending != null) await pending.future;
    final failure = error;
    if (failure != null) throw failure;
    return ratings;
  }

  // 쓰기 요청 기록과 실패 주입입니다. 성공하면 메모리 목록도 함께 바꿉니다.
  final createRequests = <CreateRatingRequest>[];
  final updateRequests = <(int, int, String?)>[];
  final deleteRequests = <int>[];
  Object? writeError;
  // 다중 삭제의 부분 실패를 만들 때 ratingId별로 실패시킵니다.
  final failingDeleteIds = <int>{};
  Completer<void>? writeGate;
  // 쓰기 성공 뒤 재조회(GET)만 실패시키고 싶을 때 씁니다.
  Object? errorAfterWrite;

  Future<void> _write() async {
    final pending = writeGate;
    if (pending != null) await pending.future;
    final failure = writeError;
    if (failure != null) throw failure;
  }

  void _afterWrite() {
    if (errorAfterWrite != null) error = errorAfterWrite;
  }

  @override
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    requestedMemberIds.add(memberId);
    createRequests.add(request);
    await _write();
  }

  @override
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required int score,
    required String? comment,
  }) async {
    updateRequests.add((ratingId, score, comment));
    await _write();
    ratings = [
      for (final rating in ratings)
        rating.ratingId == ratingId
            ? ratingFixture(
                ratingId,
                movieId: rating.movieId,
                score: score,
                comment: comment,
              )
            : rating,
    ];
    _afterWrite();
  }

  @override
  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    deleteRequests.add(ratingId);
    await _write();
    if (failingDeleteIds.contains(ratingId)) {
      throw httpError('/v6/members/$memberId/ratings/$ratingId', 500);
    }
    ratings = ratings.where((rating) => rating.ratingId != ratingId).toList();
    _afterWrite();
  }
}
