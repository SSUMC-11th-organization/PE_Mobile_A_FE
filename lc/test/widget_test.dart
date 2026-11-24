import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/screens/edit_profile_screen.dart';
import 'package:movielog/screens/login_screen.dart';
import 'package:movielog/screens/movie_detail_screen.dart';
import 'package:movielog/screens/my_ratings_screen.dart';
import 'package:movielog/screens/splash_screen.dart';
import 'package:movielog/widgets/hero_banner.dart';
import 'package:movielog/widgets/movie_rating_input.dart';
import 'package:movielog/widgets/rating_dialog.dart';

import 'week6_helpers.dart';

const _expiredText = '로그인이 만료됐어요. 다시 로그인해 주세요.';

void main() {
  late AppHarness app;

  setUp(() => app = AppHarness());

  Finder stars() => find.descendant(
    of: find.byType(MovieRatingInput),
    matching: find.byIcon(Icons.star_rounded),
  );

  /// Dialog 안의 확인 버튼. 저장 중에는 라벨이 사라지므로 타입으로 찾는다.
  Finder confirmButton() => find.descendant(
    of: find.byType(RatingDialog),
    matching: find.byType(ElevatedButton),
  );

  Finder deleteConfirmButton() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(ElevatedButton),
  );

  /// 홈 배너(파이트 클럽, TMDB id 550)에서 상세로 들어가 [score]점을 등록한다.
  Future<void> rateFromDetail(
    WidgetTester tester, {
    int score = 4,
    String? comment,
  }) async {
    await app.go(tester, '/home');
    await tester.tap(find.byType(HeroBanner));
    await tester.pumpAndSettle();
    await tester.tap(find.text('평점 남기기'));
    await tester.pumpAndSettle();
    await tester.tap(stars().at(score - 1));
    await tester.pump();
    if (comment != null) {
      await tester.enterText(find.byType(TextField), comment);
    }
    await tester.tap(confirmButton());
    await tester.pumpAndSettle();
  }

  group('로그인', () {
    testWidgets('로그인하지 않은 상태로 시작하면 로그인 화면이 보인다', (tester) async {
      await app.pump(tester, signedIn: false);

      expect(app.location(tester), '/login');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(app.members.fetchCalls, 0); // 토큰이 없으면 서버에 묻지 않는다.
    });

    testWidgets('로그인에 성공하면 Router가 홈으로 보내고, 마이페이지에 GET me의 내 정보가 보인다', (tester) async {
      await app.pump(tester, signedIn: false);

      await app.login(tester);

      expect(app.location(tester), '/home');
      expect(app.tokens.token, 'fake-access-token');
      expect(app.auth.calls.single.email, 'lc@example.com');
      expect(app.members.fetchCalls, 1); // MainScreen이 한 번 불러온다.

      await app.go(tester, '/my');
      expect(find.text('영화광'), findsOneWidget);
      expect(find.text('lc@example.com'), findsOneWidget);
      expect(find.text('2026.10.10 가입'), findsOneWidget);
      // 토큰 원문은 어느 화면에도 표시하지 않는다.
      expect(find.textContaining('fake-access-token'), findsNothing);
    });

    testWidgets('틀린 이메일·비밀번호(AUTH401_1)는 Form 아래 문구이고, 만료 Snackbar는 뜨지 않는다', (tester) async {
      await app.pump(tester, signedIn: false);
      app.auth.loginError = commonError(401, 'AUTH401_1', '이메일 또는 비밀번호가 올바르지 않습니다.');

      await app.login(tester);

      expect(app.location(tester), '/login');
      expect(find.text('이메일 또는 비밀번호를 확인해 주세요.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(app.tokens.token, isNull);
    });

    testWidgets('네트워크 실패는 입력 오류와 다른 문구다', (tester) async {
      await app.pump(tester, signedIn: false);
      app.auth.loginError = dioFailure('/v8/auth/login');

      await app.login(tester);

      expect(find.textContaining('로그인 요청에 실패했어요'), findsOneWidget);
      expect(find.text('이메일 또는 비밀번호를 확인해 주세요.'), findsNothing);
    });

    testWidgets('요청 중에는 버튼이 로딩 상태로 비활성이고 입력칸도 잠긴다', (tester) async {
      await app.pump(tester, signedIn: false);
      app.auth.gate = Completer<void>();

      await app.login(tester, settle: false);

      final button = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byType(LoginScreen),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<TextFormField>(find.byType(TextFormField).first).enabled, isFalse);
      expect(app.auth.calls, hasLength(1));

      app.auth.gate!.complete();
      await tester.pumpAndSettle();
      expect(app.location(tester), '/home');
    });

    testWidgets('이메일과 비밀번호를 비우면 요청하지 않는다', (tester) async {
      await app.pump(tester, signedIn: false);

      await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
      await tester.pump();

      expect(find.text('이메일을 입력해 주세요.'), findsOneWidget);
      expect(find.text('비밀번호를 입력해 주세요.'), findsOneWidget);
      expect(app.auth.calls, isEmpty);
    });

    testWidgets('이메일 저장을 체크하면 이메일만 저장하고, 다음에 채워져 있다 (비밀번호는 저장하지 않는다)', (tester) async {
      await app.pump(tester, signedIn: false);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      await app.login(tester);
      expect(app.savedEmail.email, 'lc@example.com');
      expect(app.savedEmail.email, isNot(contains('Password1!')));

      // 로그아웃해서 로그인 화면으로 돌아오면 저장한 이메일이 채워져 있다.
      await app.go(tester, '/my');
      await tester.tap(find.byTooltip('로그아웃'));
      await tester.pumpAndSettle();
      final email = tester.widget<TextFormField>(find.byType(TextFormField).at(0));
      final password = tester.widget<TextFormField>(find.byType(TextFormField).at(1));
      expect(email.controller!.text, 'lc@example.com');
      expect(password.controller!.text, isEmpty);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    });

    testWidgets('이메일 저장을 체크하지 않으면 저장된 이메일을 지운다', (tester) async {
      app.savedEmail.email = 'old@example.com';
      await app.pump(tester, signedIn: false);
      await tester.tap(find.byType(Checkbox)); // 체크 해제
      await tester.pump();

      await app.login(tester);

      expect(app.savedEmail.email, isNull);
    });
  });

  group('앱 재시작 세션 복원', () {
    testWidgets('토큰이 있으면 GET me 검증이 끝날 때까지 스플래시만 보이고, 끝나면 홈으로 들어간다', (tester) async {
      app.members.fetchGate = Completer<void>();

      await app.pump(tester, settle: false);

      expect(app.location(tester), '/start');
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('FLUTTER 8주차'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // 확인 전에 로그인 화면이나 홈이 잠깐 보이지 않는다.
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(HeroBanner), findsNothing);

      app.members.fetchGate!.complete();
      await tester.pumpAndSettle();

      expect(app.location(tester), '/home');
      expect(app.members.fetchCalls, 1); // 복원이 member를 채웠으므로 다시 부르지 않는다.
    });

    testWidgets('네트워크 실패면 토큰을 지우지 않고 재시도 화면을 보여주며, 다시 시도하면 홈으로 간다', (tester) async {
      app.members
        ..fetchError = dioFailure('/v8/members/me')
        ..fetchFailTimes = 1;

      await app.pump(tester);

      expect(app.location(tester), '/start');
      expect(find.text('로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
      expect(app.tokens.token, 'stored-token');
      expect(find.byType(LoginScreen), findsNothing);

      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(app.location(tester), '/home');
    });

    testWidgets('토큰이 무효·만료면 토큰을 지우고 로그인 화면에서 한 번 안내한다', (tester) async {
      app.members.fetchError = expiredError('AUTH401_4');

      await app.pump(tester);

      expect(app.location(tester), '/login');
      expect(find.text(_expiredText), findsOneWidget);
      expect(app.tokens.token, isNull);

      // 안내는 한 번만 뜬다. 사라진 뒤 화면이 다시 그려져도 반복되지 않는다.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text(_expiredText), findsNothing);
    });
  });

  group('로그아웃과 보호 화면', () {
    testWidgets('마이페이지 로그아웃은 토큰과 내 정보를 지우고 로그인으로 보낸다. 만료 안내는 없다', (tester) async {
      await app.pump(tester);
      await app.go(tester, '/my');

      await tester.tap(find.byTooltip('로그아웃'));
      await tester.pumpAndSettle();

      expect(app.location(tester), '/login');
      expect(app.tokens.token, isNull);
      expect(find.text(_expiredText), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('로그아웃 뒤에는 보호 화면 주소로 가도 로그인 화면으로 돌아온다', (tester) async {
      await app.pump(tester);
      await app.go(tester, '/my');
      await tester.tap(find.byTooltip('로그아웃'));
      await tester.pumpAndSettle();

      for (final path in ['/home', '/my', '/my/ratings', '/my/profile/edit', '/movies/550']) {
        await app.go(tester, path);
        expect(app.location(tester), '/login', reason: path);
      }
      expect(find.byType(MyRatingsScreen), findsNothing);
    });

    testWidgets('로그인한 상태에서는 로그인·회원가입 화면으로 가도 홈으로 돌아온다', (tester) async {
      await app.pump(tester);

      await app.go(tester, '/login');
      expect(app.location(tester), '/home');
      await app.go(tester, '/register');
      expect(app.location(tester), '/home');
    });

    testWidgets('로그아웃하면 이번 세션에 등록한 평점이 다음 로그인에 남지 않는다', (tester) async {
      await app.pump(tester);
      await rateFromDetail(tester);
      await app.go(tester, '/my/ratings');
      expect(find.text('파이트 클럽'), findsOneWidget);

      await app.go(tester, '/my');
      await tester.tap(find.byTooltip('로그아웃'));
      await tester.pumpAndSettle();
      await app.login(tester); // 다른 회원이 로그인했다고 본다.
      await app.go(tester, '/my/ratings');

      expect(find.text('파이트 클럽'), findsNothing);
      expect(find.text('이번 로그인에서 등록한 평점이 없어요.'), findsOneWidget);
    });
  });

  group('마이페이지와 프로필 수정', () {
    Future<void> openEdit(WidgetTester tester) async {
      await app.pump(tester);
      await app.go(tester, '/my');
      await tester.tap(find.text('프로필 수정'));
      await tester.pumpAndSettle();
    }

    Finder nicknameField() => find.byType(TextField).last;

    testWidgets('프로필 수정 화면은 하단 탭 없이 열리고 이메일은 읽기 전용이다', (tester) async {
      await openEdit(tester);

      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      final email = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(email.enabled, isFalse);
      expect(email.initialValue, 'lc@example.com');
      expect(tester.widget<TextField>(nicknameField()).controller!.text, '영화광');
    });

    testWidgets('저장에 성공하면 마이페이지로 돌아오고 새 닉네임이 바로 보인다', (tester) async {
      await openEdit(tester);

      await tester.enterText(nicknameField(), '새이름');
      await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
      await tester.pumpAndSettle();

      expect(app.members.updateCalls, ['새이름']);
      expect(find.byType(EditProfileScreen), findsNothing);
      expect(find.text('새이름'), findsOneWidget);
      expect(find.text('프로필을 수정했어요.'), findsOneWidget);
      expect(app.members.fetchCalls, 1); // GET me를 다시 부르지 않는다.
    });

    testWidgets('닉네임 중복(MEMBER409_1)은 필드 아래 오류이고 입력값과 화면을 유지한다', (tester) async {
      await openEdit(tester);
      app.members.updateError = commonError(409, 'MEMBER409_1', '이미 사용 중인 닉네임입니다.');

      await tester.enterText(nicknameField(), '중복이름');
      await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
      await tester.pumpAndSettle();

      expect(find.text('이미 사용 중인 닉네임이에요.'), findsOneWidget);
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(tester.widget<TextField>(nicknameField()).controller!.text, '중복이름');
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('2~12자가 아니면 요청 없이 안내한다', (tester) async {
      await openEdit(tester);

      await tester.enterText(nicknameField(), '가');
      await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
      await tester.pumpAndSettle();

      expect(find.text('닉네임은 2~12자로 입력해 주세요.'), findsOneWidget);
      expect(app.members.updateCalls, isEmpty);
    });

    testWidgets('네트워크 실패는 Snackbar로 안내하고 로그아웃하지 않으며 다시 저장할 수 있다', (tester) async {
      await openEdit(tester);
      app.members.updateError = dioFailure('/v8/members/me');

      await tester.enterText(nicknameField(), '새이름');
      await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
      await tester.pumpAndSettle();

      expect(find.text('네트워크 상태를 확인하고 다시 시도해 주세요.'), findsOneWidget);
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(app.tokens.token, isNotNull);

      app.members.updateError = null;
      await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
      await tester.pumpAndSettle();
      expect(find.text('새이름'), findsOneWidget);
    });

    testWidgets('저장 중 만료(401)면 로그인 화면으로 이동하고 만료 안내가 뜬다', (tester) async {
      await openEdit(tester);
      app.members.updateError = expiredError('AUTH401_3');

      await tester.enterText(nicknameField(), '새이름');
      await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
      await tester.pumpAndSettle();

      expect(app.location(tester), '/login');
      expect(find.text(_expiredText), findsOneWidget);
      expect(app.tokens.token, isNull);
    });

    testWidgets('변경 내용이 있으면 뒤로가기 때 확인 Dialog가 뜨고, 계속 수정·나가기를 고를 수 있다', (tester) async {
      await openEdit(tester);
      await tester.enterText(nicknameField(), '고치는중');
      await tester.pump();

      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();
      expect(find.text('수정을 그만둘까요?'), findsOneWidget);

      await tester.tap(find.text('계속 수정'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(tester.widget<TextField>(nicknameField()).controller!.text, '고치는중');

      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('나가기'));
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileScreen), findsNothing);
      expect(find.text('영화광'), findsOneWidget); // 저장하지 않았으므로 그대로다.
      expect(app.members.updateCalls, isEmpty);
    });

    testWidgets('변경 내용이 없으면 확인 없이 바로 돌아간다', (tester) async {
      await openEdit(tester);

      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();

      expect(find.text('수정을 그만둘까요?'), findsNothing);
      expect(find.byType(EditProfileScreen), findsNothing);
    });

    testWidgets('내 정보를 불러오는 동안 인디케이터, 실패하면 재시도 버튼을 보여준다 (로그아웃하지 않는다)', (tester) async {
      await app.pump(tester, signedIn: false);
      app.members
        ..fetchError = dioFailure('/v8/members/me')
        ..fetchFailTimes = 1;
      await app.login(tester); // 홈 진입 → MainScreen의 loadMember()가 실패
      await app.go(tester, '/my');

      expect(find.text('내 정보를 불러오지 못했어요.'), findsOneWidget);
      expect(app.location(tester), '/my');
      expect(app.tokens.token, isNotNull);

      app.members.fetchGate = Completer<void>();
      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      app.members.fetchGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('영화광'), findsOneWidget);
    });
  });

  group('토큰 기반 평점 등록 → 수정 → 삭제', () {
    testWidgets('등록 요청에는 memberId가 없고 TMDB id가 movieId다. 응답 Rating이 내 평점에 보인다', (tester) async {
      await app.pump(tester);

      await rateFromDetail(tester, score: 4, comment: '다시 봐도 좋다');

      expect(app.ratings.createCalls.single.toJson(), {
        'movieId': 550,
        'score': 4,
        'comment': '다시 봐도 좋다',
      });
      expect(find.textContaining('평점을 저장했습니다'), findsOneWidget);

      await app.go(tester, '/my/ratings');
      expect(find.byType(NavigationBar), findsNothing);
      // movieId(550)로 TMDB 영화 정보를 찾아 제목을 붙인다.
      expect(find.text('파이트 클럽'), findsOneWidget);
      expect(find.text('4점'), findsOneWidget);
      expect(find.text('다시 봐도 좋다'), findsOneWidget);
    });

    testWidgets('수정은 기존 값이 채워진 Dialog로 하고, 응답 Rating으로 카드가 바뀐다', (tester) async {
      await app.pump(tester);
      await rateFromDetail(tester, score: 4, comment: '다시 봐도 좋다');
      await app.go(tester, '/my/ratings');

      await tester.tap(find.byTooltip('수정'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MovieRatingInput>(find.byType(MovieRatingInput)).rating,
        4.0,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '다시 봐도 좋다',
      );

      await tester.tap(stars().at(1)); // 2점
      await tester.pump();
      await tester.enterText(find.byType(TextField), '다시 보니 별로');
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      final call = app.ratings.updateCalls.single;
      expect(call.ratingId, 1000); // 등록 응답으로 받은 ratingId
      expect(call.score, 2);
      expect(call.comment, '다시 보니 별로');
      expect(find.text('2점'), findsOneWidget);
      expect(find.text('다시 보니 별로'), findsOneWidget);
      expect(find.text('평점을 수정했습니다.'), findsOneWidget);
    });

    testWidgets('삭제는 확인 Dialog를 거치고, 취소하면 요청하지 않는다. 삭제하면 빈 목록이 된다', (tester) async {
      await app.pump(tester);
      await rateFromDetail(tester);
      await app.go(tester, '/my/ratings');

      await tester.tap(find.byTooltip('삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(app.ratings.deleteCalls, isEmpty);

      await tester.tap(find.byTooltip('삭제'));
      await tester.pumpAndSettle();
      await tester.tap(deleteConfirmButton());
      await tester.pumpAndSettle();

      expect(app.ratings.deleteCalls, [1000]);
      expect(find.text('이번 로그인에서 등록한 평점이 없어요.'), findsOneWidget);
      expect(find.text('평점을 삭제했습니다.'), findsOneWidget);
    });

    testWidgets('TMDB에 없는 movieId의 평점도 지우지 않고 placeholder로 보여준다', (tester) async {
      await app.pump(tester);
      await rateFromDetail(tester);
      app.movies.known.clear(); // 영화 정보를 찾지 못하는 상황
      await app.go(tester, '/my/ratings');

      expect(find.text('영화 정보를 불러오지 못했어요'), findsOneWidget);
      expect(find.text('TMDB 영화 #550'), findsOneWidget);
      expect(find.text('4점'), findsOneWidget);
    });
  });

  group('401 · 403 · 409 처리', () {
    testWidgets('RATING409_1(이미 평점을 남긴 영화)은 Dialog를 닫고 Snackbar로 안내하며 로그인 상태를 유지한다', (tester) async {
      await app.pump(tester);
      app.ratings.writeError = commonError(409, 'RATING409_1', '이미 이 영화에 평점을 남기셨습니다.');

      await rateFromDetail(tester, comment: '남기던 코멘트');

      expect(find.text('이미 이 영화에 평점을 남기셨습니다.'), findsOneWidget);
      expect(find.byType(RatingDialog), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(app.tokens.token, isNotNull);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('RATING403_1(남의 평점)은 안내만 하고 자동 로그아웃하지 않는다', (tester) async {
      await app.pump(tester);
      await rateFromDetail(tester);
      await app.go(tester, '/my/ratings');
      app.ratings.writeError = commonError(
        403,
        'RATING403_1',
        '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
      );

      await tester.tap(find.byTooltip('수정'));
      await tester.pumpAndSettle();
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(find.text('본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'), findsOneWidget);
      expect(app.location(tester), '/my/ratings');
      expect(app.tokens.token, isNotNull);
      expect(find.text(_expiredText), findsNothing);
    });

    testWidgets('보호 요청의 만료(AUTH401_4)는 세션을 정리하고 로그인 화면에서 안내한다', (tester) async {
      await app.pump(tester);
      app.ratings.writeError = expiredError('AUTH401_4');

      await rateFromDetail(tester);

      expect(app.location(tester), '/login');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MovieDetailScreen), findsNothing);
      expect(find.text(_expiredText), findsOneWidget);
      expect(app.tokens.token, isNull);
    });

    testWidgets('네트워크 실패는 401이 아니다. 로그아웃하지 않고 다시 시도할 수 있다', (tester) async {
      await app.pump(tester);
      app.ratings.writeError = dioFailure('/v8/ratings');

      await rateFromDetail(tester);

      expect(find.byType(RatingDialog), findsOneWidget);
      expect(app.tokens.token, isNotNull);

      app.ratings.writeError = null;
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();
      expect(find.textContaining('평점을 저장했습니다'), findsOneWidget);
    });
  });

  group('영화 상세 주소', () {
    testWidgets('주소로 바로 들어오면 TMDB 상세 API로 다시 조회한다', (tester) async {
      await app.pump(tester);
      app.movies.details[550] = app.movies.known[550]!;

      await app.go(tester, '/movies/550');

      expect(find.byType(MovieDetailScreen), findsOneWidget);
      expect(app.movies.fetchDetailCalls, 1);
    });

    testWidgets('숫자가 아닌 영화 ID는 조회하지 않고 안내한다', (tester) async {
      await app.pump(tester);

      await app.go(tester, '/movies/abc');

      expect(find.text('영화 ID가 올바르지 않습니다.'), findsOneWidget);
      expect(app.movies.fetchDetailCalls, 0);
    });
  });
}
