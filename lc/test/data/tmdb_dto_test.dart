import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/utils/tmdb_movie_format.dart';

void main() {
  group('TmdbMovieDto.fromJson', () {
    test('snake_case 키를 lowerCamelCase 필드로 연결한다', () {
      final dto = TmdbMovieDto.fromJson({
        'id': 550,
        'title': '파이트 클럽',
        'overview': '줄거리',
        'poster_path': '/poster.jpg',
        'backdrop_path': '/backdrop.jpg',
        'release_date': '1999-10-15',
        'genre_ids': [18, 53],
        'vote_average': 8.4,
        'popularity': 120.5,
      });

      expect(dto.id, 550);
      expect(dto.title, '파이트 클럽');
      expect(dto.posterPath, '/poster.jpg');
      expect(dto.backdropPath, '/backdrop.jpg');
      expect(dto.releaseDate, '1999-10-15');
      expect(dto.genreIds, [18, 53]);
      expect(dto.voteAverage, 8.4);
      expect(dto.popularity, 120.5);
    });

    test('정수로 내려온 숫자도 num에서 double·int로 변환한다', () {
      final dto = TmdbMovieDto.fromJson({
        'id': 1,
        'vote_average': 8,
        'popularity': 100,
        'genre_ids': [28],
      });

      expect(dto.voteAverage, 8.0);
      expect(dto.popularity, 100.0);
      expect(dto.genreIds, [28]);
    });

    test('값이 없거나 null이어도 오류 없이 기본값을 쓴다', () {
      final dto = TmdbMovieDto.fromJson({
        'id': 1,
        'title': null,
        'overview': null,
        'poster_path': null,
        'release_date': null,
      });

      expect(dto.title, '제목 없음');
      expect(dto.overview, '');
      expect(dto.posterPath, isNull);
      expect(dto.releaseDate, isNull);
      expect(dto.genreIds, isEmpty);
      expect(dto.voteAverage, 0);
    });
  });

  group('TmdbMoviePageDto.fromJson', () {
    test('영화 배열과 page 정보를 함께 변환한다', () {
      final page = TmdbMoviePageDto.fromJson({
        'page': 2,
        'results': [
          {'id': 1, 'title': 'A'},
          {'id': 2, 'title': 'B'},
        ],
        'total_pages': 10,
        'total_results': 200,
      });

      expect(page.page, 2);
      expect(page.results.map((movie) => movie.id), [1, 2]);
      expect(page.totalPages, 10);
      expect(page.totalResults, 200);
    });

    test('results가 없으면 빈 목록이다', () {
      final page = TmdbMoviePageDto.fromJson({
        'page': 1,
        'total_pages': 0,
        'total_results': 0,
      });

      expect(page.results, isEmpty);
    });
  });

  test('TmdbGenreDto.fromJson은 id와 name을 그대로 쓴다', () {
    final genre = TmdbGenreDto.fromJson({'id': 28, 'name': '액션'});

    expect(genre.id, 28);
    expect(genre.name, '액션');
  });

  group('TmdbMovieFormat', () {
    TmdbMovieDto withDate(String? date) =>
        TmdbMovieDto.fromJson({'id': 1, 'release_date': date});

    test('releaseYear는 날짜에서 연도만 꺼낸다', () {
      expect(withDate('2024-05-01').releaseYear, 2024);
    });

    test('날짜가 없거나 형식이 달라도 null이다', () {
      expect(withDate(null).releaseYear, isNull);
      expect(withDate('').releaseYear, isNull);
      expect(withDate('20').releaseYear, isNull);
      expect(withDate('abcd-01-01').releaseYear, isNull);
    });

    test('평점은 10점 만점을 별 5개 기준으로 바꾼다', () {
      final dto = TmdbMovieDto.fromJson({'id': 1, 'vote_average': 8.4});

      expect(dto.ratingOutOfFive, closeTo(4.2, 0.0001));
      expect(dto.ratingLabel, '4.2');
    });

    test('장르 id를 이름으로 바꾸고 모르는 id는 건너뛴다', () {
      final dto = TmdbMovieDto.fromJson({
        'id': 1,
        'genre_ids': [28, 999, 12],
      });

      expect(dto.genreNamesIn({28: '액션', 12: '모험'}), ['액션', '모험']);
    });
  });
}
