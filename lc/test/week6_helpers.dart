import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/core/storage/saved_email_storage.dart';
import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
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

/// 공통 오류 응답 { isSuccess: false, code, message } 형태의 실패.
DioException commonError(int statusCode, String code, String message) {
  return dioFailure(
    '/v7/x',
    statusCode: statusCode,
    body: {'isSuccess': false, 'code': code, 'message': message},
  );
}

/// 보호 요청에서 토큰이 무효일 때의 401.
DioException expiredError([String code = 'AUTH401_3']) =>
    commonError(401, code, '유효하지 않은 토큰입니다.');

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

MemberInfo memberInfo({String nickname = '영화광', String email = 'lc@example.com'}) {
  return MemberInfo(
    email: email,
    nickname: nickname,
    createdAt: DateTime.utc(2026, 10, 10, 3),
  );
}

/// 메모리에만 두는 토큰 저장소. 실패 상황과 호출 횟수를 흉내 낸다.
class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage([this.token]);

  String? token;
  bool failRead = false;
  bool failSave = false;
  bool failDelete = false;
  int deleteCalls = 0;
  int saveCalls = 0;

  @override
  Future<void> saveAccessToken(String value) async {
    saveCalls++;
    if (failSave) throw StateError('save failed');
    token = value;
  }

  @override
  Future<String?> readAccessToken() async {
    if (failRead) throw StateError('read failed');
    return token;
  }

  @override
  Future<void> deleteAccessToken() async {
    deleteCalls++;
    if (failDelete) throw StateError('delete failed');
    token = null;
  }
}

class FakeSavedEmailStorage implements SavedEmailStorage {
  FakeSavedEmailStorage([this.email]);

  String? email;

  @override
  Future<String?> read() async => email;

  @override
  Future<void> save(String value) async => email = value;

  @override
  Future<void> clear() async => email = null;
}

class FakeAuthApiService extends AuthApiService {
  FakeAuthApiService() : super(Dio());

  DioException? loginError;
  Completer<void>? gate;
  String accessToken = 'fake-access-token';
  final List<LoginRequest> calls = [];

  @override
  Future<LoginResult> login(LoginRequest request) async {
    calls.add(request);
    await gate?.future;
    final error = loginError;
    if (error != null) throw error;
    return LoginResult(nickname: '영화광', accessToken: accessToken);
  }
}

class FakeMemberApiService extends MemberApiService {
  FakeMemberApiService({MemberInfo? member})
    : member = member ?? memberInfo(),
      super(Dio());

  MemberInfo member;

  /// null이 아니면 fetchMe가 이 오류로 실패한다. [fetchFailTimes]가 0보다 크면 그 횟수만 실패한다.
  DioException? fetchError;
  int fetchFailTimes = -1;
  Completer<void>? fetchGate;
  int fetchCalls = 0;

  DioException? updateError;
  Completer<void>? updateGate;
  final List<String> updateCalls = [];

  @override
  Future<MemberInfo> fetchMe() async {
    fetchCalls++;
    await fetchGate?.future;
    final error = fetchError;
    if (error != null && fetchFailTimes != 0) {
      if (fetchFailTimes > 0) fetchFailTimes--;
      throw error;
    }
    return member;
  }

  @override
  Future<MemberInfo> updateNickname(String nickname) async {
    updateCalls.add(nickname);
    await updateGate?.future;
    final error = updateError;
    if (error != null) throw error;
    member = MemberInfo(
      email: member.email,
      nickname: nickname,
      createdAt: member.createdAt,
    );
    return member;
  }
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

  DioException? signUpError;
  Completer<void>? signUpGate;
  int signUpMemberId = 101;
  bool signUpWithoutResult = false;
  final List<CreateMemberRequest> signUpCalls = [];

  @override
  Future<bool> checkNickname(String nickname) async {
    nicknameCalls.add(nickname.trim());
    await gate?.future;
    if (fail) throw dioFailure('/v7/members/nickname/$nickname');
    return !takenNicknames.contains(nickname.trim());
  }

  @override
  Future<bool> checkEmail(String email) async {
    emailCalls.add(email.trim());
    await gate?.future;
    if (fail) throw dioFailure('/v7/members/email/$email');
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

class RecordedUpdate {
  const RecordedUpdate(this.ratingId, this.score, this.comment);

  final int ratingId;
  final int score;
  final String? comment;
}

/// v7 토큰 기반 평점 API(등록·수정·삭제)를 흉내 낸다. 어떤 메서드에도 memberId 인자가 없다.
class FakeRatingApiService extends RatingApiService {
  FakeRatingApiService() : super(Dio(), Dio());

  /// null이 아니면 모든 쓰기 요청이 이 오류로 실패한다.
  DioException? writeError;
  Completer<void>? writeGate;

  /// 이 ratingId의 삭제만 서버 오류로 실패한다. (다중 삭제의 일부 실패)
  final Set<int> failDeleteIds = {};

  final List<CreateRatingRequest> createCalls = [];
  final List<RecordedUpdate> updateCalls = [];
  final List<int> deleteCalls = [];
  int _nextRatingId = 1000;

  @override
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    createCalls.add(request);
    await writeGate?.future;
    final error = writeError;
    if (error != null) throw error;
    final comment = request.comment?.trim();
    return RatingDto(
      ratingId: _nextRatingId++,
      movieId: request.movieId,
      score: request.score,
      comment: comment == null || comment.isEmpty ? null : comment,
      createdAt: DateTime.utc(2026, 11, 15, 3),
    );
  }

  @override
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    updateCalls.add(RecordedUpdate(ratingId, score, comment));
    await writeGate?.future;
    final error = writeError;
    if (error != null) throw error;
    return RatingDto(
      ratingId: ratingId,
      movieId: 550,
      score: score,
      comment: comment,
      createdAt: DateTime.utc(2026, 9, 6, 12, 14, 3),
    );
  }

  @override
  Future<void> deleteRating(int ratingId) async {
    deleteCalls.add(ratingId);
    await writeGate?.future;
    final error = writeError;
    if (error != null) throw error;
    if (failDeleteIds.contains(ratingId)) {
      throw dioFailure('/v7/ratings/$ratingId', statusCode: 500);
    }
  }
}

/// FakeTmdbMovieService에 영화 상세 조회(findMovieById)를 얹는다.
class FakeDetailTmdbService extends FakeTmdbMovieService {
  FakeDetailTmdbService({
    Map<int, TmdbMovieDto>? known,
    Set<int>? networkFailIds,
    super.popular,
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

/// 가짜 Service·저장소로 앱 전체를 띄우는 테스트용 묶음.
class AppHarness {
  AppHarness({FakeDetailTmdbService? movies})
    : movies =
          movies ??
          FakeDetailTmdbService(
            popular: [movieDto(550, title: '파이트 클럽'), ...movieDtos(5)],
            known: {550: movieDto(550, title: '파이트 클럽')},
          );

  final FakeDetailTmdbService movies;
  final tokens = FakeTokenStorage();
  final savedEmail = FakeSavedEmailStorage();
  final auth = FakeAuthApiService();
  final members = FakeMemberApiService();
  final ratings = FakeRatingApiService();
  final signUp = FakeSignUpService();

  /// [signedIn]이면 저장된 토큰이 있는 상태로 시작해 세션 복원을 거쳐 홈으로 들어간다.
  /// [settle]이 false면 한 프레임만 그린다. (인디케이터가 도는 화면은 settle되지 않는다.)
  Future<void> pump(
    WidgetTester tester, {
    bool signedIn = true,
    bool settle = true,
    Size size = const Size(800, 2600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    if (signedIn) tokens.token ??= 'stored-token';
    await tester.pumpWidget(
      MovieLogApp(
        key: UniqueKey(),
        movieService: movies,
        signUpService: signUp,
        ratingApiService: ratings,
        authApiService: auth,
        memberApiService: members,
        tokenStorage: tokens,
        savedEmailStorage: savedEmail,
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  GoRouter router(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Navigator).first));

  String location(WidgetTester tester) =>
      router(tester).routerDelegate.currentConfiguration.uri.path;

  Future<void> go(WidgetTester tester, String path) async {
    router(tester).go(path);
    await tester.pumpAndSettle();
  }

  /// 로그인 화면에서 이메일·비밀번호를 넣고 로그인 버튼을 누른다.
  Future<void> login(WidgetTester tester, {bool settle = true}) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'lc@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'Password1!');
    await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }
}
