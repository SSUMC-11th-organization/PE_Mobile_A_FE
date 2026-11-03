import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';

TmdbMovieDto movie(int id) => TmdbMovieDto(
      id: id,
      title: '영화 $id',
      overview: '',
      posterPath: null,
      backdropPath: null,
      releaseDate: null,
      genreIds: const [],
      voteAverage: 0,
      popularity: 0,
    );

List<int> ids(int from, int to) => [for (var i = from; i <= to; i++) i];

TmdbMoviePageDto page(int number, List<int> movieIds, {int totalPages = 5}) {
  return TmdbMoviePageDto(
    page: number,
    results: movieIds.map(movie).toList(),
    totalPages: totalPages,
    totalResults: 100,
  );
}

/// 서버 대신 정해 둔 결과를 돌려주는 가짜 Service
class FakeTmdbService extends TmdbMovieService {
  FakeTmdbService() : super(Dio());

  TmdbMoviePageDto popularPage = page(1, ids(1, 20));
  List<TmdbMoviePageDto> pages = [];
  bool shouldFail = false;

  final requestedPages = <int>[];
  final requestedGenreIds = <int?>[];

  @override
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    if (shouldFail) {
      throw DioException(requestOptions: RequestOptions(path: '/popular'));
    }
    return popularPage;
  }

  @override
  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    int? genreId,
  }) async {
    requestedPages.add(page);
    requestedGenreIds.add(genreId);
    if (shouldFail) {
      throw DioException(requestOptions: RequestOptions(path: '/discover'));
    }
    return pages[page - 1];
  }

  @override
  Future<List<TmdbGenreDto>> fetchGenres() async {
    return const [TmdbGenreDto(id: 28, name: '액션')];
  }
}

void main() {
  group('MovieHomeViewModel', () {
    test('인기 영화는 앞 5개만 사용한다', () async {
      final vm = MovieHomeViewModel(FakeTmdbService());
      addTearDown(vm.dispose);

      await vm.loadPopular();

      expect(vm.status, MovieHomeLoadStatus.success);
      expect(vm.popularMovies.length, 5);
      expect(vm.popularMovies.first.id, 1);
    });

    test('5개보다 적어도 오류 없이 있는 만큼 사용한다', () async {
      final service = FakeTmdbService()..popularPage = page(1, ids(1, 3));
      final vm = MovieHomeViewModel(service);
      addTearDown(vm.dispose);

      await vm.loadPopular();

      expect(vm.status, MovieHomeLoadStatus.success);
      expect(vm.popularMovies.length, 3);
    });

    test('결과가 없으면 empty, 실패하면 error 상태가 된다', () async {
      final service = FakeTmdbService()..popularPage = page(1, []);
      final vm = MovieHomeViewModel(service);
      addTearDown(vm.dispose);

      await vm.loadPopular();
      expect(vm.status, MovieHomeLoadStatus.empty);

      service.shouldFail = true;
      await vm.loadPopular();
      expect(vm.status, MovieHomeLoadStatus.error);
      expect(vm.message, isNotNull);
    });
  });

  group('MovieListViewModel', () {
    test('2페이지를 요청해 최대 30개를 만들고 장르 목록도 불러온다', () async {
      final service = FakeTmdbService()
        ..pages = [page(1, ids(1, 20)), page(2, ids(21, 40))];
      final vm = MovieListViewModel(service);
      addTearDown(vm.dispose);

      await vm.loadInitial();

      expect(vm.status, MovieListLoadStatus.success);
      expect(vm.movies.length, 30);
      expect(vm.genres.length, 1);
      expect(service.requestedPages, [1, 2]);
      expect(service.requestedGenreIds, [null, null]);
    });

    test('페이지 사이에 겹치는 영화는 id 기준으로 하나만 남긴다', () async {
      final service = FakeTmdbService()
        ..pages = [page(1, ids(1, 20)), page(2, ids(10, 40))];
      final vm = MovieListViewModel(service);
      addTearDown(vm.dispose);

      await vm.loadInitial();

      expect(vm.movies.length, 30);
      expect(vm.movies.map((m) => m.id).toSet().length, 30);
    });

    test('30개보다 적으면 있는 만큼만 보여주고 오류로 처리하지 않는다', () async {
      final service = FakeTmdbService()
        ..pages = [page(1, ids(1, 5), totalPages: 1)];
      final vm = MovieListViewModel(service);
      addTearDown(vm.dispose);

      await vm.loadInitial();

      expect(vm.status, MovieListLoadStatus.success);
      expect(vm.movies.length, 5);
      expect(service.requestedPages, [1]);
    });

    test('결과가 하나도 없으면 empty 상태가 된다', () async {
      final service = FakeTmdbService()
        ..pages = [page(1, [], totalPages: 1)];
      final vm = MovieListViewModel(service);
      addTearDown(vm.dispose);

      await vm.loadInitial();

      expect(vm.status, MovieListLoadStatus.empty);
    });

    test('장르를 선택하면 with_genres로 page 1부터 다시 요청한다', () async {
      final service = FakeTmdbService()
        ..pages = [page(1, ids(1, 20)), page(2, ids(21, 40))];
      final vm = MovieListViewModel(service);
      addTearDown(vm.dispose);

      await vm.loadInitial();
      await vm.selectGenre(28);
      await vm.selectGenre(null); // "전체"

      expect(service.requestedPages, [1, 2, 1, 2, 1, 2]);
      expect(service.requestedGenreIds, [null, null, 28, 28, null, null]);
    });

    test('요청 중에는 장르를 바꿀 수 없다', () async {
      final service = FakeTmdbService()
        ..pages = [page(1, ids(1, 20)), page(2, ids(21, 40))];
      final vm = MovieListViewModel(service);
      addTearDown(vm.dispose);

      final loading = vm.loadInitial();
      expect(vm.status, MovieListLoadStatus.loading);

      await vm.selectGenre(28); // 무시된다
      await loading;

      expect(vm.selectedGenreId, isNull);
      expect(service.requestedGenreIds.every((id) => id == null), isTrue);
    });

    test('요청이 실패하면 error 상태가 되고 재시도하면 성공한다', () async {
      final service = FakeTmdbService()
        ..pages = [page(1, ids(1, 20)), page(2, ids(21, 40))]
        ..shouldFail = true;
      final vm = MovieListViewModel(service);
      addTearDown(vm.dispose);

      await vm.loadInitial();
      expect(vm.status, MovieListLoadStatus.error);
      expect(vm.message, isNotNull);

      service.shouldFail = false;
      await vm.retry();
      expect(vm.status, MovieListLoadStatus.success);
      expect(vm.movies.length, 30);
    });
  });
}