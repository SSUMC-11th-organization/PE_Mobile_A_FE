import 'favorite_response_dto.dart';
import 'rating_dto.dart';

/// POST /v8/movie-records 요청. 평점과 즐겨찾기를 한 번에 저장한다.
class MovieRecordRequest {
  const MovieRecordRequest({
    required this.movieId,
    required this.score,
    this.comment,
    required this.addToFavorites,
  });

  final int movieId;
  final int score;
  final String? comment;
  final bool addToFavorites;

  Map<String, Object?> toJson() => {
    'movieId': movieId,
    'score': score,
    if (comment != null) 'comment': comment,
    'addToFavorites': addToFavorites,
  };
}

/// 응답 result. addToFavorites가 false였다면 favorite은 null이 정상이다.
class MovieRecordResult {
  const MovieRecordResult({required this.rating, this.favorite});

  factory MovieRecordResult.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('MovieRecordResult must be a JSON object.');
    }
    final favorite = json['favorite'];
    return MovieRecordResult(
      rating: RatingDto.fromJson(json['rating'] as Map<String, dynamic>),
      favorite: favorite == null
          ? null
          : FavoriteResponseDto.fromJson(favorite),
    );
  }

  final RatingDto rating;
  final FavoriteResponseDto? favorite;
}
