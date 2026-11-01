import 'dart:async';

import 'package:dio/dio.dart';

import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/member_check_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';

import 'test_helpers.dart';

DioException dioFailure(String path, {int? statusCode}) {
  final options = RequestOptions(path: path);
  return DioException(
    requestOptions: options,
    type: statusCode == null
        ? DioExceptionType.connectionError
        : DioExceptionType.badResponse,
    response: statusCode == null
        ? null
        : Response<dynamic>(requestOptions: options, statusCode: statusCode),
  );
}

RatingDto ratingDto(int ratingId, int movieId, {int score = 4, String? comment}) {
  return RatingDto(
    ratingId: ratingId,
    movieId: movieId,
    score: score,
    comment: comment,
    createdAt: DateTime.utc(2026, 9, 6, 12, 14, 3),
  );
}

/// 닉네임·이메일 중복 확인을 네트워크 없이 흉내 낸다.
class FakeMemberCheckService extends MemberCheckService {
  FakeMemberCheckService() : super(Dio());

  /// 여기에 들어 있는 값은 "이미 사용 중"으로 답한다.
  final Set<String> takenNicknames = {};
  final Set<String> takenEmails = {};

  bool fail = false;

  /// 이 Completer가 완료될 때까지 응답을 붙잡아 "통신 중" 상태를 만든다.
  Completer<void>? gate;

  final List<String> nicknameCalls = [];
  final List<String> emailCalls = [];

  @override
  Future<bool> checkNickname(String nickname) async {
    nicknameCalls.add(nickname.trim());
    await gate?.future;
    if (fail) throw dioFailure('/v5/members/nickname/$nickname');
    return !takenNicknames.contains(nickname.trim());
  }

  @override
  Future<bool> checkEmail(String email) async {
    emailCalls.add(email.trim());
    await gate?.future;
    if (fail) throw dioFailure('/v5/members/email/$email');
    return !takenEmails.contains(email.trim());
  }
}

class FakeRatingApiService extends RatingApiService {
  FakeRatingApiService({this.ratings = const []}) : super(Dio());

  List<RatingDto> ratings;

  /// null이 아니면 이 상태 코드로 실패한다. 0이면 통신 자체가 실패한다.
  int? failWithStatus;
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    calls++;
    await gate?.future;
    final status = failWithStatus;
    if (status != null) {
      throw dioFailure(
        '/v5/members/$memberId/ratings',
        statusCode: status == 0 ? null : status,
      );
    }
    return ratings;
  }
}

/// FakeTmdbMovieService에 영화 상세 조회를 얹는다.
class FakeDetailTmdbService extends FakeTmdbMovieService {
  FakeDetailTmdbService({Map<int, TmdbMovieDto>? known, Set<int>? networkFailIds})
    : known = known ?? {},
      networkFailIds = networkFailIds ?? {};

  /// id → 영화. 여기에 없는 id는 404(null)로 답한다.
  final Map<int, TmdbMovieDto> known;

  /// 이 id들은 네트워크 오류로 실패한다.
  Set<int> networkFailIds;
  final List<int> detailCalls = [];

  @override
  Future<TmdbMovieDto?> findMovieById(int movieId) async {
    detailCalls.add(movieId);
    if (networkFailIds.contains(movieId)) throw dioFailure('/movie/$movieId');
    return known[movieId];
  }
}
