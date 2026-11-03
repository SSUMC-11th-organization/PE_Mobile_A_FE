import 'package:dio/dio.dart';

import '../models/tmdb_genre_dto.dart';
import '../models/tmdb_movie_page.dart';

/// HTTP 요청과 DTO 변환만 담당한다. 상태를 갖지 않으므로 여러 ViewModel이 하나를 공유한다.
/// '인기 5개', '최대 30개' 같은 화면별 정책은 ViewModel의 책임이다.
class TmdbMovieService {
  TmdbMovieService(this._dio);

  final Dio _dio;

  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    final response = await _dio.get(
      '/movie/popular',
      queryParameters: {'language': 'ko-KR', 'page': page},
    );
    return TmdbMoviePageDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    int? genreId,
  }) async {
    final response = await _dio.get(
      '/discover/movie',
      queryParameters: {
        'language': 'ko-KR',
        'page': page,
        'sort_by': 'popularity.desc',
        'include_adult': false,
        'include_video': false,
        // 장르를 고르지 않았을 때는 with_genres 자체를 보내지 않는다.
        'with_genres': ?genreId,
      },
    );
    return TmdbMoviePageDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<TmdbGenreDto>> fetchGenres() async {
    final response = await _dio.get(
      '/genre/movie/list',
      queryParameters: {'language': 'ko'},
    );
    final data = response.data as Map<String, dynamic>;
    final genres = data['genres'] as List<dynamic>? ?? const [];
    return genres
        .map((item) => TmdbGenreDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
