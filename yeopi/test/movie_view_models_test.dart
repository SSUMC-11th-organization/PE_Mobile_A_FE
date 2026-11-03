import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/services/movie_list_preferences.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/tmdb_fakes.dart';

DioException _networkError() => DioException(
  requestOptions: RequestOptions(path: '/discover/movie'),
  type: DioExceptionType.connectionError,
);

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('MovieHomeViewModel', () {
    test('Popular 첫 페이지에서 앞의 5개만 사용한다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = MovieHomeViewModel(service);

      await viewModel.loadPopular();

      expect(viewModel.status, MovieHomeLoadStatus.success);
      expect(viewModel.popularMovies.map((movie) => movie.id), [1, 2, 3, 4, 5]);
      expect(service.popularRequests, 1);
    });

    test('결과가 5개보다 적으면 있는 만큼만 보여준다', () async {
      final viewModel = MovieHomeViewModel(
        FakeTmdbMovieService(movies: [movieFixture(1), movieFixture(2)]),
      );

      await viewModel.loadPopular();

      expect(viewModel.popularMovies, hasLength(2));
    });

    test('요청이 실패하면 Error 상태와 안내 문구를 둔다', () async {
      final service = FakeTmdbMovieService()..error = _networkError();
      final viewModel = MovieHomeViewModel(service);

      await viewModel.loadPopular();

      expect(viewModel.status, MovieHomeLoadStatus.error);
      expect(viewModel.message, contains('네트워크에 연결할 수 없어요'));
    });
  });

  group('MovieListViewModel', () {
    MovieListViewModel createViewModel(FakeTmdbMovieService service) =>
        MovieListViewModel(service, MovieListPreferences());

    test('페이지를 이어 요청하면서 중복을 빼고 최대 30개를 만든다', () async {
      // 2페이지 앞부분(15~20)이 1페이지와 겹칩니다.
      final service = FakeTmdbMovieService(
        movies: [
          for (var id = 1; id <= 20; id++) movieFixture(id),
          for (var id = 15; id <= 54; id++) movieFixture(id),
        ],
      );
      final viewModel = createViewModel(service);

      await viewModel.loadInitial();

      expect(viewModel.status, MovieListLoadStatus.success);
      expect(viewModel.movies, hasLength(30));
      expect(viewModel.movies.map((movie) => movie.id).toSet(), hasLength(30));
      expect(service.discoverRequests.map((request) => request.page), [1, 2]);
    });

    test('마지막 페이지까지 30개가 안 되면 있는 만큼만 보여준다', () async {
      final service = FakeTmdbMovieService(
        movies: [for (var id = 1; id <= 25; id++) movieFixture(id)],
      );
      final viewModel = createViewModel(service);

      await viewModel.loadInitial();

      expect(viewModel.status, MovieListLoadStatus.success);
      expect(viewModel.movies, hasLength(25));
      expect(service.discoverRequests, hasLength(2));
    });

    test('결과가 없으면 Empty 상태가 된다', () async {
      final viewModel = createViewModel(FakeTmdbMovieService(movies: []));

      await viewModel.loadInitial();

      expect(viewModel.status, MovieListLoadStatus.empty);
    });

    test('장르를 고르면 with_genres로 page 1부터 다시 요청하고 저장한다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = createViewModel(service);
      await viewModel.loadInitial();
      service.discoverRequests.clear();

      await viewModel.selectGenre(18);

      expect(service.discoverRequests.first, (page: 1, genreId: 18));
      expect(viewModel.movies, hasLength(22));
      expect(
        viewModel.movies.every((movie) => movie.genreIds.contains(18)),
        isTrue,
      );
      expect(await MovieListPreferences().readGenreId(), 18);

      await viewModel.selectGenre(null);
      expect(service.discoverRequests.last.genreId, isNull);
      expect(await MovieListPreferences().readGenreId(), isNull);
    });

    test('Discover 요청 중에는 장르를 바꿀 수 없다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = createViewModel(service);
      await viewModel.loadInitial();

      service.gate = Completer<void>();
      final pending = viewModel.selectGenre(18);
      expect(viewModel.isBusy, isTrue);

      await viewModel.selectGenre(28);
      expect(viewModel.selectedGenreId, 18);

      service.gate!.complete();
      await pending;
      expect(service.discoverRequests.where((r) => r.genreId == 28), isEmpty);
    });

    test('저장된 장르와 정렬을 복원하고, 사라진 장르는 전체로 돌린다', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            MovieListPreferences.selectedGenreIdKey: 18,
            MovieListPreferences.sortKey: 'title',
          });
      final service = FakeTmdbMovieService();
      final restored = createViewModel(service);
      await restored.loadInitial();

      expect(restored.selectedGenreId, 18);
      expect(restored.sort, MovieSort.title);
      expect(service.discoverRequests.first.genreId, 18);

      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            MovieListPreferences.selectedGenreIdKey: 9999,
          });
      final fallback = createViewModel(FakeTmdbMovieService());
      await fallback.loadInitial();

      expect(fallback.selectedGenreId, isNull);
    });

    test('정렬은 받아온 목록 안에서 바꾸고, 인기순으로 돌아오면 원래 순서가 된다', () async {
      final service = FakeTmdbMovieService(
        movies: [
          movieFixture(1, title: '다', releaseDate: '2020-01-01'),
          movieFixture(2, title: '가', releaseDate: '2024-01-01'),
          movieFixture(3, title: '나', releaseDate: ''),
        ],
      );
      final viewModel = createViewModel(service);
      await viewModel.loadInitial();

      await viewModel.changeSort(MovieSort.title);
      expect(viewModel.movies.map((movie) => movie.title), ['가', '나', '다']);

      await viewModel.changeSort(MovieSort.latest);
      expect(viewModel.movies.map((movie) => movie.id), [2, 1, 3]);

      await viewModel.changeSort(MovieSort.popular);
      expect(viewModel.movies.map((movie) => movie.id), [1, 2, 3]);
      expect(service.discoverRequests, hasLength(1));
    });

    test('실패 후 다시 시도하면 Success로 돌아온다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = createViewModel(service);
      await viewModel.loadInitial();

      service.error = _networkError();
      await viewModel.refresh();
      expect(viewModel.status, MovieListLoadStatus.error);

      service.error = null;
      await viewModel.retry();
      expect(viewModel.status, MovieListLoadStatus.success);
      expect(viewModel.movies, hasLength(30));
    });
  });
}
