import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/movie_home_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/home_hero_card.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';
import '../widgets/tmdb_movie_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: 'MovieLog',
        titleStyle: AppTextStyles.titleMedium.copyWith(
          color: AppColors.violet,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search, color: AppColors.violet),
          ),
        ],
      ),
      // 상태가 바뀔 때 이 영역만 다시 그린다
      body: Consumer<MovieHomeViewModel>(
        builder: (context, viewModel, child) {
          return switch (viewModel.status) {
            MovieHomeLoadStatus.idle ||
            MovieHomeLoadStatus.loading =>
              const MovieListLoading(),
            MovieHomeLoadStatus.error => MovieListError(
                message: viewModel.message,
                // 버튼을 누를 때 한 번만 호출하므로 read
                onRetry: () => context.read<MovieHomeViewModel>().loadPopular(),
              ),
            MovieHomeLoadStatus.empty =>
              const MovieListEmpty(message: '인기 영화가 아직 없어요.'),
            MovieHomeLoadStatus.success =>
              _HomeContent(movies: viewModel.popularMovies),
          };
        },
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.movies});

  final List<TmdbMovieDto> movies;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘은 어떤\n영화를 볼까요?',
            style: AppTextStyles.titleLarge,
          ),
          const SizedBox(height: 16),
          // 성공 상태에서는 영화가 1개 이상이라 first를 써도 안전하다
          HomeHeroCard(movie: movies.first),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('인기 영화', style: AppTextStyles.titleMedium),
              TextButton(
                onPressed: () => context.go('/movies'),
                child: Text(
                  '전체보기 >',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.violet,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final movie = movies[index];
                return SizedBox(
                  width: 130,
                  child: TmdbMovieCard(
                    movie: movie,
                    rank: index + 1,
                    subtitle: '★ ${movie.voteAverage.toStringAsFixed(1)}',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}