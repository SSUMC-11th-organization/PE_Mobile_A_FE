import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../models/movie_detail_args.dart';
import '../theme/app_colors.dart';
import '../utils/tmdb_movie_format.dart';
import 'tmdb_poster_image.dart';

/// 영화 목록(2열 Grid)에서 사용하는 카드.
class MovieCard extends StatelessWidget {
  const MovieCard({super.key, required this.movie, this.genreNames = const []});

  final TmdbMovieDto movie;
  final List<String> genreNames;

  String get _caption {
    final year = movie.releaseYear;
    return [
      if (year != null) '$year',
      if (genreNames.isNotEmpty) genreNames.first,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 배열 index가 아니라 TMDB id를 경로에 담는다.
      onTap: () => context.push(
        '/movies/${movie.id}',
        extra: MovieDetailArgs(movie: movie, genreNames: genreNames),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TmdbPosterImage(posterPath: movie.posterPath),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _RatingBadge(label: movie.ratingLabel),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
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
          Opacity(
            opacity: 0.8,
            child: Text(
              _caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                height: 24 / 16,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC322F35),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '★ $label',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 16 / 12,
            color: Color(0xFFF5EFF7),
          ),
        ),
      ),
    );
  }
}
