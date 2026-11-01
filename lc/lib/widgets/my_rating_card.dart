import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../data/models/rating_with_movie.dart';
import '../theme/app_colors.dart';
import 'tmdb_poster_image.dart';

/// 백엔드 평점 한 건과 TMDB 영화 정보를 함께 보여주는 카드.
/// 영화 정보를 찾지 못해도(movie == null) 평점·후기·등록일은 그대로 보여준다.
class MyRatingCard extends StatelessWidget {
  const MyRatingCard({super.key, required this.entry});

  final RatingWithMovie entry;

  @override
  Widget build(BuildContext context) {
    final rating = entry.rating;
    final movie = entry.movie;
    final comment = rating.comment?.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.violetback,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.violetBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            // posterPath가 null이거나 영화 자체를 못 찾으면 TmdbPosterImage가 placeholder를 그린다.
            child: TmdbPosterImage(
              posterPath: movie?.posterPath,
              width: 64,
              height: 96,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie?.title ?? '영화 정보를 불러오지 못했어요',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 24 / 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (movie == null)
                  Text(
                    'TMDB 영화 #${rating.movieId}',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    RatingBarIndicator(
                      rating: rating.score.toDouble(),
                      itemCount: 5,
                      itemSize: 18,
                      unratedColor: const Color(0xFFDDD8E8),
                      itemBuilder: (context, index) => const Icon(
                        Icons.star_rounded,
                        color: AppColors.violet,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${rating.score}점',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 20 / 14,
                        color: AppColors.violet,
                      ),
                    ),
                  ],
                ),
                // 후기가 없으면(null) 아예 그리지 않는다.
                if (comment != null && comment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    comment,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _formatDate(rating.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}.$month.$day 등록';
  }
}
