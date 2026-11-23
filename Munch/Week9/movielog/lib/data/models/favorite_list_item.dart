import 'favorite_response_dto.dart';
import 'tmdb_movie_dto.dart';

class FavoriteListItem {
  const FavoriteListItem({
    required this.favorite,
    this.movie,
    this.isRetrying = false,
  });

  final FavoriteResponseDto favorite;
  final TmdbMovieDto? movie;
  final bool isRetrying;

  bool get hasMovie => movie != null;

  FavoriteListItem copyWith({TmdbMovieDto? movie, bool? isRetrying}) {
    return FavoriteListItem(
      favorite: favorite,
      movie: movie ?? this.movie,
      isRetrying: isRetrying ?? this.isRetrying,
    );
  }
}
