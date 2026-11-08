import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/main.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/sign_up_screen.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/movielog_fakes.dart';
import 'helpers/tmdb_fakes.dart';

void main() {
  // 영화 목록이 장르를 로컬에 저장하므로 테스트에서는 메모리 저장소를 씁니다.
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  // AppRouter.router는 static이라 테스트마다 시작 위치를 직접 맞춥니다.
  Future<FakeTmdbMovieService> pumpAppAt(
    WidgetTester tester,
    String location, {
    Object? extra,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final service = FakeTmdbMovieService();
    AppRouter.router.go(location, extra: extra);
    await tester.pumpWidget(
      MovieLogApp(
        movieService: service,
        memberCheckService: FakeMemberCheckService(),
        ratingApiService: FakeRatingApiService(),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  // 닉네임·이메일을 입력하고 각각 중복 확인을 눌러 '사용 가능'까지 만듭니다.
  Future<void> fillValidSignUp(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '영화광');
    await tester.enterText(fields.at(1), 'movie@movielog.com');
    await tester.enterText(fields.at(2), 'password1');
    await tester.pump();
    await tester.tap(find.widgetWithText(MovieLogButton, '중복 확인').at(0));
    await tester.tap(find.widgetWithText(MovieLogButton, '중복 확인').at(1));
    await tester.pumpAndSettle();
  }

  group('회원가입', () {
    Future<void> pumpSignUp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => SignUpViewModel(FakeMemberCheckService()),
            child: const SignUpScreen(),
          ),
        ),
      );
    }

    ElevatedButton signUpButton(WidgetTester tester) => tester
        .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '가입하기'));

    testWidgets('형식이 유효하고 중복 확인을 마치고 약관에 동의해야 가입 버튼이 활성화된다', (tester) async {
      await pumpSignUp(tester);

      expect(signUpButton(tester).onPressed, isNull);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '영화광');
      await tester.enterText(fields.at(1), 'movie@movielog.com');
      await tester.enterText(fields.at(2), 'password1');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // 형식이 맞고 약관에 동의해도 중복 확인 전이면 가입할 수 없습니다.
      expect(signUpButton(tester).onPressed, isNull);

      await tester.tap(find.widgetWithText(MovieLogButton, '중복 확인').at(0));
      await tester.tap(find.widgetWithText(MovieLogButton, '중복 확인').at(1));
      await tester.pumpAndSettle();

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

      await fillValidSignUp(tester);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('가입하기'));
      await tester.pumpAndSettle();

      expect(AppRouter.router.state.uri.path, '/home');
      expect(find.byType(NavigationBar), findsOneWidget);
      // go로 이동했기 때문에 되돌아갈 화면이 없습니다.
      expect(AppRouter.router.canPop(), isFalse);
    });

    testWidgets('홈은 인기 영화 5개를 보여주고, 카드를 누르면 TMDB id로 상세에 간다', (tester) async {
      final service = await pumpAppAt(tester, '/home');
      expect(service.popularRequests, 1);

      await tester.tap(find.text('영화 2'));
      await tester.pumpAndSettle();

      expect(AppRouter.router.state.uri.path, '/movies/2');
      expect(find.text('평점 남기기'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(AppRouter.router.state.uri.path, '/home');
      // 상세에서 돌아와도 홈 ViewModel이 유지되어 Popular를 다시 요청하지 않습니다.
      expect(service.popularRequests, 1);

      // 가로 목록은 보이는 카드만 그리므로 끝까지 스크롤해서 5개에서 끝나는지 확인합니다.
      final popularList = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.right,
      );
      await tester.scrollUntilVisible(
        find.text('영화 5'),
        200,
        scrollable: popularList,
      );
      expect(find.text('영화 5'), findsOneWidget);
      expect(find.text('영화 6'), findsNothing);
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

    testWidgets('영화 정보 없이 주소로 들어오면 안내 문구를 보여준다', (tester) async {
      await pumpAppAt(tester, '/movies/999');

      expect(find.text('영화를 찾을 수 없어요'), findsOneWidget);
    });
  });

  group('영화 목록과 상세', () {
    testWidgets('영화 탭에서 장르를 고르면 with_genres로 다시 요청한다', (tester) async {
      final service = await pumpAppAt(tester, '/movies');
      expect(find.text('30편 · 인기순'), findsOneWidget);
      final requestsBefore = service.discoverRequests.length;

      await tester.tap(find.widgetWithText(ChoiceChip, '드라마'));
      await tester.pumpAndSettle();

      final genreRequests = service.discoverRequests.skip(requestsBefore);
      expect(genreRequests.first, (page: 1, genreId: 18));
      expect(genreRequests.every((request) => request.genreId == 18), isTrue);
      expect(find.text('22편 · 인기순'), findsOneWidget);
    });

    testWidgets('줄거리와 포스터가 없으면 안내 문구와 placeholder를 보여준다', (tester) async {
      await pumpAppAt(
        tester,
        '/movies/7',
        extra: movieFixture(7, overview: '', posterPath: null),
      );

      expect(find.text('줄거리 정보가 없어요.'), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });

    testWidgets('평점 Dialog는 별점을 골라야 저장되고 Snackbar로 안내한다', (tester) async {
      await pumpAppAt(tester, '/movies/1', extra: movieFixture(1));

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
      await pumpAppAt(tester, '/movies/1', extra: movieFixture(1));

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
