import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/edit_profile_view_model.dart';
import 'package:movielog/view_models/session_rating_store.dart';

import '../fakes/fake_auth.dart';
import '../fakes/fake_rating_api_service.dart';

void main() {
  late FakeAuthApiService authApi;
  late FakeMemberApiService memberApi;
  late InMemoryTokenStorage storage;
  late SessionRatingStore store;
  late AuthViewModel auth;

  setUp(() {
    authApi = FakeAuthApiService();
    memberApi = FakeMemberApiService();
    storage = InMemoryTokenStorage();
    store = SessionRatingStore();
    auth = AuthViewModel(authApi, memberApi, storage, store);
  });

  tearDown(() => auth.dispose());

  group('restoreSession', () {
    test('토큰이 없으면 GET me 없이 signedOut', () async {
      await auth.restoreSession();
      expect(auth.status, AuthStatus.signedOut);
      expect(memberApi.fetchCalls, 0);
    });

    test('토큰이 있으면 GET me 성공 뒤에만 signedIn', () async {
      storage.token = 'saved';
      memberApi.fetchPending = Completer<void>();

      final future = auth.restoreSession();
      await Future<void>.delayed(Duration.zero);
      expect(auth.status, AuthStatus.initializing);

      memberApi.fetchPending!.complete();
      await future;
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.member?.nickname, '무비러버');
    });

    test('만료 토큰(AUTH401_4)은 토큰을 지우고 만료 안내를 켠다', () async {
      storage.token = 'expired';
      memberApi.fetchFailure = apiError(401, 'AUTH401_4');

      await auth.restoreSession();

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
      expect(storage.token, isNull);
    });

    test('네트워크 실패는 토큰을 지우지 않고 retryRequired', () async {
      storage.token = 'saved';
      memberApi.fetchFailure = connectionError();

      await auth.restoreSession();

      expect(auth.status, AuthStatus.retryRequired);
      expect(storage.token, 'saved');
    });

    test('저장소 읽기 실패는 retryRequired', () async {
      storage.readError = Exception('keystore');
      await auth.restoreSession();
      expect(auth.status, AuthStatus.retryRequired);
      expect(auth.message, contains('인증 저장소'));
    });
  });

  group('login', () {
    test('성공하면 토큰을 저장하고 signedIn', () async {
      await auth.login('movie@example.com', 'Umc1234!');

      expect(auth.status, AuthStatus.signedIn);
      expect(storage.token, 'test-token');
      expect(auth.sessionExpired, isFalse);
    });

    test('AUTH401_1은 Form 오류일 뿐 만료 처리를 하지 않는다', () async {
      authApi.failure = apiError(401, 'AUTH401_1');

      await auth.login('movie@example.com', 'wrong');

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.message, '이메일 또는 비밀번호를 확인해 주세요.');
      expect(auth.sessionExpired, isFalse);
    });

    test('네트워크 실패는 다른 문구로 구분한다', () async {
      authApi.failure = connectionError();
      await auth.login('movie@example.com', 'Umc1234!');
      expect(auth.message, '로그인 요청에 실패했어요. 잠시 후 다시 시도해 주세요.');
    });

    test('로그인 요청 중 중복 호출은 무시한다', () async {
      authApi.pending = Completer<void>();
      final first = auth.login('a@a.com', 'p');
      await auth.login('a@a.com', 'p');
      authApi.pending!.complete();
      await first;
      expect(authApi.requests, hasLength(1));
    });
  });

  group('loadMember / logout', () {
    setUp(() async => auth.login('movie@example.com', 'Umc1234!'));

    test('loadMember는 member를 채우고, 실패는 로그아웃 없이 error', () async {
      memberApi.fetchFailure = connectionError();
      await auth.loadMember();
      expect(auth.memberStatus, MemberLoadStatus.error);
      expect(auth.status, AuthStatus.signedIn);

      memberApi.fetchFailure = null;
      await auth.loadMember(force: true);
      expect(auth.memberStatus, MemberLoadStatus.success);
      expect(auth.member, isNotNull);
    });

    test('loadMember의 401은 세션을 정리한다', () async {
      memberApi.fetchFailure = apiError(401, 'AUTH401_3');
      await auth.loadMember();
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
    });

    test('직접 로그아웃은 토큰·member·세션 평점을 지우고 만료 안내는 켜지 않는다', () async {
      await auth.loadMember();
      store.add(ratingFixture(1, 13));

      await auth.logout();

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.member, isNull);
      expect(storage.token, isNull);
      expect(store.ratings, isEmpty);
      expect(auth.sessionExpired, isFalse);
    });

    test('로그아웃 뒤 늦게 도착한 GET me 응답은 무시한다', () async {
      memberApi.fetchPending = Completer<void>();
      final loading = auth.loadMember();
      await auth.logout();
      memberApi.fetchPending!.complete();
      await loading;

      expect(auth.member, isNull);
      expect(auth.status, AuthStatus.signedOut);
    });
  });

  group('EditProfileViewModel', () {
    late EditProfileViewModel viewModel;

    setUp(() async {
      await auth.login('movie@example.com', 'Umc1234!');
      await auth.loadMember();
      viewModel = EditProfileViewModel(memberApi, auth);
    });

    tearDown(() => viewModel.dispose());

    test('2~12자 규칙은 요청 전에 검사한다', () async {
      expect(await viewModel.save('a'), isFalse);
      expect(viewModel.nicknameError, '닉네임은 2~12자로 입력해 주세요.');
      expect(memberApi.nicknameUpdates, isEmpty);
    });

    test('현재 닉네임과 같으면 요청 없이 성공', () async {
      expect(await viewModel.save(' 무비러버 '), isTrue);
      expect(memberApi.nicknameUpdates, isEmpty);
    });

    test('성공하면 AuthViewModel.member를 교체한다', () async {
      expect(await viewModel.save('영화광'), isTrue);
      expect(auth.member?.nickname, '영화광');
    });

    test('MEMBER409_1은 필드 오류로 보여주고 로그인을 유지한다', () async {
      memberApi.updateFailure = apiError(409, 'MEMBER409_1');
      expect(await viewModel.save('영화광'), isFalse);
      expect(viewModel.nicknameError, '이미 사용 중인 닉네임이에요.');
      expect(auth.status, AuthStatus.signedIn);
    });

    test('네트워크 실패는 message로 안내하고 로그아웃하지 않는다', () async {
      memberApi.updateFailure = connectionError();
      expect(await viewModel.save('영화광'), isFalse);
      expect(viewModel.message, contains('네트워크'));
      expect(auth.status, AuthStatus.signedIn);
    });

    test('401은 세션을 만료 처리한다', () async {
      memberApi.updateFailure = apiError(401, 'AUTH401_4');
      expect(await viewModel.save('영화광'), isFalse);
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
    });
  });

  test('authRedirect는 상태별로 허용 경로를 나눈다', () {
    expect(authRedirect(AuthStatus.initializing, '/home'), '/start');
    expect(authRedirect(AuthStatus.retryRequired, '/start'), isNull);
    expect(authRedirect(AuthStatus.signedOut, '/my'), '/login');
    expect(authRedirect(AuthStatus.signedOut, '/register'), isNull);
    expect(authRedirect(AuthStatus.authenticating, '/login'), isNull);
    expect(authRedirect(AuthStatus.signedIn, '/login'), '/home');
    expect(authRedirect(AuthStatus.signedIn, '/movies/550'), isNull);
  });
}
