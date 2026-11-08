import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/check_result.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/services/member_check_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

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
  group('v5 응답 모델', () {
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

  group('MemberCheckService', () {
    test('닉네임과 이메일을 인코딩해서 path에 넣는다', () async {
      final adapter = _StubAdapter((_) => (200, {'available': true}));
      final service = MemberCheckService(_dio(adapter));

      expect(await service.checkNickname(' 무비러버 '), isTrue);
      await service.checkEmail('movie@log.com');

      expect(
        adapter.requests[0].path,
        '/v5/members/nickname/${Uri.encodeComponent('무비러버')}',
      );
      expect(adapter.requests[1].path, '/v5/members/email/movie%40log.com');
    });
  });

  group('RatingApiService', () {
    test('memberId 경로로 조회하고 배열을 RatingDto 목록으로 바꾼다', () async {
      final adapter = _StubAdapter(
        (_) => (
          200,
          [
            {
              'ratingId': 1,
              'movieId': 550,
              'score': 5,
              'comment': '최고의 영화!',
              'createdAt': '2026-09-06T12:14:03.000Z',
            },
          ],
        ),
      );

      final ratings = await RatingApiService(_dio(adapter)).fetchMyRatings(1);

      expect(adapter.requests.single.path, '/v5/members/1/ratings');
      expect(ratings.single.movieId, 550);
    });

    test('빈 배열은 실패가 아니라 빈 목록이다', () async {
      final adapter = _StubAdapter((_) => (200, <Object>[]));

      expect(await RatingApiService(_dio(adapter)).fetchMyRatings(1), isEmpty);
    });

    test('404는 statusCode를 가진 DioException으로 전달된다', () async {
      final adapter = _StubAdapter(
        (_) => (
          404,
          {
            'message': '존재하지 않는 유저입니다.',
            'error': 'Not Found',
            'statusCode': 404,
          },
        ),
      );

      expect(
        RatingApiService(_dio(adapter)).fetchMyRatings(999),
        throwsA(
          isA<DioException>().having(
            (error) => error.response?.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
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
