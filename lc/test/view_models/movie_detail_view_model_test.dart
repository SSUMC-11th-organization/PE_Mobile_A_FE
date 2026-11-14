import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/movie_detail_view_model.dart';

import '../test_helpers.dart';
import '../week6_helpers.dart';

void main() {
  late FakeRatingApiService service;

  MovieDetailViewModel build({int? memberId = 7, int movieId = 550}) =>
      MovieDetailViewModel(service, memberId, movieDto(movieId));

  setUp(() => service = FakeRatingApiService());

  test('회원가입 전(memberId null)에는 평점을 남길 수 없다', () async {
    final viewModel = build(memberId: null);

    expect(viewModel.canRate, isFalse);
    await viewModel.createRating(score: 5);

    expect(viewModel.submitStatus, SubmitStatus.error);
    expect(viewModel.submitMessage, '먼저 회원가입을 완료해 주세요.');
    expect(service.createCalls, isEmpty); // 요청 자체를 보내지 않는다.
    viewModel.dispose();
  });

  test('등록은 학습용 memberId path와 TMDB id를 movieId로 보낸다 (배열 index가 아니다)', () async {
    final viewModel = build(memberId: 7, movieId: 27205);

    await viewModel.createRating(score: 4, comment: '재밌다');

    expect(viewModel.submitStatus, SubmitStatus.success);
    expect(service.createCalls.single.memberId, 7);
    expect(service.createCalls.single.request.movieId, 27205);
    expect(service.createCalls.single.request.score, 4);
    expect(service.createCalls.single.request.comment, '재밌다');
    viewModel.dispose();
  });

  test('저장 중에는 submitting이며 연속 탭은 요청을 늘리지 않는다', () async {
    service.writeGate = Completer<void>();
    final viewModel = build();

    final pending = viewModel.createRating(score: 5);
    expect(viewModel.submitStatus, SubmitStatus.submitting);
    await viewModel.createRating(score: 5);
    expect(service.createCalls, hasLength(1));

    service.writeGate!.complete();
    await pending;
    expect(viewModel.submitStatus, SubmitStatus.success);
    viewModel.dispose();
  });

  test('400 · 404 · 409는 서버 message를 그대로 안내한다', () async {
    final cases = {
      commonError(400, 'COMMON400', '별점은 5점 이하여야 합니다.'): '별점은 5점 이하여야 합니다.',
      commonError(404, 'COMMON404', '존재하지 않는 유저입니다.'): '존재하지 않는 유저입니다.',
      commonError(409, 'COMMON409', '이미 이 영화에 평점을 남기셨습니다.'):
          '이미 이 영화에 평점을 남기셨습니다.',
    };
    for (final entry in cases.entries) {
      service.writeError = entry.key;
      final viewModel = build();

      await viewModel.createRating(score: 5);

      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(viewModel.submitMessage, entry.value);
      viewModel.dispose();
    }
  });

  test('실패 뒤에도 같은 ViewModel로 다시 시도해 성공할 수 있다', () async {
    service.writeError = commonError(409, 'COMMON409', '이미 이 영화에 평점을 남기셨습니다.');
    final viewModel = build();
    await viewModel.createRating(score: 5);
    expect(viewModel.submitStatus, SubmitStatus.error);

    service.writeError = null;
    await viewModel.createRating(score: 5);

    expect(viewModel.submitStatus, SubmitStatus.success);
    expect(viewModel.submitMessage, isNull);
    viewModel.dispose();
  });

  test('화면이 사라진 뒤 도착한 응답은 notifyListeners를 부르지 않는다', () async {
    service.writeGate = Completer<void>();
    final viewModel = build();
    final pending = viewModel.createRating(score: 5);

    viewModel.dispose();
    service.writeGate!.complete();

    await pending;
  });
}
