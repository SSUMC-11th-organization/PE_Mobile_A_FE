import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/router/app_router.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/session_rating_store.dart';

import '../week6_helpers.dart';

void main() {
  late FakeAuthApiService authApi;
  late FakeMemberApiService memberApi;
  late FakeTokenStorage storage;
  late AuthViewModel viewModel;

  setUp(() {
    authApi = FakeAuthApiService();
    memberApi = FakeMemberApiService();
    storage = FakeTokenStorage();
    viewModel = AuthViewModel(authApi, memberApi, storage);
  });

  tearDown(() => viewModel.dispose());

  Future<void> signIn() async {
    await viewModel.login('lc@example.com', 'Password1!');
    await viewModel.loadMember();
  }

  group('앱 시작 세션 복원', () {
    test('처음에는 initializing이다', () {
      expect(viewModel.status, AuthStatus.initializing);
    });

    test('저장된 토큰이 없으면 서버에 묻지 않고 signedOut이다', () async {
      await viewModel.restoreSession();

      expect(viewModel.status, AuthStatus.signedOut);
      expect(memberApi.fetchCalls, 0);
      expect(viewModel.sessionExpired, isFalse);
    });

    test('토큰이 있어도 GET me 검증이 끝나기 전에는 signedIn이 아니다', () async {
      storage.token = 'stored';
      memberApi.fetchGate = Completer<void>();

      final pending = viewModel.restoreSession();
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.status, AuthStatus.initializing);

      memberApi.fetchGate!.complete();
      await pending;
      expect(viewModel.status, AuthStatus.signedIn);
      expect(viewModel.member?.nickname, '영화광');
      expect(viewModel.memberStatus, MemberLoadStatus.success);
    });

    test('토큰이 무효·만료(AUTH401_2/3/4)면 토큰을 지우고 만료 안내와 함께 signedOut이다', () async {
      for (final code in ['AUTH401_2', 'AUTH401_3', 'AUTH401_4']) {
        final storage = FakeTokenStorage('stored');
        final memberApi = FakeMemberApiService()..fetchError = expiredError(code);
        final vm = AuthViewModel(authApi, memberApi, storage);

        await vm.restoreSession();

        expect(vm.status, AuthStatus.signedOut, reason: code);
        expect(vm.sessionExpired, isTrue, reason: code);
        expect(storage.token, isNull, reason: code);
        vm.dispose();
      }
    });

    test('네트워크 실패면 토큰을 지우지 않고 retryRequired이며, 다시 시도하면 복구된다', () async {
      storage.token = 'stored';
      memberApi
        ..fetchError = dioFailure('/v7/members/me')
        ..fetchFailTimes = 1;

      await viewModel.restoreSession();

      expect(viewModel.status, AuthStatus.retryRequired);
      expect(viewModel.message, contains('다시 시도'));
      expect(storage.token, 'stored');
      expect(storage.deleteCalls, 0);
      expect(viewModel.sessionExpired, isFalse);

      await viewModel.restoreSession();
      expect(viewModel.status, AuthStatus.signedIn);
    });

    test('서버 5xx도 로그아웃이 아니라 재시도다', () async {
      storage.token = 'stored';
      memberApi.fetchError = dioFailure('/v7/members/me', statusCode: 500);

      await viewModel.restoreSession();

      expect(viewModel.status, AuthStatus.retryRequired);
      expect(storage.token, 'stored');
    });

    test('저장소를 읽지 못하면 retryRequired이고 문구가 다르다', () async {
      storage.failRead = true;

      await viewModel.restoreSession();

      expect(viewModel.status, AuthStatus.retryRequired);
      expect(viewModel.message, contains('인증 저장소'));
    });
  });

  group('로그인', () {
    setUp(() => viewModel.restoreSession());

    test('성공하면 토큰을 저장하고 signedIn이 된다 (비밀번호는 저장하지 않는다)', () async {
      authApi.accessToken = 'new-jwt';

      await viewModel.login('lc@example.com', 'Password1!');

      expect(viewModel.status, AuthStatus.signedIn);
      expect(storage.token, 'new-jwt');
      expect(storage.token, isNot(contains('Password1!')));
      expect(viewModel.message, isNull);
      // 내 정보는 로그인 함수가 아니라 MainScreen의 loadMember()가 불러온다.
      expect(memberApi.fetchCalls, 0);
    });

    test('요청 중에는 authenticating이며 연속 탭이 요청을 늘리지 않는다', () async {
      authApi.gate = Completer<void>();

      final pending = viewModel.login('lc@example.com', 'Password1!');
      expect(viewModel.status, AuthStatus.authenticating);
      await viewModel.login('lc@example.com', 'Password1!');
      expect(authApi.calls, hasLength(1));

      authApi.gate!.complete();
      await pending;
      expect(viewModel.status, AuthStatus.signedIn);
    });

    test('AUTH401_1은 로그인 Form 오류다. 만료 안내를 켜지 않는다', () async {
      authApi.loginError = commonError(401, 'AUTH401_1', '이메일 또는 비밀번호가 올바르지 않습니다.');

      await viewModel.login('lc@example.com', 'wrong');

      expect(viewModel.status, AuthStatus.signedOut);
      expect(viewModel.message, '이메일 또는 비밀번호를 확인해 주세요.');
      expect(viewModel.sessionExpired, isFalse);
      expect(storage.token, isNull);
    });

    test('네트워크 실패는 입력 오류와 다른 문구다', () async {
      authApi.loginError = dioFailure('/v7/auth/login');

      await viewModel.login('lc@example.com', 'Password1!');

      expect(viewModel.status, AuthStatus.signedOut);
      expect(viewModel.message, contains('로그인 요청에 실패'));
    });

    test('토큰 저장에 실패하면 signedIn이 되지 않고 저장 실패 문구를 보인다', () async {
      storage.failSave = true;

      await viewModel.login('lc@example.com', 'Password1!');

      expect(viewModel.status, AuthStatus.signedOut);
      expect(viewModel.message, contains('안전하게 저장하지 못했어요'));
    });
  });

  group('내 정보', () {
    setUp(() => viewModel.restoreSession());

    test('loadMember는 GET me 결과를 보관하고, 이미 있으면 다시 호출하지 않는다', () async {
      await signIn();
      expect(viewModel.member?.email, 'lc@example.com');
      expect(memberApi.fetchCalls, 1);

      await viewModel.loadMember();
      expect(memberApi.fetchCalls, 1);

      await viewModel.loadMember(force: true);
      expect(memberApi.fetchCalls, 2);
    });

    test('네트워크 실패면 로그아웃하지 않고 error로 남겨 재시도할 수 있다', () async {
      await viewModel.login('lc@example.com', 'Password1!');
      memberApi
        ..fetchError = dioFailure('/v7/members/me')
        ..fetchFailTimes = 1;

      await viewModel.loadMember();

      expect(viewModel.status, AuthStatus.signedIn);
      expect(viewModel.memberStatus, MemberLoadStatus.error);
      expect(storage.token, isNotNull);

      await viewModel.loadMember(force: true);
      expect(viewModel.memberStatus, MemberLoadStatus.success);
    });

    test('만료(401)면 세션을 정리하고 만료 안내를 켠다', () async {
      await viewModel.login('lc@example.com', 'Password1!');
      memberApi.fetchError = expiredError('AUTH401_4');

      await viewModel.loadMember();

      expect(viewModel.status, AuthStatus.signedOut);
      expect(viewModel.sessionExpired, isTrue);
      expect(storage.token, isNull);
      expect(viewModel.member, isNull);
    });

    test('로그인하지 않은 상태에서는 호출하지 않는다', () async {
      await viewModel.loadMember();

      expect(memberApi.fetchCalls, 0);
    });

    test('updateMember는 GET me 없이 메모리의 내 정보를 교체하고 알린다', () async {
      await signIn();
      var notified = 0;
      viewModel.addListener(() => notified++);

      viewModel.updateMember(memberInfo(nickname: '새이름'));

      expect(viewModel.member?.nickname, '새이름');
      expect(notified, 1);
      expect(memberApi.fetchCalls, 1);
    });
  });

  group('로그아웃·만료·회원 전환', () {
    setUp(() => viewModel.restoreSession());

    test('로그아웃하면 토큰과 내 정보를 지우고, 만료 안내는 켜지 않는다', () async {
      await signIn();

      await viewModel.logout();

      expect(viewModel.status, AuthStatus.signedOut);
      expect(storage.token, isNull);
      expect(viewModel.member, isNull);
      expect(viewModel.sessionExpired, isFalse);
    });

    test('동시에 여러 요청이 401을 받아도 세션 정리는 한 번만 일어난다', () async {
      await signIn();
      var signedOutNotifications = 0;
      viewModel.addListener(() {
        if (viewModel.status == AuthStatus.signedOut &&
            viewModel.storageCleanupInProgress) {
          signedOutNotifications++;
        }
      });

      await Future.wait([
        viewModel.expireSession(),
        viewModel.expireSession(),
        viewModel.expireSession(),
      ]);

      expect(storage.deleteCalls, 1);
      expect(signedOutNotifications, 1);
      expect(viewModel.sessionExpired, isTrue);
    });

    test('직접 로그아웃한 뒤 늦게 도착한 401은 만료 안내를 켜지 않는다', () async {
      await signIn();
      await viewModel.logout();

      await viewModel.expireSession();

      expect(viewModel.sessionExpired, isFalse);
      expect(storage.deleteCalls, 1);
    });

    test('consumeSessionExpired는 안내를 한 번 보여준 뒤 끈다', () async {
      await signIn();
      await viewModel.expireSession();
      expect(viewModel.sessionExpired, isTrue);

      viewModel.consumeSessionExpired();

      expect(viewModel.sessionExpired, isFalse);
    });

    test('이전 세션에서 늦게 온 내 정보 응답은 새 세션에 반영되지 않는다', () async {
      await viewModel.login('lc@example.com', 'Password1!');
      memberApi.fetchGate = Completer<void>();
      final pending = viewModel.loadMember(); // A 회원의 GET me가 아직 오는 중

      await viewModel.logout();
      memberApi.fetchGate!.complete();
      await pending;

      expect(viewModel.member, isNull);
      expect(viewModel.status, AuthStatus.signedOut);
    });

    test('세션이 바뀔 때마다 sessionVersion이 올라간다', () async {
      final v0 = viewModel.sessionVersion;
      await viewModel.login('lc@example.com', 'Password1!');
      final v1 = viewModel.sessionVersion;
      await viewModel.logout();
      final v2 = viewModel.sessionVersion;

      expect(v1, greaterThan(v0));
      expect(v2, greaterThan(v1));
    });

    test('토큰 삭제에 실패하면 화면은 로그아웃되지만 저장소 확인을 안내한다', () async {
      await signIn();
      storage.failDelete = true;

      await viewModel.logout();

      expect(viewModel.status, AuthStatus.signedOut);
      expect(viewModel.message, contains('지우지 못했어요'));
      expect(viewModel.storageCleanupInProgress, isFalse);
    });

    test('이번 세션의 평점은 로그아웃하면 비워진다', () async {
      await signIn();
      final store = SessionRatingStore(viewModel)..add(ratingDto(1, 550));
      expect(store.ratings, hasLength(1));

      await viewModel.logout();

      expect(store.ratings, isEmpty);
      store.dispose();
    });
  });

  group('authRedirect', () {
    test('확인 중·확인 실패에는 스플래시만 보여준다 (보호 화면이 잠깐 보이지 않는다)', () {
      for (final status in [
        AuthStatus.initializing,
        AuthStatus.retryRequired,
      ]) {
        expect(authRedirect(status, '/start'), isNull);
        expect(authRedirect(status, '/home'), '/start');
        expect(authRedirect(status, '/login'), '/start');
        expect(authRedirect(status, '/my/ratings'), '/start');
      }
    });

    test('로그아웃 상태에서는 공개 화면만 허용하고 보호 화면은 로그인으로 보낸다', () {
      for (final status in [AuthStatus.signedOut, AuthStatus.authenticating]) {
        expect(authRedirect(status, '/login'), isNull);
        expect(authRedirect(status, '/register'), isNull);
        expect(authRedirect(status, '/start'), '/login');
        expect(authRedirect(status, '/home'), '/login');
        expect(authRedirect(status, '/my'), '/login');
        expect(authRedirect(status, '/my/profile/edit'), '/login');
        expect(authRedirect(status, '/movies/550'), '/login');
      }
    });

    test('로그인 상태에서는 스플래시·로그인·회원가입을 홈으로 보낸다', () {
      expect(authRedirect(AuthStatus.signedIn, '/start'), '/home');
      expect(authRedirect(AuthStatus.signedIn, '/login'), '/home');
      expect(authRedirect(AuthStatus.signedIn, '/register'), '/home');
      expect(authRedirect(AuthStatus.signedIn, '/home'), isNull);
      expect(authRedirect(AuthStatus.signedIn, '/my/ratings'), isNull);
    });
  });
}
