import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

import 'helpers/movielog_fakes.dart';

void main() {
  group('SignUpViewModel', () {
    late FakeSignUpService service;
    late SignUpViewModel viewModel;

    setUp(() {
      service = FakeSignUpService();
      viewModel = SignUpViewModel(service);
    });

    test('확인 전 → 통신 중 → 사용 가능 순서로 바뀐다', () async {
      viewModel.onNicknameChanged(' 영화광 ');
      expect(viewModel.nicknameCheckStatus, CheckStatus.idle);

      final pending = viewModel.checkNickname(' 영화광 ');
      expect(viewModel.nicknameCheckStatus, CheckStatus.checking);
      expect(viewModel.canCheckNickname, isFalse);

      await pending;
      expect(viewModel.nicknameCheckStatus, CheckStatus.available);
      expect(viewModel.nicknameErrorText, isNull);
      expect(service.nicknameRequests.single, '영화광');
    });

    test('서버가 중복이라고 하면 duplicated와 중복 문구를 둔다', () async {
      viewModel.onNicknameChanged('무비러버');
      await viewModel.checkNickname('무비러버');

      expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
      expect(viewModel.nicknameErrorText, '이미 사용 중인 닉네임입니다.');
    });

    test('통신 실패는 중복과 다른 상태·문구로 구분한다', () async {
      service.error = networkError('/v7/members/nickname/x');
      viewModel.onNicknameChanged('영화광');
      await viewModel.checkNickname('영화광');

      expect(viewModel.nicknameCheckStatus, CheckStatus.error);
      expect(viewModel.nicknameErrorText, '중복 확인에 실패했습니다. 다시 시도해 주세요.');
    });

    test('입력을 바꾸면 이전 결과가 바로 사라진다', () async {
      viewModel.onNicknameChanged('무비러버');
      await viewModel.checkNickname('무비러버');

      viewModel.onNicknameChanged('무비러버2');

      expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
      expect(viewModel.nicknameErrorText, isNull);
    });

    test('중복이었던 값으로 되돌아오면 다시 묻지 않고 즉시 중복 에러가 된다', () async {
      viewModel.onNicknameChanged('무비러버');
      await viewModel.checkNickname('무비러버');
      expect(viewModel.canCheckNickname, isFalse);

      viewModel.onNicknameChanged('무비러');
      expect(viewModel.canCheckNickname, isTrue);

      viewModel.onNicknameChanged(' 무비러버 ');
      expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
      expect(viewModel.nicknameErrorText, '이미 사용 중인 닉네임입니다.');
      expect(viewModel.canCheckNickname, isFalse);
      expect(service.nicknameRequests, ['무비러버']);
    });

    test('응답을 기다리는 중에 입력이 바뀌면 늦게 온 응답은 무시한다', () async {
      service.gate = Completer<void>();
      viewModel.onNicknameChanged('무비러버');
      final pending = viewModel.checkNickname('무비러버');

      viewModel.onNicknameChanged('영화광');
      service.gate!.complete();
      await pending;

      expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
      expect(viewModel.nicknameErrorText, isNull);
    });

    test('형식이 맞지 않으면 확인 버튼을 누를 수 없고 요청도 보내지 않는다', () async {
      viewModel.onNicknameChanged('무');
      viewModel.onEmailChanged('movie');

      expect(viewModel.canCheckNickname, isFalse);
      expect(viewModel.canCheckEmail, isFalse);
      await viewModel.checkNickname('무');
      expect(service.nicknameRequests, isEmpty);
    });

    test('닉네임과 이메일 결과는 서로 영향을 주지 않는다', () async {
      viewModel.onNicknameChanged('무비러버');
      viewModel.onEmailChanged('new@movielog.com');
      await viewModel.checkNickname('무비러버');
      await viewModel.checkEmail('new@movielog.com');

      expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
      expect(viewModel.emailCheckStatus, CheckStatus.available);
      expect(viewModel.emailErrorText, isNull);
    });
  });
}
