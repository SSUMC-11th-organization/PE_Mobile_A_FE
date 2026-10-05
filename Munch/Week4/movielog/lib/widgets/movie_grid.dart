import 'package:flutter/material.dart';

import '../models/movie.dart';
import 'movie_card.dart';

class MovieGrid extends StatelessWidget {
  const MovieGrid({super.key, required this.movies, required this.onMovieTap});

  final List<Movie> movies;
  final ValueChanged<Movie> onMovieTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      itemCount: movies.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 20,
        childAspectRatio: 0.55,
      ),
      itemBuilder: (context, index) {
        final movie = movies[index];
        return MovieCard(movie: movie, onTap: () => onMovieTap(movie));
      },
    );
  }
}
