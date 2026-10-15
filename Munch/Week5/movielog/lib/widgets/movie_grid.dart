import 'package:flutter/material.dart';

import '../data/models/tmdb_movie_dto.dart';
import 'movie_card.dart';

class MovieGrid extends StatelessWidget {
  const MovieGrid({
    super.key,
    required this.movies,
    required this.onMovieTap,
    this.genreNames = const {},
  });

  static const padding = EdgeInsets.fromLTRB(24, 8, 24, 24);
  static const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: 12,
    mainAxisSpacing: 20,
    childAspectRatio: 0.55,
  );

  final List<TmdbMovieDto> movies;
  final ValueChanged<TmdbMovieDto> onMovieTap;
  final Map<int, String> genreNames;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: movies.length,
      gridDelegate: gridDelegate,
      itemBuilder: (context, index) {
        final movie = movies[index];
        return MovieCard(
          key: ValueKey(movie.id),
          movie: movie,
          genreNames: genreNames,
          onTap: () => onMovieTap(movie),
        );
      },
    );
  }
}
