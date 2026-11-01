import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/movie_list_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/genre_chip_list.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';

class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        titleStyle: AppTextStyles.titleMedium.copyWith(
          color: AppColors.violet,
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search, color: AppColors.violet),
          ),
        ],
      ),
      // ViewModel 상태가 바뀔 때 이 영역만 다시 그린다
      body: Consumer<MovieListViewModel>(
        builder: (context, viewModel, child) {
          return Column(
            children: [
              const SizedBox(height: 8),
              GenreChipList(
                genres: viewModel.genres,
                selectedGenreId: viewModel.selectedGenreId,
                // 요청 중에는 장르를 바꿀 수 없다
                enabled: !viewModel.isLoading,
                onSelected: (genreId) =>
                    context.read<MovieListViewModel>().selectGenre(genreId),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: switch (viewModel.status) {
                  MovieListLoadStatus.idle ||
                  MovieListLoadStatus.loading =>
                    const MovieListLoading(),
                  MovieListLoadStatus.error => MovieListError(
                      message: viewModel.message,
                      // 지금 선택된 장르 그대로 처음부터 다시 요청
                      onRetry: () => context.read<MovieListViewModel>().retry(),
                    ),
                  MovieListLoadStatus.empty => const MovieListEmpty(),
                  MovieListLoadStatus.success =>
                    _MovieListSuccess(movies: viewModel.movies),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MovieListSuccess extends StatelessWidget {
  const _MovieListSuccess({required this.movies});

  final List<TmdbMovieDto> movies;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('영화 ${movies.length}편', style: AppTextStyles.bodySmall),
        ),
        Expanded(child: MovieGrid(movies: movies)),
      ],
    );
  }
}