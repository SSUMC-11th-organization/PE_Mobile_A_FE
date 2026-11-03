import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/movie_format.dart';
import 'tmdb_poster_image.dart';

// 홈과 영화 목록에서 함께 쓰는 영화 카드입니다. 누르면 상세 Route로 push 합니다.
class MovieCard extends StatelessWidget {
  const MovieCard({super.key, required this.movie});

  final TmdbMovieDto movie;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 목록 index가 아니라 TMDB id로 이동하고, 이미 받은 영화 정보는 extra로 함께 넘깁니다.
      onTap: () => context.push('/movies/${movie.id}', extra: movie),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: TmdbPosterImage(
                posterPath: movie.posterPath,
                width: double.infinity,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            movie.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            movieMetaLabel(movie),
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray),
          ),
        ],
      ),
    );
  }
}
