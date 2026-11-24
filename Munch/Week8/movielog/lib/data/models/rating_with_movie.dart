import 'rating_dto.dart';
import 'tmdb_movie_dto.dart';

class RatingWithMovie {
  const RatingWithMovie({required this.rating, this.movie});

  final RatingDto rating;

  // TMDB에서 찾지 못했거나 조회에 실패하면 null
  final TmdbMovieDto? movie;
}
