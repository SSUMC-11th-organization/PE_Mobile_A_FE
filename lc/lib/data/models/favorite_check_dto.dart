/// 특정 영화의 즐겨찾기 여부 조회 결과.
class FavoriteCheckDto {
  const FavoriteCheckDto({required this.movieId, required this.isFavorite});

  /// 응답 result에는 isFavorite만 있고 movieId가 없다.
  /// 그래서 요청에 사용한 movieId를 factory 인자로 따로 넘겨 받는다.
  factory FavoriteCheckDto.fromJson(Object? json, {required int movieId}) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('FavoriteCheckDto must be a JSON object.');
    }
    if (json['isFavorite'] is! bool) {
      throw const FormatException('isFavorite must be a boolean.');
    }
    return FavoriteCheckDto(
      movieId: movieId,
      isFavorite: json['isFavorite'] as bool,
    );
  }

  final int movieId;
  final bool isFavorite;
}
