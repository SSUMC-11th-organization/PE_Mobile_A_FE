import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/main.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/sign_up_screen.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  // 영화 목록이 장르를 로컬에 저장하므로 테스트에서는 메모리 저장소를 씁니다.
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  // AppRouter.router는 static이라 테스트마다 시작 위치를 직접 맞춥니다.
  Future<void> pumpAppAt(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    AppRouter.router.go(location);
    await tester.pumpWidget(const MovieLogApp());
    await tester.pumpAndSettle();
  }

  group('회원가입', () {
    Future<void> pumpSignUp(WidgetTester tester) =>
        tester.pumpWidget(const MaterialApp(home: SignUpScreen()));

    ElevatedButton signUpButton(WidgetTester tester) => tester
        .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '가입하기'));

    testWidgets('모든 입력이 유효하고 약관에 동의해야 가입 버튼이 활성화된다', (tester) async {
      await pumpSignUp(tester);

      expect(signUpButton(tester).onPressed, isNull);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '무비러버');
      await tester.enterText(fields.at(1), 'movie@movielog.com');
      await tester.enterText(fields.at(2), 'password1');
      await tester.pump();

      expect(signUpButton(tester).onPressed, isNull);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(signUpButton(tester).onPressed, isNotNull);
    });

    testWidgets('잘못된 입력은 한국어 오류 메시지를 표시한다', (tester) async {
      await pumpSignUp(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '무');
      await tester.enterText(fields.at(1), 'movie');
      await tester.enterText(fields.at(2), '1234');
      await tester.pump();

      expect(find.text('닉네임은 두 글자 이상 입력해주세요.'), findsOneWidget);
      expect(find.text('올바른 이메일 형식이 아닙니다.'), findsOneWidget);
      expect(find.text('비밀번호는 8자 이상 입력해주세요.'), findsOneWidget);
    });
  });

  group('화면 전환', () {
    testWidgets('시작하기 → 회원가입 → 가입 완료 시 홈으로 이동한다', (tester) async {
      await pumpAppAt(tester, '/start');

      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();
      expect(find.text('회원가입'), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '무비러버');
      await tester.enterText(fields.at(1), 'movie@movielog.com');
      await tester.enterText(fields.at(2), 'password1');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('가입하기'));
      await tester.pumpAndSettle();

      expect(AppRouter.router.state.uri.path, '/home');
      expect(find.byType(NavigationBar), findsOneWidget);
      // go로 이동했기 때문에 되돌아갈 화면이 없습니다.
      expect(AppRouter.router.canPop(), isFalse);
    });

    testWidgets('영화 카드를 누르면 상세로 push 되고 뒤로 가기로 돌아온다', (tester) async {
      await pumpAppAt(tester, '/home');

      await tester.tap(find.text('미션 임프로버블'));
      await tester.pumpAndSettle();

      expect(AppRouter.router.state.uri.path, '/movies/2');
      expect(find.text('평점 남기기'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(AppRouter.router.state.uri.path, '/home');
    });

    testWidgets('NavigationBar 선택 상태가 현재 탭과 일치한다', (tester) async {
      await pumpAppAt(tester, '/home');

      await tester.tap(find.text('마이'));
      await tester.pumpAndSettle();

      expect(AppRouter.router.state.uri.path, '/my');
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
    });

    testWidgets('없는 영화 ID로 들어오면 안내 문구를 보여준다', (tester) async {
      await pumpAppAt(tester, '/movies/999');

      expect(find.text('영화를 찾을 수 없어요'), findsOneWidget);
    });
  });

  group('영화 목록과 상세', () {
    testWidgets('장르 Chip을 누르면 해당 장르 영화만 보인다', (tester) async {
      await pumpAppAt(tester, '/movies');
      expect(find.text('6편 · 최신순'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, '드라마'));
      await tester.pumpAndSettle();

      expect(find.text('2편 · 최신순'), findsOneWidget);
      expect(find.text('네 번째 오후'), findsOneWidget);
      expect(find.text('공허의 메아리'), findsNothing);
    });

    testWidgets('정렬 BottomSheet에서 제목순을 고르면 정렬이 바뀐다', (tester) async {
      await pumpAppAt(tester, '/movies');

      await tester.tap(find.byTooltip('정렬'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('제목순'));
      await tester.pumpAndSettle();

      expect(find.text('6편 · 제목순'), findsOneWidget);
    });

    testWidgets('평점 Dialog는 별점을 골라야 저장되고 Snackbar로 안내한다', (tester) async {
      await pumpAppAt(tester, '/movies/1');

      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(ElevatedButton, '저장');
      expect(tester.widget<ElevatedButton>(saveButton).onPressed, isNull);

      await tester.tap(
        find
            .descendant(
              of: find.byType(RatingBar),
              matching: find.byIcon(Icons.star),
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(saveButton).onPressed, isNotNull);

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('점을 남겼어요'), findsOneWidget);
      expect(find.textContaining('내 평점'), findsOneWidget);
    });

    testWidgets('즐겨찾기를 누를 때마다 추가·삭제 Snackbar가 나온다', (tester) async {
      await pumpAppAt(tester, '/movies/1');

      await tester.tap(find.byTooltip('즐겨찾기 추가'));
      await tester.pump();
      expect(find.text('즐겨찾기에 추가했어요'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      await tester.tap(find.byTooltip('즐겨찾기 삭제'));
      await tester.pump();
      expect(find.text('즐겨찾기에서 삭제했어요'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });
  });
}
