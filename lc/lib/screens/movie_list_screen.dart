import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../view_models/movie_list_view_model.dart';
import '../widgets/genre_filter_chips.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';

class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 16,
        title: const Text('영화'),
        actions: [
          IconButton(
            tooltip: '검색',
            icon: const Icon(Icons.search, size: 22),
            color: AppColors.textSecondary,
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<MovieListViewModel>(
        builder: (context, viewModel, child) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                if (viewModel.genres.isNotEmpty) ...[
                  GenreFilterChips(
                    genres: viewModel.genres,
                    selectedGenreId: viewModel.selectedGenreId,
                    // 요청 중에는 장르를 바꾸지 못하게 한다.
                    enabled: !viewModel.isLoading,
                    onSelected: viewModel.selectGenre,
                  ),
                  const SizedBox(height: 8),
                ],
                Expanded(child: _MovieListBody(viewModel: viewModel)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MovieListBody extends StatelessWidget {
  const _MovieListBody({required this.viewModel});

  final MovieListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return switch (viewModel.status) {
      MovieListLoadStatus.idle ||
      MovieListLoadStatus.loading => const MovieListLoading(),
      MovieListLoadStatus.error => MovieListError(
        message: viewModel.message,
        onRetry: viewModel.retry,
      ),
      MovieListLoadStatus.empty => const MovieListEmpty(),
      MovieListLoadStatus.success => MovieGrid(
        movies: viewModel.movies,
        genreNames: viewModel.genreNames,
      ),
    };
  }
}
