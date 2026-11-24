import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';

import '../fakes/fake_tmdb_movie_service.dart';

void main() {
  late FakeTmdbMovieService service;
  late PagedMoviesViewModel vm;

  setUp(() {
    service = FakeTmdbMovieService();
    vm = PagedMoviesViewModel(tmdbApi: service);
  });

  test('첫 page는 목록을 교체하고 다음 page는 중복 id를 빼고 붙인다', () async {
    await vm.loadInitial();
    expect(vm.phase, LoadPhase.ready);
    expect(vm.movies, hasLength(20));
    expect(vm.nextPage, 2);

    await vm.loadNextPage();
    // page 2는 16~35를 내려주므로 겹치는 16~20은 제외된다.
    expect(vm.movies, hasLength(35));
    expect(vm.movies.map((movie) => movie.id).toSet(), hasLength(35));
    expect(vm.nextPage, 3);
  });

  test('다음 page가 실패하면 목록과 nextPage를 유지하고 같은 page를 다시 요청한다', () async {
    await vm.loadInitial();
    service.failDiscover = true;

    await vm.loadNextPage();
    expect(vm.loadMoreError, isNotNull);
    expect(vm.movies, hasLength(20));
    expect(vm.nextPage, 2);

    service.failDiscover = false;
    await vm.loadNextPage();
    expect(service.discoverCalls.map((call) => call.page), [1, 2, 2]);
    expect(vm.loadMoreError, isNull);
  });

  test('추가 로딩 중에는 같은 요청을 중복으로 보내지 않는다', () async {
    await vm.loadInitial();
    service.discoverGate = Completer<void>();

    final first = vm.loadNextPage();
    final second = vm.loadNextPage();
    expect(vm.isLoadingMore, isTrue);
    service.discoverGate!.complete();
    await Future.wait([first, second]);

    expect(service.discoverCalls.map((call) => call.page), [1, 2]);
  });

  test('마지막 page 이후에는 hasMore가 false이고 total_pages는 500으로 제한한다', () async {
    service.discover = (page, genreIds) =>
        pageFixture(page, [page], totalPages: 1);
    await vm.loadInitial();
    expect(vm.hasMore, isFalse);

    service.discover = (page, genreIds) =>
        pageFixture(page, [page], totalPages: 9999);
    await vm.loadInitial();
    expect(vm.totalPages, PagedMoviesViewModel.maxTmdbPage);
  });

  test('장르를 바꾸면 이전 장르의 늦은 응답은 무시한다', () async {
    final gate = Completer<void>();
    service.discoverGate = gate;
    final stale = vm.loadInitial(genreIds: [28]);

    service.discoverGate = null;
    service.discover = (page, genreIds) => pageFixture(page, [900]);
    await vm.loadInitial(genreIds: [18]);
    expect(vm.movies.single.id, 900);

    service.discover = (page, genreIds) => pageFixture(page, [1]);
    gate.complete();
    await stale;
    expect(vm.movies.single.id, 900);
    expect(vm.selectedGenreIds, [18]);
  });

  test('검색어가 바뀌면 이전 검색어의 늦은 응답은 무시한다', () async {
    final gate = Completer<void>();
    service.searchGates['어벤'] = gate;
    service.search = (page, query) =>
        pageFixture(page, [query == '어벤' ? 1 : 2]);

    final stale = vm.loadInitial(query: '어벤');
    await vm.loadInitial(query: '어벤져스');
    gate.complete();
    await stale;

    expect(vm.query, '어벤져스');
    expect(vm.movies.single.id, 2);
  });

  test('검색 결과가 없으면 empty, 실패하면 error로 구분한다', () async {
    service.search = (page, query) => pageFixture(page, [], totalPages: 0);
    await vm.loadInitial(query: '없는영화');
    expect(vm.phase, LoadPhase.empty);

    service.failSearch = true;
    await vm.loadInitial(query: '별빛');
    expect(vm.phase, LoadPhase.error);
    expect(vm.errorMessage, '검색 결과를 불러오지 못했습니다.');
  });
}
