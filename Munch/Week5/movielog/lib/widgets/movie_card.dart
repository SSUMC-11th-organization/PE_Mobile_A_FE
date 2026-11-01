import 'package:flutter/material.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'tmdb_poster_image.dart';

/// `release_date`가 없거나 형식이 맞지 않으면 null을 반환해 연도를 표시하지 않는다.
String? releaseYearOf(String? releaseDate) {
  if (releaseDate == null || releaseDate.length < 4) return null;
  final year = releaseDate.substring(0, 4);
  return int.tryParse(year) == null ? null : year;
}

class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.movie,
    required this.onTap,
    this.genreNames = const {},
  });

  final TmdbMovieDto movie;
  final VoidCallback onTap;
  final Map<int, String> genreNames;

  String get _subtitle {
    final year = releaseYearOf(movie.releaseDate);
    final genre = movie.genreIds
        .map((id) => genreNames[id])
        .whereType<String>()
        .firstOrNull;
    return [?year, ?genre].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitle;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
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
                    child: RatingBadge(rating: movie.voteAverage),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            movie.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleMedium.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(fontSize: 14, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 14, color: AppColors.white),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}
