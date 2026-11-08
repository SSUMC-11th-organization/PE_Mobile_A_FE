import 'package:dio/dio.dart';

import '../models/rating_dto.dart';

class RatingApiService {
  RatingApiService(this._dio);

  final Dio _dio;

  // 평점이 없으면 빈 배열, memberId 형식이 틀리면 400, 없는 회원이면 404가 옵니다.
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _dio.get('/v5/members/$memberId/ratings');
    final list = response.data as List<dynamic>;
    return list
        .map((item) => RatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
