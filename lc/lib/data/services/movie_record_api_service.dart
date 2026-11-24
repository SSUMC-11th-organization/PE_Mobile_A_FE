import 'package:dio/dio.dart';

import '../models/common_response.dart';
import '../models/movie_record_models.dart';

/// POST /v8/movie-records. 보호용 Client(JWT Interceptor 포함)를 주입받는다.
/// 서버가 한 트랜잭션으로 처리하므로 평점·즐겨찾기 중 하나라도 실패하면 둘 다 저장되지 않는다.
class MovieRecordApiService {
  MovieRecordApiService(this._dio);

  final Dio _dio;

  Future<MovieRecordResult> createRecord(MovieRecordRequest request) async {
    final response = await _dio.post(
      '/v8/movie-records',
      data: request.toJson(),
    );
    final body = CommonResponse<MovieRecordResult>.fromJson(
      response.data as Map<String, dynamic>,
      MovieRecordResult.fromJson,
    );
    final result = body.result;
    if (result == null) throw StateError('movie-records result가 없습니다.');
    return result;
  }
}
