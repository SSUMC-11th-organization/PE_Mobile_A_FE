import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/movie_list_view_model.dart';

import '../test_helpers.dart';

void main() {
  late FakeTmdbMovieService service;
  late MovieListViewModel viewModel;

  tearDown(() => viewModel.dispose());

  group('최대 30개 만들기', () {
    test('여러 페이지를 요청해 정확히 30개를 만든다', () async {
      service = FakeTmdbMovieService();
      viewModel = MovieListViewModel(service);

      await viewModel.loadInitial();

      expect(viewModel.status, MovieListLoadStatus.success);
      expect(viewModel.movies, hasLength(30));
      // 한 페이지 개수를 가정하지 않고, 30개가 찰 때까지만 요청한다.
      expect(service.discoverCalls.map((call) => call.page), [1, 2]);
      expect(service.discoverCalls.every((call) => call.genreId == null), true);
    });

    test('결과가 30개보다 적으면 있는 만큼만 보여주고 오류로 처리하지 않는다', () async {
      service = FakeTmdbMovieService(catalog: (_) => movieDtos(7));
      viewModel = MovieListViewModel(service);

      await viewModel.loadInitial();

      expect(viewModel.status, MovieListLoadStatus.success);
      expect(viewModel.movies, hasLength(7));
      expect(service.discoverCalls, hasLength(1));
    });

    test('마지막 페이지까지 요청하고 더 없으면 멈춘다', () async {
      service = FakeTmdbMovieService(catalog: (_) => movieDtos(25));
      viewModel = MovieListViewModel(service);

      await viewModel.loadInitial();

      expect(viewModel.movies, hasLength(25));
      expect(service.discoverCalls.map((call) => call.page), [1, 2]);
    });

    test('페이지 사이에 겹친 영화는 TMDB id 기준으로 하나만 남긴다', () async {
      // id 1~25 다음에 20~60이 이어져서 20~25가 두 번 나온다.
      service = FakeTmdbMovieService(
        catalog: (_) => [...movieDtos(25), ...movieDtos(41, startId: 20)],
      );
      viewModel = MovieListViewModel(service);

      await viewModel.loadInitial();

      final ids = viewModel.movies.map((movie) => movie.id).toList();
      expect(ids, hasLength(30));
      expect(ids.toSet(), hasLength(30));
    });

    test('결과가 하나도 없으면 Empty 상태다', () async {
      service = FakeTmdbMovieService(catalog: (_) => const []);
      viewModel = MovieListViewModel(service);

      await viewModel.loadInitial();

      expect(viewModel.status, MovieListLoadStatus.empty);
      expect(viewModel.movies, isEmpty);
    });
  });

  group('장르 선택', () {
    test('장르를 고르면 page 1부터 with_genres로 다시 요청한다', () async {
      service = FakeTmdbMovieService();
      viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();
      service.discoverCalls.clear();

      await viewModel.selectGenre(28);

      expect(viewModel.selectedGenreId, 28);
      expect(service.discoverCalls.first.page, 1);
      expect(service.discoverCalls.every((call) => call.genreId == 28), true);
      expect(viewModel.status, MovieListLoadStatus.success);
    });

    test('전체를 고르면 with_genres 없이 요청한다', () async {
      service = FakeTmdbMovieService();
      viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();
      await viewModel.selectGenre(28);
      service.discoverCalls.clear();

      await viewModel.selectGenre(null);

      expect(viewModel.selectedGenreId, isNull);
      expect(service.discoverCalls.every((call) => call.genreId == null), true);
    });

    test('장르 목록은 한 번만 받는다', () async {
      service = FakeTmdbMovieService();
      viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();

      await viewModel.selectGenre(28);
      await viewModel.selectGenre(12);

      expect(service.genreCalls, 1);
    });

    test('요청 중에는 장르를 바꿔도 무시한다', () async {
      service = FakeTmdbMovieService();
      service.discoverGate = Completer<void>();
      viewModel = MovieListViewModel(service);

      final loading = viewModel.loadInitial();
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.isLoading, isTrue);

      await viewModel.selectGenre(28);
      expect(viewModel.selectedGenreId, isNull);
      expect(service.discoverCalls.every((call) => call.genreId == null), true);

      service.discoverGate!.complete();
      await loading;
      expect(viewModel.status, MovieListLoadStatus.success);
    });
  });

  group('오류와 재시도', () {
    test('요청이 실패하면 Error 상태와 안내 문구가 된다', () async {
      service = FakeTmdbMovieService()..failDiscover = true;
      viewModel = MovieListViewModel(service);

      await viewModel.loadInitial();

      expect(viewModel.status, MovieListLoadStatus.error);
      expect(viewModel.message, isNotNull);
      expect(viewModel.message, isNot(contains('Exception')));
    });

    test('재시도는 마지막으로 고른 장르를 유지한 채 page 1부터 다시 요청한다', () async {
      service = FakeTmdbMovieService();
      viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();

      service.failDiscover = true;
      await viewModel.selectGenre(28);
      expect(viewModel.status, MovieListLoadStatus.error);

      service
        ..failDiscover = false
        ..discoverCalls.clear();
      await viewModel.retry();

      expect(viewModel.status, MovieListLoadStatus.success);
      expect(viewModel.selectedGenreId, 28);
      expect(service.discoverCalls.first.page, 1);
      expect(service.discoverCalls.first.genreId, 28);
    });

    test('장르 목록 요청이 실패해도 Error가 되고 재시도로 복구된다', () async {
      service = FakeTmdbMovieService()..failGenres = true;
      viewModel = MovieListViewModel(service);

      await viewModel.loadInitial();
      expect(viewModel.status, MovieListLoadStatus.error);

      service.failGenres = false;
      await viewModel.retry();

      expect(viewModel.status, MovieListLoadStatus.success);
      expect(viewModel.genres, isNotEmpty);
    });
  });

  test('화면이 사라진 뒤 늦게 온 응답은 무시하고 오류를 내지 않는다', () async {
    service = FakeTmdbMovieService();
    service.discoverGate = Completer<void>();
    viewModel = MovieListViewModel(service);
    var notified = 0;
    viewModel.addListener(() => notified++);

    final loading = viewModel.loadInitial();
    await Future<void>.delayed(Duration.zero);
    final notifiedWhileLoading = notified;

    viewModel.dispose();
    service.discoverGate!.complete();
    await loading;

    expect(notified, notifiedWhileLoading);
    // tearDown의 dispose와 겹치지 않도록 새 인스턴스로 교체한다.
    viewModel = MovieListViewModel(service);
  });
}
