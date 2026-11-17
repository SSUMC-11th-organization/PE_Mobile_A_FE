import 'rating_dto.dart';
import 'tmdb_movie_dto.dart';

// 평점은 자체 백엔드가 주인이라, TMDB에서 영화를 찾지 못해도(movie == null) 평점은 그대로 남깁니다.
class RatingWithMovie {
  const RatingWithMovie({required this.rating, this.movie});

  final RatingDto rating;
  final TmdbMovieDto? movie;
}
