import 'rating_dto.dart';
import 'tmdb_movie_dto.dart';

/// 우리 백엔드의 평점과 TMDB 영화 정보를 한 쌍으로 묶는다.
class RatingWithMovie {
  const RatingWithMovie({required this.rating, this.movie});

  final RatingDto rating;

  /// TMDB에서 찾지 못했으면 null이다. 이때도 평점은 그대로 보여준다.
  final TmdbMovieDto? movie;
}
