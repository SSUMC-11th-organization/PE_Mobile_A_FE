import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';

import '../fakes/fake_tmdb_movie_service.dart';

void main() {
  late FakeTmdbMovieService service;
  late MovieListViewModel viewModel;

  setUp(() {
    service = FakeTmdbMovieService();
    viewModel = MovieListViewModel(service);
  });

  group('최대 30개 구성', () {
    test('페이지 사이 중복을 id로 제거하며 30개까지 page 1부터 요청한다', () async {
      final movies = await viewModel.fetchUpToThirtyMovies();

      expect(movies, hasLength(30));
      expect(movies.map((movie) => movie.id).toSet(), hasLength(30));
      expect(service.discoverCalls.map((call) => call.page), [1, 2]);
    });

    test('마지막 페이지에 도달하면 30개보다 적어도 그대로 반환한다', () async {
      service.discover = (page, genreIds) =>
          pageFixture(page, [page * 100, page * 100 + 1], totalPages: 2);

      final movies = await viewModel.fetchUpToThirtyMovies();

      expect(movies.map((movie) => movie.id), [100, 101, 200, 201]);
      expect(service.discoverCalls, hasLength(2));
    });

    test('빈 페이지를 받으면 더 요청하지 않는다', () async {
      service.discover = (page, genreIds) => pageFixture(page, []);

      final movies = await viewModel.fetchUpToThirtyMovies();

      expect(movies, isEmpty);
      expect(service.discoverCalls, hasLength(1));
    });
  });

  test('loadInitial은 장르와 영화를 불러와 Success가 된다', () async {
    await viewModel.loadInitial();

    expect(viewModel.status, MovieListLoadStatus.success);
    expect(viewModel.genres, hasLength(3));
    expect(viewModel.genreNames[28], '액션');
    expect(viewModel.movies, hasLength(30));
    expect(viewModel.selectedGenreIds, isNull);
    expect(service.discoverCalls.first.genreIds, isNull);
  });

  test('선택 없이 확인하면 null(전체)로 바꾸고 with_genres 없이 다시 요청한다', () async {
    await viewModel.loadInitial();
    await viewModel.selectGenres([28]);
    service.discoverCalls.clear();

    final result = await viewModel.selectGenres(const []);

    expect(result, MovieListLoadResult.success);
    expect(viewModel.selectedGenreIds, isNull);
    expect(service.discoverCalls.first.genreIds, isNull);
  });

  test('장르를 선택하면 해당 장르로 page 1부터 다시 요청한다', () async {
    await viewModel.loadInitial();
    service.discoverCalls.clear();

    final result = await viewModel.selectGenres([28, 18]);

    expect(result, MovieListLoadResult.success);
    expect(viewModel.selectedGenreIds, [28, 18]);
    expect(service.discoverCalls.first, isDiscoverCall(1, [28, 18]));
  });

  test('장르 결과가 없으면 Empty', () async {
    await viewModel.loadInitial();
    service.discover = (page, genreIds) => pageFixture(page, []);

    await viewModel.selectGenres([878]);

    expect(viewModel.status, MovieListLoadStatus.empty);
  });

  test('Discover 요청 중에는 장르를 바꿀 수 없다', () async {
    await viewModel.loadInitial();
    service.discoverGate = Completer<void>();

    final pending = viewModel.selectGenres([28]);
    expect(viewModel.isBusy, isTrue);
    expect(await viewModel.selectGenres([18]), MovieListLoadResult.ignored);

    service.discoverGate!.complete();
    await pending;
    expect(viewModel.selectedGenreIds, [28]);
  });

  test('새로고침 중에도 기존 목록을 유지하고 완료되면 교체한다', () async {
    await viewModel.loadInitial();
    final before = viewModel.movies;
    service.discover = (page, genreIds) =>
        pageFixture(page, [999], totalPages: 1);
    service.discoverGate = Completer<void>();

    final pending = viewModel.refresh();
    expect(viewModel.isRefreshing, isTrue);
    expect(viewModel.movies, same(before));

    service.discoverGate!.complete();
    await pending;
    expect(viewModel.isRefreshing, isFalse);
    expect(viewModel.movies.map((movie) => movie.id), [999]);
  });

  test('최근 성공 목록이 있으면 실패해도 목록을 유지하고 재시도를 요청한다', () async {
    await viewModel.loadInitial();
    final before = viewModel.movies;
    service.failDiscover = true;

    final result = await viewModel.selectGenres([18]);

    expect(result, MovieListLoadResult.failedWithPrevious);
    expect(viewModel.status, MovieListLoadStatus.success);
    expect(viewModel.movies, same(before));

    service
      ..failDiscover = false
      ..discoverCalls.clear();
    expect(await viewModel.retry(), MovieListLoadResult.success);
    expect(service.discoverCalls.first, isDiscoverCall(1, [18]));
  });

  test('성공한 목록이 없을 때 실패하면 Error', () async {
    service.failGenres = true;

    final result = await viewModel.loadInitial();

    expect(result, MovieListLoadResult.failed);
    expect(viewModel.status, MovieListLoadStatus.error);
    expect(viewModel.message, isNotNull);
  });
}
