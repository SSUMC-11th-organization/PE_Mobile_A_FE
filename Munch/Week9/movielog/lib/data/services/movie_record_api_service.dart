import 'package:dio/dio.dart';

import '../models/common_response.dart';
import '../models/movie_record_models.dart';

// 평점과 즐겨찾기를 서버 한 트랜잭션으로 저장한다(보호용 Dio 사용).
class MovieRecordApiService {
  MovieRecordApiService(this._dio);

  final Dio _dio;

  Future<MovieRecordResponse> saveRecord(MovieRecordRequest request) async {
    final response = await _dio.post(
      '/v8/movie-records',
      data: request.toJson(),
    );
    final body = CommonResponse<MovieRecordResponse>.fromJson(
      response.data as Map<String, dynamic>,
      MovieRecordResponse.fromJson,
    );
    return body.result!;
  }
}
