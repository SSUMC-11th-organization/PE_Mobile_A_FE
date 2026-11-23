import 'favorite_response_dto.dart';
import 'rating_dto.dart';

class MovieRecordRequest {
  const MovieRecordRequest({
    required this.movieId,
    required this.score,
    required this.addToFavorites,
    this.comment,
  });

  final int movieId;
  final int score;
  final String? comment;
  final bool addToFavorites;

  Map<String, dynamic> toJson() => {
    'movieId': movieId,
    'score': score,
    if (comment != null && comment!.trim().isNotEmpty)
      'comment': comment!.trim(),
    'addToFavorites': addToFavorites,
  };
}

class MovieRecordResponse {
  const MovieRecordResponse({required this.rating, this.favorite});

  // addToFavorites가 false면 favorite은 null이 정상이다.
  factory MovieRecordResponse.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('MovieRecordResponse must be a JSON object.');
    }
    final favorite = json['favorite'];
    return MovieRecordResponse(
      rating: RatingDto.fromJson(json['rating'] as Map<String, dynamic>),
      favorite: favorite == null
          ? null
          : FavoriteResponseDto.fromJson(favorite),
    );
  }

  final RatingDto rating;
  final FavoriteResponseDto? favorite;
}
