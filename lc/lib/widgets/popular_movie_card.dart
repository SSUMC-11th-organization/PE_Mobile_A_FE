import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../models/movie_detail_args.dart';
import '../theme/app_colors.dart';
import '../utils/tmdb_movie_format.dart';
import 'tmdb_poster_image.dart';

/// 홈의 '인기 영화' 가로 목록 카드 (순위 배지 + 별점).
class PopularMovieCard extends StatelessWidget {
  const PopularMovieCard({
    super.key,
    required this.movie,
    required this.rank,
    this.genreNames = const [],
  });

  final TmdbMovieDto movie;
  final int rank;
  final List<String> genreNames;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(
        '/movies/${movie.id}',
        extra: MovieDetailArgs(movie: movie, genreNames: genreNames),
      ),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PosterBox(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TmdbPosterImage(posterPath: movie.posterPath),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0x99000000),
                        border: Border.all(color: const Color(0x1AFFFFFF)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 16 / 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              movie.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 24 / 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star, size: 12, color: AppColors.star),
                const SizedBox(width: 4),
                Text(
                  movie.ratingLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 홈의 '인기 영화' 목록 마지막에 붙는 개봉 예정작 자리표시 카드. (Figma의 정적 요소)
class UpcomingMovieCard extends StatelessWidget {
  const UpcomingMovieCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PosterBox(
            child: ColoredBox(
              color: AppColors.upcomingBackground,
              child: Center(
                child: Icon(
                  Icons.movie_creation_outlined,
                  size: 28,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '개봉 예정작',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 24 / 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'D-5',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 16 / 12,
              color: AppColors.violetNumber,
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterBox extends StatelessWidget {
  const _PosterBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(width: 140, height: 200, child: child),
      ),
    );
  }
}
