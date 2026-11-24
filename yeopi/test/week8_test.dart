import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/edit_profile_view_model.dart';
import 'package:movielog/view_models/load_error_message.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/session_rating_store.dart';
import 'package:movielog/widgets/rating_dialog.dart';

import 'helpers/app_harness.dart';
import 'helpers/movielog_fakes.dart';
import 'helpers/tmdb_fakes.dart';

// 로그인한 상태의 AuthViewModel을 만듭니다. (저장된 토큰 + GET me 성공)
Future<AuthViewModel> signedInAuth({
  FakeTokenStorage? tokens,
  FakeMemberApiService? memberApi,
  FakeAuthApiService? authApi,
}) async {
  final auth = AuthViewModel(
    authApi ?? FakeAuthApiService(),
    memberApi ?? FakeMemberApiService(),
    tokens ?? FakeTokenStorage(fakeAccessToken),
  );
  await auth.restoreSession();
  expect(auth.status, AuthStatus.signedIn);
  return auth;
}

void main() {
  group('authRedirect', () {
    test('확인 중·확인 실패는 스플래시에 머문다', () {
      expect(authRedirect(AuthStatus.initializing, '/home'), '/start');
      expect(authRedirect(AuthStatus.retryRequired, '/my'), '/start');
      expect(authRedirect(AuthStatus.initializing, '/start'), isNull);
    });

    test('로그아웃 상태는 로그인·회원가입만 허용한다', () {
      expect(authRedirect(AuthStatus.signedOut, '/my/ratings'), '/login');
      expect(authRedirect(AuthStatus.signedOut, '/start'), '/login');
      expect(authRedirect(AuthStatus.signedOut, '/register'), isNull);
      expect(authRedirect(AuthStatus.authenticating, '/login'), isNull);
    });

    test('로그인 상태는 스플래시·로그인·회원가입에서 홈으로 보낸다', () {
      expect(authRedirect(AuthStatus.signedIn, '/login'), '/home');
      expect(authRedirect(AuthStatus.signedIn, '/start'), '/home');
      expect(authRedirect(AuthStatus.signedIn, '/my/profile/edit'), isNull);
    });
  });

  group('AuthViewModel 세션 복원', () {
    test('토큰이 없으면 signedOut이고 GET me를 부르지 않는다', () async {
      final member = FakeMemberApiService();
      final auth = AuthViewModel(
        FakeAuthApiService(),
        member,
        FakeTokenStorage(),
      );

      await auth.restoreSession();

      expect(auth.status, AuthStatus.signedOut);
      expect(member.fetchCount, 0);
    });

    test('토큰이 있어도 GET me 성공 전에는 signedIn이 아니다', () async {
      final member = FakeMemberApiService()..fetchGate = Completer<void>();
      final auth = AuthViewModel(
        FakeAuthApiService(),
        member,
        FakeTokenStorage(fakeAccessToken),
      );

      final pending = auth.restoreSession();
      await Future<void>.delayed(Duration.zero);
      expect(auth.status, AuthStatus.initializing);

      member.fetchGate!.complete();
      await pending;
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.member?.nickname, '여비');
    });

    test('만료 토큰(AUTH401_4)이면 토큰을 지우고 만료 안내를 켠다', () async {
      final tokens = FakeTokenStorage(fakeAccessToken);
      final auth = AuthViewModel(
        FakeAuthApiService(),
        FakeMemberApiService()..fetchError = expiredError(),
        tokens,
      );

      await auth.restoreSession();

      expect(auth.status, AuthStatus.signedOut);
      expect(tokens.token, isNull);
      expect(auth.sessionExpired, isTrue);
    });

    test('네트워크 실패는 토큰을 지우지 않고 재시도 상태가 된다', () async {
      final tokens = FakeTokenStorage(fakeAccessToken);
      final member = FakeMemberApiService()
        ..fetchError = networkError('/v7/members/me');
      final auth = AuthViewModel(FakeAuthApiService(), member, tokens);

      await auth.restoreSession();
      expect(auth.status, AuthStatus.retryRequired);
      expect(tokens.token, fakeAccessToken);
      expect(tokens.deleteCount, 0);

      member.fetchError = null;
      await auth.restoreSession();
      expect(auth.status, AuthStatus.signedIn);
    });

    test('저장소를 읽지 못하면 재시도 상태로 다른 문구를 보여준다', () async {
      final auth = AuthViewModel(
        FakeAuthApiService(),
        FakeMemberApiService(),
        FakeTokenStorage()..readError = Exception('keystore'),
      );

      await auth.restoreSession();

      expect(auth.status, AuthStatus.retryRequired);
      expect(auth.message, contains('인증 저장소'));
    });
  });

  group('AuthViewModel 로그인·로그아웃', () {
    test('로그인 성공은 토큰을 저장하고 signedIn이 된다', () async {
      final tokens = FakeTokenStorage();
      final auth = AuthViewModel(
        FakeAuthApiService(),
        FakeMemberApiService(),
        tokens,
      );

      await auth.login('me@movielog.com', 'Password1!');

      expect(auth.status, AuthStatus.signedIn);
      expect(tokens.token, fakeAccessToken);
      // 내 정보는 MainScreen이 loadMember()로 따로 불러옵니다.
      expect(auth.member, isNull);
    });

    test('AUTH401_1은 Form 문구만 남기고 만료 처리를 하지 않는다', () async {
      final tokens = FakeTokenStorage();
      final auth = AuthViewModel(
        FakeAuthApiService(),
        FakeMemberApiService(),
        tokens,
      );

      await auth.login('me@movielog.com', 'wrong');

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.message, '이메일 또는 비밀번호를 확인해 주세요.');
      expect(auth.sessionExpired, isFalse);
      expect(tokens.deleteCount, 0);
    });

    test('네트워크 실패와 저장 실패를 서로 다른 문구로 보여준다', () async {
      final authApi = FakeAuthApiService()
        ..error = networkError('/v7/auth/login');
      final auth = AuthViewModel(
        authApi,
        FakeMemberApiService(),
        FakeTokenStorage(),
      );

      await auth.login('me@movielog.com', 'Password1!');
      expect(auth.message, '로그인 요청에 실패했어요. 잠시 후 다시 시도해 주세요.');

      final failingStorage = _FailingWriteStorage();
      final auth2 = AuthViewModel(
        FakeAuthApiService(),
        FakeMemberApiService(),
        failingStorage,
      );
      await auth2.login('me@movielog.com', 'Password1!');
      expect(auth2.status, AuthStatus.signedOut);
      expect(auth2.message, '로그인 정보를 안전하게 저장하지 못했어요.');
    });

    test('직접 로그아웃은 토큰과 내 정보를 지우고 만료 안내는 켜지 않는다', () async {
      final tokens = FakeTokenStorage(fakeAccessToken);
      final auth = await signedInAuth(tokens: tokens);

      await auth.logout();

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.member, isNull);
      expect(tokens.token, isNull);
      expect(auth.sessionExpired, isFalse);
    });

    test('이전 세션 버전의 401은 새 세션을 지우지 않는다', () async {
      final tokens = FakeTokenStorage(fakeAccessToken);
      final auth = await signedInAuth(tokens: tokens);
      final oldVersion = auth.sessionVersion;

      await auth.logout();
      await auth.login('me@movielog.com', 'Password1!');
      await auth.expireSession(version: oldVersion);

      expect(auth.status, AuthStatus.signedIn);
      expect(tokens.token, fakeAccessToken);
    });

    test('동시에 여러 401이 와도 정리는 한 번만 한다', () async {
      final tokens = FakeTokenStorage(fakeAccessToken);
      final auth = await signedInAuth(tokens: tokens);
      final version = auth.sessionVersion;

      await Future.wait([
        auth.expireSession(version: version),
        auth.expireSession(version: version),
        auth.expireSession(version: version),
      ]);

      expect(tokens.deleteCount, 1);
      expect(auth.sessionExpired, isTrue);
    });

    test('loadMember의 네트워크 실패는 로그아웃하지 않고, 401은 세션을 정리한다', () async {
      final member = FakeMemberApiService();
      final auth = AuthViewModel(
        FakeAuthApiService(),
        member,
        FakeTokenStorage(),
      );
      await auth.login('me@movielog.com', 'Password1!');

      member.fetchError = networkError('/v7/members/me');
      await auth.loadMember();
      expect(auth.memberStatus, MemberLoadStatus.error);
      expect(auth.status, AuthStatus.signedIn);

      member.fetchError = expiredError('AUTH401_3');
      await auth.loadMember(force: true);
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
    });
  });

  group('EditProfileViewModel', () {
    test('2~12자 규칙은 요청 전에 검사한다', () async {
      final member = FakeMemberApiService();
      final auth = await signedInAuth(memberApi: member);
      final viewModel = EditProfileViewModel(member, auth);

      expect(await viewModel.save('가'), isFalse);
      expect(viewModel.nicknameError, '닉네임은 2~12자로 입력해 주세요.');
      expect(member.updateRequests, isEmpty);
    });

    test('현재 닉네임과 같으면 요청 없이 완료한다', () async {
      final member = FakeMemberApiService();
      final auth = await signedInAuth(memberApi: member);

      expect(await EditProfileViewModel(member, auth).save(' 여비 '), isTrue);
      expect(member.updateRequests, isEmpty);
    });

    test('성공하면 AuthViewModel.member를 응답으로 교체한다', () async {
      final member = FakeMemberApiService();
      final auth = await signedInAuth(memberApi: member);

      expect(await EditProfileViewModel(member, auth).save('새닉네임'), isTrue);
      expect(auth.member?.nickname, '새닉네임');
      // 수정 result로 교체하므로 GET me를 다시 부르지 않습니다.
      expect(member.fetchCount, 1);
    });

    test('MEMBER409_1은 입력칸 오류, 네트워크 실패는 Snackbar 문구이며 로그아웃하지 않는다', () async {
      final member = FakeMemberApiService();
      final auth = await signedInAuth(memberApi: member);
      final viewModel = EditProfileViewModel(member, auth);

      member.updateError = httpError(
        '/v7/members/me',
        409,
        code: 'MEMBER409_1',
        message: '이미 사용 중인 닉네임입니다.',
      );
      expect(await viewModel.save('무비러버'), isFalse);
      expect(viewModel.nicknameError, '이미 사용 중인 닉네임이에요.');

      member.updateError = networkError('/v7/members/me');
      expect(await viewModel.save('무비러버'), isFalse);
      expect(viewModel.message, contains('네트워크'));
      expect(auth.status, AuthStatus.signedIn);
    });

    test('401은 세션을 만료시킨다', () async {
      final member = FakeMemberApiService();
      final auth = await signedInAuth(memberApi: member);
      member.updateError = expiredError();

      expect(await EditProfileViewModel(member, auth).save('새닉네임'), isFalse);
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
    });
  });

  group('토큰 기반 평점', () {
    test('등록 결과 Rating을 세션 목록에 넣고, 로그아웃하면 비운다', () async {
      final auth = await signedInAuth();
      final store = SessionRatingStore(auth);
      final ratings = FakeRatingApiService();
      final viewModel = MovieDetailViewModel(
        ratings,
        auth,
        store,
        movieFixture(550),
      );

      await viewModel.createRating(score: 4, comment: '재밌어요');

      expect(ratings.createRequests.single.toJson(), {
        'movieId': 550,
        'score': 4,
        'comment': '재밌어요',
      });
      expect(store.ratings.single.movieId, 550);

      await auth.logout();
      expect(store.ratings, isEmpty);
    });

    test('RATING409_1은 안내만 하고 로그인 상태를 유지한다', () async {
      final auth = await signedInAuth();
      final ratings = FakeRatingApiService()
        ..writeError = httpError(
          '/v7/ratings',
          409,
          code: 'RATING409_1',
          message: '이미 이 영화에 평점을 남기셨습니다.',
        );
      final viewModel = MovieDetailViewModel(
        ratings,
        auth,
        SessionRatingStore(auth),
        movieFixture(1),
      );

      await expectLater(
        viewModel.createRating(score: 3),
        throwsA(
          isA<WriteFailure>().having(
            (e) => e.message,
            'message',
            contains('이미 평점을 남긴 영화'),
          ),
        ),
      );
      expect(auth.status, AuthStatus.signedIn);
    });

    test('등록 중 401이면 세션을 정리한다', () async {
      final auth = await signedInAuth();
      final ratings = FakeRatingApiService()..writeError = expiredError();
      final viewModel = MovieDetailViewModel(
        ratings,
        auth,
        SessionRatingStore(auth),
        movieFixture(1),
      );

      await expectLater(
        viewModel.createRating(score: 3),
        throwsA(isA<WriteFailure>()),
      );
      expect(auth.status, AuthStatus.signedOut);
    });

    test('로그아웃 뒤 늦게 도착한 등록 응답은 새 세션 목록에 넣지 않는다', () async {
      final auth = await signedInAuth();
      final store = SessionRatingStore(auth);
      final ratings = FakeRatingApiService()..writeGate = Completer<void>();
      final viewModel = MovieDetailViewModel(
        ratings,
        auth,
        store,
        movieFixture(1),
      );

      final pending = viewModel.createRating(score: 5);
      await auth.logout();
      await auth.login('me@movielog.com', 'Password1!');
      ratings.writeGate!.complete();
      await pending;

      expect(store.ratings, isEmpty);
    });

    Future<(MyRatingsViewModel, FakeRatingApiService, AuthViewModel)>
    myRatingsWith(List<int> movieIds) async {
      final auth = await signedInAuth();
      final store = SessionRatingStore(auth);
      final ratings = FakeRatingApiService();
      for (final movieId in movieIds) {
        final created = await ratings.createRating(
          CreateRatingRequest(movieId: movieId, score: 4),
        );
        store.add(created, version: auth.sessionVersion);
      }
      final viewModel = MyRatingsViewModel(
        ratings,
        FakeTmdbMovieService(),
        auth,
        store,
      );
      await viewModel.load();
      return (viewModel, ratings, auth);
    }

    test('수정·삭제 응답으로 목록을 갱신한다', () async {
      final (viewModel, ratings, _) = await myRatingsWith([1, 2]);
      expect(viewModel.status, MyRatingsLoadStatus.success);
      final firstId = viewModel.ratings.first.rating.ratingId;

      await viewModel.updateRating(ratingId: firstId, score: 2, comment: '음');
      await Future<void>.delayed(Duration.zero);
      expect(ratings.updateRequests.single, (firstId, 2, '음'));
      expect(viewModel.ratings.first.rating.score, 2);

      await viewModel.deleteRating(firstId);
      await Future<void>.delayed(Duration.zero);
      expect(ratings.deleteRequests.single, firstId);
      expect(viewModel.ratings, hasLength(1));
    });

    test('RATING403_1은 안내만 하고 로그아웃하지 않는다', () async {
      final (viewModel, ratings, auth) = await myRatingsWith([1]);
      ratings.writeError = httpError(
        '/v7/ratings/100',
        403,
        code: 'RATING403_1',
        message: '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
      );

      await expectLater(
        viewModel.deleteRating(100),
        throwsA(
          isA<WriteFailure>().having(
            (e) => e.message,
            'message',
            contains('본인이 작성한 평점'),
          ),
        ),
      );
      expect(auth.status, AuthStatus.signedIn);
      expect(viewModel.ratings, hasLength(1));
    });

    test('RATING404_1이면 목록에서도 뺀다', () async {
      final (viewModel, ratings, _) = await myRatingsWith([1]);
      ratings.writeError = httpError(
        '/v7/ratings/100',
        404,
        code: 'RATING404_1',
        message: '해당 평점을 찾을 수 없습니다.',
      );

      await expectLater(
        viewModel.deleteRating(100),
        throwsA(isA<WriteFailure>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.status, MyRatingsLoadStatus.empty);
    });

    test('TMDB에 없는 영화도 평점은 남기고 안내 문구를 둔다', () async {
      final (viewModel, _, _) = await myRatingsWith([1, 999]);

      expect(viewModel.ratings, hasLength(2));
      expect(viewModel.ratings.first.movie, isNull); // 최근 등록(999)이 위
      expect(viewModel.message, contains('영화 #번호'));
    });

    test('다중 삭제는 순서대로 지우고 실패한 항목만 선택에 남긴다', () async {
      final (viewModel, ratings, _) = await myRatingsWith([1, 2, 3]);
      ratings.failingDeleteIds.add(101);

      viewModel
        ..startEditing()
        ..toggleSelection(100)
        ..toggleSelection(101)
        ..toggleSelection(102);
      final failed = await viewModel.deleteSelectedRatings();
      await Future<void>.delayed(Duration.zero);

      expect(failed, 1);
      expect(ratings.deleteRequests, [100, 101, 102]);
      expect(viewModel.selectedRatingIds, {101});
      expect(viewModel.isEditing, isTrue);
      expect(viewModel.ratings.map((e) => e.rating.ratingId), [101]);
    });
  });

  group('8주차 화면', () {
    testWidgets('세션 확인 실패면 스플래시에 재시도 버튼이 나오고, 재시도하면 홈으로 간다', (tester) async {
      final member = FakeMemberApiService()
        ..fetchError = networkError('/v7/members/me');
      final app = await pumpMovieLogApp(tester, memberApi: member);

      expect(app.location, '/start');
      expect(find.text('로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
      // 네트워크 실패만으로 토큰을 지우지 않습니다.
      expect(app.tokens.token, fakeAccessToken);

      member.fetchError = null;
      await tester.tap(find.widgetWithText(ElevatedButton, '다시 시도'));
      await tester.pumpAndSettle();
      expect(app.location, '/home');
    });

    testWidgets('로그인 실패는 Form 문구, 성공하면 홈으로 가고 내 정보를 불러온다', (tester) async {
      final app = await pumpMovieLogApp(tester, signedIn: false);
      expect(app.location, '/login');

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'me@movielog.com');
      await tester.enterText(fields.at(1), 'wrong');
      await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
      await tester.pumpAndSettle();
      expect(find.text('이메일 또는 비밀번호를 확인해 주세요.'), findsOneWidget);
      expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsNothing);

      await tester.enterText(fields.at(1), 'Password1!');
      await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
      await tester.pumpAndSettle();

      expect(app.location, '/home');
      expect(app.tokens.token, fakeAccessToken);
      expect(app.memberApi.fetchCount, 1); // MainScreen의 loadMember()
      expect(app.auth.member?.nickname, '여비');
    });

    testWidgets('이메일 저장을 체크하면 이메일만 남고 다음 로그인 화면에 채워진다', (tester) async {
      final app = await pumpMovieLogApp(
        tester,
        signedIn: false,
        savedEmail: 'saved@movielog.com',
      );

      final emailField = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(emailField.controller?.text, 'saved@movielog.com');
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      expect(app.location, '/login');
    });

    testWidgets('마이페이지는 닉네임·가입일을 보여주고, 로그아웃하면 로그인 화면으로 가며 보호 화면에 못 들어간다', (
      tester,
    ) async {
      final app = await pumpMovieLogApp(tester);
      await app.go('/my');

      expect(find.text('여비'), findsOneWidget);
      expect(find.text('2026.10.10 가입'), findsOneWidget);

      await tester.tap(find.byTooltip('로그아웃'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '로그아웃'));
      await tester.pumpAndSettle();

      expect(app.location, '/login');
      expect(app.tokens.token, isNull);
      // 직접 로그아웃에는 만료 안내가 나오지 않습니다.
      expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsNothing);

      await app.go('/my/ratings');
      expect(app.location, '/login');
    });

    testWidgets('내 정보 로딩 실패는 재시도 버튼을 보여주고 재시도하면 표시된다', (tester) async {
      final member = FakeMemberApiService();
      final app = await pumpMovieLogApp(
        tester,
        signedIn: false,
        memberApi: member,
      );
      member.fetchError = networkError('/v7/members/me');
      await app.auth.login('me@movielog.com', 'Password1!');
      await tester.pumpAndSettle();
      await app.go('/my');

      expect(find.text('내 정보를 불러오지 못했어요.'), findsOneWidget);
      expect(app.auth.status, AuthStatus.signedIn);

      member.fetchError = null;
      await tester.tap(find.widgetWithText(ElevatedButton, '다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('2026.10.10 가입'), findsOneWidget);
    });

    testWidgets('보호 요청이 만료되면 로그인 화면으로 가서 Snackbar를 한 번 보여준다', (tester) async {
      final app = await pumpMovieLogApp(tester);
      await app.push('/movies/1', extra: movieFixture(1));
      app.ratings.writeError = expiredError();

      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(RatingBar),
              matching: find.byIcon(Icons.star),
            )
            .last,
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
      await tester.pumpAndSettle();

      expect(app.location, '/login');
      expect(app.tokens.token, isNull);
      expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsOneWidget);
      expect(app.auth.sessionExpired, isFalse); // 한 번 보여준 뒤 꺼집니다.
    });

    testWidgets('프로필 수정: 중복은 입력값을 유지하고, 성공하면 마이페이지에 바로 반영된다', (tester) async {
      final app = await pumpMovieLogApp(tester);
      await app.go('/my');
      await tester.tap(find.text('프로필 수정'));
      await tester.pumpAndSettle();
      expect(app.location, '/my/profile/edit');
      expect(find.byType(NavigationBar), findsNothing);

      app.memberApi.updateError = httpError(
        '/v7/members/me',
        409,
        code: 'MEMBER409_1',
        message: '이미 사용 중인 닉네임입니다.',
      );
      await tester.enterText(find.byType(TextField).last, '무비러버');
      await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
      await tester.pumpAndSettle();
      expect(find.text('이미 사용 중인 닉네임이에요.'), findsOneWidget);
      expect(find.text('무비러버'), findsOneWidget);

      app.memberApi.updateError = null;
      await tester.enterText(find.byType(TextField).last, '새닉네임');
      await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
      await tester.pumpAndSettle();

      expect(app.location, '/my');
      expect(find.text('새닉네임'), findsOneWidget);
      expect(find.text('프로필을 수정했어요.'), findsOneWidget);
    });

    testWidgets('프로필 수정: 변경 내용이 있으면 뒤로가기 전에 확인한다', (tester) async {
      final app = await pumpMovieLogApp(tester);
      await app.go('/my');
      await tester.tap(find.text('프로필 수정'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '바꾸는중');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('변경 내용을 저장하지 않고 나갈까요?'), findsOneWidget);

      await tester.tap(find.text('계속 수정'));
      await tester.pumpAndSettle();
      expect(app.location, '/my/profile/edit');

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.text('나가기'));
      await tester.pumpAndSettle();
      expect(app.location, '/my');
      expect(app.memberApi.updateRequests, isEmpty);
    });

    testWidgets('이번 세션에서 등록한 평점을 수정·삭제한다', (tester) async {
      final app = await pumpMovieLogApp(tester);
      await app.push('/movies/1', extra: movieFixture(1));
      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(RatingBar),
              matching: find.byIcon(Icons.star),
            )
            .last,
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), '최고');
      await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
      await tester.pumpAndSettle();

      await app.go('/my');
      await tester.tap(find.text('내가 등록한 평점'));
      await tester.pumpAndSettle();
      expect(find.text('이번 로그인에서 등록한 평점 1개'), findsOneWidget);
      expect(find.text('영화 1'), findsOneWidget);

      // 수정 Dialog는 기존 점수·코멘트를 채워서 엽니다.
      await tester.tap(find.text('수정'));
      await tester.pumpAndSettle();
      expect(find.text('5점'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '최고',
      );
      await tester.tap(
        find
            .descendant(
              of: find.byType(RatingBar),
              matching: find.byIcon(Icons.star),
            )
            .at(1),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '수정'));
      await tester.pumpAndSettle();
      expect(app.ratings.updateRequests.single, (100, 2, '최고'));
      expect(find.byType(RatingDialog), findsNothing);
      expect(find.text('평점을 수정했습니다.'), findsOneWidget);

      await tester.tap(find.text('삭제').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '삭제'));
      await tester.pumpAndSettle();
      expect(app.ratings.deleteRequests.single, 100);
      expect(find.textContaining('이번 로그인에서 등록한 평점이 없어요.'), findsOneWidget);
    });
  });
}

class _FailingWriteStorage extends FakeTokenStorage {
  @override
  Future<void> saveAccessToken(String token) async =>
      throw Exception('keystore write failed');
}
