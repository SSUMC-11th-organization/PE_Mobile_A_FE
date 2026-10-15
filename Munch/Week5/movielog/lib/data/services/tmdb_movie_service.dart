import 'package:dio/dio.dart';

import '../models/tmdb_genre_dto.dart';
import '../models/tmdb_movie_page_dto.dart';

/// TMDB HTTP 요청과 DTO 변환만 담당한다. 상태가 없어 여러 ViewModel이 공유한다.
/// "인기 5개", "최대 30개", "선택된 장르" 같은 화면 정책은 ViewModel의 책임이다.
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

  /// [genreIds]가 비어 있거나 null이면 `with_genres`를 보내지 않는다(전체).
  /// 여러 개면 OR(`|`)로 연결한다.
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
