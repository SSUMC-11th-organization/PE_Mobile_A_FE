import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../models/movie_detail_args.dart';
import '../theme/app_colors.dart';
import '../utils/tmdb_movie_format.dart';
import 'tmdb_poster_image.dart';

class HeroBanner extends StatelessWidget {
  const HeroBanner({
    super.key,
    required this.movie,
    this.genreNames = const [],
  });

  final TmdbMovieDto movie;
  final List<String> genreNames;

  static const _shadows = [
    Shadow(color: Color(0x0F000000), offset: Offset(0, 2), blurRadius: 1),
    Shadow(color: Color(0x12000000), offset: Offset(0, 4), blurRadius: 1.5),
  ];

  String get _subtitle {
    final year = movie.releaseYear;
    final parts = [...genreNames.take(2), if (year != null) '$year'];
    return parts.isEmpty ? '★ ${movie.ratingLabel}' : parts.join(' · ');
  }

  void _openDetail(BuildContext context) => context.push(
    '/movies/${movie.id}',
    extra: MovieDetailArgs(movie: movie, genreNames: genreNames),
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openDetail(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TmdbPosterImage(posterPath: movie.posterPath),
              const ColoredBox(color: Color(0xB3000000)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xE64F378A),
                          border: Border.all(color: const Color(0x33FFFFFF)),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 8,
                          ),
                          child: Text(
                            '추천 신작',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 16 / 12,
                              letterSpacing: 0.6,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        movie.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                          height: 36 / 28,
                          color: Colors.white,
                          shadows: _shadows,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Opacity(
                        opacity: 0.9,
                        child: Text(
                          _subtitle,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 24 / 16,
                            color: Color(0xFFF8F2FA),
                            shadows: _shadows,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _openDetail(context),
                          icon: const Icon(Icons.info, size: 17),
                          label: const Text('상세보기'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.violetNumber,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shadowColor: const Color(0x33000000),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              height: 24 / 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
