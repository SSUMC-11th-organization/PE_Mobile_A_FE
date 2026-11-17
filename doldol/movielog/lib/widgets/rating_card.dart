import 'package:flutter/material.dart';
import '../data/models/rating_with_movie.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'tmdb_poster_image.dart';

class RatingCard extends StatelessWidget {
  const RatingCard({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final RatingWithMovie entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const double _posterWidth = 88;
  static const double _posterHeight = 132;

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}.$month.$day';
  }

  @override
  Widget build(BuildContext context) {
    final rating = entry.rating;
    final movie = entry.movie; // TMDB에서 못 찾으면 null
    final comment = rating.comment;
    final bodyStyle = AppTextStyles.bodyMedium.copyWith(fontSize: 14);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.disabledViolet, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: movie == null
                ? Container(
                    width: _posterWidth,
                    height: _posterHeight,
                    color: AppColors.starEmpty,
                  )
                : TmdbPosterImage(
                    posterPath: movie.posterPath,
                    width: _posterWidth,
                    height: _posterHeight,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie?.title ?? '영화 #${rating.movieId}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '별점 ${rating.score} / 5',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.violet,
                  ),
                ),
                const SizedBox(height: 8),
                if (movie == null) ...[
                  Text('포스터 정보 없음', style: bodyStyle),
                  const SizedBox(height: 4),
                ],
                // 후기가 없으면(null) 표시하지 않는다
                if (comment != null && comment.isNotEmpty) ...[
                  Text(
                    comment,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: bodyStyle,
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  _formatDate(rating.createdAt),
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              _ActionButton(
                label: '수정',
                background: AppColors.lavender,
                foreground: AppColors.deepViolet,
                onPressed: onEdit,
              ),
              const SizedBox(height: 8),
              _ActionButton(
                label: '삭제',
                background: AppColors.errorBg,
                foreground: AppColors.error,
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 32,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}