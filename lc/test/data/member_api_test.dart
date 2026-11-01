import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/core/network/movie_log_client.dart';
import 'package:movielog/data/models/check_result.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/services/member_check_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

import 'tmdb_movie_service_test.dart' show RecordingAdapter;

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
  });

  group('MemberCheckService', () {
    MemberCheckService serviceWith(RecordingAdapter adapter) {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;
      return MemberCheckService(dio);
    }

    test('닉네임은 /v5/members/nickname/{값}으로 묻고 한글·공백을 인코딩한다', () async {
      final adapter = RecordingAdapter(body: {'available': true});

      final available = await serviceWith(adapter).checkNickname(' 영화 팬 ');

      expect(available, isTrue);
      expect(
        adapter.requests.single.uri.toString(),
        'https://example.test/v5/members/nickname/'
        '${Uri.encodeComponent('영화 팬')}',
      );
    });

    test('이메일은 /v5/members/email/{값}으로 묻고 available: false를 그대로 돌려준다', () async {
      final adapter = RecordingAdapter(body: {'available': false});

      final available = await serviceWith(adapter).checkEmail('a@b.com');

      expect(available, isFalse);
      expect(adapter.requests.single.uri.path, '/v5/members/email/a%40b.com');
    });
  });

  group('RatingApiService', () {
    test('평점 배열 응답을 RatingDto 목록으로 바꾼다', () async {
      final adapter = _ListAdapter([
        {
          'ratingId': 1,
          'movieId': 550,
          'score': 5,
          'comment': '최고!',
          'createdAt': '2026-09-06T12:14:03.000Z',
        },
        {
          'ratingId': 2,
          'movieId': 27205,
          'score': 3,
          'comment': null,
          'createdAt': '2026-09-07T01:00:00.000Z',
        },
      ]);
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;

      final ratings = await RatingApiService(dio).fetchMyRatings(1);

      expect(adapter.lastPath, '/v5/members/1/ratings');
      expect(ratings.map((r) => r.movieId), [550, 27205]);
      expect(ratings.last.comment, isNull);
    });

    test('빈 배열은 실패가 아니라 빈 목록이다', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _ListAdapter(const []);

      expect(await RatingApiService(dio).fetchMyRatings(1), isEmpty);
    });

    test('400 · 404 · 그 외 실패는 서로 다른 문구가 된다', () {
      DioException error(int? status) => DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: status == null
            ? null
            : Response<dynamic>(
                requestOptions: RequestOptions(path: '/x'),
                statusCode: status,
              ),
      );

      final messages = {
        writeMyRatingsErrorMessage(error(400)),
        writeMyRatingsErrorMessage(error(404)),
        writeMyRatingsErrorMessage(error(500)),
      };
      expect(messages, hasLength(3));
      expect(
        writeMyRatingsErrorMessage(error(null)),
        writeMyRatingsErrorMessage(error(500)),
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

/// 최상위가 배열인 JSON을 돌려주는 어댑터.
class _ListAdapter extends RecordingAdapter {
  _ListAdapter(this.list);

  final List<dynamic> list;
  String? lastPath;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.uri.path;
    return ResponseBody.fromString(
      jsonEncode(list),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
