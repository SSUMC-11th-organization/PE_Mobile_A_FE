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

  group('RatingApiService', () {
    test('memberId로 평점 배열을 조회한다', () async {
      late String requestedPath;
      final service = RatingApiService(
        stubDio((options) {
          requestedPath = options.path;
          return (
            200,
            [
              {
                'ratingId': 1,
                'movieId': 550,
                'score': 5,
                'comment': null,
                'createdAt': '2026-11-01T19:00:27.956Z',
                'updatedAt': '2026-11-01T19:00:27.956Z',
              },
            ],
          );
        }),
      );

      final ratings = await service.fetchMyRatings(1);

      expect(requestedPath, '/v6/members/1/ratings');
      expect(ratings.single.movieId, 550);
    });

    test('빈 배열은 실패가 아니라 빈 목록이다', () async {
      final service = RatingApiService(stubDio((_) => (200, [])));
      expect(await service.fetchMyRatings(1), isEmpty);
    });

    test('400·404·기타 오류는 서로 다른 문구로 바뀐다', () async {
      Future<String> messageFor(int status) async {
        final service = RatingApiService(
          stubDio((_) => (status, {'message': 'x', 'statusCode': status})),
        );
        try {
          await service.fetchMyRatings(1);
          fail('DioException이 발생해야 합니다.');
        } on DioException catch (error) {
          return writeMyRatingsErrorMessage(error);
        }
      }

      expect(await messageFor(400), 'memberId 형식을 다시 확인해 주세요.');
      expect(await messageFor(404), '존재하지 않는 회원입니다.');
      expect(await messageFor(500), '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.');
    });
  });

  group('RatingApiService 쓰기', () {
    test('등록은 201을 성공으로 보고 빈 코멘트는 생략한다', () async {
      late RequestOptions request;
      final service = RatingApiService(
        stubDio((options) {
          request = options;
          return (
            201,
            {
              'isSuccess': true,
              'code': 'COMMON201',
              'message': 'ok',
              'result': null,
            },
          );
        }),
      );

      await service.createRating(
        memberId: 7,
        request: const CreateRatingRequest(
          movieId: 550,
          score: 4,
          comment: '  ',
        ),
      );

      expect(request.method, 'POST');
      expect(request.path, '/v6/members/7/ratings');
      expect(request.data, {'movieId': 550, 'score': 4});
    });

    test('수정은 comment가 null이어도 body에 명시한다', () async {
      late RequestOptions request;
      final service = RatingApiService(
        stubDio((options) {
          request = options;
          return (200, {'isSuccess': true, 'code': 'C', 'message': 'ok'});
        }),
      );

      await service.updateRating(memberId: 7, ratingId: 3, score: 2);

      expect(request.method, 'PATCH');
      expect(request.path, '/v6/members/7/ratings/3');
      expect(request.data, {'score': 2, 'comment': null});
    });

    test('삭제는 204를 성공으로 처리한다', () async {
      final service = RatingApiService(stubDio((_) => (204, null)));
      await service.deleteRating(memberId: 7, ratingId: 3);
    });

    test('공통 응답이 아닌 오류 body에도 기본 문구로 처리한다', () async {
      final service = RatingApiService(stubDio((_) => (500, 'bad gateway')));
      try {
        await service.deleteRating(memberId: 7, ratingId: 3);
        fail('DioException이 발생해야 합니다.');
      } on DioException catch (error) {
        expect(writeErrorMessage(error), '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.');
        expect(shouldRefreshAfterRatingError(error), isFalse);
      }
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
