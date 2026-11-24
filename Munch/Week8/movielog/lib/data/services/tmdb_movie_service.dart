import 'package:dio/dio.dart';

import '../models/tmdb_genre_dto.dart';
import '../models/tmdb_movie_dto.dart';
import '../models/tmdb_movie_page_dto.dart';

class TmdbMovieService {
  TmdbMovieService(this._dio);

  final Dio _dio;

  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/movie/popular',
      queryParameters: {'language': 'ko-KR', 'page': page},
    );
    return TmdbMoviePageDto.fromJson(response.data!);
  }

  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    List<int>? genreIds,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/discover/movie',
      queryParameters: {
        'language': 'ko-KR',
        'page': page,
        'sort_by': 'popularity.desc',
        'include_adult': false,
        'include_video': false,
        if (genreIds != null && genreIds.isNotEmpty)
          'with_genres': genreIds.join('|'),
      },
    );
    return TmdbMoviePageDto.fromJson(response.data!);
  }

  Future<TmdbMovieDto> fetchMovieDetail(int movieId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/movie/$movieId',
      queryParameters: {'language': 'ko-KR'},
    );
    return TmdbMovieDto.fromJson(response.data!);
  }

  // 404만 null로 바꾸고, 그 외 네트워크 오류는 호출한 쪽에서 처리한다.
  Future<TmdbMovieDto?> findMovieById(int movieId) async {
    try {
      return await fetchMovieDetail(movieId);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<TmdbGenreDto>> fetchGenres() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/genre/movie/list',
      queryParameters: {'language': 'ko'},
    );
    final genres = response.data?['genres'] as List<dynamic>? ?? const [];
    return genres
        .map((item) => TmdbGenreDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
