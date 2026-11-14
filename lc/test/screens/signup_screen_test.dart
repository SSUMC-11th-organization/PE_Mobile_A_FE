import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/view_models/learning_member_session.dart';
import 'package:movielog/widgets/movielog_button.dart';

import '../test_helpers.dart';
import '../week6_helpers.dart';

void main() {
  late FakeSignUpService members;
  late LearningMemberSession session;

  /// 폰 크기(390 x 900)에서 회원가입 화면을 연다.
  Future<void> openSignUp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    members = FakeSignUpService();
    session = LearningMemberSession();
    await tester.pumpWidget(
      MovieLogApp(
        movieService: FakeTmdbMovieService(),
        signUpService: members,
        memberSession: session,
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

  Finder submitButton() => find.byType(MovieLogButton).last;

  bool submitEnabled(WidgetTester tester) => enabled(
    tester,
    find.descendant(of: submitButton(), matching: find.byType(ElevatedButton)),
  );

  Future<void> fillForm(
    WidgetTester tester, {
    String password = 'Password1!',
  }) async {
    await typeNickname(tester, '영화광');
    await tester.enterText(field(1), 'lc@example.com');
    await tester.enterText(field(2), password);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
  }

  /// 닉네임·이메일 중복 확인을 둘 다 통과시킨다.
  Future<void> verifyBoth(WidgetTester tester) async {
    await tester.tap(checkButton(0));
    await tester.pumpAndSettle();
    await tester.tap(checkButton(1));
    await tester.pumpAndSettle();
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.ensureVisible(submitButton());
    await tester.tap(submitButton());
    await tester.pump();
  }

  group('가입하기 활성화 조건', () {
    testWidgets('모든 입력이 유효해도 중복 확인 전에는 비활성이다', (tester) async {
      await openSignUp(tester);

      await fillForm(tester);

      expect(submitEnabled(tester), isFalse);
    });

    testWidgets('닉네임만 확인하면 아직 비활성이고, 이메일까지 확인해야 활성화된다', (tester) async {
      await openSignUp(tester);
      await fillForm(tester);

      await tester.tap(checkButton(0));
      await tester.pumpAndSettle();
      expect(submitEnabled(tester), isFalse);

      await tester.tap(checkButton(1));
      await tester.pumpAndSettle();
      expect(submitEnabled(tester), isTrue);
    });

    testWidgets('확인 뒤 닉네임을 바꾸면 이전 확인이 무효화되어 다시 비활성이다', (tester) async {
      await openSignUp(tester);
      await fillForm(tester);
      await verifyBoth(tester);
      expect(submitEnabled(tester), isTrue);

      await typeNickname(tester, '영화광2');

      expect(submitEnabled(tester), isFalse);
    });

    testWidgets('중복으로 확인된 값이 남아 있으면 가입할 수 없다', (tester) async {
      await openSignUp(tester);
      members.takenNicknames.add('영화광');
      await fillForm(tester);

      await verifyBoth(tester);

      expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
      expect(submitEnabled(tester), isFalse);
    });

    testWidgets('비밀번호 규칙(대·소문자·숫자·특수문자)을 지키지 않으면 비활성이고 안내가 보인다', (tester) async {
      await openSignUp(tester);
      await fillForm(tester, password: 'password1');
      await verifyBoth(tester);

      expect(submitEnabled(tester), isFalse);
      expect(find.textContaining('특수문자'), findsWidgets);
    });

    testWidgets('약관에 동의하지 않으면 비활성이다', (tester) async {
      await openSignUp(tester);
      await fillForm(tester);
      await verifyBoth(tester);
      expect(submitEnabled(tester), isTrue);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(submitEnabled(tester), isFalse);
    });
  });

  group('회원가입 제출', () {
    Future<void> readyToSubmit(WidgetTester tester) async {
      await openSignUp(tester);
      await fillForm(tester);
      await verifyBoth(tester);
    }

    testWidgets('성공하면 응답의 memberId를 세션에 저장하고 영화 목록으로 이동한다', (tester) async {
      await readyToSubmit(tester);
      members.signUpMemberId = 321;

      await tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(members.signUpCalls, hasLength(1));
      expect(members.signUpCalls.single.email, 'lc@example.com');
      expect(members.signUpCalls.single.nickname, '영화광');
      expect(session.memberId, 321);
      expect(
        AppRouter.router.routerDelegate.currentConfiguration.uri.path,
        '/movies',
      );
    });

    testWidgets('제출 중에는 버튼이 로딩 상태로 잠기고 연속 탭이 요청을 늘리지 않는다', (tester) async {
      await readyToSubmit(tester);
      members.signUpGate = Completer<void>();

      await tapSubmit(tester);
      expect(
        find.descendant(
          of: submitButton(),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(submitEnabled(tester), isFalse);

      await tester.tap(submitButton(), warnIfMissed: false);
      await tester.pump();
      expect(members.signUpCalls, hasLength(1));

      members.signUpGate!.complete();
      await tester.pumpAndSettle();
      expect(session.memberId, 101);
    });

    testWidgets('비밀번호 형식 400은 비밀번호 입력칸의 에러가 되고, 고치면 사라진다', (tester) async {
      await readyToSubmit(tester);
      members.signUpError = commonError(
        400,
        'COMMON400',
        '비밀번호는 서버 기준을 만족해야 합니다.',
      );

      await tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text('비밀번호는 서버 기준을 만족해야 합니다.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(session.memberId, isNull);

      await tester.enterText(field(2), 'Password2!');
      await tester.pump();
      expect(find.text('비밀번호는 서버 기준을 만족해야 합니다.'), findsNothing);
    });

    testWidgets('최종 중복 409는 Snackbar로 안내하고 가입 화면에 머문다', (tester) async {
      await readyToSubmit(tester);
      members.signUpError = commonError(
        409,
        'COMMON409',
        '이미 사용 중인 이메일입니다.',
      );

      await tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text('이미 사용 중인 이메일입니다.'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(session.memberId, isNull);
      expect(
        AppRouter.router.routerDelegate.currentConfiguration.uri.path,
        '/register',
      );
      // 제출이 끝났으므로 다시 제출할 수 있다.
      expect(submitEnabled(tester), isTrue);
    });

    testWidgets('통신 실패도 Snackbar로 안내하고 다시 시도할 수 있다', (tester) async {
      await readyToSubmit(tester);
      members.signUpError = dioFailure('/v6/members');

      await tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('회원가입에 실패'), findsOneWidget);
      expect(submitEnabled(tester), isTrue);
    });

    testWidgets('응답에 memberId가 없으면 가입 완료로 처리하지 않는다', (tester) async {
      await readyToSubmit(tester);
      members.signUpWithoutResult = true;

      await tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('가입 결과를 확인하지 못했습니다'), findsOneWidget);
      expect(session.memberId, isNull);
      expect(
        AppRouter.router.routerDelegate.currentConfiguration.uri.path,
        '/register',
      );
    });
  });
}
