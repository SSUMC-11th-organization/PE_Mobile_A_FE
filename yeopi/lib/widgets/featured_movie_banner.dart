import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/movie.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

// 홈 상단의 대표 영화 배너입니다. 영화 카드와 같은 상세 Route로 이동합니다.
class FeaturedMovieBanner extends StatelessWidget {
  const FeaturedMovieBanner({super.key, required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/movies/${movie.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(movie.posterAsset, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '오늘의 추천',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.violetDisabled,
                      ),
                    ),
                    Text(
                      movie.title,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                    Text(
                      '${movie.genre} · ${movie.year}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.white,
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
