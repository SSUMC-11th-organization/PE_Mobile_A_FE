import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/movie_log_app.dart';
import 'package:movielog/router/app_router.dart';

Future<void> pumpSignUpScreen(WidgetTester tester) async {
  await tester.pumpWidget(const MovieLogApp());
  AppRouter.router.go('/register');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('빈 값으로는 가입 버튼이 비활성화된다', (WidgetTester tester) async {
    await pumpSignUpScreen(tester);

    final submitButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '가입하기'),
    );
    expect(submitButton.onPressed, isNull);
  });

  testWidgets('형식이 잘못된 입력에는 한국어 오류 메시지가 표시된다', (WidgetTester tester) async {
    await pumpSignUpScreen(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'a');
    await tester.enterText(find.byType(TextFormField).at(1), 'test@');
    await tester.enterText(find.byType(TextFormField).at(2), '1234');
    await tester.pump();

    expect(find.text('닉네임은 2자 이상이어야 합니다.'), findsOneWidget);
    expect(find.text('올바른 이메일 형식이 아닙니다.'), findsOneWidget);
    expect(find.text('비밀번호는 8자 이상이어야 합니다.'), findsOneWidget);

    final submitButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '가입하기'),
    );
    expect(submitButton.onPressed, isNull);
  });

  testWidgets('모든 입력이 유효하면 가입 버튼이 활성화되고 제출된다', (WidgetTester tester) async {
    await pumpSignUpScreen(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '무비러버');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'movie@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'password1234');
    await tester.pump();

    final submitButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '가입하기'),
    );
    expect(submitButton.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(ElevatedButton, '가입하기'));
    await tester.pump();

    expect(find.text('회원가입이 완료되었습니다.'), findsOneWidget);
  });

  testWidgets('좁은 화면에서도 RenderFlex overflow 없이 렌더링된다', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    await pumpSignUpScreen(tester);

    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('넓은 화면에서 Form의 최대 너비가 560으로 제한된다', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 800));
    await pumpSignUpScreen(tester);

    final maxWidths = tester
        .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
        .map((box) => box.constraints.maxWidth);
    expect(maxWidths, contains(560));

    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });
}
