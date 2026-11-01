import 'package:flutter/material.dart';
import '../data/models/tmdb_movie_dto.dart';
import 'tmdb_movie_card.dart';

class MovieGrid extends StatelessWidget {
  const MovieGrid({super.key, required this.movies});

  final List<TmdbMovieDto> movies;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: movies.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.62,
      ),
      itemBuilder: (context, index) {
        final movie = movies[index];
        return TmdbMovieCard(
          movie: movie,
          showRatingBadge: true,
          // 출시 연도가 없으면 표시하지 않는다
          subtitle: movie.releaseYear ?? '',
        );
      },
    );
  }
}