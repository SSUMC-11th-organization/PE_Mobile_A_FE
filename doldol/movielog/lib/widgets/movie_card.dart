import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/movie_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'movie_poster.dart';

class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.movie,
    required this.subtitle,
    this.rank,
    this.showRatingBadge = false,
  });

  final Movie movie;
  final String subtitle;
  final int? rank; // 홈 인기 영화의 순위 배지
  final bool showRatingBadge; // 목록의 별점 배지

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/movies/${movie.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: MoviePoster(asset: movie.posterAsset),
                  ),
                ),
                if (rank != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _Badge(text: '$rank'),
                  ),
                if (showRatingBadge)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _Badge(text: '★ ${movie.rating}'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            movie.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleMedium.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.scrim,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppTextStyles.label.copyWith(
          color: AppColors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}