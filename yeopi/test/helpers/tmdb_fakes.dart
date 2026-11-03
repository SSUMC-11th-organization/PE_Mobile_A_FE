import 'dart:async';

import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page_dto.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

TmdbMovieDto movieFixture(
  int id, {
  String? title,
  String overview = '테스트용 줄거리',
  String? posterPath = '/poster.jpg',
  String? releaseDate = '2024-05-01',
  List<int> genreIds = const [28],
  double voteAverage = 7.5,
}) {
  return TmdbMovieDto(
    id: id,
    title: title ?? '영화 $id',
    overview: overview,
    posterPath: posterPath,
    backdropPath: null,
    releaseDate: releaseDate,
    genreIds: genreIds,
    voteAverage: voteAverage,
    popularity: 100.0 - id,
  );
}

const genreFixtures = [
  TmdbGenreDto(id: 28, name: '액션'),
  TmdbGenreDto(id: 18, name: '드라마'),
  TmdbGenreDto(id: 16, name: '애니메이션'),
];

// 홀수 id는 액션(23편), 짝수 id는 드라마(22편)인 45편입니다.
List<TmdbMovieDto> defaultMovieFixtures() => [
  for (var id = 1; id <= 45; id++)
    movieFixture(id, genreIds: [id.isEven ? 18 : 28]),
];

// 실제 TMDB 대신 목록을 pageSize만큼 잘라 페이지 응답으로 돌려주는 테스트용 Service입니다.
class FakeTmdbMovieService implements TmdbMovieService {
  FakeTmdbMovieService({
    List<TmdbMovieDto>? movies,
    this.genres = genreFixtures,
    this.pageSize = 20,
  }) : movies = movies ?? defaultMovieFixtures();

  List<TmdbMovieDto> movies;
  List<TmdbGenreDto> genres;
  final int pageSize;

  // 값을 넣으면 이후 요청이 이 예외로 실패합니다.
  Object? error;

  // 값을 넣으면 complete() 할 때까지 응답을 붙잡아 둡니다.
  Completer<void>? gate;

  int popularRequests = 0;
  final discoverRequests = <({int page, int? genreId})>[];

  Future<void> _respond() async {
    final pending = gate;
    if (pending != null) await pending.future;
    final failure = error;
    if (failure != null) throw failure;
  }

  TmdbMoviePageDto _page(List<TmdbMovieDto> source, int page) {
    final totalPages = source.isEmpty ? 1 : (source.length / pageSize).ceil();
    final start = (page - 1) * pageSize;
    final end = (start + pageSize).clamp(0, source.length);
    return TmdbMoviePageDto(
      page: page,
      results: start >= source.length ? const [] : source.sublist(start, end),
      totalPages: totalPages,
      totalResults: source.length,
    );
  }

  @override
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    popularRequests++;
    await _respond();
    return _page(movies, page);
  }

  @override
  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    int? genreId,
  }) async {
    discoverRequests.add((page: page, genreId: genreId));
    await _respond();
    final source = genreId == null
        ? movies
        : movies.where((movie) => movie.genreIds.contains(genreId)).toList();
    return _page(source, page);
  }

  @override
  Future<List<TmdbGenreDto>> fetchGenres() async {
    await _respond();
    return genres;
  }
}
