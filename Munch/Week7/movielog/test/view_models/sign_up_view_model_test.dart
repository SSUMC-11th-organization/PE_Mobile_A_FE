import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

import '../fakes/fake_member_check_service.dart';

void main() {
  late FakeMemberCheckService service;
  late SignUpViewModel viewModel;

  setUp(() {
    service = FakeMemberCheckService(duplicatedValues: {'영화광', 'dup@umc.com'});
    viewModel = SignUpViewModel(service);
  });

  tearDown(() => viewModel.dispose());

  test('사용 가능한 닉네임이면 available', () async {
    viewModel.onNicknameChanged('무비러버');
    await viewModel.checkNickname('무비러버');

    expect(viewModel.nicknameCheckStatus, CheckStatus.available);
    expect(viewModel.nicknameErrorText, isNull);
  });

  test('통신 중에는 checking이고 버튼을 누를 수 없다', () async {
    service.pending = Completer<void>();
    viewModel.onNicknameChanged('무비러버');
    final future = viewModel.checkNickname('무비러버');

    expect(viewModel.nicknameCheckStatus, CheckStatus.checking);
    expect(viewModel.canCheckNickname, isFalse);

    service.pending!.complete();
    await future;
    expect(viewModel.nicknameCheckStatus, CheckStatus.available);
  });

  test('중복 응답과 통신 실패는 다른 상태·문구로 구분된다', () async {
    viewModel.onNicknameChanged('영화광');
    await viewModel.checkNickname('영화광');
    expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
    expect(viewModel.nicknameErrorText, '이미 사용 중인 닉네임입니다.');

    service.failing = true;
    viewModel.onNicknameChanged('무비러버');
    await viewModel.checkNickname('무비러버');
    expect(viewModel.nicknameCheckStatus, CheckStatus.error);
    expect(viewModel.nicknameErrorText, '중복 확인에 실패했습니다. 다시 시도해 주세요.');
    expect(viewModel.canCheckNickname, isTrue);
  });

  test('입력을 바꾸면 이전 결과가 idle로 무효화된다', () async {
    viewModel.onNicknameChanged('무비러버');
    await viewModel.checkNickname('무비러버');
    expect(viewModel.isNicknameAvailable, isTrue);

    viewModel.onNicknameChanged('무비러버2');
    expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
    expect(viewModel.isNicknameAvailable, isFalse);
  });

  test('입력이 바뀐 뒤 도착한 이전 응답은 무시된다', () async {
    service.pending = Completer<void>();
    viewModel.onNicknameChanged('무비러버');
    final future = viewModel.checkNickname('무비러버');

    viewModel.onNicknameChanged('다른닉네임');
    service.pending!.complete();
    await future;

    expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
  });

  group('챌린지: 중복이었던 값 기억하기', () {
    test('중복 응답 즉시 버튼이 비활성화된다', () async {
      viewModel.onNicknameChanged('영화광');
      await viewModel.checkNickname('영화광');
      expect(viewModel.canCheckNickname, isFalse);
    });

    test('다른 값으로 고치면 에러가 사라지고 버튼이 다시 활성화된다', () async {
      viewModel.onNicknameChanged('영화광');
      await viewModel.checkNickname('영화광');

      viewModel.onNicknameChanged('영화');
      expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
      expect(viewModel.nicknameErrorText, isNull);
      expect(viewModel.canCheckNickname, isTrue);
    });

    test('중복이었던 값을 다시 입력하면 재요청 없이 즉시 에러로 돌아온다', () async {
      viewModel.onNicknameChanged('영화광');
      await viewModel.checkNickname('영화광');
      viewModel.onNicknameChanged('영화');
      viewModel.onNicknameChanged(' 영화광 ');

      expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
      expect(viewModel.nicknameErrorText, '이미 사용 중인 닉네임입니다.');
      expect(viewModel.canCheckNickname, isFalse);
      expect(service.nicknameCalls, ['영화광']);
    });
  });

  test('닉네임과 이메일 상태는 서로 영향을 주지 않는다', () async {
    viewModel.onNicknameChanged('영화광');
    await viewModel.checkNickname('영화광');
    viewModel.onEmailChanged('movie@umc.com');
    await viewModel.checkEmail('movie@umc.com');

    expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
    expect(viewModel.emailCheckStatus, CheckStatus.available);

    viewModel.onEmailChanged('dup@umc.com');
    await viewModel.checkEmail('dup@umc.com');
    expect(viewModel.emailErrorText, '이미 사용 중인 이메일입니다.');
    viewModel.onEmailChanged('dup@umc.co');
    viewModel.onEmailChanged('dup@umc.com');
    expect(viewModel.emailCheckStatus, CheckStatus.duplicated);
    expect(service.emailCalls, ['movie@umc.com', 'dup@umc.com']);
  });
}
