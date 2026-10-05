import 'package:flutter/material.dart';

import '../models/movie.dart';
import 'movie_card.dart';

class MovieGrid extends StatelessWidget {
  const MovieGrid({super.key, required this.movies, required this.onMovieTap});

  static const padding = EdgeInsets.fromLTRB(24, 8, 24, 24);
  static const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: 12,
    mainAxisSpacing: 20,
    childAspectRatio: 0.55,
  );

  final List<Movie> movies;
  final ValueChanged<Movie> onMovieTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: movies.length,
      gridDelegate: gridDelegate,
      itemBuilder: (context, index) {
        final movie = movies[index];
        return MovieCard(movie: movie, onTap: () => onMovieTap(movie));
      },
    );
  }
}
