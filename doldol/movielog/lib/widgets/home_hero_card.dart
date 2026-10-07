import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/movie_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'movie_poster.dart';

class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard({super.key, required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 0.75,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MoviePoster(asset: movie.posterAsset),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.clear, AppColors.scrim],
                  stops: [0.5, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.violet,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '추천 신작',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    movie.title,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${movie.year} · ${movie.genre} · ${movie.runtime}분',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/movies/${movie.id}'),
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('상세보기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepViolet,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}