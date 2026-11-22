import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/screens/sign_up_screen.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:provider/provider.dart';

import 'helpers/app_harness.dart';
import 'helpers/movielog_fakes.dart';
import 'helpers/tmdb_fakes.dart';

void main() {
  group('회원가입', () {
    Future<void> pumpSignUp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => SignUpViewModel(FakeSignUpService()),
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
      await tester.enterText(fields.at(2), 'Password1!');
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

    testWidgets('로그인 화면 → 회원가입 → 가입 완료 시 로그인 화면으로 돌아온다', (tester) async {
      final app = await pumpMovieLogApp(tester, signedIn: false);
      expect(app.location, '/login');

      await tester.tap(find.widgetWithText(TextButton, '회원가입'));
      await tester.pumpAndSettle();
      expect(app.location, '/register');

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '영화광');
      await tester.enterText(fields.at(1), 'movie@movielog.com');
      await tester.enterText(fields.at(2), 'Password1!');
      await tester.pump();
      await tester.tap(find.widgetWithText(MovieLogButton, '중복 확인').at(0));
      await tester.tap(find.widgetWithText(MovieLogButton, '중복 확인').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('가입하기'));
      await tester.pumpAndSettle();

      // 가입 응답에는 토큰이 없어서 바로 로그인되지 않고 로그인 화면으로 갑니다.
      expect(app.signUp.signUpRequests.single.nickname, '영화광');
      expect(app.location, '/login');
      expect(find.text('회원가입이 완료되었습니다. 로그인해 주세요.'), findsOneWidget);
    });
  });

  group('화면 전환', () {
    testWidgets('홈은 인기 영화 5개를 보여주고, 카드를 누르면 TMDB id로 상세에 간다', (tester) async {
      final app = await pumpMovieLogApp(tester);
      expect(app.location, '/home');
      expect(app.movies.popularRequests, 1);

      await tester.tap(find.text('영화 2'));
      await tester.pumpAndSettle();

      expect(app.location, '/movies/2');
      expect(find.text('평점 남기기'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(app.location, '/home');
      // 상세에서 돌아와도 홈 ViewModel이 유지되어 Popular를 다시 요청하지 않습니다.
      expect(app.movies.popularRequests, 1);

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
      final app = await pumpMovieLogApp(tester);

      await tester.tap(find.text('마이'));
      await tester.pumpAndSettle();

      expect(app.location, '/my');
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
    });

    testWidgets('없는 영화 주소로 들어오면 불러오기 실패 문구를 보여준다', (tester) async {
      final app = await pumpMovieLogApp(tester);
      await app.push('/movies/999');

      // 목록에서 넘긴 영화가 없으면 TMDB 상세를 다시 조회하고, 없으면 오류 문구를 보여줍니다.
      expect(find.text('영화를 불러오지 못했습니다.'), findsOneWidget);
    });
  });

  group('영화 목록과 상세', () {
    testWidgets('영화 탭에서 장르를 고르면 with_genres로 다시 요청한다', (tester) async {
      final app = await pumpMovieLogApp(tester);
      await app.go('/movies');
      expect(find.text('30편 · 인기순'), findsOneWidget);
      final requestsBefore = app.movies.discoverRequests.length;

      await tester.tap(find.widgetWithText(ChoiceChip, '드라마'));
      await tester.pumpAndSettle();

      final genreRequests = app.movies.discoverRequests.skip(requestsBefore);
      expect(genreRequests.first, (page: 1, genreId: 18));
      expect(genreRequests.every((request) => request.genreId == 18), isTrue);
      expect(find.text('22편 · 인기순'), findsOneWidget);
    });

    testWidgets('줄거리와 포스터가 없으면 안내 문구와 placeholder를 보여준다', (tester) async {
      final app = await pumpMovieLogApp(tester);
      await app.push(
        '/movies/7',
        extra: movieFixture(7, overview: '', posterPath: null),
      );

      expect(find.text('줄거리 정보가 없어요.'), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });

    testWidgets('평점 Dialog는 별점을 골라야 저장되고, 토큰 기반으로 등록한 뒤 Snackbar로 안내한다', (
      tester,
    ) async {
      final app = await pumpMovieLogApp(tester);
      await app.push('/movies/1', extra: movieFixture(1));

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

      expect(find.byType(Dialog), findsNothing);
      expect(find.textContaining('평점을 등록했습니다.'), findsOneWidget);
      // 등록 body에는 memberId가 없고, 응답 Rating이 이번 세션 목록에 들어갑니다.
      expect(app.ratings.createRequests.single.toJson(), {
        'movieId': 1,
        'score': 5,
      });
      expect(app.store.ratings.single.movieId, 1);
    });

    testWidgets('즐겨찾기를 누를 때마다 추가·삭제 Snackbar가 나온다', (tester) async {
      final app = await pumpMovieLogApp(tester);
      await app.push('/movies/1', extra: movieFixture(1));

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
