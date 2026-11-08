import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/services/member_check_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';

DioException httpError(String path, int statusCode) {
  final options = RequestOptions(path: path);
  return DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: statusCode),
    type: DioExceptionType.badResponse,
  );
}

DioException networkError(String path) => DioException(
  requestOptions: RequestOptions(path: path),
  type: DioExceptionType.connectionError,
);

// takenNicknames·takenEmails에 있는 값만 '중복'으로 응답하는 테스트용 Service입니다.
class FakeMemberCheckService implements MemberCheckService {
  FakeMemberCheckService({
    this.takenNicknames = const {'무비러버'},
    this.takenEmails = const {'taken@movielog.com'},
  });

  final Set<String> takenNicknames;
  final Set<String> takenEmails;

  Object? error;
  Completer<void>? gate;
  final nicknameRequests = <String>[];
  final emailRequests = <String>[];

  Future<void> _respond() async {
    final pending = gate;
    if (pending != null) await pending.future;
    final failure = error;
    if (failure != null) throw failure;
  }

  @override
  Future<bool> checkNickname(String nickname) async {
    nicknameRequests.add(nickname);
    await _respond();
    return !takenNicknames.contains(nickname.trim());
  }

  @override
  Future<bool> checkEmail(String email) async {
    emailRequests.add(email);
    await _respond();
    return !takenEmails.contains(email.trim());
  }
}

RatingDto ratingFixture(
  int ratingId, {
  required int movieId,
  int score = 4,
  String? comment = '좋았어요',
}) {
  return RatingDto(
    ratingId: ratingId,
    movieId: movieId,
    score: score,
    comment: comment,
    createdAt: DateTime.utc(2026, 9, 6, 12),
  );
}

// 두 번째 평점은 후기(comment)가 없습니다.
List<RatingDto> defaultRatingFixtures() => [
  ratingFixture(1, movieId: 1, score: 5, comment: '최고의 영화!'),
  ratingFixture(2, movieId: 2, score: 3, comment: null),
];

class FakeRatingApiService implements RatingApiService {
  FakeRatingApiService({List<RatingDto>? ratings})
    : ratings = ratings ?? defaultRatingFixtures();

  List<RatingDto> ratings;
  Object? error;
  Completer<void>? gate;
  final requestedMemberIds = <int>[];

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    requestedMemberIds.add(memberId);
    final pending = gate;
    if (pending != null) await pending.future;
    final failure = error;
    if (failure != null) throw failure;
    return ratings;
  }
}
