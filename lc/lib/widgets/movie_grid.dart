import 'package:flutter/material.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../utils/tmdb_movie_format.dart';
import 'movie_card.dart';

class MovieGrid extends StatelessWidget {
  const MovieGrid({
    super.key,
    required this.movies,
    this.genreNames = const {},
  });

  final List<TmdbMovieDto> movies;

  /// 장르 id → 이름. 카드에 장르 이름을 보여주는 데 쓴다.
  final Map<int, String> genreNames;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: movies.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 24,
        mainAxisExtent: 316.5,
      ),
      itemBuilder: (context, index) {
        final movie = movies[index];
        return MovieCard(
          movie: movie,
          genreNames: movie.genreNamesIn(genreNames),
        );
      },
    );
  }
}
