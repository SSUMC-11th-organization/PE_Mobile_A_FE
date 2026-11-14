import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/my_ratings_screen.dart';
import 'package:movielog/view_models/learning_member_session.dart';
import 'package:movielog/widgets/movie_rating_input.dart';
import 'package:movielog/widgets/rating_dialog.dart';

import '../test_helpers.dart';
import '../week6_helpers.dart';

void main() {
  late FakeRatingApiService ratings;
  late FakeDetailTmdbService movies;

  /// [settle]이 false면 두 프레임만 그린다. (인디케이터는 계속 움직여 pumpAndSettle이 끝나지 않는다.)
  Future<void> pumpApp(
    WidgetTester tester, {
    String at = '/my',
    bool settle = true,
    int? memberId = 9,
  }) async {
    useTallScreen(tester);
    // AppRouter.router는 static이라 이전 테스트의 위치를 기억한다. 먼저 시작 화면으로 되돌린다.
    AppRouter.router.go('/start');
    await tester.pumpWidget(
      MovieLogApp(
        movieService: movies,
        ratingApiService: ratings,
        memberSession: LearningMemberSession(memberId),
      ),
    );
    AppRouter.router.go(at);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  setUp(() {
    ratings = FakeRatingApiService();
    movies = FakeDetailTmdbService();
  });

  /// 평점 3건과 영화 정보를 준비한다. (ratingId 1·2·3 = 파이트 클럽·펄프 픽션·포레스트 검프)
  void seedThree() {
    ratings.ratings = [
      ratingDto(1, 550, score: 5, comment: '최고의 영화!'),
      ratingDto(2, 680, score: 3), // 후기 없음(null)
      ratingDto(3, 13, score: 4, comment: '좋다'),
    ];
    movies = FakeDetailTmdbService(
      known: {
        550: movieDto(550, title: '파이트 클럽'),
        680: movieDto(680, title: '펄프 픽션'),
        13: movieDto(13, title: '포레스트 검프'),
      },
    );
  }

  Finder dialogButton(String label) => find.descendant(
    of: find.byType(RatingDialog),
    matching: find.widgetWithText(ElevatedButton, label),
  );

  Finder stars() => find.descendant(
    of: find.byType(MovieRatingInput),
    matching: find.byIcon(Icons.star_rounded),
  );

  testWidgets('마이페이지의 진입 행을 누르면 하단 탭 없는 자식 화면이 열리고, 뒤로가기로 돌아온다', (tester) async {
    await pumpApp(tester);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('내가 등록한 평점'));
    await tester.pumpAndSettle();

    expect(find.byType(MyRatingsScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(ratings.calls, 1);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(MyRatingsScreen), findsNothing);
    expect(find.text('내 프로필'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('조회는 6주차의 고정 1번이 아니라 회원가입으로 받은 memberId를 쓴다', (tester) async {
    await pumpApp(tester, at: '/my/ratings', memberId: 321);

    expect(ratings.fetchedMemberIds, [321]);
  });

  testWidgets('회원가입 전(memberId 없음)에는 조회하지 않고 가입이 필요하다고 안내한다', (tester) async {
    await pumpApp(tester, at: '/my/ratings', memberId: null);

    expect(find.text('학습용 회원가입이 필요합니다.'), findsOneWidget);
    expect(ratings.calls, 0);
  });

  testWidgets('Loading: 응답을 기다리는 동안 인디케이터가 보인다', (tester) async {
    ratings.gate = Completer<void>();
    await pumpApp(tester, at: '/my/ratings', settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('평점을 불러오는 중이에요'), findsOneWidget);

    ratings.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('Empty: 빈 배열은 안내 문구이고 Error가 아니다', (tester) async {
    await pumpApp(tester, at: '/my/ratings');

    expect(find.text('아직 등록한 평점이 없어요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
    expect(find.text('편집'), findsNothing); // 편집할 항목이 없다.
  });

  testWidgets('Error: 상태 코드별 문구와 다시 시도 버튼이 보이고, 누르면 복구된다', (tester) async {
    seedThree();
    ratings.failWithStatus = 404;
    await pumpApp(tester, at: '/my/ratings');

    expect(find.text('존재하지 않는 회원입니다.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);

    ratings.failWithStatus = null;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('파이트 클럽'), findsOneWidget);
  });

  testWidgets('Success: 영화 제목·점수·후기·등록일이 보이고 후기가 없으면 그리지 않는다', (tester) async {
    seedThree();
    await pumpApp(tester, at: '/my/ratings');

    expect(find.text('파이트 클럽'), findsOneWidget);
    expect(find.text('펄프 픽션'), findsOneWidget);
    expect(find.text('5점'), findsOneWidget);
    expect(find.text('3점'), findsOneWidget);
    expect(find.text('최고의 영화!'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'\d{4}\.\d{2}\.\d{2} 등록')),
      findsNWidgets(3),
    );
    expect(find.textContaining('memberId 9'), findsOneWidget);
  });

  testWidgets('영화 정보를 못 찾으면 placeholder 제목으로 평점은 유지하고 안내한다', (tester) async {
    ratings.ratings = [ratingDto(1, 999999, score: 4, comment: '기록은 남는다')];
    await pumpApp(tester, at: '/my/ratings');

    expect(find.text('영화 정보를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('TMDB 영화 #999999'), findsOneWidget);
    expect(find.text('4점'), findsOneWidget);
    expect(find.text('기록은 남는다'), findsOneWidget);
    expect(find.textContaining('일부 영화 정보를 가져오지 못해'), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });

  group('수정', () {
    testWidgets('카드마다 수정·삭제 버튼이 있다', (tester) async {
      seedThree();
      await pumpApp(tester, at: '/my/ratings');

      expect(find.byTooltip('수정'), findsNWidgets(3));
      expect(find.byTooltip('삭제'), findsNWidgets(3));
    });

    testWidgets('수정을 누르면 기존 별점·코멘트가 채워진 Dialog가 뜬다', (tester) async {
      seedThree();
      await pumpApp(tester, at: '/my/ratings');

      await tester.tap(find.byTooltip('수정').first);
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsOneWidget);
      expect(find.text('평점을 수정해 주세요'), findsOneWidget);
      expect(
        tester.widget<MovieRatingInput>(find.byType(MovieRatingInput)).rating,
        5.0,
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '최고의 영화!');
    });

    testWidgets('후기가 없던 평점은 코멘트 칸이 빈 채로 시작한다', (tester) async {
      seedThree();
      await pumpApp(tester, at: '/my/ratings');

      await tester.tap(find.byTooltip('수정').at(1)); // 펄프 픽션(후기 null)
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
      expect(
        tester.widget<MovieRatingInput>(find.byType(MovieRatingInput)).rating,
        3.0,
      );
    });

    testWidgets('값을 바꿔 저장하면 PATCH 후 목록을 다시 조회해 갱신하고 Snackbar가 보인다', (tester) async {
      seedThree();
      await pumpApp(tester, at: '/my/ratings');
      final callsBefore = ratings.calls;

      await tester.tap(find.byTooltip('수정').first);
      await tester.pumpAndSettle();
      await tester.tap(stars().at(1)); // 2점
      await tester.pump();
      await tester.enterText(find.byType(TextField), '다시 보니 별로');
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      final update = ratings.updateCalls.single;
      expect(update.memberId, 9);
      expect(update.ratingId, 1);
      expect(update.score, 2);
      expect(update.comment, '다시 보니 별로');
      expect(ratings.calls, callsBefore + 1); // 저장 뒤 재조회
      expect(find.byType(RatingDialog), findsNothing);
      expect(find.text('2점'), findsOneWidget);
      expect(find.text('다시 보니 별로'), findsOneWidget);
      expect(find.text('평점을 수정했습니다.'), findsOneWidget);
    });

    testWidgets('코멘트를 비우고 저장하면 comment를 null로 명시해 보낸다', (tester) async {
      seedThree();
      await pumpApp(tester, at: '/my/ratings');

      await tester.tap(find.byTooltip('수정').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(ratings.updateCalls.single.comment, isNull);
      expect(find.text('최고의 영화!'), findsNothing);
    });

    testWidgets('값을 바꾸지 않고 저장해도 기존 comment를 그대로 보낸다 (후기가 사라지지 않는다)', (tester) async {
      seedThree();
      await pumpApp(tester, at: '/my/ratings');

      await tester.tap(find.byTooltip('수정').first);
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(ratings.updateCalls.single.comment, '최고의 영화!');
      expect(find.text('최고의 영화!'), findsOneWidget);
    });

    testWidgets('취소하면 요청을 보내지 않는다', (tester) async {
      seedThree();
      await pumpApp(tester, at: '/my/ratings');

      await tester.tap(find.byTooltip('수정').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(ratings.updateCalls, isEmpty);
      expect(find.byType(RatingDialog), findsNothing);
    });

    testWidgets('403이면 서버 문구를 Dialog에 보이고 입력은 유지한다', (tester) async {
      seedThree();
      await pumpApp(tester, at: '/my/ratings');
      ratings.writeError = commonError(
        403,
        'COMMON403',
        '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
      );

      await tester.tap(find.byTooltip('수정').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '고치던 중');
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsOneWidget);
      expect(find.text('본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'), findsOneWidget);
      expect(find.text('고치던 중'), findsOneWidget); // 입력 보존
      expect(find.text('평점을 수정했습니다.'), findsNothing);
    });

    testWidgets('저장은 성공했는데 조회만 실패하면 안내가 뜨고, 다시 시도는 조회만 한다', (tester) async {
      seedThree();
      await pumpApp(tester, at: '/my/ratings');
      ratings.failFetchTimes = 1; // 수정 직후의 GET만 실패

      await tester.tap(find.byTooltip('수정').first);
      await tester.pumpAndSettle();
      await tester.tap(stars().at(1));
      await tester.pump();
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      // Dialog는 저장 성공으로 닫히고, 목록 쪽에 조회 재시도 안내가 보인다.
      expect(find.byType(RatingDialog), findsNothing);
      expect(find.textContaining('저장은 완료됐지만 목록을 불러오지 못했습니다'), findsOneWidget);
      expect(find.text('평점을 수정했습니다.'), findsOneWidget);

      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(ratings.updateCalls, hasLength(1)); // PATCH는 다시 가지 않는다.
      expect(find.text('2점'), findsOneWidget);
      expect(find.textContaining('저장은 완료됐지만'), findsNothing);
    });

    testWidgets('저장 중에는 Dialog를 닫을 수 없다', (tester) async {
      seedThree();
      await pumpApp(tester, at: '/my/ratings');
      ratings.writeGate = Completer<void>();

      await tester.tap(find.byTooltip('수정').first);
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('확인'));
      await tester.pump();

      await tester.tapAt(const Offset(5, 5)); // 바깥 탭
      await tester.binding.handlePopRoute(); // 뒤로가기
      await tester.pump();
      expect(find.byType(RatingDialog), findsOneWidget);

      ratings.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(RatingDialog), findsNothing);
    });
  });

  group('개별 삭제', () {
    /// Dialog 안의 삭제 버튼. 삭제 중에는 라벨이 사라지므로 라벨이 아니라 타입으로 찾는다.
    Finder confirmDelete() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(ElevatedButton),
    );

    testWidgets('삭제를 누르면 확인 Dialog가 뜨고, 취소하면 요청을 보내지 않는다', (tester) async {
      seedThree();
      await pumpApp(tester, at: '/my/ratings');

      await tester.tap(find.byTooltip('삭제').first);
      await tester.pumpAndSettle();
      expect(find.text('평점을 삭제할까요?'), findsOneWidget);
      expect(find.text('삭제한 평점은 복구할 수 없습니다.'), findsOneWidget);

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(ratings.deleteCalls, isEmpty);
      expect(find.text('파이트 클럽'), findsOneWidget);
    });

    testWidgets('삭제를 확인하면 DELETE 후 목록을 다시 조회해 사라지고 Snackbar가 보인다', (tester) async {
      seedThree();
      await pumpApp(tester, at: '/my/ratings');

      await tester.tap(find.byTooltip('삭제').first);
      await tester.pumpAndSettle();
      await tester.tap(confirmDelete());
      await tester.pumpAndSettle();

      expect(ratings.deleteCalls, [1]);
      expect(find.text('파이트 클럽'), findsNothing);
      expect(find.text('펄프 픽션'), findsOneWidget);
      expect(find.text('평점을 삭제했습니다.'), findsOneWidget);
    });

    testWidgets('마지막 항목을 지우면 Empty UI가 보인다', (tester) async {
      ratings.ratings = [ratingDto(1, 550)];
      await pumpApp(tester, at: '/my/ratings');

      await tester.tap(find.byTooltip('삭제'));
      await tester.pumpAndSettle();
      await tester.tap(confirmDelete());
      await tester.pumpAndSettle();

      expect(find.text('아직 등록한 평점이 없어요.'), findsOneWidget);
    });

    testWidgets('삭제 중에는 Dialog가 유지되고 닫을 수 없으며 요청은 한 번이다', (tester) async {
      seedThree();
      await pumpApp(tester, at: '/my/ratings');
      ratings.writeGate = Completer<void>();

      await tester.tap(find.byTooltip('삭제').first);
      await tester.pumpAndSettle();
      await tester.tap(confirmDelete());
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      await tester.tap(confirmDelete(), warnIfMissed: false);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(ratings.deleteCalls, hasLength(1));

      ratings.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('404면 서버 문구를 Dialog에 보이고 목록은 서버 상태로 다시 맞춘다', (tester) async {
      seedThree();
      await pumpApp(tester, at: '/my/ratings');
      final callsBefore = ratings.calls;
      ratings.writeError = commonError(404, 'COMMON404', '존재하지 않는 평점입니다.');

      await tester.tap(find.byTooltip('삭제').first);
      await tester.pumpAndSettle();
      await tester.tap(confirmDelete());
      await tester.pumpAndSettle();

      expect(find.text('존재하지 않는 평점입니다.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget); // 다시 시도하거나 취소할 수 있다.
      expect(ratings.calls, callsBefore + 1);
    });
  });

  group('편집(다중 선택) 모드', () {
    testWidgets('편집을 누르면 선택 개수와 취소가 보이고 카드에는 체크박스만 남는다', (tester) async {
      seedThree();
      await pumpApp(tester, at: '/my/ratings');
      expect(find.text('편집'), findsOneWidget);

      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();

      expect(find.text('0개 선택'), findsOneWidget);
      expect(find.text('취소'), findsOneWidget);
      expect(find.text('편집'), findsNothing);
      expect(find.byType(Checkbox), findsNWidgets(3));
      expect(find.byTooltip('수정'), findsNothing);
      expect(find.byTooltip('삭제'), findsNothing);
      expect(find.text('선택한 0개 삭제'), findsOneWidget);
    });

    testWidgets('선택이 0개일 때는 삭제 버튼이 비활성이고, 1개 이상이면 활성화된다', (tester) async {
      seedThree();
      await pumpApp(tester, at: '/my/ratings');
      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();

      Finder bar() => find.widgetWithText(ElevatedButton, '선택한 0개 삭제');
      expect(tester.widget<ElevatedButton>(bar()).onPressed, isNull);

      await tester.tap(find.text('파이트 클럽')); // 카드 탭으로 선택
      await tester.pump();

      expect(find.text('1개 선택'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, '선택한 1개 삭제'),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.text('파이트 클럽')); // 다시 탭하면 해제
      await tester.pump();
      expect(find.text('0개 선택'), findsOneWidget);
    });

    testWidgets('취소를 누르면 선택을 해제하고 기본 목록으로 돌아간다', (tester) async {
      seedThree();
      await pumpApp(tester, at: '/my/ratings');
      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('펄프 픽션'));
      await tester.pump();

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(find.text('편집'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byTooltip('수정'), findsNWidgets(3));
      expect(find.textContaining('선택한'), findsNothing);
    });

    Future<void> selectAndPressDelete(
      WidgetTester tester,
      List<String> titles,
    ) async {
      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();
      for (final title in titles) {
        await tester.tap(find.text(title));
        await tester.pump();
      }
      await tester.tap(
        find.widgetWithText(ElevatedButton, '선택한 ${titles.length}개 삭제'),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('다중 삭제 확인 Dialog에서 취소하면 요청을 보내지 않는다', (tester) async {
      seedThree();
      await pumpApp(tester, at: '/my/ratings');

      await selectAndPressDelete(tester, ['파이트 클럽']);
      expect(find.text('선택한 평점을 삭제할까요?'), findsOneWidget);
      await tester.tap(find.text('취소').last);
      await tester.pumpAndSettle();

      expect(ratings.deleteCalls, isEmpty);
    });

    testWidgets('확인하면 Dialog는 바로 닫히고, 삭제하는 동안 로딩 오버레이가 화면을 막는다', (tester) async {
      seedThree();
      await pumpApp(tester, at: '/my/ratings');
      await selectAndPressDelete(tester, ['파이트 클럽', '포레스트 검프']);
      ratings.writeGate = Completer<void>();

      await tester.tap(find.widgetWithText(TextButton, '삭제'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500)); // Dialog 닫힘 애니메이션

      // 단일 삭제와 달리 확인 Dialog는 요청 전에 닫힌다.
      expect(find.byType(AlertDialog), findsNothing);
      // 로딩은 Dialog가 아니라 화면 위 오버레이가 맡는다.
      expect(find.byType(ModalBarrier), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // 삭제 중에는 뒤로가기도 막힌다.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(MyRatingsScreen), findsOneWidget);

      ratings.writeGate!.complete();
      await tester.pumpAndSettle();

      expect(ratings.deleteCalls, [1, 3]);
      expect(find.text('파이트 클럽'), findsNothing);
      expect(find.text('포레스트 검프'), findsNothing);
      expect(find.text('펄프 픽션'), findsOneWidget);
      // 모두 성공하면 편집 모드도 끝난다.
      expect(find.text('편집'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('일부만 실패하면 성공한 항목만 사라지고 실패 Snackbar와 선택이 유지된다', (tester) async {
      seedThree();
      ratings.failDeleteIds.add(3);
      await pumpApp(tester, at: '/my/ratings');
      await selectAndPressDelete(tester, ['파이트 클럽', '포레스트 검프']);

      await tester.tap(find.widgetWithText(TextButton, '삭제'));
      await tester.pumpAndSettle();

      expect(find.text('파이트 클럽'), findsNothing); // 성공한 항목
      expect(find.text('포레스트 검프'), findsOneWidget); // 실패한 항목은 남는다.
      expect(
        find.text('1개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.'),
        findsWidgets,
      );
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('1개 선택'), findsOneWidget); // 실패한 항목의 선택 유지
      expect(find.text('취소'), findsOneWidget);
    });
  });
}
