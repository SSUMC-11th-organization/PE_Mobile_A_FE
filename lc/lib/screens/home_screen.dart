import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../view_models/movie_home_view_model.dart';
import '../widgets/hero_banner.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';
import '../widgets/popular_movie_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 16,
        title: const Text(
          'MovieLog',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 28 / 22,
            letterSpacing: -0.55,
            color: AppColors.violetNumber,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '검색',
            icon: const Icon(Icons.search, size: 22),
            color: AppColors.violetNumber,
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      // 상태가 바뀔 때 이 영역만 다시 그린다.
      body: Consumer<MovieHomeViewModel>(
        builder: (context, viewModel, child) {
          return switch (viewModel.status) {
            MovieHomeLoadStatus.idle ||
            MovieHomeLoadStatus.loading => const MovieListLoading(),
            MovieHomeLoadStatus.error => MovieListError(
              message: viewModel.message,
              onRetry: viewModel.loadPopular,
            ),
            MovieHomeLoadStatus.empty => const MovieListEmpty(
              title: '인기 영화를 찾지 못했어요.',
              description: '잠시 후 다시 확인해 주세요.',
            ),
            MovieHomeLoadStatus.success => _HomeContent(viewModel: viewModel),
          };
        },
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.viewModel});

  final MovieHomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final popular = viewModel.popularMovies;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '오늘은 어떤\n영화를 볼까요?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                height: 36 / 28,
                letterSpacing: -0.7,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: HeroBanner(
              movie: popular.first,
              genreNames: viewModel.genreNamesOf(popular.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '인기 영화',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    height: 28 / 22,
                    color: AppColors.textPrimary,
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.go('/movies'),
                  child: const Row(
                    children: [
                      Text(
                        '전체보기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 24 / 16,
                          color: AppColors.violetNumber,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.violetNumber,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 264,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: popular.length + 1,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) => index == popular.length
                  ? const UpcomingMovieCard()
                  : PopularMovieCard(
                      movie: popular[index],
                      rank: index + 1,
                      genreNames: viewModel.genreNamesOf(popular[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
