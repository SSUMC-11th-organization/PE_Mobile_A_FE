import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/core/network/auth_interceptor.dart';
import 'package:movielog/data/models/check_result.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

import 'helpers/movielog_fakes.dart';

// 요청을 기록하고, 테스트가 정한 status·body로 응답하는 Adapter입니다.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.respond);

  final (int, Object) Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = respond(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_StubAdapter adapter) => Dio()..httpClientAdapter = adapter;

void main() {
  group('응답 모델', () {
    test('Wrapper 없는 중복 확인 body를 그대로 파싱한다', () {
      expect(CheckResult.fromJson({'available': false}).available, isFalse);
    });

    test('평점의 comment가 null이어도 파싱한다', () {
      final rating = RatingDto.fromJson({
        'ratingId': 3,
        'movieId': 13,
        'score': 3,
        'comment': null,
        'createdAt': '2026-11-02T19:00:19.459Z',
        'updatedAt': '2026-11-02T19:00:19.459Z',
      });

      expect(rating.movieId, 13);
      expect(rating.comment, isNull);
      expect(rating.createdAt.isUtc, isTrue);
    });
  });

  group('공통 응답', () {
    test('CommonResponse가 result를 원하는 타입으로 파싱한다', () {
      final response = CommonResponse<int>.fromJson({
        'isSuccess': true,
        'code': 'COMMON201',
        'message': '성공',
        'result': 7,
      }, (value) => value as int);

      expect(response.isSuccess, isTrue);
      expect(response.result, 7);
    });

    test('공통 형식이 아닌 오류 body는 null로 구분한다', () {
      expect(CommonResponse.tryParseError({'statusCode': 404}), isNull);
      expect(
        CommonResponse.tryParseError({
          'isSuccess': false,
          'code': 'MEMBER409',
          'message': '이미 사용 중인 이메일입니다.',
          'result': null,
        })?.message,
        '이미 사용 중인 이메일입니다.',
      );
    });

    test('score는 1~5 정수만 허용하고 빈 comment는 보내지 않는다', () {
      expect(validateServerScore(4), 4);
      expect(() => validateServerScore(3.5), throwsArgumentError);
      expect(() => validateServerScore(0), throwsArgumentError);
      expect(
        const CreateRatingRequest(movieId: 550, score: 5, comment: '').toJson(),
        {'movieId': 550, 'score': 5},
      );
    });

    test('회원가입 요청은 이메일·닉네임만 trim한다', () {
      final json = const CreateMemberRequest(
        email: ' me@log.com ',
        password: ' Pass1234! ',
        nickname: ' 여비 ',
      ).toJson();

      expect(json, {
        'email': 'me@log.com',
        'password': ' Pass1234! ',
        'nickname': '여비',
      });
    });
  });

  group('SignUpService', () {
    test('닉네임과 이메일을 인코딩해서 path에 넣는다', () async {
      final adapter = _StubAdapter((_) => (200, {'available': true}));
      final service = SignUpService(_dio(adapter));

      expect(await service.checkNickname(' 무비러버 '), isTrue);
      await service.checkEmail('movie@log.com');

      expect(
        adapter.requests[0].path,
        '/v7/members/nickname/${Uri.encodeComponent('무비러버')}',
      );
      expect(adapter.requests[1].path, '/v7/members/email/movie%40log.com');
    });

    test('회원가입은 POST /v7/members이고 result에서 memberId를 읽는다', () async {
      final adapter = _StubAdapter(
        (_) => (
          201,
          {
            'isSuccess': true,
            'code': 'COMMON201',
            'message': '성공',
            'result': {'memberId': 12, 'email': 'me@log.com', 'nickname': '여비'},
          },
        ),
      );

      final response = await SignUpService(_dio(adapter)).signUp(
        const CreateMemberRequest(
          email: 'me@log.com',
          password: 'Pass1234!',
          nickname: '여비',
        ),
      );

      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/v7/members');
      expect(response.result?.memberId, 12);
    });
  });

  group('RatingApiService v7', () {
    Map<String, Object?> ratingJson({int id = 12, int score = 5}) => {
      'ratingId': id,
      'movieId': 550,
      'score': score,
      'comment': '최고의 영화!',
      'createdAt': '2026-09-06T12:14:03.000Z',
      'updatedAt': '2026-09-06T12:14:03.000Z',
    };

    test('공개 유저별 평점 조회는 공개 Client로 memberId 경로를 부른다', () async {
      final public = _StubAdapter((_) => (200, [ratingJson()]));
      final auth = _StubAdapter((_) => (500, {}));

      final ratings = await RatingApiService(
        _dio(public),
        _dio(auth),
      ).fetchMemberRatings(1);

      expect(public.requests.single.path, '/v7/members/1/ratings');
      expect(auth.requests, isEmpty);
      expect(ratings.single.movieId, 550);
    });

    test(
      '등록은 보호 Client로 POST /v7/ratings, body에 memberId가 없고 Rating을 돌려준다',
      () async {
        final public = _StubAdapter((_) => (500, {}));
        final auth = _StubAdapter(
          (_) => (
            201,
            {
              'isSuccess': true,
              'code': 'COMMON201',
              'message': '평점을 등록했습니다.',
              'result': ratingJson(score: 4),
            },
          ),
        );

        final created = await RatingApiService(_dio(public), _dio(auth))
            .createRating(
              const CreateRatingRequest(movieId: 550, score: 4, comment: '굿'),
            );

        final request = auth.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '/v7/ratings');
        expect(request.data, {'movieId': 550, 'score': 4, 'comment': '굿'});
        expect(public.requests, isEmpty);
        expect(created.ratingId, 12);
        expect(created.score, 4);
      },
    );

    test('수정은 PATCH /v7/ratings/{id}로 score와 comment를 함께 보낸다', () async {
      final auth = _StubAdapter(
        (_) => (
          200,
          {
            'isSuccess': true,
            'code': 'COMMON200',
            'message': '수정',
            'result': ratingJson(id: 9, score: 2),
          },
        ),
      );

      final updated = await RatingApiService(
        _dio(_StubAdapter((_) => (500, {}))),
        _dio(auth),
      ).updateRating(ratingId: 9, score: 2, comment: null);

      final request = auth.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/v7/ratings/9');
      expect(request.data, {'score': 2, 'comment': null});
      expect(updated.score, 2);
    });

    test('삭제는 DELETE /v7/ratings/{id}이고 200(result null)을 성공으로 본다', () async {
      final auth = _StubAdapter(
        (_) => (
          200,
          {
            'isSuccess': true,
            'code': 'COMMON200',
            'message': '삭제',
            'result': null,
          },
        ),
      );

      await RatingApiService(
        _dio(_StubAdapter((_) => (500, {}))),
        _dio(auth),
      ).deleteRating(9);

      expect(auth.requests.single.method, 'DELETE');
      expect(auth.requests.single.path, '/v7/ratings/9');
    });

    test('v6처럼 204가 오면 예상하지 못한 응답으로 본다', () async {
      final auth = _StubAdapter((_) => (204, ''));

      expect(
        RatingApiService(
          _dio(_StubAdapter((_) => (500, {}))),
          _dio(auth),
        ).deleteRating(9),
        throwsStateError,
      );
    });
  });

  group('로그인·내 정보', () {
    test('로그인은 POST /v7/auth/login이고 result에서 accessToken을 읽는다', () async {
      final adapter = _StubAdapter(
        (_) => (
          200,
          {
            'isSuccess': true,
            'code': 'COMMON200',
            'message': '로그인에 성공했습니다.',
            'result': {'nickname': '여비', 'accessToken': 'test-token'},
          },
        ),
      );

      final result = await AuthApiService(
        _dio(adapter),
      ).login(const LoginRequest(email: ' me@log.com ', password: 'Pass1234!'));

      expect(adapter.requests.single.path, '/v7/auth/login');
      expect(adapter.requests.single.data, {
        'email': 'me@log.com',
        'password': 'Pass1234!',
      });
      expect(result.accessToken, 'test-token');
      expect(result.nickname, '여비');
    });

    test('로그인 실패 AUTH401_1은 code를 가진 DioException으로 전달된다', () async {
      final adapter = _StubAdapter(
        (_) => (
          401,
          {
            'isSuccess': false,
            'code': 'AUTH401_1',
            'message': '이메일 또는 비밀번호가 올바르지 않습니다.',
            'result': null,
          },
        ),
      );

      await expectLater(
        AuthApiService(_dio(adapter))
            .login(const LoginRequest(email: 'me@log.com', password: 'x')),
        throwsA(isA<DioException>().having(apiErrorCode, 'code', 'AUTH401_1')),
      );
    });

    test('내 정보 조회·수정은 /v7/members/me를 부르고 MemberInfo로 바꾼다', () async {
      final adapter = _StubAdapter(
        (options) => (
          200,
          {
            'isSuccess': true,
            'code': 'COMMON200',
            'message': '성공',
            'result': {
              'email': 'me@log.com',
              'nickname': options.method == 'PATCH' ? '새닉네임' : '여비',
              'createdAt': '2026-10-10T03:00:00.000Z',
            },
          },
        ),
      );
      final service = MemberApiService(_dio(adapter));

      final me = await service.fetchMe();
      final updated = await service.updateNickname('새닉네임');

      expect(adapter.requests[0].method, 'GET');
      expect(adapter.requests[0].path, '/v7/members/me');
      expect(adapter.requests[1].method, 'PATCH');
      expect(adapter.requests[1].data, {'nickname': '새닉네임'});
      expect(me.nickname, '여비');
      expect(updated.nickname, '새닉네임');
      expect(me.createdAt, DateTime.utc(2026, 10, 10, 3));
    });
  });

  group('AuthInterceptor', () {
    Dio authDio(_StubAdapter adapter, FakeTokenStorage storage) =>
        Dio(BaseOptions(baseUrl: 'https://workbook.devnoco.com'))
          ..httpClientAdapter = adapter
          ..interceptors.add(AuthInterceptor(storage));

    _StubAdapter okAdapter() => _StubAdapter((_) => (200, <String, Object?>{}));

    test('보호 경로(/v7/members/me, /v7/ratings)에만 Bearer를 붙인다', () async {
      final adapter = okAdapter();
      final dio = authDio(adapter, FakeTokenStorage('test-token'));

      await dio.get('/v7/members/me');
      await dio.post('/v7/ratings');
      await dio.delete('/v7/ratings/3');
      await dio.get('/v7/members/1/ratings');
      await dio.post('/v7/auth/login');

      final headers = adapter.requests
          .map((r) => r.headers['Authorization'])
          .toList();
      expect(headers, [
        'Bearer test-token',
        'Bearer test-token',
        'Bearer test-token',
        null,
        null,
      ]);
    });

    test('다른 host로 가는 요청에는 경로가 같아도 토큰을 붙이지 않는다', () async {
      final adapter = okAdapter();
      final dio = authDio(adapter, FakeTokenStorage('test-token'));

      await dio.get('https://api.themoviedb.org/v7/ratings');

      expect(adapter.requests.single.headers['Authorization'], isNull);
    });

    test('토큰이 없으면 헤더 없이 보내고, 이전에 남은 Authorization은 지운다', () async {
      final adapter = okAdapter();
      final dio = authDio(adapter, FakeTokenStorage());

      await dio.get(
        '/v7/members/me',
        options: Options(headers: {'Authorization': 'Bearer old'}),
      );

      expect(adapter.requests.single.headers['Authorization'], isNull);
    });

    test('저장소를 읽지 못하면 서버 401과 다른 오류로 요청을 막는다', () async {
      final adapter = okAdapter();
      final storage = FakeTokenStorage()..readError = Exception('keystore');
      final dio = authDio(adapter, storage);

      await expectLater(
        dio.get('/v7/members/me'),
        throwsA(
          isA<DioException>()
              .having((e) => e.type, 'type', DioExceptionType.unknown)
              .having((e) => e.response, 'response', isNull),
        ),
      );
      expect(adapter.requests, isEmpty);
    });
  });

  group('TmdbMovieService.findMovieById', () {
    test('영화 상세를 DTO로 바꾼다', () async {
      final adapter = _StubAdapter(
        (_) => (200, {'id': 550, 'title': '파이트 클럽', 'poster_path': '/f.jpg'}),
      );

      final movie = await TmdbMovieService(_dio(adapter)).findMovieById(550);

      expect(adapter.requests.single.path, '/movie/550');
      expect(movie?.title, '파이트 클럽');
    });

    test('TMDB에 없는 영화(404)는 null을 돌려준다', () async {
      final adapter = _StubAdapter((_) => (404, {'status_code': 34}));

      expect(await TmdbMovieService(_dio(adapter)).findMovieById(1), isNull);
    });

    test('404가 아닌 오류는 호출한 쪽으로 다시 던진다', () async {
      final adapter = _StubAdapter((_) => (500, {'status_code': 11}));

      expect(
        TmdbMovieService(_dio(adapter)).findMovieById(1),
        throwsA(isA<DioException>()),
      );
    });
  });
}
