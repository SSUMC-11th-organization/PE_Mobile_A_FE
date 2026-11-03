import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page_dto.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

// 네트워크 없이 Dio 요청을 기록하고, 경로에 맞는 JSON을 돌려주는 Adapter입니다.
class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = switch (options.path) {
      '/genre/movie/list' => {
        'genres': [
          {'id': 28, 'name': '액션'},
          {'id': 16, 'name': '애니메이션'},
        ],
      },
      _ => {
        'page': options.queryParameters['page'],
        'results': [
          {
            'id': 550,
            'title': '파이트 클럽',
            'poster_path': '/fight.jpg',
            'genre_ids': [18],
            'vote_average': 8.4,
          },
        ],
        'total_pages': 3,
        'total_results': 41,
      },
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('DTO 변환', () {
    test('snake_case key를 연결하고 null·누락 값을 기본값으로 바꾼다', () {
      final movie = TmdbMovieDto.fromJson({
        'id': 550,
        'title': '파이트 클럽',
        'overview': null,
        'poster_path': null,
        'genre_ids': [18, 53],
        'vote_average': 8,
      });

      expect(movie.id, 550);
      expect(movie.overview, '');
      expect(movie.posterPath, isNull);
      expect(movie.releaseDate, isNull);
      expect(movie.genreIds, [18, 53]);
      expect(movie.voteAverage, 8.0);
      expect(movie.popularity, 0.0);
    });

    test('페이지 응답은 영화 목록과 페이지 정보를 함께 담는다', () {
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
    });
  });

  group('TmdbMovieService', () {
    late _RecordingAdapter adapter;
    late TmdbMovieService service;

    setUp(() {
      adapter = _RecordingAdapter();
      service = TmdbMovieService(Dio()..httpClientAdapter = adapter);
    });

    test('전체 장르로 Discover를 요청하면 with_genres를 보내지 않는다', () async {
      final page = await service.discoverMovies(page: 1);

      final query = adapter.requests.single.queryParameters;
      expect(adapter.requests.single.path, '/discover/movie');
      expect(query.containsKey('with_genres'), isFalse);
      expect(query['sort_by'], 'popularity.desc');
      expect(query['include_adult'], false);
      expect(page.results.single.title, '파이트 클럽');
    });

    test('장르를 지정하면 with_genres와 page를 함께 보낸다', () async {
      await service.discoverMovies(page: 2, genreId: 28);

      final query = adapter.requests.single.queryParameters;
      expect(query['with_genres'], 28);
      expect(query['page'], 2);
    });

    test('Popular와 Genre 응답을 DTO로 변환한다', () async {
      final popular = await service.fetchPopular();
      final genres = await service.fetchGenres();

      expect(adapter.requests.first.path, '/movie/popular');
      expect(adapter.requests.first.queryParameters['language'], 'ko-KR');
      expect(popular.results.single.posterPath, '/fight.jpg');
      expect(genres.map((genre) => genre.name), ['액션', '애니메이션']);
    });
  });
}
