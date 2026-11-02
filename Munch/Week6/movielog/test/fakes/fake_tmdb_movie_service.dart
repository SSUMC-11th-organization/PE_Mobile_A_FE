import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page_dto.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

TmdbMovieDto movieFixture(int id, {String? posterPath = '/p.jpg'}) {
  return TmdbMovieDto(
    id: id,
    title: '영화 $id',
    overview: '',
    posterPath: posterPath,
    backdropPath: null,
    releaseDate: '2024-01-01',
    genreIds: const [28],
    voteAverage: 7.5,
    popularity: 1,
  );
}

TmdbMoviePageDto pageFixture(int page, List<int> ids, {int totalPages = 10}) {
  return TmdbMoviePageDto(
    page: page,
    results: ids.map(movieFixture).toList(),
    totalPages: totalPages,
    totalResults: totalPages * ids.length,
  );
}

DioException networkError(String path) {
  return DioException(
    requestOptions: RequestOptions(path: path),
    type: DioExceptionType.connectionError,
  );
}

/// Record의 `==`는 List를 값으로 비교하지 않으므로 page와 genreIds를 따로 비교한다.
Matcher isDiscoverCall(int page, List<int> genreIds) {
  return isA<({int page, List<int>? genreIds})>()
      .having((call) => call.page, 'page', page)
      .having((call) => call.genreIds, 'genreIds', genreIds);
}

/// 네트워크 없이 ViewModel·화면을 검증하는 가짜 Service.
class FakeTmdbMovieService extends TmdbMovieService {
  FakeTmdbMovieService() : super(Dio());

  final discoverCalls = <({int page, List<int>? genreIds})>[];

  TmdbMoviePageDto Function(int page) popular = (page) =>
      pageFixture(page, [1, 2, 3, 4, 5, 6, 7]);

  /// 기본: 페이지마다 20개, 다음 페이지와 5개씩 겹친다.
  TmdbMoviePageDto Function(int page, List<int>? genreIds) discover =
      (page, genreIds) => pageFixture(
        page,
        List.generate(20, (index) => (page - 1) * 15 + index + 1),
      );

  List<TmdbGenreDto> genres = const [
    TmdbGenreDto(id: 28, name: '액션'),
    TmdbGenreDto(id: 18, name: '드라마'),
    TmdbGenreDto(id: 878, name: 'SF'),
  ];

  bool failDiscover = false;
  bool failGenres = false;
  bool failPopular = false;

  /// 지정하면 Discover 응답이 이 Future가 끝날 때까지 멈춘다.
  Completer<void>? discoverGate;

  @override
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    if (failPopular) throw networkError('/movie/popular');
    return popular(page);
  }

  @override
  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    List<int>? genreIds,
  }) async {
    discoverCalls.add((page: page, genreIds: genreIds));
    await discoverGate?.future;
    if (failDiscover) throw networkError('/discover/movie');
    return discover(page, genreIds);
  }

  @override
  Future<List<TmdbGenreDto>> fetchGenres() async {
    if (failGenres) throw networkError('/genre/movie/list');
    return genres;
  }
}
