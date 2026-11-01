import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/widgets/movielog_button.dart';

import '../test_helpers.dart';
import '../week6_helpers.dart';

void main() {
  late FakeMemberCheckService members;

  /// 폰 크기(390 x 900)에서 회원가입 화면을 연다.
  Future<void> openSignUp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    members = FakeMemberCheckService();
    await tester.pumpWidget(
      MovieLogApp(
        movieService: FakeTmdbMovieService(),
        memberCheckService: members,
      ),
    );
    AppRouter.router.go('/register');
    await tester.pumpAndSettle();
  }

  Finder field(int index) => find.byType(TextFormField).at(index);
  Finder checkButton(int index) =>
      find.widgetWithText(ElevatedButton, '중복 확인').at(index);

  bool enabled(WidgetTester tester, Finder button) =>
      tester.widget<ElevatedButton>(button).onPressed != null;

  Future<void> typeNickname(WidgetTester tester, String text) async {
    await tester.enterText(field(0), text);
    await tester.pump();
  }

  testWidgets('확인 전에는 두 중복 확인 버튼이 입력창 바깥에 있고, 입력 전에는 비활성이다', (tester) async {
    await openSignUp(tester);

    expect(find.widgetWithText(ElevatedButton, '중복 확인'), findsNWidgets(2));
    expect(enabled(tester, checkButton(0)), isFalse);

    await typeNickname(tester, '영화광');
    expect(enabled(tester, checkButton(0)), isTrue);

    // 버튼은 입력창 오른쪽 바깥에 있고 서로 겹치지 않는다.
    final fieldRect = tester.getRect(field(0));
    final buttonRect = tester.getRect(checkButton(0));
    expect(buttonRect.left, greaterThanOrEqualTo(fieldRect.right + 8));
  });

  testWidgets('통신 중에는 버튼 중앙에 인디케이터만 보이고 비활성이다', (tester) async {
    await openSignUp(tester);
    members.gate = Completer<void>();
    await typeNickname(tester, '영화광');

    await tester.tap(checkButton(0));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(MovieLogButton).at(0),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    // 라벨 '중복 확인'은 이메일 쪽 버튼에만 남는다.
    expect(find.text('중복 확인'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(find.byType(ElevatedButton).at(0))
          .onPressed,
      isNull,
    );

    members.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('사용 가능하면 안내 문구가 보인다', (tester) async {
    await openSignUp(tester);
    await typeNickname(tester, '영화광');

    await tester.tap(checkButton(0));
    await tester.pumpAndSettle();

    expect(find.text('사용할 수 있는 닉네임입니다.'), findsOneWidget);
    expect(find.text('이미 사용 중인 닉네임입니다.'), findsNothing);
  });

  testWidgets('중복이면 입력창이 에러 상태가 되고 버튼이 비활성이다', (tester) async {
    await openSignUp(tester);
    members.takenNicknames.add('영화광');
    await typeNickname(tester, '영화광');

    await tester.tap(checkButton(0));
    await tester.pumpAndSettle();

    expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
    expect(find.text('사용할 수 있는 닉네임입니다.'), findsNothing);
    expect(enabled(tester, checkButton(0)), isFalse);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('입력을 바꾸면 이전 결과가 사라지고, 같은 값을 다시 쓰면 요청 없이 에러로 돌아온다', (tester) async {
    await openSignUp(tester);
    members.takenNicknames.add('영화광');
    await typeNickname(tester, '영화광');
    await tester.tap(checkButton(0));
    await tester.pumpAndSettle();
    expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);

    await typeNickname(tester, '영화광팬');
    expect(find.text('이미 사용 중인 닉네임입니다.'), findsNothing);
    expect(enabled(tester, checkButton(0)), isTrue);

    await typeNickname(tester, '영화광');
    expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
    expect(enabled(tester, checkButton(0)), isFalse);
    expect(members.nicknameCalls, hasLength(1));
  });

  testWidgets('사용 가능 결과도 입력을 바꾸면 사라진다', (tester) async {
    await openSignUp(tester);
    await typeNickname(tester, '영화광');
    await tester.tap(checkButton(0));
    await tester.pumpAndSettle();
    expect(find.text('사용할 수 있는 닉네임입니다.'), findsOneWidget);

    await typeNickname(tester, '영화광2');

    expect(find.text('사용할 수 있는 닉네임입니다.'), findsNothing);
  });

  testWidgets('통신 실패는 중복과 다른 문구로 보인다', (tester) async {
    await openSignUp(tester);
    members.fail = true;
    await typeNickname(tester, '영화광');

    await tester.tap(checkButton(0));
    await tester.pumpAndSettle();

    expect(find.text('중복 확인에 실패했습니다. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('이미 사용 중인 닉네임입니다.'), findsNothing);
    // 실패 뒤에는 다시 누를 수 있다.
    expect(enabled(tester, checkButton(0)), isTrue);
  });

  testWidgets('이메일도 같은 규칙으로 닉네임과 따로 동작한다', (tester) async {
    await openSignUp(tester);
    members.takenEmails.add('a@b.com');
    await typeNickname(tester, '영화광');
    await tester.enterText(field(1), 'a@b.com');
    await tester.pump();

    await tester.tap(checkButton(1));
    await tester.pumpAndSettle();

    expect(find.text('이미 사용 중인 이메일입니다.'), findsOneWidget);
    expect(find.text('이미 사용 중인 닉네임입니다.'), findsNothing);
    expect(enabled(tester, checkButton(0)), isTrue);
    expect(enabled(tester, checkButton(1)), isFalse);
  });

  testWidgets('중복 확인 버튼은 내용 크기, 가입하기 버튼은 전체 너비다', (tester) async {
    await openSignUp(tester);

    final checkWidth = tester.getSize(find.byType(MovieLogButton).at(0)).width;
    final submitWidth = tester
        .getSize(find.widgetWithText(MovieLogButton, '가입하기'))
        .width;

    expect(checkWidth, lessThan(120));
    expect(submitWidth, 390 - 32); // 화면 너비 - 좌우 패딩 16
  });

  testWidgets('중복으로 확인된 값이 남아 있으면 가입할 수 없다', (tester) async {
    await openSignUp(tester);
    members.takenNicknames.add('영화광');
    await typeNickname(tester, '영화광');
    await tester.enterText(field(1), 'a@b.com');
    await tester.enterText(field(2), 'password1');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    Finder submit() => find.widgetWithText(ElevatedButton, '가입하기');
    expect(enabled(tester, submit()), isTrue);

    await tester.tap(checkButton(0));
    await tester.pumpAndSettle();

    expect(enabled(tester, submit()), isFalse);
  });
}
