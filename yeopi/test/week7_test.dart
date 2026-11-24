import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

import 'helpers/movielog_fakes.dart';

// 7주차 테스트 중 v6 memberId 기반 평점 테스트는 8주차 토큰 기반 테스트(week8_test.dart)로 옮겼습니다.
const _request = CreateMemberRequest(
  email: 'me@movielog.com',
  password: 'Password1!',
  nickname: '여비',
);

void main() {
  group('SignUpViewModel.submit', () {
    test('성공하면 응답 result의 memberId를 보관한다', () async {
      final service = FakeSignUpService()..signUpMemberId = 31;
      final viewModel = SignUpViewModel(service);

      final pending = viewModel.submit(_request);
      expect(viewModel.isSubmitting, isTrue);
      await pending;

      expect(viewModel.submitStatus, SubmitStatus.success);
      expect(viewModel.createdMemberId, 31);
    });

    test('비밀번호 400은 입력칸 오류로, 409는 Snackbar 문구로 나눈다', () async {
      final service = FakeSignUpService()
        ..signUpError = httpError(
          '/v7/members',
          400,
          message: '비밀번호는 대문자를 포함해야 합니다.',
        );
      final viewModel = SignUpViewModel(service);

      await viewModel.submit(_request);
      expect(viewModel.passwordErrorText, '비밀번호는 대문자를 포함해야 합니다.');
      expect(viewModel.snackbarMessage, isNull);

      // 비밀번호를 고치면 서버 오류는 지웁니다.
      viewModel.onPasswordChanged();
      expect(viewModel.passwordErrorText, isNull);

      service.signUpError = httpError(
        '/v7/members',
        409,
        message: '이미 사용 중인 이메일입니다.',
      );
      await viewModel.submit(_request);
      expect(viewModel.passwordErrorText, isNull);
      expect(viewModel.snackbarMessage, '이미 사용 중인 이메일입니다.');
      expect(viewModel.createdMemberId, isNull);
    });

    test('요청 중에 다시 제출해도 POST는 한 번만 보낸다', () async {
      final service = FakeSignUpService()..signUpGate = Completer<void>();
      final viewModel = SignUpViewModel(service);

      final first = viewModel.submit(_request);
      await viewModel.submit(_request);
      service.signUpGate!.complete();
      await first;

      expect(service.signUpRequests, hasLength(1));
    });
  });
}
