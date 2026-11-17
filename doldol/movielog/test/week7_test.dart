import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/utils/validators.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/view_models/submit_status.dart';

DioException httpError(int status, {String? code, String? message}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: status,
      data: {
        'isSuccess': false,
        'code': code ?? 'COMMON$status',
        'message': message ?? '오류',
        'result': null,
      },
    ),
  );
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

RatingDto rating(int id, int movieId) => RatingDto(
      ratingId: id,
      movieId: movieId,
      score: 5,
      comment: null,
      createdAt: DateTime.utc(2026, 9, 6),
    );

class FakeSignUpService extends SignUpService {
  FakeSignUpService() : super(Dio());

  Object? signUpError;
  int? memberId = 7;
  Completer<void>? hold;
  int signUpCalls = 0;
  CreateMemberRequest? lastRequest;

  @override
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    signUpCalls++;
    lastRequest = request;

    final pending = hold;
    if (pending != null) await pending.future;

    final error = signUpError;
    if (error != null) throw error;

    final id = memberId;
    return CommonResponse<SignUpResult>(
      isSuccess: true,
      code: 'COMMON201',
      message: '성공',
      result: id == null
          ? null
          : SignUpResult(
              memberId: id,
              email: request.email,
              nickname: request.nickname,
            ),
    );
  }
}

class FakeRatingService extends RatingApiService {
  FakeRatingService() : super(Dio());

  List<RatingDto> ratings = [];
  Object? fetchError;
  Object? writeError;
  bool failFetchAfterWrite = false;
  int fetchCalls = 0;
  final updates = <int>[];
  final deletes = <int>[];
  final creates = <CreateRatingRequest>[];

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    fetchCalls++;
    final error = fetchError;
    if (error != null) throw error;
    return ratings;
  }

  @override
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    final error = writeError;
    if (error != null) throw error;
    creates.add(request);
  }

  @override
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final error = writeError;
    if (error != null) throw error;
    updates.add(ratingId);
    if (failFetchAfterWrite) fetchError = httpError(500);
  }

  @override
  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    final error = writeError;
    if (error != null) throw error;
    deletes.add(ratingId);
    ratings.removeWhere((item) => item.ratingId == ratingId);
  }
}

class FakeMovieLookup extends TmdbMovieService {
  FakeMovieLookup() : super(Dio());

  @override
  Future<TmdbMovieDto?> findMovieById(int movieId) async => movie(movieId);
}

CreateMemberRequest signUpRequest() => const CreateMemberRequest(
      email: 'a@b.com',
      password: 'Abcdef1!',
      nickname: '무비러버',
    );

void main() {
  group('요청 모델과 검증', () {
    test('CreateRatingRequest: 코멘트가 비어 있으면 생략한다', () {
      expect(
        const CreateRatingRequest(movieId: 550, score: 4).toJson(),
        {'movieId': 550, 'score': 4},
      );
      expect(
        const CreateRatingRequest(movieId: 550, score: 4, comment: '  ')
            .toJson()
            .containsKey('comment'),
        isFalse,
      );
      expect(
        const CreateRatingRequest(movieId: 550, score: 4, comment: ' 좋아요 ')
            .toJson()['comment'],
        '좋아요',
      );
    });

    test('validateServerScore: 1~5 정수만 허용한다', () {
      expect(validateServerScore(4.0), 4);
      expect(() => validateServerScore(3.5), throwsArgumentError);
      expect(() => validateServerScore(0), throwsArgumentError);
      expect(() => validateServerScore(6), throwsArgumentError);
    });

    test('회원가입 요청: 비밀번호는 그대로 두고 이메일·닉네임만 다듬는다', () {
      final json = const CreateMemberRequest(
        email: ' a@b.com ',
        password: 'Abcdef1!',
        nickname: ' 무비러버 ',
      ).toJson();

      expect(json['email'], 'a@b.com');
      expect(json['nickname'], '무비러버');
      expect(json['password'], 'Abcdef1!');
    });

    test('Validators: 닉네임 2~12자, 비밀번호 규칙', () {
      expect(Validators.nickname('가'), isNotNull);
      expect(Validators.nickname('가나'), isNull);
      expect(Validators.nickname('가' * 13), isNotNull);

      expect(Validators.password('Abcdef1!'), isNull);
      expect(Validators.password('abcdefgh'), isNotNull); // 대문자·숫자·특수문자 없음
      expect(Validators.password('Abcdef1'), isNotNull); // 8자 미만
      expect(Validators.password(' Abcdef1!'), isNotNull); // 앞 공백
    });
  });

  group('SignUpViewModel.submit', () {
    test('성공하면 result의 memberId를 보관한다', () async {
      final vm = SignUpViewModel(FakeSignUpService());
      addTearDown(vm.dispose);

      await vm.submit(signUpRequest());

      expect(vm.submitStatus, SubmitStatus.success);
      expect(vm.createdMemberId, 7);
    });

    test('result에 memberId가 없으면 가입 완료로 보지 않는다', () async {
      final service = FakeSignUpService()..memberId = null;
      final vm = SignUpViewModel(service);
      addTearDown(vm.dispose);

      await vm.submit(signUpRequest());

      expect(vm.submitStatus, SubmitStatus.error);
      expect(vm.createdMemberId, isNull);
      expect(vm.snackbarMessage, isNotNull);
    });

    test('400 비밀번호 오류는 입력칸에, 그 외 400은 Snackbar에 담는다', () async {
      final service = FakeSignUpService()
        ..signUpError = httpError(400, message: '비밀번호는 8자 이상이어야 합니다.');
      final vm = SignUpViewModel(service);
      addTearDown(vm.dispose);

      await vm.submit(signUpRequest());
      expect(vm.passwordErrorText, contains('비밀번호'));
      expect(vm.snackbarMessage, isNull);

      service.signUpError = httpError(400, message: '이메일 형식이 올바르지 않습니다.');
      await vm.submit(signUpRequest());
      expect(vm.passwordErrorText, isNull);
      expect(vm.snackbarMessage, '이메일 형식이 올바르지 않습니다.');
    });

    test('409 중복은 서버 message를 Snackbar로 보여준다', () async {
      final service = FakeSignUpService()
        ..signUpError = httpError(409, message: '이미 사용 중인 이메일입니다.');
      final vm = SignUpViewModel(service);
      addTearDown(vm.dispose);

      await vm.submit(signUpRequest());

      expect(vm.submitStatus, SubmitStatus.error);
      expect(vm.snackbarMessage, '이미 사용 중인 이메일입니다.');
      expect(vm.passwordErrorText, isNull);
    });

    test('비밀번호를 고치면 서버 오류가 사라진다', () async {
      final service = FakeSignUpService()
        ..signUpError = httpError(400, message: '비밀번호 형식 오류');
      final vm = SignUpViewModel(service);
      addTearDown(vm.dispose);

      await vm.submit(signUpRequest());
      vm.onPasswordChanged();

      expect(vm.passwordErrorText, isNull);
      expect(vm.submitStatus, SubmitStatus.idle);
    });

    test('제출 중에는 중복 탭을 막는다', () async {
      final service = FakeSignUpService()..hold = Completer<void>();
      final vm = SignUpViewModel(service);
      addTearDown(vm.dispose);

      final first = vm.submit(signUpRequest());
      final second = vm.submit(signUpRequest());
      expect(vm.submitStatus, SubmitStatus.submitting);

      service.hold?.complete();
      await Future.wait([first, second]);

      expect(service.signUpCalls, 1);
    });
  });

  group('MyRatingsViewModel 수정·삭제', () {
    test('수정에 성공하면 목록을 다시 조회한다', () async {
      final service = FakeRatingService()..ratings = [rating(1, 550)];
      final vm = MyRatingsViewModel(service, FakeMovieLookup(), 7);
      addTearDown(vm.dispose);

      await vm.load();
      await vm.updateRating(ratingId: 1, score: 4, comment: '수정');

      expect(service.updates, [1]);
      expect(service.fetchCalls, 2);
      expect(vm.status, MyRatingsLoadStatus.success);
    });

    test('403이면 실패를 다시 던지고 목록도 다시 맞춘다', () async {
      final service = FakeRatingService()..ratings = [rating(1, 550)];
      final vm = MyRatingsViewModel(service, FakeMovieLookup(), 7);
      addTearDown(vm.dispose);

      await vm.load();
      service.writeError = httpError(403, code: 'COMMON403');

      await expectLater(
        vm.updateRating(ratingId: 1, score: 4),
        throwsA(isA<DioException>()),
      );
      expect(service.fetchCalls, 2);
    });

    test('400이면 실패를 다시 던지지만 목록은 다시 조회하지 않는다', () async {
      final service = FakeRatingService()..ratings = [rating(1, 550)];
      final vm = MyRatingsViewModel(service, FakeMovieLookup(), 7);
      addTearDown(vm.dispose);

      await vm.load();
      service.writeError = httpError(400, code: 'COMMON400');

      await expectLater(
        vm.updateRating(ratingId: 1, score: 4),
        throwsA(isA<DioException>()),
      );
      expect(service.fetchCalls, 1);
    });

    test('저장은 성공했는데 조회만 실패하면 저장 실패로 처리하지 않는다', () async {
      final service = FakeRatingService()
        ..ratings = [rating(1, 550)]
        ..failFetchAfterWrite = true;
      final vm = MyRatingsViewModel(service, FakeMovieLookup(), 7);
      addTearDown(vm.dispose);

      await vm.load();
      await vm.updateRating(ratingId: 1, score: 4); // 예외 없이 끝난다

      expect(service.updates, [1]);
      expect(vm.status, MyRatingsLoadStatus.error);
      expect(vm.refreshWarning, isNotNull);

      // 조회만 다시 시도하면 복구된다 (쓰기 요청은 다시 보내지 않는다)
      service.fetchError = null;
      await vm.load();

      expect(vm.status, MyRatingsLoadStatus.success);
      expect(vm.refreshWarning, isNull);
      expect(service.updates.length, 1);
    });

    test('마지막 평점을 삭제하면 Empty 상태가 된다', () async {
      final service = FakeRatingService()..ratings = [rating(1, 550)];
      final vm = MyRatingsViewModel(service, FakeMovieLookup(), 7);
      addTearDown(vm.dispose);

      await vm.load();
      await vm.deleteRating(1);

      expect(service.deletes, [1]);
      expect(vm.status, MyRatingsLoadStatus.empty);
    });
  });

  group('MovieDetailViewModel.createRating', () {
    test('memberId가 없으면 요청하지 않고 안내한다', () async {
      final service = FakeRatingService();
      final vm = MovieDetailViewModel(service, null, movie(550));
      addTearDown(vm.dispose);

      await vm.createRating(score: 4);

      expect(vm.submitStatus, SubmitStatus.error);
      expect(vm.submitMessage, '먼저 회원가입을 완료해 주세요.');
      expect(service.creates, isEmpty);
    });

    test('성공하면 TMDB id를 movieId로 보낸다', () async {
      final service = FakeRatingService();
      final vm = MovieDetailViewModel(service, 7, movie(550));
      addTearDown(vm.dispose);

      await vm.createRating(score: 4, comment: '좋아요');

      expect(vm.submitStatus, SubmitStatus.success);
      expect(service.creates.single.movieId, 550);
      expect(service.creates.single.score, 4);
      expect(service.creates.single.comment, '좋아요');
    });

    test('409면 서버 message를 보여준다', () async {
      final service = FakeRatingService()
        ..writeError = httpError(409, message: '이미 이 영화에 평점을 남기셨습니다.');
      final vm = MovieDetailViewModel(service, 7, movie(550));
      addTearDown(vm.dispose);

      await vm.createRating(score: 4);

      expect(vm.submitStatus, SubmitStatus.error);
      expect(vm.submitMessage, '이미 이 영화에 평점을 남기셨습니다.');
    });
  });
}