import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';

// message나 code를 넘기면 공통 오류 형식(CommonResponse) body를 함께 담습니다.
DioException httpError(
  String path,
  int statusCode, {
  String? message,
  String? code,
}) {
  final options = RequestOptions(path: path);
  final hasBody = message != null || code != null;
  return DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: statusCode,
      data: hasBody
          ? {
              'isSuccess': false,
              'code': code ?? 'COMMON$statusCode',
              'message': message ?? '오류',
              'result': null,
            }
          : null,
    ),
    type: DioExceptionType.badResponse,
  );
}

DioException networkError(String path) => DioException(
  requestOptions: RequestOptions(path: path),
  type: DioExceptionType.connectionError,
);

DioException expiredError([String code = 'AUTH401_4']) =>
    httpError('/v7/members/me', 401, code: code, message: '토큰이 만료되었습니다.');

// 테스트용 토큰 값입니다. 실제 JWT가 아닙니다.
const fakeAccessToken = 'test-access-token';

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

// 기기 보안 저장소 대신 메모리에 토큰을 둡니다.
class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage([this.token]);

  String? token;
  Object? readError;
  Object? deleteError;
  int deleteCount = 0;

  @override
  Future<void> saveAccessToken(String token) async => this.token = token;

  @override
  Future<String?> readAccessToken() async {
    final failure = readError;
    if (failure != null) throw failure;
    return token;
  }

  @override
  Future<void> deleteAccessToken() async {
    deleteCount++;
    final failure = deleteError;
    if (failure != null) throw failure;
    token = null;
  }
}

// 정해 둔 이메일·비밀번호만 성공시키고, 나머지는 서버처럼 AUTH401_1을 돌려줍니다.
class FakeAuthApiService implements AuthApiService {
  FakeAuthApiService({
    this.email = 'me@movielog.com',
    this.password = 'Password1!',
  });

  final String email;
  final String password;
  Object? error;
  Completer<void>? gate;
  final requests = <String>[]; // 이메일만 기록합니다. 비밀번호는 남기지 않습니다.

  @override
  Future<LoginResult> login(LoginRequest request) async {
    requests.add(request.email.trim());
    final pending = gate;
    if (pending != null) await pending.future;
    final failure = error;
    if (failure != null) throw failure;
    if (request.email.trim() != email || request.password != password) {
      throw httpError(
        '/v7/auth/login',
        401,
        code: 'AUTH401_1',
        message: '이메일 또는 비밀번호가 올바르지 않습니다.',
      );
    }
    return const LoginResult(nickname: '여비', accessToken: fakeAccessToken);
  }
}

MemberInfo memberFixture({String nickname = '여비'}) => MemberInfo(
  email: 'me@movielog.com',
  nickname: nickname,
  createdAt: DateTime.utc(2026, 10, 10, 3),
);

class FakeMemberApiService implements MemberApiService {
  FakeMemberApiService({MemberInfo? member})
    : member = member ?? memberFixture();

  MemberInfo member;
  Object? fetchError;
  Object? updateError;
  Completer<void>? fetchGate;
  Completer<void>? updateGate;
  int fetchCount = 0;
  final updateRequests = <String>[];

  @override
  Future<MemberInfo> fetchMe() async {
    fetchCount++;
    final pending = fetchGate;
    if (pending != null) await pending.future;
    final failure = fetchError;
    if (failure != null) throw failure;
    return member;
  }

  @override
  Future<MemberInfo> updateNickname(String nickname) async {
    updateRequests.add(nickname);
    final pending = updateGate;
    if (pending != null) await pending.future;
    final failure = updateError;
    if (failure != null) throw failure;
    member = MemberInfo(
      email: member.email,
      nickname: nickname,
      createdAt: member.createdAt,
    );
    return member;
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

// v7 평점 API Fake입니다. 등록하면 새 ratingId를 붙인 Rating 객체를 돌려줍니다.
class FakeRatingApiService implements RatingApiService {
  int _nextId = 100;
  // 수정 응답의 movieId를 맞추기 위해 평점별 영화를 기억합니다.
  final movieIdsByRating = <int, int>{};
  final createRequests = <CreateRatingRequest>[];
  final updateRequests = <(int, int, String?)>[];
  final deleteRequests = <int>[];
  final requestedMemberIds = <int>[];
  Object? writeError;
  // 다중 삭제의 부분 실패를 만들 때 ratingId별로 실패시킵니다.
  final failingDeleteIds = <int>{};
  Completer<void>? writeGate;

  Future<void> _write() async {
    final pending = writeGate;
    if (pending != null) await pending.future;
    final failure = writeError;
    if (failure != null) throw failure;
  }

  @override
  Future<List<RatingDto>> fetchMemberRatings(int memberId) async {
    requestedMemberIds.add(memberId);
    return const [];
  }

  @override
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    createRequests.add(request);
    await _write();
    final id = _nextId++;
    movieIdsByRating[id] = request.movieId;
    return ratingFixture(
      id,
      movieId: request.movieId,
      score: request.score,
      comment: request.comment,
    );
  }

  @override
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    required String? comment,
  }) async {
    updateRequests.add((ratingId, score, comment));
    await _write();
    return ratingFixture(
      ratingId,
      movieId: movieIdsByRating[ratingId] ?? 1,
      score: score,
      comment: comment,
    );
  }

  @override
  Future<void> deleteRating(int ratingId) async {
    deleteRequests.add(ratingId);
    await _write();
    if (failingDeleteIds.contains(ratingId)) {
      throw httpError('/v7/ratings/$ratingId', 500);
    }
  }
}
