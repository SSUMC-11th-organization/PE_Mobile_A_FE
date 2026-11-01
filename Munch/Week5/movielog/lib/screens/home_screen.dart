import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/movie_home_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_card.dart';
import '../widgets/movie_card_skeleton.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/tmdb_poster_image.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static void _openDetail(BuildContext context, TmdbMovieDto movie) {
    context.push(
      AppRouter.movieDetailLocation(movie.id),
      extra: MovieDetailArgs(movie: movie),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: 'MovieLog',
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Text(
            '오늘은 어떤\n영화를 볼까요?',
            style: AppTextStyles.titleLarge.copyWith(fontSize: 28, height: 1.3),
          ),
          const SizedBox(height: 24),
          // 상태가 바뀌면 인기 영화 영역만 다시 그린다.
          Consumer<MovieHomeViewModel>(
            builder: (context, viewModel, child) {
              return switch (viewModel.status) {
                MovieHomeLoadStatus.idle ||
                MovieHomeLoadStatus.loading => const _PopularLoading(),
                MovieHomeLoadStatus.error => SizedBox(
                  height: 320,
                  child: MovieListError(
                    message: viewModel.message ?? MovieListError.defaultMessage,
                    onRetry: () =>
                        context.read<MovieHomeViewModel>().loadPopular(),
                  ),
                ),
                MovieHomeLoadStatus.empty => const SizedBox(
                  height: 320,
                  child: MovieListEmpty(message: '인기 영화가 아직 없어요.'),
                ),
                MovieHomeLoadStatus.success => _PopularContent(
                  movies: viewModel.popularMovies,
                  onMovieTap: (movie) => _openDetail(context, movie),
                ),
              };
            },
          ),
        ],
      ),
    );
  }
}

class _PopularContent extends StatelessWidget {
  const _PopularContent({required this.movies, required this.onMovieTap});

  final List<TmdbMovieDto> movies;
  final ValueChanged<TmdbMovieDto> onMovieTap;

  @override
  Widget build(BuildContext context) {
    final featured = movies.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FeaturedMovieCard(movie: featured, onTap: () => onMovieTap(featured)),
        const SizedBox(height: 32),
        _SectionHeader(
          title: '인기 영화',
          onMore: () => StatefulNavigationShell.of(context).goBranch(1),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 290,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: movies.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final movie = movies[index];
              return SizedBox(
                width: 150,
                child: PopularMovieCard(
                  key: ValueKey(movie.id),
                  rank: index + 1,
                  movie: movie,
                  onTap: () => onMovieTap(movie),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PopularLoading extends StatelessWidget {
  const _PopularLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AspectRatio(aspectRatio: 0.68, child: SkeletonBox(radius: 28)),
        const SizedBox(height: 32),
        const SkeletonBox(width: 120, height: 26),
        const SizedBox(height: 16),
        SizedBox(
          height: 290,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: MovieHomeViewModel.popularCount,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                const SizedBox(width: 150, child: MovieCardSkeleton()),
          ),
        ),
      ],
    );
  }
}

class FeaturedMovieCard extends StatelessWidget {
  const FeaturedMovieCard({
    super.key,
    required this.movie,
    required this.onTap,
  });

  final TmdbMovieDto movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final year = releaseYearOf(movie.releaseDate);
    final info = [?year, '★ ${movie.voteAverage.toStringAsFixed(1)}'];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 0.68,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              TmdbPosterImage(posterPath: movie.posterPath, size: 'w780'),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.4, 1],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.violet.withValues(alpha: 0.7),
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '오늘의 인기 1위',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info.join(' · '),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.info),
                      label: const Text(
                        '상세보기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.violet,
                        foregroundColor: AppColors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PopularMovieCard extends StatelessWidget {
  const PopularMovieCard({
    super.key,
    required this.rank,
    required this.movie,
    required this.onTap,
  });

  final int rank;
  final TmdbMovieDto movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TmdbPosterImage(posterPath: movie.posterPath),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            movie.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleMedium.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.star, size: 16, color: Color(0xFFE0A526)),
              const SizedBox(width: 4),
              Text(
                movie.voteAverage.toStringAsFixed(1),
                style: AppTextStyles.bodyMedium.copyWith(fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onMore});

  final String title;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTextStyles.titleLarge.copyWith(fontSize: 22)),
        const Spacer(),
        TextButton(
          onPressed: onMore,
          style: TextButton.styleFrom(foregroundColor: AppColors.violet),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('전체보기', style: TextStyle(fontSize: 16)),
              Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ],
    );
  }
}
