import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

import '../week6_helpers.dart';

const _request = CreateMemberRequest(
  email: 'a@b.com',
  password: 'Pass1!word',
  nickname: '영화광',
);

void main() {
  late FakeSignUpService service;
  late SignUpViewModel viewModel;

  setUp(() {
    service = FakeSignUpService();
    viewModel = SignUpViewModel(service);
  });

  tearDown(() => viewModel.dispose());

  test('처음에는 제출 전(idle)이고 memberId와 오류가 없다', () {
    expect(viewModel.submitStatus, SubmitStatus.idle);
    expect(viewModel.createdMemberId, isNull);
    expect(viewModel.passwordErrorText, isNull);
    expect(viewModel.snackbarMessage, isNull);
  });

  test('가입 성공 응답의 result.memberId를 createdMemberId에 담는다', () async {
    service.signUpMemberId = 321;

    await viewModel.submit(_request);

    expect(viewModel.submitStatus, SubmitStatus.success);
    expect(viewModel.createdMemberId, 321);
    expect(service.signUpCalls.single.nickname, '영화광');
  });

  test('제출 중에는 submitting이며 다시 눌러도 요청이 늘지 않는다', () async {
    service.signUpGate = Completer<void>();

    final pending = viewModel.submit(_request);
    expect(viewModel.submitStatus, SubmitStatus.submitting);
    expect(viewModel.isSubmitting, isTrue);

    await viewModel.submit(_request);
    expect(service.signUpCalls, hasLength(1));

    service.signUpGate!.complete();
    await pending;
    expect(viewModel.submitStatus, SubmitStatus.success);
  });

  test('result에 memberId가 없으면 가입을 완료한 것으로 표시하지 않는다', () async {
    service.signUpWithoutResult = true;

    await viewModel.submit(_request);

    expect(viewModel.submitStatus, SubmitStatus.error);
    expect(viewModel.createdMemberId, isNull);
    expect(viewModel.snackbarMessage, contains('가입 결과를 확인하지 못했습니다'));
  });

  test('비밀번호 형식 400은 passwordErrorText로, Snackbar 문구는 비운다', () async {
    service.signUpError = commonError(
      400,
      'COMMON400',
      '비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.',
    );

    await viewModel.submit(_request);

    expect(viewModel.submitStatus, SubmitStatus.error);
    expect(viewModel.passwordErrorText, contains('비밀번호는'));
    expect(viewModel.snackbarMessage, isNull);
  });

  test('비밀번호와 무관한 400은 Snackbar 문구로 보낸다', () async {
    service.signUpError = commonError(400, 'COMMON400', '이메일 형식이 올바르지 않습니다.');

    await viewModel.submit(_request);

    expect(viewModel.passwordErrorText, isNull);
    expect(viewModel.snackbarMessage, '이메일 형식이 올바르지 않습니다.');
  });

  test('최종 중복 409는 서버 message를 Snackbar 문구로 보낸다', () async {
    service.signUpError = commonError(409, 'COMMON409', '이미 사용 중인 이메일입니다.');

    await viewModel.submit(_request);

    expect(viewModel.submitStatus, SubmitStatus.error);
    expect(viewModel.snackbarMessage, '이미 사용 중인 이메일입니다.');
    expect(viewModel.passwordErrorText, isNull);
    expect(viewModel.createdMemberId, isNull);
  });

  test('통신 실패는 기본 문구를 쓰고 제출 상태가 풀린다', () async {
    service.signUpError = dioFailure('/v6/members');

    await viewModel.submit(_request);

    expect(viewModel.submitStatus, SubmitStatus.error);
    expect(viewModel.snackbarMessage, contains('회원가입에 실패'));
    expect(viewModel.isSubmitting, isFalse);
  });

  test('실패 뒤에는 같은 입력으로 다시 제출할 수 있다', () async {
    service.signUpError = commonError(409, 'COMMON409', '이미 사용 중인 이메일입니다.');
    await viewModel.submit(_request);

    service.signUpError = null;
    await viewModel.submit(_request);

    expect(viewModel.submitStatus, SubmitStatus.success);
    expect(viewModel.snackbarMessage, isNull);
    expect(service.signUpCalls, hasLength(2));
  });

  test('비밀번호를 고치면 서버가 거부한 비밀번호 오류가 사라진다', () async {
    service.signUpError = commonError(400, 'COMMON400', '비밀번호는 8자 이상이어야 합니다.');
    await viewModel.submit(_request);
    expect(viewModel.passwordErrorText, isNotNull);

    viewModel.onPasswordChanged();

    expect(viewModel.passwordErrorText, isNull);
  });

  test('닉네임·이메일이 모두 사용 가능으로 확인돼야 가입 조건의 서버 확인을 통과한다', () async {
    expect(viewModel.isRemoteChecksPassed, isFalse);

    viewModel.onNicknameChanged('영화광');
    await viewModel.checkNickname('영화광');
    expect(viewModel.isRemoteChecksPassed, isFalse); // 이메일은 아직

    viewModel.onEmailChanged('a@b.com');
    await viewModel.checkEmail('a@b.com');
    expect(viewModel.isRemoteChecksPassed, isTrue);

    // 입력을 바꾸면 이전 확인 결과가 무효화되어 다시 막힌다.
    viewModel.onEmailChanged('a@b.co');
    expect(viewModel.isRemoteChecksPassed, isFalse);
  });

  test('중복으로 확인된 값은 서버 확인을 통과하지 못한다', () async {
    service.takenNicknames.add('영화광');
    viewModel.onNicknameChanged('영화광');
    await viewModel.checkNickname('영화광');
    viewModel.onEmailChanged('a@b.com');
    await viewModel.checkEmail('a@b.com');

    expect(viewModel.isRemoteChecksPassed, isFalse);
  });

  test('consumeSnackbarMessage는 보여준 문구를 비운다', () async {
    service.signUpError = commonError(409, 'COMMON409', '이미 사용 중인 닉네임입니다.');
    await viewModel.submit(_request);

    viewModel.consumeSnackbarMessage();

    expect(viewModel.snackbarMessage, isNull);
  });

  test('화면이 사라진 뒤 도착한 응답은 notifyListeners를 부르지 않는다', () async {
    service.signUpGate = Completer<void>();
    final pending = viewModel.submit(_request);

    viewModel.dispose();
    service.signUpGate!.complete();

    await pending; // dispose된 notifier에 notify하면 예외가 나므로 조용히 끝나야 한다.
    viewModel = SignUpViewModel(service);
  });
}
