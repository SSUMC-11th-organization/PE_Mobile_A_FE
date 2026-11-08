import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/main.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/sign_up_screen.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:provider/provider.dart';

import 'helpers/movielog_fakes.dart';
import 'helpers/tmdb_fakes.dart';

void main() {
  void useTallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  group('회원가입 중복 확인', () {
    late FakeMemberCheckService service;

    Future<void> pumpSignUp(WidgetTester tester) async {
      useTallView(tester);
      service = FakeMemberCheckService();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => SignUpViewModel(service),
            child: const SignUpScreen(),
          ),
        ),
      );
    }

    Finder nicknameField() => find.byType(TextFormField).at(0);
    Finder nicknameCheckButton() => find.byType(MovieLogButton).at(0);
    ElevatedButton buttonOf(WidgetTester tester, Finder movieLogButton) =>
        tester.widget<ElevatedButton>(
          find.descendant(
            of: movieLogButton,
            matching: find.byType(ElevatedButton),
          ),
        );

    testWidgets('통신 중에는 버튼이 비활성화되고 인디케이터만 보인다', (tester) async {
      await pumpSignUp(tester);
      await tester.enterText(nicknameField(), '영화광');
      await tester.pump();

      service.gate = Completer<void>();
      await tester.tap(nicknameCheckButton());
      await tester.pump();

      expect(buttonOf(tester, nicknameCheckButton()).onPressed, isNull);
      expect(
        find.descendant(
          of: nicknameCheckButton(),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: nicknameCheckButton(),
          matching: find.text('중복 확인'),
        ),
        findsNothing,
      );

      service.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('사용할 수 있는 닉네임입니다.'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('중복이면 입력창 에러가 되고, 입력을 바꾸면 에러가 사라진다', (tester) async {
      await pumpSignUp(tester);
      await tester.enterText(nicknameField(), '무비러버');
      await tester.pump();
      await tester.tap(nicknameCheckButton());
      await tester.pumpAndSettle();

      expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
      // 중복이라고 답한 즉시 값을 바꾸기 전까지 다시 확인할 수 없습니다.
      expect(buttonOf(tester, nicknameCheckButton()).onPressed, isNull);

      await tester.enterText(nicknameField(), '무비러버2');
      await tester.pump();

      expect(find.text('이미 사용 중인 닉네임입니다.'), findsNothing);
      expect(buttonOf(tester, nicknameCheckButton()).onPressed, isNotNull);

      await tester.enterText(nicknameField(), '무비러버');
      await tester.pump();

      expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
      expect(buttonOf(tester, nicknameCheckButton()).onPressed, isNull);
      expect(service.nicknameRequests, ['무비러버']);
    });

    testWidgets('통신 실패는 중복과 다른 문구로 보여준다', (tester) async {
      await pumpSignUp(tester);
      service.error = networkError('/v5/members/nickname/x');
      await tester.enterText(nicknameField(), '영화광');
      await tester.pump();
      await tester.tap(nicknameCheckButton());
      await tester.pumpAndSettle();

      expect(find.text('중복 확인에 실패했습니다. 다시 시도해 주세요.'), findsOneWidget);
      expect(find.text('이미 사용 중인 닉네임입니다.'), findsNothing);
    });

    testWidgets('width null은 글자만큼, double.infinity는 Form 전체 너비를 쓴다', (
      tester,
    ) async {
      await pumpSignUp(tester);

      final checkWidth = tester.getSize(nicknameCheckButton()).width;
      final submitWidth = tester
          .getSize(find.widgetWithText(MovieLogButton, '가입하기'))
          .width;
      final formWidth = tester.getSize(find.byType(Form)).width;

      expect(checkWidth, lessThan(formWidth / 2));
      expect(submitWidth, formWidth);
    });
  });

  group('내가 등록한 평점', () {
    Future<FakeRatingApiService> pumpAppAt(
      WidgetTester tester,
      String location, {
      FakeRatingApiService? ratings,
    }) async {
      useTallView(tester);
      final ratingService = ratings ?? FakeRatingApiService();
      AppRouter.router.go(location);
      await tester.pumpWidget(
        MovieLogApp(
          movieService: FakeTmdbMovieService(),
          memberCheckService: FakeMemberCheckService(),
          ratingApiService: ratingService,
        ),
      );
      await tester.pumpAndSettle();
      return ratingService;
    }

    testWidgets('마이페이지에서 진입하면 하단 탭 없이 memberId 1의 평점을 보여준다', (tester) async {
      final ratings = await pumpAppAt(tester, '/my');

      await tester.tap(find.text('내가 등록한 평점'));
      await tester.pumpAndSettle();

      expect(AppRouter.router.state.uri.path, '/my/ratings');
      expect(find.byType(NavigationBar), findsNothing);
      expect(ratings.requestedMemberIds.single, 1);
      expect(find.text('영화 1'), findsOneWidget);
      expect(find.text('최고의 영화!'), findsOneWidget);
      expect(find.text('2026.09.06'), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(AppRouter.router.state.uri.path, '/my');
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('평점이 없으면 Empty 안내를 보여준다', (tester) async {
      await pumpAppAt(
        tester,
        '/my/ratings',
        ratings: FakeRatingApiService(ratings: []),
      );

      expect(find.text('아직 등록한 평점이 없어요.'), findsOneWidget);
    });

    testWidgets('실패하면 문구와 고정 너비 다시 시도 버튼을 보여주고, 재시도는 성공한다', (tester) async {
      final ratings = FakeRatingApiService()
        ..error = httpError('/v5/members/1/ratings', 404);
      await pumpAppAt(tester, '/my/ratings', ratings: ratings);

      expect(find.text('존재하지 않는 회원입니다.'), findsOneWidget);
      final retry = find.widgetWithText(MovieLogButton, '다시 시도');
      expect(tester.getSize(retry).width, 120);

      ratings.error = null;
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(find.text('최고의 영화!'), findsOneWidget);
    });
  });
}
