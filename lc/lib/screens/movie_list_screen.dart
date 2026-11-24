import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../view_models/paged_movies_view_model.dart';
import '../widgets/genre_filter_chips.dart';
import '../widgets/paged_movie_body.dart';

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
            onPressed: () => context.push('/movies/search'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<PagedMoviesViewModel>(
        builder: (context, viewModel, child) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                if (viewModel.genres.isNotEmpty) ...[
                  GenreFilterChips(
                    genres: viewModel.genres,
                    selectedGenreId: viewModel.selectedGenreId,
                    enabled: !viewModel.isInitialLoading,
                    onSelected: viewModel.selectGenre,
                  ),
                  const SizedBox(height: 8),
                ],
                Expanded(child: PagedMovieBody(viewModel: viewModel)),
              ],
            ),
          );
        },
      ),
    );
  }
}
