import 'package:dio/dio.dart';
import '../models/tmdb_genre_dto.dart';
import '../models/tmdb_movie_page.dart';

class TmdbMovieService {
  TmdbMovieService(this._dio);

  final Dio _dio;

  /// 인기순 영화 목록 (page 기본값 1)
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    final response = await _dio.get(
      '/movie/popular',
      queryParameters: {'language': 'ko-KR', 'page': page},
    );

    return TmdbMoviePageDto.fromJson(response.data as Map<String, dynamic>);
  }

  /// 영화 탐색. genreId가 null이면 장르 조건 없이 전체를 조회한다.
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
        // genreId가 null이면 이 항목 자체를 넣지 않는다
        'with_genres': ?genreId,
      },
    );

    return TmdbMoviePageDto.fromJson(response.data as Map<String, dynamic>);
  }

  /// TMDB 공식 영화 장르 목록
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