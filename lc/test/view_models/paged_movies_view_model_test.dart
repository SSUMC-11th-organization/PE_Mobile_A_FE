import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';

import '../test_helpers.dart';

void main() {
  late FakeTmdbMovieService service;
  late PagedMoviesViewModel vm;

  tearDown(() => vm.dispose());

  test('첫 페이지를 받고 더 보기로 다음 페이지를 이어 붙인다', () async {
    service = FakeTmdbMovieService();
    vm = PagedMoviesViewModel(service);
    await vm.loadInitial();
    expect(vm.phase, LoadPhase.ready);
    expect(vm.movies, hasLength(20));
    expect(vm.hasMore, true);

    await vm.loadMore();
    expect(vm.movies, hasLength(40));
    expect(service.discoverCalls.map((c) => c.page), [1, 2]);
  });

  test('페이지 사이에 겹친 영화는 id 기준으로 한 번만 남긴다', () async {
    service = FakeTmdbMovieService(
      catalog: (_) => [...movieDtos(25), ...movieDtos(25, startId: 20)],
    );
    vm = PagedMoviesViewModel(service);
    await vm.loadInitial();
    await vm.loadMore();
    final ids = vm.movies.map((m) => m.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('마지막 페이지에서는 더 요청하지 않는다', () async {
    service = FakeTmdbMovieService(catalog: (_) => movieDtos(7));
    vm = PagedMoviesViewModel(service);
    await vm.loadInitial();
    expect(vm.hasMore, false);
    await vm.loadMore();
    expect(service.discoverCalls, hasLength(1));
  });

  test('다음 페이지 실패는 기존 목록을 지키고, 재시도하면 이어진다', () async {
    service = FakeTmdbMovieService();
    vm = PagedMoviesViewModel(service);
    await vm.loadInitial();
    service.failDiscoverPages.add(2);

    await vm.loadMore();
    expect(vm.phase, LoadPhase.ready);
    expect(vm.movies, hasLength(20));
    expect(vm.loadMoreError, isNotNull);

    await vm.loadMore();
    expect(vm.loadMoreError, isNull);
    expect(vm.movies, hasLength(40));
  });

  test('더 보기 중복 호출은 한 번만 요청한다', () async {
    service = FakeTmdbMovieService();
    vm = PagedMoviesViewModel(service);
    await vm.loadInitial();
    final a = vm.loadMore();
    final b = vm.loadMore();
    await Future.wait([a, b]);
    expect(service.discoverCalls.where((c) => c.page == 2), hasLength(1));
  });

  test('TMDB page 500을 넘겨 요청하지 않는다', () async {
    // 한 페이지에 1개씩, 전체 600페이지인 목록. 500페이지까지만 받아야 한다.
    service = FakeTmdbMovieService(catalog: (_) => movieDtos(600), pageSize: 1);
    vm = PagedMoviesViewModel(service);
    await vm.loadInitial();
    for (var i = 0; i < 520; i++) {
      await vm.loadMore();
    }
    expect(vm.hasMore, false);
    expect(service.discoverCalls.map((c) => c.page).reduce((a, b) => a > b ? a : b), 500);
    expect(vm.movies, hasLength(500));
  });

  test('장르를 바꾸면 처음부터 다시 받고 이전 응답은 버린다', () async {
    service = FakeTmdbMovieService();
    vm = PagedMoviesViewModel(service);
    await vm.loadInitial();
    await vm.selectGenre(28);
    expect(vm.selectedGenreId, 28);
    expect(service.discoverCalls.last.genreId, 28);
    expect(service.discoverCalls.last.page, 1);
    expect(vm.movies.first.id, 28000);
  });

  test('검색 결과가 없으면 empty 상태가 된다', () async {
    service = FakeTmdbMovieService();
    vm = PagedMoviesViewModel(service, debounce: Duration.zero);
    vm.onQueryChanged('없는영화');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(vm.phase, LoadPhase.empty);
  });

  testWidgets('debounce: 빠르게 입력하면 마지막 검색어로 한 번만 요청한다', (tester) async {
    service = FakeTmdbMovieService();
    vm = PagedMoviesViewModel(service);
    vm.onQueryChanged('매');
    await tester.pump(const Duration(milliseconds: 200));
    vm.onQueryChanged('매트');
    await tester.pump(const Duration(milliseconds: 200));
    vm.onQueryChanged('매트릭스');
    expect(service.searchCalls, isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    expect(service.searchCalls.map((c) => c.query), ['매트릭스']);
  });

  testWidgets('검색어를 지우면 요청 없이 안내 상태로 돌아간다', (tester) async {
    service = FakeTmdbMovieService();
    vm = PagedMoviesViewModel(service);
    vm.onQueryChanged('매트릭스');
    vm.onQueryChanged('   ');
    await tester.pump(const Duration(seconds: 1));
    expect(service.searchCalls, isEmpty);
    expect(vm.phase, LoadPhase.idle);
  });
}
