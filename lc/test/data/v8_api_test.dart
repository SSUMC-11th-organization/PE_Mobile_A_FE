import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

import 'tmdb_movie_service_test.dart' show RecordingAdapter;

/// 정해진 상태 코드와 body(없으면 빈 문자열)를 돌려주고, 보낸 요청을 기록한다.
class StubAdapter implements HttpClientAdapter {
  StubAdapter({this.statusCode = 200, this.body});

  final int statusCode;
  final Object? body;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      statusCode,
      headers: {
        if (body != null) Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(HttpClientAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter;
}

DioException _error(int? status, {Object? body}) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  response: status == null
      ? null
      : Response<dynamic>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: status,
          data: body,
        ),
);

Map<String, dynamic> _fail(String code, String message) => {
  'isSuccess': false,
  'code': code,
  'message': message,
  'result': null,
};

Map<String, dynamic> _ok(Object? result, {String code = 'COMMON200'}) => {
  'isSuccess': true,
  'code': code,
  'message': '성공입니다.',
  'result': result,
};

const _ratingJson = {
  'ratingId': 12,
  'movieId': 550,
  'score': 5,
  'comment': '최고!',
  'createdAt': '2026-09-06T12:14:03.000Z',
  'updatedAt': '2026-09-06T12:14:03.000Z',
};

void main() {
  group('오류 code 읽기', () {
    test('공통 오류 응답에서 code와 message를 읽는다', () {
      final error = _error(409, body: _fail('MEMBER409_1', '이미 사용 중인 닉네임입니다.'));

      expect(apiErrorCode(error), 'MEMBER409_1');
      expect(apiErrorMessage(error), '이미 사용 중인 닉네임입니다.');
    });

    test('body가 없거나 JSON이 아니면 null이다', () {
      expect(apiErrorCode(_error(null)), isNull);
      expect(apiErrorCode(_error(500, body: 'oops')), isNull);
      expect(apiErrorMessage(_error(500, body: 'oops')), isNull);
    });

    test('AUTH401_2/3/4만 세션 만료다. 로그인 입력 오류(AUTH401_1)와 403은 아니다', () {
      bool expired(String code, int status) =>
          isSessionExpiredError(_error(status, body: _fail(code, 'm')));

      expect(expired('AUTH401_2', 401), isTrue);
      expect(expired('AUTH401_3', 401), isTrue);
      expect(expired('AUTH401_4', 401), isTrue);
      expect(expired('AUTH401_1', 401), isFalse);
      expect(expired('RATING403_1', 403), isFalse);
      expect(expired('RATING409_1', 409), isFalse);
      expect(isSessionExpiredError(_error(null)), isFalse); // 네트워크 실패는 401이 아니다.
      expect(isSessionExpiredError(_error(401)), isFalse); // code 없는 401은 추정하지 않는다.
    });

    test('writeErrorMessage는 서버 message를 우선하고 없으면 기본 문구를 쓴다', () {
      expect(
        writeErrorMessage(_error(403, body: _fail('RATING403_1', '본인 평점만 가능'))),
        '본인 평점만 가능',
      );
      expect(writeErrorMessage(_error(null)), contains('네트워크'));
    });
  });

  group('로그인', () {
    test('POST /v8/auth/login으로 보내고 result의 accessToken을 읽는다', () async {
      final adapter = StubAdapter(
        body: _ok({'nickname': '영화광', 'accessToken': 'jwt-value'}),
      );

      final result = await AuthApiService(_dioWith(adapter)).login(
        const LoginRequest(email: ' a@b.com ', password: ' Pass1!word '),
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/v8/auth/login');
      // 이메일만 trim하고 비밀번호는 입력 그대로 보낸다.
      expect(request.data, {'email': 'a@b.com', 'password': ' Pass1!word '});
      expect(result.accessToken, 'jwt-value');
      expect(result.nickname, '영화광');
    });

    test('result가 없으면 로그인 성공으로 처리하지 않는다', () async {
      final adapter = StubAdapter(body: _ok(null));

      await expectLater(
        AuthApiService(_dioWith(adapter)).login(
          const LoginRequest(email: 'a@b.com', password: 'x'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('틀린 비밀번호는 AUTH401_1 DioException이다', () async {
      final adapter = StubAdapter(
        statusCode: 401,
        body: _fail('AUTH401_1', '이메일 또는 비밀번호가 올바르지 않습니다.'),
      );

      await expectLater(
        AuthApiService(_dioWith(adapter)).login(
          const LoginRequest(email: 'a@b.com', password: 'x'),
        ),
        throwsA(isA<DioException>().having(apiErrorCode, 'code', 'AUTH401_1')),
      );
    });

    test('toString에는 비밀번호와 토큰 원문이 들어가지 않는다', () {
      expect(
        const LoginRequest(email: 'a@b.com', password: 'Secret1!pw').toString(),
        isNot(contains('Secret1!pw')),
      );
      expect(
        const LoginResult(nickname: 'n', accessToken: 'jwt-secret').toString(),
        isNot(contains('jwt-secret')),
      );
    });
  });

  group('내 정보', () {
    const memberJson = {
      'email': 'a@b.com',
      'nickname': '영화광',
      'createdAt': '2026-10-10T03:00:00.000Z',
    };

    test('GET /v8/members/me의 result를 MemberInfo로 읽는다 (memberId는 없다)', () async {
      final adapter = StubAdapter(body: _ok(memberJson));

      final member = await MemberApiService(_dioWith(adapter)).fetchMe();

      expect(adapter.requests.single.uri.path, '/v8/members/me');
      expect(member.email, 'a@b.com');
      expect(member.nickname, '영화광');
      expect(member.createdAt, DateTime.utc(2026, 10, 10, 3));
    });

    test('닉네임 수정은 PATCH /v8/members/me로 nickname만 보낸다', () async {
      final adapter = StubAdapter(body: _ok({...memberJson, 'nickname': '새이름'}));

      final member = await MemberApiService(
        _dioWith(adapter),
      ).updateNickname('새이름');

      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.uri.path, '/v8/members/me');
      expect(request.data, {'nickname': '새이름'});
      expect(member.nickname, '새이름');
    });

    test('result가 없으면 StateError다', () {
      expect(() => parseMemberInfo(_ok(null)), throwsStateError);
      expect(() => parseMemberInfo('oops'), throwsStateError);
    });
  });

  group('평점 v8', () {
    RatingApiService service(StubAdapter public, StubAdapter auth) =>
        RatingApiService(_dioWith(public), _dioWith(auth));

    test('등록은 /v8/ratings로 보내고 path·body에 memberId가 없다. result는 Rating 객체다', () async {
      final public = StubAdapter();
      final auth = StubAdapter(
        statusCode: 201,
        body: _ok(_ratingJson, code: 'COMMON201'),
      );

      final rating = await service(public, auth).createRating(
        const CreateRatingRequest(movieId: 550, score: 5, comment: '최고!'),
      );

      final request = auth.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/v8/ratings');
      expect(request.uri.path, isNot(contains('members')));
      expect(request.data, {'movieId': 550, 'score': 5, 'comment': '최고!'});
      expect((request.data as Map).containsKey('memberId'), isFalse);
      expect(rating.ratingId, 12);
      expect(rating.movieId, 550);
      expect(public.requests, isEmpty); // 쓰기는 보호 Client로만 간다.
    });

    test('수정은 PATCH /v8/ratings/{id}로 score와 comment를 항상 함께 보낸다', () async {
      final auth = StubAdapter(body: _ok({..._ratingJson, 'score': 2, 'comment': null}));

      final rating = await service(StubAdapter(), auth).updateRating(
        ratingId: 12,
        score: 2,
      );

      final request = auth.requests.single;
      expect(request.method, 'PATCH');
      expect(request.uri.path, '/v8/ratings/12');
      expect(request.data, {'score': 2, 'comment': null});
      expect((request.data as Map).containsKey('comment'), isTrue);
      expect(rating.score, 2);
      expect(rating.comment, isNull);
    });

    test('삭제 성공은 204가 아니라 result가 null인 200이다', () async {
      final auth = StubAdapter(body: _ok(null));

      await service(StubAdapter(), auth).deleteRating(12);

      expect(auth.requests.single.method, 'DELETE');
      expect(auth.requests.single.uri.path, '/v8/ratings/12');
    });

    test('삭제가 200이 아닌 성공 응답이면 StateError다', () async {
      final auth = StubAdapter(statusCode: 204);

      await expectLater(
        service(StubAdapter(), auth).deleteRating(12),
        throwsA(isA<StateError>()),
      );
    });

    test('등록 result가 없으면 성공으로 처리하지 않는다', () {
      expect(() => parseRatingResult(_ok(null)), throwsStateError);
      expect(() => parseRatingResult([1, 2]), throwsStateError);
    });

    test('유저별 평점 조회는 공개 Client로 /v8/members/{id}/ratings의 직접 배열을 읽는다', () async {
      final public = StubAdapter(body: [_ratingJson]);
      final auth = StubAdapter();

      final ratings = await service(public, auth).fetchMyRatings(1);

      expect(public.requests.single.uri.path, '/v8/members/1/ratings');
      expect(auth.requests, isEmpty); // 공개 조회는 보호 Client를 쓰지 않는다.
      expect(ratings.single.ratingId, 12);
      expect(() => parseRatingList({'a': 1}), throwsStateError);
    });

    test('도메인 오류 code(RATING403_1 등)를 읽을 수 있다', () async {
      final auth = StubAdapter(
        statusCode: 403,
        body: _fail('RATING403_1', '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'),
      );

      await expectLater(
        service(StubAdapter(), auth).deleteRating(12),
        throwsA(isA<DioException>().having(apiErrorCode, 'code', 'RATING403_1')),
      );
    });
  });

  group('회원가입·중복 확인 v8', () {
    test('닉네임·이메일 확인과 가입이 /v8 경로를 쓴다', () async {
      final adapter = RecordingAdapter(body: {'available': true});
      final service = SignUpService(_dioWith(adapter));

      await service.checkNickname('영화광');
      await service.checkEmail('a@b.com');

      expect(
        adapter.requests.first.uri.path,
        '/v8/members/nickname/${Uri.encodeComponent('영화광')}',
      );
      expect(adapter.requests.last.uri.path, '/v8/members/email/a%40b.com');

      final signUp = StubAdapter(
        statusCode: 201,
        body: _ok({
          'memberId': 42,
          'email': 'a@b.com',
          'nickname': '영화광',
        }, code: 'COMMON201'),
      );
      final response = await SignUpService(_dioWith(signUp)).signUp(
        const CreateMemberRequest(
          email: 'a@b.com',
          password: 'Pass1!word',
          nickname: '영화광',
        ),
      );
      expect(signUp.requests.single.uri.path, '/v8/members');
      expect(response.result?.memberId, 42);
    });

    test('CommonResponse는 result가 null이면 파싱하지 않는다', () {
      final response = CommonResponse<SignUpResult>.fromJson(
        _ok(null),
        (value) => SignUpResult.fromJson(value as Map<String, dynamic>),
      );
      expect(response.result, isNull);
    });
  });

  group('TmdbMovieService 영화 상세', () {
    test('fetchMovieDetail은 /movie/{id}를 조회하고 genres 배열에서 장르 id를 읽는다', () async {
      final adapter = RecordingAdapter(
        body: {
          'id': 550,
          'title': '파이트 클럽',
          'genres': [
            {'id': 18, 'name': '드라마'},
          ],
        },
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/3'))
        ..httpClientAdapter = adapter;

      final movie = await TmdbMovieService(dio).fetchMovieDetail(550);

      expect(adapter.requests.single.uri.path, '/3/movie/550');
      expect(movie.genreIds, [18]);
    });

    test('findMovieById는 404만 null로 바꾸고 다른 실패는 다시 던진다', () async {
      Dio dio(int status) => Dio(BaseOptions(baseUrl: 'https://example.test/3'))
        ..httpClientAdapter = RecordingAdapter(statusCode: status);

      expect(await TmdbMovieService(dio(404)).findMovieById(1), isNull);
      await expectLater(
        TmdbMovieService(dio(500)).findMovieById(1),
        throwsA(isA<DioException>()),
      );
    });
  });
}
