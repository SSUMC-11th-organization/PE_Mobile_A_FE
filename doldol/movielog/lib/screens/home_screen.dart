import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/movie_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/home_hero_card.dart';
import '../widgets/movie_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final popular = popularMovies;

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '오늘은 어떤\n영화를 볼까요?',
              style: AppTextStyles.titleLarge,
            ),
            const SizedBox(height: 16),
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
                itemCount: popular.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final movie = popular[index];
                  return SizedBox(
                    width: 130,
                    child: MovieCard(
                      movie: movie,
                      rank: index + 1,
                      subtitle: '★ ${movie.rating}',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}