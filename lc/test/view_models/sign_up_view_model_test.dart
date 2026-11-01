import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/sign_up_view_model.dart';

import '../week6_helpers.dart';

void main() {
  late FakeMemberCheckService service;
  late SignUpViewModel viewModel;

  setUp(() {
    service = FakeMemberCheckService();
    viewModel = SignUpViewModel(service);
  });

  tearDown(() => viewModel.dispose());

  /// 입력 → 중복 확인 한 번을 화면과 같은 순서로 흉내 낸다.
  Future<void> typeAndCheckNickname(String value) async {
    viewModel.onNicknameChanged(value);
    await viewModel.checkNickname(value);
  }

  test('처음에는 idle이고 에러 문구가 없다', () {
    expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
    expect(viewModel.nicknameErrorText, isNull);
    expect(viewModel.canCheckNickname, isTrue);
  });

  test('통신 중에는 checking이며 다시 확인할 수 없다', () async {
    service.gate = Completer<void>();
    viewModel.onNicknameChanged('영화광');

    final pending = viewModel.checkNickname('영화광');
    expect(viewModel.nicknameCheckStatus, CheckStatus.checking);
    expect(viewModel.canCheckNickname, isFalse);

    // 통신 중에 한 번 더 눌러도 요청이 늘지 않는다.
    await viewModel.checkNickname('영화광');
    expect(service.nicknameCalls, hasLength(1));

    service.gate!.complete();
    await pending;
    expect(viewModel.nicknameCheckStatus, CheckStatus.available);
  });

  test('사용 가능하면 available이고 에러 문구가 없다', () async {
    await typeAndCheckNickname('영화광');

    expect(viewModel.nicknameCheckStatus, CheckStatus.available);
    expect(viewModel.nicknameErrorText, isNull);
  });

  test('중복이면 duplicated, 에러 문구가 생기고 버튼을 누를 수 없다', () async {
    service.takenNicknames.add('영화광');

    await typeAndCheckNickname('영화광');

    expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
    expect(viewModel.nicknameErrorText, '이미 사용 중인 닉네임입니다.');
    expect(viewModel.canCheckNickname, isFalse);
  });

  test('통신 실패는 중복과 다른 상태와 문구가 된다', () async {
    service.fail = true;

    await typeAndCheckNickname('영화광');

    expect(viewModel.nicknameCheckStatus, CheckStatus.error);
    expect(viewModel.nicknameErrorText, '중복 확인에 실패했습니다. 다시 시도해 주세요.');
    expect(viewModel.nicknameErrorText, isNot('이미 사용 중인 닉네임입니다.'));
    // 실패 뒤에는 다시 시도할 수 있다.
    expect(viewModel.canCheckNickname, isTrue);
  });

  test('입력을 바꾸면 이전 확인 결과가 즉시 idle로 무효화된다', () async {
    await typeAndCheckNickname('영화광');
    expect(viewModel.nicknameCheckStatus, CheckStatus.available);

    viewModel.onNicknameChanged('영화광2');

    expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
    expect(viewModel.nicknameErrorText, isNull);
  });

  test('중복이었던 값을 지우면 에러가 풀리고 버튼이 다시 눌린다', () async {
    service.takenNicknames.add('영화광');
    await typeAndCheckNickname('영화광');

    viewModel.onNicknameChanged('영화');

    expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
    expect(viewModel.nicknameErrorText, isNull);
    expect(viewModel.canCheckNickname, isTrue);
  });

  test('중복이었던 값을 그대로 다시 입력하면 서버에 묻지 않고 즉시 에러로 돌아온다', () async {
    service.takenNicknames.add('영화광');
    await typeAndCheckNickname('영화광');
    viewModel.onNicknameChanged('영화');
    expect(service.nicknameCalls, hasLength(1));

    viewModel.onNicknameChanged('영화광');

    expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
    expect(viewModel.nicknameErrorText, '이미 사용 중인 닉네임입니다.');
    expect(viewModel.canCheckNickname, isFalse);

    // 이 상태에서 확인을 눌러도 요청하지 않는다.
    await viewModel.checkNickname('영화광');
    expect(service.nicknameCalls, hasLength(1));
  });

  test('공백만 다른 값도 같은 값으로 본다(trim)', () async {
    service.takenNicknames.add('영화광');
    await typeAndCheckNickname('영화광');
    viewModel.onNicknameChanged('영화');

    viewModel.onNicknameChanged('  영화광  ');

    expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
  });

  test('응답을 기다리는 동안 입력을 바꾸면 늦게 온 이전 응답은 무시한다', () async {
    service.gate = Completer<void>();
    viewModel.onNicknameChanged('영화광');
    final pending = viewModel.checkNickname('영화광');

    viewModel.onNicknameChanged('영화광2');
    service.gate!.complete();
    await pending;

    expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
    expect(viewModel.nicknameErrorText, isNull);
  });

  test('빈 값은 요청하지 않는다', () async {
    viewModel.onNicknameChanged('   ');
    await viewModel.checkNickname('   ');

    expect(service.nicknameCalls, isEmpty);
    expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
  });

  test('닉네임과 이메일 상태는 서로 영향을 주지 않는다', () async {
    service.takenEmails.add('a@b.com');
    await typeAndCheckNickname('영화광');

    viewModel.onEmailChanged('a@b.com');
    await viewModel.checkEmail('a@b.com');

    expect(viewModel.emailCheckStatus, CheckStatus.duplicated);
    expect(viewModel.emailErrorText, '이미 사용 중인 이메일입니다.');
    expect(viewModel.nicknameCheckStatus, CheckStatus.available);
    expect(viewModel.nicknameErrorText, isNull);

    viewModel.onNicknameChanged('다른닉네임');
    expect(viewModel.emailCheckStatus, CheckStatus.duplicated);
  });

  test('화면이 사라진 뒤 도착한 응답은 notifyListeners를 부르지 않는다', () async {
    service.gate = Completer<void>();
    viewModel.onNicknameChanged('영화광');
    final pending = viewModel.checkNickname('영화광');

    viewModel.dispose();
    service.gate!.complete();

    // dispose된 ChangeNotifier에 notify하면 예외가 나므로, 끝까지 조용히 끝나야 한다.
    await pending;
    // tearDown의 dispose가 한 번 더 불리지 않도록 새 인스턴스로 바꿔 둔다.
    viewModel = SignUpViewModel(service);
  });
}
