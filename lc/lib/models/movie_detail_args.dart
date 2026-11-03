import '../data/models/tmdb_movie_dto.dart';

/// 상세 화면으로 넘기는 값. 이번 범위에서는 TMDB 상세 API를 쓰지 않으므로
/// 목록이 이미 가진 DTO(와 그 장르 이름)를 그대로 전달한다.
class MovieDetailArgs {
  const MovieDetailArgs({required this.movie, this.genreNames = const []});

  final TmdbMovieDto movie;
  final List<String> genreNames;
}
