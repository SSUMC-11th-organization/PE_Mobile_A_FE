import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/core/network/movie_log_client.dart';
import 'package:movielog/data/models/check_result.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
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
        if (body != null)
          Headers.contentTypeHeader: [Headers.jsonContentType],
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

Map<String, dynamic> _commonError(String code, String message) => {
  'isSuccess': false,
  'code': code,
  'message': message,
};

void main() {
  group('모델', () {
    test('CheckResult는 Wrapper 없이 available만 읽는다', () {
      expect(CheckResult.fromJson({'available': true}).available, isTrue);
      expect(CheckResult.fromJson({'available': false}).available, isFalse);
    });

    test('RatingDto는 comment가 null이어도 읽는다', () {
      final dto = RatingDto.fromJson({
        'ratingId': 12,
        'movieId': 550,
        'score': 5,
        'comment': null,
        'createdAt': '2026-09-06T12:14:03.000Z',
        'updatedAt': '2026-09-06T12:14:03.000Z',
      });

      expect(dto.ratingId, 12);
      expect(dto.movieId, 550);
      expect(dto.score, 5);
      expect(dto.comment, isNull);
      expect(dto.createdAt, DateTime.utc(2026, 9, 6, 12, 14, 3));
    });

    test('CommonResponse는 result를 제네릭 타입으로 파싱한다', () {
      final response = CommonResponse<SignUpResult>.fromJson({
        'isSuccess': true,
        'code': 'COMMON201',
        'message': '성공입니다.',
        'result': {'memberId': 7, 'email': 'a@b.com', 'nickname': '영화광'},
      }, (value) => SignUpResult.fromJson(value as Map<String, dynamic>));

      expect(response.isSuccess, isTrue);
      expect(response.code, 'COMMON201');
      expect(response.result?.memberId, 7);
      expect(response.result?.nickname, '영화광');
    });

    test('CommonResponse는 result가 null이면 파싱하지 않고 null로 둔다', () {
      var parsed = false;
      final response = CommonResponse<int>.fromJson({
        'isSuccess': true,
        'code': 'COMMON200',
        'message': '성공입니다.',
        'result': null,
      }, (value) {
        parsed = true;
        return 0;
      });

      expect(response.result, isNull);
      expect(parsed, isFalse);
    });

    test('CreateMemberRequest는 이메일·닉네임만 trim하고 비밀번호는 그대로 보낸다', () {
      const request = CreateMemberRequest(
        email: ' a@b.com ',
        password: ' Pass1!word ',
        nickname: ' 영화광 ',
      );

      expect(request.toJson(), {
        'email': 'a@b.com',
        'password': ' Pass1!word ',
        'nickname': '영화광',
      });
    });

    test('CreateMemberRequest.toString에는 비밀번호가 들어가지 않는다', () {
      const request = CreateMemberRequest(
        email: 'a@b.com',
        password: 'Secret1!pw',
        nickname: '영화광',
      );

      expect(request.toString(), isNot(contains('Secret1!pw')));
    });

    test('CreateRatingRequest는 comment가 비어 있으면 키를 생략한다', () {
      expect(
        const CreateRatingRequest(movieId: 550, score: 5).toJson(),
        {'movieId': 550, 'score': 5},
      );
      expect(
        const CreateRatingRequest(movieId: 550, score: 5, comment: '  ')
            .toJson(),
        {'movieId': 550, 'score': 5},
      );
      expect(
        const CreateRatingRequest(movieId: 550, score: 4, comment: ' 좋다 ')
            .toJson(),
        {'movieId': 550, 'score': 4, 'comment': '좋다'},
      );
    });

    test('validateServerScore는 1~5 정수만 통과시킨다', () {
      expect(validateServerScore(1), 1);
      expect(validateServerScore(5.0), 5);
      expect(() => validateServerScore(0), throwsArgumentError);
      expect(() => validateServerScore(6), throwsArgumentError);
      expect(() => validateServerScore(3.5), throwsArgumentError);
    });
  });

  group('서버 오류 읽기', () {
    test('공통 오류 응답에서 message와 code를 읽는다', () {
      final error = _error(
        409,
        body: _commonError('COMMON409', '이미 사용 중인 이메일입니다.'),
      );

      expect(readServerMessage(error), '이미 사용 중인 이메일입니다.');
      expect(readServerCode(error), 'COMMON409');
    });

    test('프레임워크 기본 오류({message, error, statusCode})도 message를 읽는다', () {
      final error = _error(
        404,
        body: {'message': '존재하지 않는 유저입니다.', 'error': 'Not Found', 'statusCode': 404},
      );

      expect(readServerMessage(error), '존재하지 않는 유저입니다.');
      expect(readServerCode(error), isNull);
    });

    test('body가 없거나 JSON이 아니면 null이다', () {
      expect(readServerMessage(_error(500)), isNull);
      expect(readServerMessage(_error(500, body: 'oops')), isNull);
      expect(readServerCode(_error(500, body: 'oops')), isNull);
    });

    test('writeErrorMessage는 서버 message를 우선하고 없으면 상태 코드별 기본 문구를 쓴다', () {
      expect(
        writeErrorMessage(
          _error(403, body: _commonError('COMMON403', '서버가 준 문구')),
        ),
        '서버가 준 문구',
      );

      final fallbacks = {
        writeErrorMessage(_error(400)),
        writeErrorMessage(_error(403)),
        writeErrorMessage(_error(404)),
        writeErrorMessage(_error(409)),
        writeErrorMessage(_error(500)),
      };
      expect(fallbacks, hasLength(5)); // 400/403/404/409/그 외가 모두 다른 문구
    });

    test('403·404만 목록을 다시 조회해 맞추고, 400·409는 다시 조회하지 않는다', () {
      bool refresh(String code, int status) => shouldRefreshAfterRatingError(
        _error(status, body: _commonError(code, 'm')),
      );

      expect(refresh('COMMON403', 403), isTrue);
      expect(refresh('COMMON404', 404), isTrue);
      expect(refresh('COMMON400', 400), isFalse);
      expect(refresh('COMMON409', 409), isFalse);
      expect(shouldRefreshAfterRatingError(_error(500)), isFalse);
    });

    test('writeSignUpErrorMessage는 서버 message를 그대로 쓴다', () {
      expect(
        writeSignUpErrorMessage(
          _error(409, body: _commonError('COMMON409', '이미 사용 중인 닉네임입니다.')),
        ),
        '이미 사용 중인 닉네임입니다.',
      );
      expect(writeSignUpErrorMessage(_error(null)), contains('회원가입에 실패'));
    });
  });

  group('SignUpService', () {
    test('닉네임 확인은 /v6/members/nickname/{값}으로 묻고 한글·공백을 인코딩한다', () async {
      final adapter = RecordingAdapter(body: {'available': true});

      final available = await SignUpService(
        _dioWith(adapter),
      ).checkNickname(' 영화 팬 ');

      expect(available, isTrue);
      expect(
        adapter.requests.single.uri.toString(),
        'https://example.test/v6/members/nickname/'
        '${Uri.encodeComponent('영화 팬')}',
      );
    });

    test('이메일 확인은 /v6/members/email/{값}으로 묻고 available: false를 돌려준다', () async {
      final adapter = RecordingAdapter(body: {'available': false});

      final available = await SignUpService(
        _dioWith(adapter),
      ).checkEmail('a@b.com');

      expect(available, isFalse);
      expect(adapter.requests.single.uri.path, '/v6/members/email/a%40b.com');
    });

    test('signUp은 POST /v6/members로 body를 보내고 공통 응답의 result를 읽는다', () async {
      final adapter = StubAdapter(
        statusCode: 201,
        body: {
          'isSuccess': true,
          'code': 'COMMON201',
          'message': '성공입니다.',
          'result': {'memberId': 42, 'email': 'a@b.com', 'nickname': '영화광'},
        },
      );

      final response = await SignUpService(_dioWith(adapter)).signUp(
        const CreateMemberRequest(
          email: 'a@b.com',
          password: 'Pass1!word',
          nickname: '영화광',
        ),
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/v6/members');
      expect(request.data, {
        'email': 'a@b.com',
        'password': 'Pass1!word',
        'nickname': '영화광',
      });
      expect(response.result?.memberId, 42);
    });

    test('가입 409는 DioException으로 전달되고 body에서 공통 오류를 읽을 수 있다', () async {
      final adapter = StubAdapter(
        statusCode: 409,
        body: _commonError('COMMON409', '이미 사용 중인 이메일입니다.'),
      );

      await expectLater(
        SignUpService(_dioWith(adapter)).signUp(
          const CreateMemberRequest(
            email: 'a@b.com',
            password: 'Pass1!word',
            nickname: '영화광',
          ),
        ),
        throwsA(
          isA<DioException>().having(
            readServerCode,
            'code',
            'COMMON409',
          ),
        ),
      );
    });
  });

  group('RatingApiService', () {
    final ratingJson = {
      'ratingId': 1,
      'movieId': 550,
      'score': 5,
      'comment': '최고!',
      'createdAt': '2026-09-06T12:14:03.000Z',
    };

    test('조회는 /v6/members/{id}/ratings의 직접 배열을 RatingDto 목록으로 바꾼다', () async {
      final adapter = StubAdapter(
        body: [
          ratingJson,
          {...ratingJson, 'ratingId': 2, 'movieId': 27205, 'comment': null},
        ],
      );

      final ratings = await RatingApiService(_dioWith(adapter)).fetchMyRatings(9);

      expect(adapter.requests.single.uri.path, '/v6/members/9/ratings');
      expect(ratings.map((r) => r.movieId), [550, 27205]);
      expect(ratings.last.comment, isNull);
    });

    test('빈 배열은 실패가 아니라 빈 목록이다', () async {
      final adapter = StubAdapter(body: const []);

      expect(await RatingApiService(_dioWith(adapter)).fetchMyRatings(1), isEmpty);
    });

    test('등록은 POST로 movieId·score·comment를 보내고 201을 성공으로 본다', () async {
      final adapter = StubAdapter(
        statusCode: 201,
        body: {'isSuccess': true, 'code': 'COMMON201', 'message': 'ok', 'result': null},
      );

      await RatingApiService(_dioWith(adapter)).createRating(
        memberId: 9,
        request: const CreateRatingRequest(
          movieId: 550,
          score: 5,
          comment: '최고!',
        ),
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/v6/members/9/ratings');
      expect(request.data, {'movieId': 550, 'score': 5, 'comment': '최고!'});
    });

    test('등록 성공 result가 숫자여도 null이어도 파싱하지 않고 성공으로 본다', () async {
      for (final result in [123, null]) {
        final adapter = StubAdapter(
          statusCode: 201,
          body: {'isSuccess': true, 'code': 'COMMON201', 'message': 'ok', 'result': result},
        );

        await RatingApiService(_dioWith(adapter)).createRating(
          memberId: 9,
          request: const CreateRatingRequest(movieId: 550, score: 5),
        );
      }
    });

    test('등록이 201이 아닌 성공 응답이면 StateError다', () async {
      final adapter = StubAdapter(statusCode: 200, body: {'ok': true});

      await expectLater(
        RatingApiService(_dioWith(adapter)).createRating(
          memberId: 9,
          request: const CreateRatingRequest(movieId: 550, score: 5),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('수정은 PATCH로 score와 comment 키를 항상 보낸다 (comment가 null이어도 생략하지 않는다)', () async {
      final adapter = StubAdapter(
        body: {'isSuccess': true, 'code': 'COMMON200', 'message': 'ok', 'result': null},
      );
      final service = RatingApiService(_dioWith(adapter));

      await service.updateRating(memberId: 9, ratingId: 3, score: 4, comment: '수정');
      await service.updateRating(memberId: 9, ratingId: 3, score: 2);

      expect(adapter.requests.first.method, 'PATCH');
      expect(adapter.requests.first.uri.path, '/v6/members/9/ratings/3');
      expect(adapter.requests.first.data, {'score': 4, 'comment': '수정'});
      // 생략하면 기존 후기가 null로 덮이므로, 지우는 의도도 키를 명시해서 보낸다.
      expect(adapter.requests.last.data, {'score': 2, 'comment': null});
      expect((adapter.requests.last.data as Map).containsKey('comment'), isTrue);
    });

    test('삭제는 204 body 없음을 파싱하지 않고 성공으로 본다', () async {
      final adapter = StubAdapter(statusCode: 204);

      await RatingApiService(_dioWith(adapter)).deleteRating(memberId: 9, ratingId: 3);

      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.uri.path, '/v6/members/9/ratings/3');
    });

    test('삭제가 204가 아닌 성공 응답이면 StateError다', () async {
      final adapter = StubAdapter(statusCode: 200, body: {'ok': true});

      await expectLater(
        RatingApiService(_dioWith(adapter)).deleteRating(memberId: 9, ratingId: 3),
        throwsA(isA<StateError>()),
      );
    });

    test('쓰기 403은 DioException이고 공통 오류 code를 읽을 수 있다', () async {
      final adapter = StubAdapter(
        statusCode: 403,
        body: _commonError('COMMON403', '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'),
      );

      await expectLater(
        RatingApiService(_dioWith(adapter)).deleteRating(memberId: 9, ratingId: 3),
        throwsA(
          isA<DioException>().having(readServerCode, 'code', 'COMMON403'),
        ),
      );
    });
  });

  group('MovieLog Client', () {
    test('TMDB와 다른 baseUrl을 쓰고 TMDB Token 헤더를 붙이지 않는다', () {
      final dio = createMovieLogClient();

      expect(dio.options.baseUrl, 'https://workbook.devnoco.com');
      expect(dio.options.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('TmdbMovieService 영화 상세', () {
    TmdbMovieService serviceFor(Dio dio) => TmdbMovieService(dio);

    test('fetchMovieDetail은 /movie/{id}를 한국어로 조회한다', () async {
      final adapter = RecordingAdapter(
        body: {'id': 550, 'title': '파이트 클럽', 'poster_path': '/a.jpg'},
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/3'))
        ..httpClientAdapter = adapter;

      final movie = await serviceFor(dio).fetchMovieDetail(550);

      expect(movie.id, 550);
      expect(movie.title, '파이트 클럽');
      expect(adapter.requests.single.uri.path, '/3/movie/550');
      expect(adapter.requests.single.queryParameters['language'], 'ko-KR');
    });

    test('상세 응답의 genres 배열에서 장르 id를 읽는다', () async {
      final adapter = RecordingAdapter(
        body: {
          'id': 550,
          'title': '파이트 클럽',
          'genres': [
            {'id': 18, 'name': '드라마'},
            {'id': 53, 'name': '스릴러'},
          ],
        },
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/3'))
        ..httpClientAdapter = adapter;

      final movie = await serviceFor(dio).fetchMovieDetail(550);

      expect(movie.genreIds, [18, 53]);
    });

    test('findMovieById는 404만 null로 바꾼다', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/3'))
        ..httpClientAdapter = RecordingAdapter(statusCode: 404);

      expect(await serviceFor(dio).findMovieById(1), isNull);
    });

    test('findMovieById는 404가 아닌 실패는 다시 던진다', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/3'))
        ..httpClientAdapter = RecordingAdapter(statusCode: 500);

      await expectLater(
        serviceFor(dio).findMovieById(1),
        throwsA(isA<DioException>()),
      );
    });
  });
}
