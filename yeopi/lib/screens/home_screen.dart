import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_text_styles.dart';
import '../view_models/movie_home_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/featured_movie_banner.dart';
import '../widgets/movie_card.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: 'MovieLog'),
      // 상태가 바뀌면 AppBar는 두고 Consumer 아래 본문만 다시 그립니다.
      body: Consumer<MovieHomeViewModel>(
        builder: (context, viewModel, child) => switch (viewModel.status) {
          MovieHomeLoadStatus.idle || MovieHomeLoadStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          MovieHomeLoadStatus.error => _centered(
            MovieListError(
              message: viewModel.message ?? '인기 영화를 불러오지 못했어요.',
              onRetry: () => context.read<MovieHomeViewModel>().loadPopular(),
            ),
          ),
          MovieHomeLoadStatus.empty => _centered(
            MovieListEmpty(
              message: '지금 보여줄 인기 영화가 없어요.',
              actionLabel: '새로고침',
              onAction: () => context.read<MovieHomeViewModel>().loadPopular(),
            ),
          ),
          MovieHomeLoadStatus.success => _PopularMovies(
            movies: viewModel.popularMovies,
          ),
        },
      ),
    );
  }

  Widget _centered(Widget child) {
    return Center(
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    );
  }
}

class _PopularMovies extends StatelessWidget {
  const _PopularMovies({required this.movies});

  final List<TmdbMovieDto> movies;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FeaturedMovieBanner(movie: movies.first),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('지금 인기 있는 영화', style: AppTextStyles.titleMedium),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: movies.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                SizedBox(width: 130, child: MovieCard(movie: movies[index])),
          ),
        ),
      ],
    );
  }
}
