import 'package:dio/dio.dart';
import '../models/common_response.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';

class RatingApiService {
  RatingApiService(this._dio);

  final Dio _dio;

  /// 200 + 직접 배열
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _dio.get('/v6/members/$memberId/ratings');
    final list = response.data as List<dynamic>;

    return list
        .map((item) => RatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 201 + wrapper. result의 계약이 확정되지 않아 파싱하지 않고 상태 코드만 확인한다.
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    final response = await _dio.post(
      '/v6/members/$memberId/ratings',
      data: request.toJson(),
    );

    if (response.statusCode != 201) {
      throw StateError('예상하지 못한 등록 응답: ${response.statusCode}');
    }
  }

  /// 200 + result null. score는 필수이고, comment를 null로 보내면 후기가 지워진다.
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    await _dio.patch(
      '/v6/members/$memberId/ratings/$ratingId',
      data: {'score': score, 'comment': comment},
    );
  }

  /// 204 + body 없음 (본문을 파싱하지 않는다)
  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    final response = await _dio.delete(
      '/v6/members/$memberId/ratings/$ratingId',
    );

    if (response.statusCode != 204) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

/// 평점 목록 조회(GET) 오류 문구
String writeMyRatingsErrorMessage(DioException error) {
  final status = error.response?.statusCode;
  if (status == 400) return 'memberId 형식을 다시 확인해 주세요.';
  if (status == 404) return '존재하지 않는 회원입니다.';
  return '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
}

/// 쓰기(등록·수정·삭제) 오류 문구. 서버 message를 그대로 쓴다.
/// 같은 COMMON404라도 등록은 "유저", 수정·삭제는 "평점"을 가리키므로 code로 문구를 새로 만들지 않는다.
String writeErrorMessage(DioException error) {
  if (error.response == null) {
    return '네트워크 연결을 확인하고 다시 시도해 주세요.';
  }
  return readServerMessage(error.response?.data) ??
      '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}

/// 403·404는 화면의 목록이 서버 상태와 어긋났다는 뜻이라 다시 조회한다.
/// 400·409는 값만 고치거나 다시 시도하면 되므로 조회하지 않는다.
bool shouldRefreshAfterRatingError(DioException error) {
  final code = readServerCode(error.response?.data);
  return code == 'COMMON403' || code == 'COMMON404';
}