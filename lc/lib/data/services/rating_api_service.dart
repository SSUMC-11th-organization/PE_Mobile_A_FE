import 'package:dio/dio.dart';

import '../models/rating_dto.dart';

class RatingApiService {
  RatingApiService(this._dio);

  final Dio _dio;

  /// 결과가 없으면 빈 배열이 온다. 빈 배열은 실패가 아니다.
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _dio.get('/v5/members/$memberId/ratings');
    final list = response.data as List<dynamic>;
    return list
        .map((item) => RatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

/// 400·404·그 외 실패를 하나로 뭉치지 않고 사용자에게 다른 문구로 알린다.
String writeMyRatingsErrorMessage(DioException error) {
  final status = error.response?.statusCode;
  if (status == 400) return 'memberId 형식을 다시 확인해 주세요.';
  if (status == 404) return '존재하지 않는 회원입니다.';
  return '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
}
