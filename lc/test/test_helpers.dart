import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

/// GridView가 카드를 충분히 그리도록 테스트 화면을 세로로 길게 만든다.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// [body]를 실행하는 동안 debugPrint로 남는 로그를 모아서 돌려준다.
/// 위젯 테스트는 테스트가 끝나기 전에 debugPrint가 원래대로여야 하므로 finally에서 되돌린다.
Future<List<String>> collectDebugPrint(Future<void> Function() body) async {
  final logs = <String>[];
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) => logs.add(message ?? '');
  try {
    await body();
  } finally {
    debugPrint = original;
  }
  return logs;
}

TmdbMovieDto movieDto(
  int id, {
  String? title,
  String? posterPath = '/poster.jpg',
  String overview = '줄거리',
  String? releaseDate = '2024-05-01',
  List<int> genreIds = const [28],
  double voteAverage = 8.0,
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
    popularity: 100,
  );
}

List<TmdbMovieDto> movieDtos(
  int count, {
  int startId = 1,
  List<int> genreIds = const [28],
}) {
  return [
    for (var i = 0; i < count; i++) movieDto(startId + i, genreIds: genreIds),
  ];
}

const testGenres = [
  TmdbGenreDto(id: 28, name: '액션'),
  TmdbGenreDto(id: 12, name: '모험'),
  TmdbGenreDto(id: 16, name: '애니메이션'),
];

class DiscoverCall {
  const DiscoverCall(this.page, this.genreId);

  final int page;
  final int? genreId;
}

/// 실제 네트워크 없이 TmdbMovieService의 호출 경계를 대신하는 가짜 Service.
class FakeTmdbMovieService extends TmdbMovieService {
  FakeTmdbMovieService({
    List<TmdbMovieDto>? popular,
    this.genres = testGenres,
    List<TmdbMovieDto> Function(int? genreId)? catalog,
    this.pageSize = 20,
  }) : popular = popular ?? movieDtos(20),
       catalog = catalog ?? _defaultCatalog,
       super(Dio());

  final List<TmdbMovieDto> popular;
  final List<TmdbGenreDto> genres;

  /// 장르(null이면 전체)에 해당하는 영화 전체. 한 페이지씩 잘라서 돌려준다.
  final List<TmdbMovieDto> Function(int? genreId) catalog;
  final int pageSize;

  bool failPopular = false;
  bool failDiscover = false;
  bool failGenres = false;

  /// 이 Completer가 완료될 때까지 Discover 응답을 붙잡아 Loading 상태를 만든다.
  Completer<void>? discoverGate;

  final List<DiscoverCall> discoverCalls = [];
  int popularCalls = 0;
  int genreCalls = 0;

  static List<TmdbMovieDto> _defaultCatalog(int? genreId) {
    if (genreId == null) return movieDtos(100);
    return movieDtos(40, startId: genreId * 1000, genreIds: [genreId]);
  }

  @override
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    popularCalls++;
    if (failPopular) throw _failure('/movie/popular');
    return _page(popular, page);
  }

  @override
  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    int? genreId,
  }) async {
    discoverCalls.add(DiscoverCall(page, genreId));
    final gate = discoverGate;
    if (gate != null) await gate.future;
    if (failDiscover) throw _failure('/discover/movie');
    return _page(catalog(genreId), page);
  }

  @override
  Future<List<TmdbGenreDto>> fetchGenres() async {
    genreCalls++;
    if (failGenres) throw _failure('/genre/movie/list');
    return genres;
  }

  DioException _failure(String path) {
    return DioException(
      requestOptions: RequestOptions(path: path),
      type: DioExceptionType.connectionError,
      message: 'fake failure',
    );
  }

  TmdbMoviePageDto _page(List<TmdbMovieDto> all, int page) {
    final start = (page - 1) * pageSize;
    final results = start >= all.length
        ? <TmdbMovieDto>[]
        : all.skip(start).take(pageSize).toList();

    return TmdbMoviePageDto(
      page: page,
      results: results,
      totalPages: all.isEmpty ? 1 : (all.length / pageSize).ceil(),
      totalResults: all.length,
    );
  }
}
