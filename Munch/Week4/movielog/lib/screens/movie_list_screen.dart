import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/mock_movies.dart';
import '../models/movie.dart';
import '../models/movie_sort.dart';
import '../services/fake_movie_service.dart';
import '../services/genre_preference.dart';
import '../services/sort_preference.dart';
import '../theme/app_colors.dart';
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
    required this.selectedSort,
  });

  final List<Movie> movies;
  final String selectedGenre;
  final MovieSort selectedSort;
}

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({
    super.key,
    this.movieService = const FakeMovieService(),
    this.genrePreference,
    this.sortPreference,
  });

  static const loadTimeout = Duration(seconds: 5);

  final FakeMovieService movieService;
  final GenrePreference? genrePreference;
  final SortPreference? sortPreference;

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  static const _genres = [GenrePreference.allGenre, ...movieGenres];

  late final GenrePreference _genrePreference =
      widget.genrePreference ?? GenrePreference();
  late final SortPreference _sortPreference =
      widget.sortPreference ?? SortPreference();

  late Future<MovieListInitialData> _initialDataFuture;

  String? _selectedGenre;
  MovieSort? _selectedSort;

  @override
  void initState() {
    super.initState();
    _initialDataFuture = _loadInitialData();
  }

  Future<MovieListInitialData> _loadInitialData() async {
    try {
      final results = await Future.wait([
        widget.movieService.fetchMovies().timeout(MovieListScreen.loadTimeout),
        _genrePreference.read(),
        _sortPreference.read(),
      ]);

      return MovieListInitialData(
        movies: results[0] as List<Movie>,
        selectedGenre: results[1] as String,
        selectedSort: results[2] as MovieSort,
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
      _selectedSort = null;
      _initialDataFuture = _loadInitialData();
    });
  }

  Future<void> _refresh() async {
    final future = _loadInitialData();
    setState(() {
      _initialDataFuture = future;
    });
    await future.then<void>((_) {}, onError: (Object _) {});
  }

  Future<void> _selectGenre(String genre) async {
    setState(() => _selectedGenre = genre);
    await _genrePreference.save(genre);
  }

  Future<void> _selectSort(MovieSort sort) async {
    setState(() => _selectedSort = sort);
    await _sortPreference.save(sort);
  }

  List<Movie> _filter(List<Movie> movies, String genre) {
    if (genre == GenrePreference.allGenre) return movies;
    return movies.where((movie) => movie.genres.contains(genre)).toList();
  }

  String _errorMessage(Object? error) {
    if (error is TimeoutException) return MovieListError.timeoutMessage;
    return MovieListError.defaultMessage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          FutureBuilder<MovieListInitialData>(
            future: _initialDataFuture,
            builder: (context, snapshot) {
              final sort =
                  _selectedSort ??
                  snapshot.data?.selectedSort ??
                  SortPreference.defaultSort;
              return _SortMenuButton(
                selectedSort: sort,
                enabled: snapshot.hasData,
                onSelected: _selectSort,
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<MovieListInitialData>(
        future: _initialDataFuture,
        builder: (context, snapshot) {
          final isWaiting = snapshot.connectionState == ConnectionState.waiting;

          if (isWaiting && !snapshot.hasData) {
            return const MovieListLoading();
          }

          if (snapshot.hasError) {
            return MovieListError(
              message: _errorMessage(snapshot.error),
              onRetry: _retry,
            );
          }

          final data = snapshot.data;
          if (data == null) return const MovieListEmpty();

          final selectedGenre = _selectedGenre ?? data.selectedGenre;
          final selectedSort = _selectedSort ?? data.selectedSort;
          final visibleMovies = selectedSort.apply(
            _filter(data.movies, selectedGenre),
          );

          return Column(
            children: [
              GenreChipBar(
                genres: _genres,
                selectedGenre: selectedGenre,
                onSelected: _selectGenre,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.violet,
                  onRefresh: _refresh,
                  child: visibleMovies.isEmpty
                      ? const _ScrollableEmpty()
                      : MovieGrid(
                          movies: visibleMovies,
                          onMovieTap: (movie) =>
                              context.push('/movies/${movie.id}'),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SortMenuButton extends StatelessWidget {
  const _SortMenuButton({
    required this.selectedSort,
    required this.enabled,
    required this.onSelected,
  });

  final MovieSort selectedSort;
  final bool enabled;
  final ValueChanged<MovieSort> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<MovieSort>(
      tooltip: '정렬',
      enabled: enabled,
      icon: const Icon(Icons.sort),
      initialValue: selectedSort,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final sort in MovieSort.values)
          CheckedPopupMenuItem(
            value: sort,
            checked: sort == selectedSort,
            child: Text(sort.label),
          ),
      ],
    );
  }
}

class _ScrollableEmpty extends StatelessWidget {
  const _ScrollableEmpty();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: const MovieListEmpty(),
          ),
        );
      },
    );
  }
}
