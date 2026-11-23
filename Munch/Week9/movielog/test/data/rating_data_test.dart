import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

import '../fakes/stub_http_adapter.dart';

void main() {
  group('RatingDto.fromJson', () {
    test('모든 필드를 파싱한다', () {
      final rating = RatingDto.fromJson({
        'ratingId': 12,
        'movieId': 550,
        'score': 5,
        'comment': '최고의 영화!',
        'createdAt': '2026-09-06T12:14:03.000Z',
        'updatedAt': '2026-09-06T12:14:03.000Z',
      });

      expect(rating.ratingId, 12);
      expect(rating.movieId, 550);
      expect(rating.score, 5);
      expect(rating.comment, '최고의 영화!');
      expect(rating.createdAt, DateTime.utc(2026, 9, 6, 12, 14, 3));
    });

    test('comment가 null이어도 파싱된다', () {
      final rating = RatingDto.fromJson({
        'ratingId': 3,
        'movieId': 13,
        'score': 3,
        'comment': null,
        'createdAt': '2026-11-01T19:00:27.956Z',
        'updatedAt': '2026-11-01T19:00:27.956Z',
      });

      expect(rating.comment, isNull);
    });
  });

  group('RatingApiService v7', () {
    Map<String, dynamic> ratingJson(int id) => {
      'ratingId': id,
      'movieId': 550,
      'score': 4,
      'comment': null,
      'createdAt': '2026-11-01T19:00:27.956Z',
      'updatedAt': '2026-11-01T19:00:27.956Z',
    };

    Map<String, dynamic> wrap(Object? result) => {
      'isSuccess': true,
      'code': 'COMMON200',
      'message': 'ok',
      'result': result,
    };

    test('유저별 평점 조회는 공개 Client로 v7 경로를 호출한다', () async {
      late String requestedPath;
      final service = RatingApiService(
        stubDio((options) {
          requestedPath = options.path;
          return (200, [ratingJson(1)]);
        }),
        stubDio((_) => fail('보호 Client를 쓰면 안 됩니다.')),
      );

      final ratings = await service.fetchMemberRatings(1);

      expect(requestedPath, '/v7/members/1/ratings');
      expect(ratings.single.movieId, 550);
    });

    test('등록은 보호 Client로 /v7/ratings에 memberId 없이 보내고 Rating을 반환한다', () async {
      late RequestOptions request;
      final service = RatingApiService(
        stubDio((_) => fail('공개 Client를 쓰면 안 됩니다.')),
        stubDio((options) {
          request = options;
          return (201, wrap(ratingJson(12)));
        }),
      );

      final created = await service.createRating(
        const CreateRatingRequest(movieId: 550, score: 4, comment: '  '),
      );

      expect(request.method, 'POST');
      expect(request.path, '/v7/ratings');
      expect(request.data, {'movieId': 550, 'score': 4});
      expect(created.ratingId, 12);
    });

    test('수정은 comment가 null이어도 body에 명시하고 Rating을 반환한다', () async {
      late RequestOptions request;
      final service = RatingApiService(
        stubDio((_) => fail('공개 Client를 쓰면 안 됩니다.')),
        stubDio((options) {
          request = options;
          return (200, wrap(ratingJson(3)));
        }),
      );

      final updated = await service.updateRating(ratingId: 3, score: 2);

      expect(request.method, 'PATCH');
      expect(request.path, '/v7/ratings/3');
      expect(request.data, {'score': 2, 'comment': null});
      expect(updated.ratingId, 3);
    });

    test('삭제는 result가 null인 200을 성공으로 처리한다', () async {
      late RequestOptions request;
      final service = RatingApiService(
        stubDio((_) => fail('공개 Client를 쓰면 안 됩니다.')),
        stubDio((options) {
          request = options;
          return (200, wrap(null));
        }),
      );

      await service.deleteRating(3);

      expect(request.method, 'DELETE');
      expect(request.path, '/v7/ratings/3');
    });

    test('등록 result가 없으면 StateError', () async {
      final service = RatingApiService(
        stubDio((_) => (200, null)),
        stubDio((_) => (201, wrap(null))),
      );
      expect(
        service.createRating(const CreateRatingRequest(movieId: 1, score: 3)),
        throwsStateError,
      );
    });

    test('도메인 오류 code별로 다른 문구를 만든다', () async {
      Future<String> messageFor(int status, Object? body) async {
        final service = RatingApiService(
          stubDio((_) => (200, null)),
          stubDio((_) => (status, body)),
        );
        try {
          await service.deleteRating(1);
          fail('DioException이 발생해야 합니다.');
        } on DioException catch (error) {
          return ratingErrorMessage(error);
        }
      }

      Map<String, dynamic> errorBody(String code, [String message = 'x']) => {
        'isSuccess': false,
        'code': code,
        'message': message,
        'result': null,
      };

      expect(
        await messageFor(401, errorBody('AUTH401_4')),
        '로그인이 만료됐어요. 다시 로그인해 주세요.',
      );
      expect(
        await messageFor(403, errorBody('RATING403_1')),
        '본인이 작성한 평점만 수정하거나 삭제할 수 있어요.',
      );
      expect(
        await messageFor(409, errorBody('RATING409_1')),
        contains('이미 이 영화에 평점을 남겼어요'),
      );
      expect(
        await messageFor(400, errorBody('COMMON400', '별점은 5점 이하여야 합니다.')),
        '별점은 5점 이하여야 합니다.',
      );
      expect(
        await messageFor(500, 'bad gateway'),
        '요청에 실패했어요. 잠시 후 다시 시도해 주세요.',
      );
    });
  });

  test('validateServerScore는 1~5 정수만 허용한다', () {
    expect(validateServerScore(5), 5);
    expect(() => validateServerScore(0), throwsArgumentError);
    expect(() => validateServerScore(3.5), throwsArgumentError);
  });

  group('TmdbMovieService.findMovieById', () {
    test('영화 상세를 파싱한다', () async {
      final service = TmdbMovieService(
        stubDio(
          (options) => (
            200,
            {
              'id': 550,
              'title': '파이트 클럽',
              'overview': '',
              'poster_path': '/poster.jpg',
              'genres': [
                {'id': 18, 'name': '드라마'},
              ],
            },
          ),
        ),
      );

      final movie = await service.findMovieById(550);

      expect(movie?.title, '파이트 클럽');
      expect(movie?.posterPath, '/poster.jpg');
      expect(movie?.genreIds, [18]);
    });

    test('404면 null을 반환한다', () async {
      final service = TmdbMovieService(
        stubDio((_) => (404, {'status_message': 'not found'})),
      );
      expect(await service.findMovieById(1), isNull);
    });

    test('404가 아닌 오류는 그대로 던진다', () async {
      final service = TmdbMovieService(stubDio((_) => (500, {})));
      expect(service.findMovieById(1), throwsA(isA<DioException>()));
    });
  });
}
