import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/auth_interceptor.dart';

import '../fakes/fake_auth.dart';
import '../fakes/pump_app.dart';
import '../fakes/stub_http_adapter.dart';

Future<void> fillLogin(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'movie@example.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'Umc1234!');
  await tapLogin(tester);
}

Future<void> tapLogin(WidgetTester tester) async {
  final button = find.widgetWithText(ElevatedButton, '로그인');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('토큰이 없으면 로그인 화면, 실패 문구 후 성공하면 홈으로 이동한다', (tester) async {
    final authService = FakeAuthApiService()
      ..failure = apiError(401, 'AUTH401_1');
    await pumpApp(tester, authService: authService, signedIn: false);
    expect(currentPath(tester), '/login');

    await fillLogin(tester);
    expect(find.text('이메일 또는 비밀번호를 확인해 주세요.'), findsOneWidget);
    expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsNothing);

    authService.failure = null;
    await tapLogin(tester);
    expect(currentPath(tester), '/home');
  });

  testWidgets('저장된 토큰은 GET me 검증 후 홈으로 복원된다', (tester) async {
    final memberService = FakeMemberApiService();
    await pumpApp(tester, memberService: memberService);

    expect(currentPath(tester), '/home');
    expect(memberService.fetchCalls, 1);
  });

  testWidgets('세션 확인 실패는 스플래시에서 재시도할 수 있다', (tester) async {
    final memberService = FakeMemberApiService()
      ..fetchFailure = connectionError();
    await pumpApp(tester, memberService: memberService);

    expect(currentPath(tester), '/start');
    expect(find.text('다시 시도'), findsOneWidget);

    memberService.fetchFailure = null;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(currentPath(tester), '/home');
  });

  testWidgets('만료 토큰으로 시작하면 로그인 화면에서 만료 안내를 한 번 보여준다', (tester) async {
    final memberService = FakeMemberApiService()
      ..fetchFailure = apiError(401, 'AUTH401_4');
    final storage = InMemoryTokenStorage('expired');
    await pumpApp(tester, memberService: memberService, tokenStorage: storage);

    expect(currentPath(tester), '/login');
    expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsOneWidget);
    expect(storage.token, isNull);
  });

  testWidgets('마이페이지에 내 정보·가입일을 보여주고 로그아웃하면 보호 화면이 막힌다', (tester) async {
    final storage = InMemoryTokenStorage('saved');
    await pumpApp(tester, tokenStorage: storage, location: '/my');

    expect(find.text('무비러버'), findsOneWidget);
    expect(find.text('movie@example.com'), findsOneWidget);
    expect(find.text('2026.10.10 가입'), findsOneWidget);

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(currentPath(tester), '/login');
    expect(storage.token, isNull);
    expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsNothing);

    routerOf(tester).go('/my/ratings');
    await tester.pumpAndSettle();
    expect(currentPath(tester), '/login');
  });

  testWidgets('마이페이지 내 정보 실패는 재시도 버튼을 보여준다', (tester) async {
    final memberService = FakeMemberApiService();
    await pumpApp(tester, memberService: memberService, signedIn: false);
    memberService.fetchFailure = connectionError();
    await fillLogin(tester);
    routerOf(tester).go('/my');
    await tester.pumpAndSettle();

    expect(find.text('내 정보를 불러오지 못했어요.'), findsOneWidget);

    memberService.fetchFailure = null;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('무비러버'), findsOneWidget);
  });

  testWidgets('프로필 수정 성공은 마이페이지에 바로 반영되고 409는 입력값을 유지한다', (tester) async {
    final memberService = FakeMemberApiService();
    await pumpApp(tester, memberService: memberService, location: '/my');

    await tester.tap(find.text('프로필 수정'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);

    memberService.updateFailure = apiError(409, 'MEMBER409_1');
    await tester.enterText(find.byType(TextField).last, '영화광');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('이미 사용 중인 닉네임이에요.'), findsOneWidget);
    expect(find.text('영화광'), findsOneWidget);

    memberService.updateFailure = null;
    await tester.enterText(find.byType(TextField).last, '새닉네임');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(currentPath(tester), '/my');
    expect(find.text('새닉네임'), findsOneWidget);
  });

  testWidgets('변경 내용이 있으면 뒤로가기 전에 확인 Dialog를 띄운다', (tester) async {
    await pumpApp(tester, location: '/my');
    await tester.tap(find.text('프로필 수정'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '바뀐닉네임');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('변경 내용을 버릴까요?'), findsOneWidget);

    await tester.tap(find.text('계속 수정'));
    await tester.pumpAndSettle();
    expect(currentPath(tester), '/my/profile/edit');

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    expect(currentPath(tester), '/my');
    expect(find.text('무비러버'), findsOneWidget);
  });

  testWidgets('이메일 저장을 체크하면 다음 로그인 화면에 이메일이 채워진다', (tester) async {
    final savedEmail = FakeSavedEmailStorage();
    await pumpApp(tester, savedEmailStorage: savedEmail, signedIn: false);

    await tester.tap(find.text('이메일 저장'));
    await fillLogin(tester);
    expect(savedEmail.email, 'movie@example.com');

    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, savedEmailStorage: savedEmail, signedIn: false);
    expect(find.text('movie@example.com'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });

  group('AuthInterceptor', () {
    Future<Map<String, dynamic>> headersFor(String url, String? token) async {
      late Map<String, dynamic> headers;
      final dio = Dio()
        ..httpClientAdapter = StubHttpAdapter((options) {
          headers = options.headers;
          return (200, {});
        })
        ..interceptors.add(AuthInterceptor(InMemoryTokenStorage(token)));
      await dio.get(url);
      return headers;
    }

    test('보호 경로에만 Bearer 토큰을 붙인다', () async {
      expect(
        (await headersFor(
          'https://workbook.devnoco.com/v8/members/me',
          't',
        ))['Authorization'],
        'Bearer t',
      );
      expect(
        (await headersFor(
          'https://workbook.devnoco.com/v8/ratings/3',
          't',
        ))['Authorization'],
        'Bearer t',
      );
      expect(
        await headersFor('https://workbook.devnoco.com/v8/auth/login', 't'),
        isNot(contains('Authorization')),
      );
      expect(
        await headersFor(
          'https://workbook.devnoco.com/v8/members/1/ratings',
          't',
        ),
        isNot(contains('Authorization')),
      );
      expect(
        await headersFor('https://api.themoviedb.org/v8/ratings', 't'),
        isNot(contains('Authorization')),
      );
    });

    test('즐겨찾기는 정해진 메서드·경로에만 Bearer 토큰을 붙인다', () async {
      Future<Object?> authFor(String method, String path) async {
        late Map<String, dynamic> headers;
        final dio = Dio()
          ..httpClientAdapter = StubHttpAdapter((options) {
            headers = options.headers;
            return (200, {});
          })
          ..interceptors.add(AuthInterceptor(InMemoryTokenStorage('t')));
        await dio.request(
          'https://workbook.devnoco.com$path',
          options: Options(method: method),
        );
        return headers['Authorization'];
      }

      expect(await authFor('GET', '/v8/favorites'), 'Bearer t');
      expect(await authFor('POST', '/v8/favorites'), 'Bearer t');
      expect(await authFor('GET', '/v8/favorites/550'), 'Bearer t');
      expect(await authFor('DELETE', '/v8/favorites/550'), 'Bearer t');
      expect(await authFor('POST', '/v8/movie-records'), 'Bearer t');
      expect(await authFor('DELETE', '/v8/favorites'), isNull);
      expect(await authFor('GET', '/v8/favorites/abc'), isNull);
      expect(await authFor('GET', '/v7/members/me'), isNull);
    });

    test('토큰이 없으면 헤더 없이 보낸다', () async {
      expect(
        await headersFor('https://workbook.devnoco.com/v8/ratings', null),
        isNot(contains('Authorization')),
      );
    });
  });
}
