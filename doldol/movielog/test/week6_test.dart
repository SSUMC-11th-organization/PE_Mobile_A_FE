import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/check_result.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/member_check_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

class FakeMemberCheckService extends MemberCheckService {
  FakeMemberCheckService() : super(Dio());

  final taken = <String>{'taken'};
  bool shouldFail = false;
  Completer<bool>? hold;
  int callCount = 0;

  Future<bool> _answer(String value) async {
    callCount++;
    if (shouldFail) {
      throw DioException(requestOptions: RequestOptions(path: '/check'));
    }
    final pending = hold;
    if (pending != null) return pending.future;
    return !taken.contains(value.trim());
  }

  @override
  Future<bool> checkNickname(String nickname) => _answer(nickname);

  @override
  Future<bool> checkEmail(String email) => _answer(email);
}

class FakeRatingApiService extends RatingApiService {
  FakeRatingApiService() : super(Dio());

  List<RatingDto> ratings = [];
  DioException? error;

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final failure = error;
    if (failure != null) throw failure;
    return ratings;
  }
}

class FakeMovieLookup extends TmdbMovieService {
  FakeMovieLookup() : super(Dio());

  final movies = <int, TmdbMovieDto>{};
  int lookupCount = 0;

  @override
  Future<TmdbMovieDto?> findMovieById(int movieId) async {
    lookupCount++;
    return movies[movieId];
  }
}

TmdbMovieDto movie(int id) => TmdbMovieDto(
      id: id,
      title: '영화 $id',
      overview: '',
      posterPath: null,
      backdropPath: null,
      releaseDate: null,
      genreIds: const [],
      voteAverage: 0,
      popularity: 0,
    );

RatingDto rating(int id, int movieId, {String? comment}) => RatingDto(
      ratingId: id,
      movieId: movieId,
      score: 5,
      comment: comment,
      createdAt: DateTime.utc(2026, 9, 6),
    );

DioException httpError(int status) {
  final options = RequestOptions(path: '/ratings');
  return DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status),
  );
}

void main() {
  group('모델', () {
    test('RatingDto: comment가 null이어도 변환한다', () {
      final dto = RatingDto.fromJson({
        'ratingId': 12,
        'movieId': 550,
        'score': 5,
        'comment': null,
        'createdAt': '2026-09-06T12:14:03.000Z',
      });

      expect(dto.movieId, 550);
      expect(dto.comment, isNull);
      expect(dto.createdAt.year, 2026);
    });

    test('CheckResult: available 값을 읽는다', () {
      expect(CheckResult.fromJson({'available': true}).available, isTrue);
      expect(CheckResult.fromJson({'available': false}).available, isFalse);
    });
  });

  group('SignUpViewModel', () {
    test('사용 가능 응답이면 available 상태가 된다', () async {
      final vm = SignUpViewModel(FakeMemberCheckService());
      addTearDown(vm.dispose);

      vm.onNicknameChanged('무비러버');
      await vm.checkNickname('무비러버');

      expect(vm.nicknameCheckStatus, CheckStatus.available);
      expect(vm.nicknameErrorText, isNull);
    });

    test('중복 응답이면 에러 문구가 생기고 버튼이 비활성화된다', () async {
      final vm = SignUpViewModel(FakeMemberCheckService());
      addTearDown(vm.dispose);

      vm.onNicknameChanged('taken');
      await vm.checkNickname('taken');

      expect(vm.nicknameCheckStatus, CheckStatus.duplicated);
      expect(vm.nicknameErrorText, contains('이미'));
      expect(vm.canCheckNickname, isFalse);
    });

    test('통신 실패와 중복 응답은 서로 다른 상태와 문구다', () async {
      final service = FakeMemberCheckService()..shouldFail = true;
      final vm = SignUpViewModel(service);
      addTearDown(vm.dispose);

      vm.onNicknameChanged('무비러버');
      await vm.checkNickname('무비러버');

      expect(vm.nicknameCheckStatus, CheckStatus.error);
      expect(vm.nicknameErrorText, contains('실패'));
      expect(vm.canCheckNickname, isTrue); // 다시 시도할 수 있다
    });

    test('입력을 바꾸면 이전 결과가 무효화된다', () async {
      final vm = SignUpViewModel(FakeMemberCheckService());
      addTearDown(vm.dispose);

      vm.onNicknameChanged('taken');
      await vm.checkNickname('taken');
      vm.onNicknameChanged('taken2');

      expect(vm.nicknameCheckStatus, CheckStatus.idle);
      expect(vm.nicknameErrorText, isNull);
      expect(vm.canCheckNickname, isTrue);
    });

    test('중복이었던 값을 다시 입력하면 재요청 없이 즉시 에러 상태가 된다', () async {
      final service = FakeMemberCheckService();
      final vm = SignUpViewModel(service);
      addTearDown(vm.dispose);

      vm.onNicknameChanged('taken');
      await vm.checkNickname('taken');
      vm.onNicknameChanged('taken2');
      vm.onNicknameChanged(' taken '); // 공백 차이는 같은 값으로 본다

      expect(service.callCount, 1);
      expect(vm.nicknameCheckStatus, CheckStatus.duplicated);
      expect(vm.nicknameErrorText, isNotNull);
      expect(vm.canCheckNickname, isFalse);
    });

    test('기다리는 중 입력을 바꾸면 늦게 온 응답은 무시한다', () async {
      final service = FakeMemberCheckService()..hold = Completer<bool>();
      final vm = SignUpViewModel(service);
      addTearDown(vm.dispose);

      vm.onNicknameChanged('무비러버');
      final pending = vm.checkNickname('무비러버');
      expect(vm.nicknameCheckStatus, CheckStatus.checking);

      vm.onNicknameChanged('무비러버2');
      service.hold?.complete(false);
      await pending;

      expect(vm.nicknameCheckStatus, CheckStatus.idle);
      expect(vm.nicknameErrorText, isNull);
    });

    test('닉네임과 이메일 상태는 서로 영향을 주지 않는다', () async {
      final vm = SignUpViewModel(FakeMemberCheckService());
      addTearDown(vm.dispose);

      vm.onNicknameChanged('taken');
      await vm.checkNickname('taken');
      vm.onEmailChanged('a@b.com');
      await vm.checkEmail('a@b.com');

      expect(vm.nicknameCheckStatus, CheckStatus.duplicated);
      expect(vm.emailCheckStatus, CheckStatus.available);
    });

    test('형식이 맞지 않으면 중복 확인 버튼이 비활성화된다', () {
      final vm = SignUpViewModel(FakeMemberCheckService());
      addTearDown(vm.dispose);

      vm.onEmailChanged('abc');
      expect(vm.canCheckEmail, isFalse);

      vm.onEmailChanged('a@b.com');
      expect(vm.canCheckEmail, isTrue);
    });
  });

  group('MyRatingsViewModel', () {
    test('평점이 없으면 error가 아니라 empty 상태다', () async {
      final vm = MyRatingsViewModel(
        FakeRatingApiService(),
        FakeMovieLookup(),
        1,
      );
      addTearDown(vm.dispose);

      await vm.load();

      expect(vm.status, MyRatingsLoadStatus.empty);
    });

    test('404면 error 상태와 전용 문구를 보여준다', () async {
      final service = FakeRatingApiService()..error = httpError(404);
      final vm = MyRatingsViewModel(service, FakeMovieLookup(), 1);
      addTearDown(vm.dispose);

      await vm.load();

      expect(vm.status, MyRatingsLoadStatus.error);
      expect(vm.message, '존재하지 않는 회원입니다.');
    });

    test('평점의 movieId를 TMDB 영화와 연결한다', () async {
      final service = FakeRatingApiService()..ratings = [rating(1, 550)];
      final lookup = FakeMovieLookup()..movies[550] = movie(550);
      final vm = MyRatingsViewModel(service, lookup, 1);
      addTearDown(vm.dispose);

      await vm.load();

      expect(vm.status, MyRatingsLoadStatus.success);
      expect(vm.ratings.first.movie?.id, 550);
      expect(vm.message, isNull);
    });

    test('영화 정보를 못 찾아도 평점은 남고 안내 문구가 생긴다', () async {
      final service = FakeRatingApiService()..ratings = [rating(1, 999)];
      final vm = MyRatingsViewModel(service, FakeMovieLookup(), 1);
      addTearDown(vm.dispose);

      await vm.load();

      expect(vm.status, MyRatingsLoadStatus.success);
      expect(vm.ratings.length, 1);
      expect(vm.ratings.first.movie, isNull);
      expect(vm.ratings.first.rating.movieId, 999);
      expect(vm.message, isNotNull);
    });

    test('같은 movieId는 한 번만 조회한다', () async {
      final service = FakeRatingApiService()
        ..ratings = [rating(1, 550), rating(2, 550)];
      final lookup = FakeMovieLookup()..movies[550] = movie(550);
      final vm = MyRatingsViewModel(service, lookup, 1);
      addTearDown(vm.dispose);

      await vm.load();

      expect(vm.ratings.length, 2);
      expect(lookup.lookupCount, 1);
    });
  });
}