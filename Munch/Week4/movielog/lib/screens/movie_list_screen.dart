import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/mock_movies.dart';
import '../models/movie.dart';
import '../services/fake_movie_service.dart';
import '../services/genre_preference.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/genre_chip_bar.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';

class MovieListInitialData {
  const MovieListInitialData({
    required this.movies,
    required this.selectedGenre,
  });

  final List<Movie> movies;
  final String selectedGenre;
}

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({
    super.key,
    this.movieService = const FakeMovieService(),
    this.genrePreference,
  });

  final FakeMovieService movieService;
  final GenrePreference? genrePreference;

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  static const _genres = [GenrePreference.allGenre, ...movieGenres];

  late final GenrePreference _genrePreference =
      widget.genrePreference ?? GenrePreference();

  // Future는 build가 아니라 initState와 재시도 시점에만 만든다.
  late Future<MovieListInitialData> _initialDataFuture;

  // 로드 이후 Chip으로 바꾼 장르. null이면 저장소에서 읽은 값을 쓴다.
  String? _selectedGenre;

  @override
  void initState() {
    super.initState();
    _initialDataFuture = _loadInitialData();
  }

  Future<MovieListInitialData> _loadInitialData() async {
    try {
      // 영화 목록과 저장된 장르는 서로 의존하지 않으므로 함께 시작한다.
      final results = await Future.wait([
        widget.movieService.fetchMovies(),
        _genrePreference.read(),
      ]);

      return MovieListInitialData(
        movies: results[0] as List<Movie>,
        selectedGenre: results[1] as String,
      );
    } catch (error, stackTrace) {
      debugPrint('영화 목록 로드 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  void _retry() {
    setState(() {
      _selectedGenre = null;
      _initialDataFuture = _loadInitialData();
    });
  }

  Future<void> _selectGenre(String genre) async {
    setState(() => _selectedGenre = genre);
    await _genrePreference.save(genre);
  }

  List<Movie> _filter(List<Movie> movies, String genre) {
    if (genre == GenrePreference.allGenre) return movies;
    return movies.where((movie) => movie.genres.contains(genre)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
      ),
      body: FutureBuilder<MovieListInitialData>(
        future: _initialDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const MovieListLoading();
          }

          if (snapshot.hasError) {
            return MovieListError(onRetry: _retry);
          }

          final data = snapshot.data;
          if (data == null) return const MovieListEmpty();

          final selectedGenre = _selectedGenre ?? data.selectedGenre;
          final filtered = _filter(data.movies, selectedGenre);

          return Column(
            children: [
              GenreChipBar(
                genres: _genres,
                selectedGenre: selectedGenre,
                onSelected: _selectGenre,
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const MovieListEmpty()
                    : MovieGrid(
                        movies: filtered,
                        onMovieTap: (movie) =>
                            context.push('/movies/${movie.id}'),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
