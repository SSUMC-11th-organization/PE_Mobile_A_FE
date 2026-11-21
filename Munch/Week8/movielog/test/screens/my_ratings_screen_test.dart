import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/view_models/session_rating_store.dart';
import 'package:movielog/widgets/loading_overlay.dart';

import '../fakes/fake_auth.dart';
import '../fakes/fake_rating_api_service.dart';
import '../fakes/fake_tmdb_movie_service.dart';
import '../fakes/pump_app.dart';

Future<void> pumpProfile(
  WidgetTester tester,
  FakeRatingApiService ratingService, {
  List<RatingDto> ratings = const [],
  FakeTmdbMovieService? movieService,
}) async {
  final store = SessionRatingStore();
  for (final rating in ratings.reversed) {
    store.add(rating);
    ratingService.movieIdsByRatingId[rating.ratingId] = rating.movieId;
  }
  await pumpApp(
    tester,
    ratingService: ratingService,
    movieService: movieService,
    sessionRatingStore: store,
    location: '/my',
  );
}

Future<void> openMyRatings(WidgetTester tester) async {
  await tester.ensureVisible(find.text('내가 등록한 평점'));
  await tester.tap(find.text('내가 등록한 평점'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('마이페이지에서 진입하면 하단 탭 없이 열리고, 뒤로가면 돌아온다', (tester) async {
    final movieService = FakeTmdbMovieService()
      ..movieDetails = {550: movieFixture(550)};
    await pumpProfile(
      tester,
      FakeRatingApiService(),
      ratings: [ratingFixture(1, 550, comment: '최고의 영화!')],
      movieService: movieService,
    );
    expect(find.byType(NavigationBar), findsOneWidget);

    await openMyRatings(tester);

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('영화 550'), findsOneWidget);
    expect(find.text('별점 4 / 5'), findsOneWidget);
    expect(find.text('최고의 영화!'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('내 프로필'), findsOneWidget);
  });

  testWidgets('이번 세션에 등록한 평점이 없으면 Empty 안내', (tester) async {
    await pumpProfile(tester, FakeRatingApiService());
    await openMyRatings(tester);

    expect(find.textContaining('이번 로그인에서 등록한 평점이 없습니다.'), findsOneWidget);
  });

  testWidgets('TMDB에 없는 영화는 placeholder로 표시한다', (tester) async {
    await pumpProfile(
      tester,
      FakeRatingApiService(),
      ratings: [ratingFixture(1, 13)],
    );
    await openMyRatings(tester);

    expect(find.text('영화 #13'), findsOneWidget);
    expect(find.text('영화 정보 없음'), findsOneWidget);
  });

  testWidgets('편집 모드: 선택 수 표시, 선택해야 삭제 활성화, 취소하면 복귀', (tester) async {
    await pumpProfile(
      tester,
      FakeRatingApiService(),
      ratings: [ratingFixture(1, 13)],
    );
    await openMyRatings(tester);

    await tester.tap(find.text('편집'));
    await tester.pump();
    expect(find.text('0개 선택됨'), findsOneWidget);
    expect(find.text('수정'), findsNothing);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, '선택한 0개 삭제'),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(find.text('1개 선택됨'), findsOneWidget);
    expect(find.text('선택한 1개 삭제'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pump();
    expect(find.text('편집'), findsOneWidget);
    expect(find.text('수정'), findsOneWidget);
  });

  testWidgets('다중 삭제: Dialog는 바로 닫히고 오버레이 후 일부 실패를 안내한다', (tester) async {
    final service = FakeRatingApiService()..failingDeleteIds = {2};
    await pumpProfile(
      tester,
      service,
      ratings: [ratingFixture(1, 13), ratingFixture(2, 14)],
    );
    await openMyRatings(tester);

    await tester.tap(find.text('편집'));
    await tester.pump();
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();

    service.deletePending = Completer<void>();
    await tester.tap(find.text('선택한 2개 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      tester.widget<LoadingOverlay>(find.byType(LoadingOverlay)).isLoading,
      isTrue,
    );

    service.deletePending!.complete();
    await tester.pumpAndSettle();

    expect(service.deletedRatingIds, [1]);
    expect(find.text('1개 항목을 삭제하지 못했습니다.'), findsOneWidget);
    expect(find.text('1개 선택됨'), findsOneWidget);
    expect(
      tester.widget<LoadingOverlay>(find.byType(LoadingOverlay)).isLoading,
      isFalse,
    );
  });

  testWidgets('수정 Dialog는 기존 값으로 열리고 저장 응답으로 카드를 갱신한다', (tester) async {
    final service = FakeRatingApiService();
    await pumpProfile(
      tester,
      service,
      ratings: [ratingFixture(1, 13, comment: '기존 코멘트')],
    );
    await openMyRatings(tester);

    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '기존 코멘트'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '수정한 코멘트');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(service.updates.single.ratingId, 1);
    expect(service.updates.single.score, 4);
    expect(service.updates.single.comment, '수정한 코멘트');
    expect(find.text('수정한 코멘트'), findsOneWidget);
  });

  testWidgets('403 수정 실패는 Dialog에 안내하고 로그인 상태를 유지한다', (tester) async {
    final service = FakeRatingApiService()
      ..writeFailure = apiError(403, 'RATING403_1');
    await pumpProfile(tester, service, ratings: [ratingFixture(1, 13)]);
    await openMyRatings(tester);

    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(find.text('본인이 작성한 평점만 수정하거나 삭제할 수 있어요.'), findsWidgets);
    expect(currentPath(tester), '/my/ratings');
  });

  testWidgets('401 삭제 실패는 로그인 화면으로 이동하고 만료 안내를 띄운다', (tester) async {
    final service = FakeRatingApiService()
      ..writeFailure = apiError(401, 'AUTH401_4');
    await pumpProfile(tester, service, ratings: [ratingFixture(1, 13)]);
    await openMyRatings(tester);

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제').last);
    await tester.pumpAndSettle();

    expect(currentPath(tester), '/login');
    expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsOneWidget);
  });

  testWidgets('삭제 취소는 요청하지 않고, 마지막 항목 삭제 후 Empty를 표시한다', (tester) async {
    final service = FakeRatingApiService();
    await pumpProfile(tester, service, ratings: [ratingFixture(1, 13)]);
    await openMyRatings(tester);

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(service.deletedRatingIds, isEmpty);

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제').last);
    await tester.pumpAndSettle();

    expect(service.deletedRatingIds, [1]);
    expect(find.textContaining('이번 로그인에서 등록한 평점이 없습니다.'), findsOneWidget);
  });
}
