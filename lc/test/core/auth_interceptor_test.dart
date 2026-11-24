import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/core/network/movie_log_client.dart';
import 'package:movielog/core/network/tmdb_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../data/tmdb_movie_service_test.dart' show RecordingAdapter;
import '../week6_helpers.dart';

const _jwt = 'movielog-jwt-abc123';

void main() {
  late FakeTokenStorage storage;
  late RecordingAdapter adapter;
  late Dio authDio;

  setUp(() {
    storage = FakeTokenStorage(_jwt);
    adapter = RecordingAdapter(body: {'ok': true});
    authDio = createAuthMovieLogClient(storage)..httpClientAdapter = adapter;
  });

  String? sentAuth() =>
      adapter.requests.last.headers['Authorization'] as String?;

  test('보호 경로(내 정보, 평점 쓰기)에는 Bearer 토큰을 붙인다', () async {
    await authDio.get('/v8/members/me');
    expect(sentAuth(), 'Bearer $_jwt');

    await authDio.post('/v8/ratings', data: {'movieId': 550, 'score': 5});
    expect(sentAuth(), 'Bearer $_jwt');

    await authDio.patch('/v8/ratings/3', data: {'score': 4, 'comment': null});
    expect(sentAuth(), 'Bearer $_jwt');

    await authDio.delete('/v8/ratings/3');
    expect(sentAuth(), 'Bearer $_jwt');
  });

  test('보호용 Client로 보내도 공개 경로에는 토큰을 붙이지 않는다', () async {
    for (final path in [
      '/v8/auth/login',
      '/v8/members',
      '/v8/members/nickname/abc',
      '/v8/members/1/ratings',
      '/v8/ratingsX',
    ]) {
      await authDio.get(path);
      expect(sentAuth(), isNull, reason: path);
    }
  });

  test('다른 host로 가는 요청에는 토큰을 붙이지 않는다', () async {
    await authDio.get('https://image.tmdb.org/t/p/w500/a.jpg');
    expect(sentAuth(), isNull);

    await authDio.get('https://api.themoviedb.org/v8/ratings');
    expect(sentAuth(), isNull);
  });

  test('공개용 Client는 토큰이 저장돼 있어도 어떤 요청에도 붙이지 않는다', () async {
    final publicDio = createMovieLogClient()..httpClientAdapter = adapter;

    await publicDio.get('/v8/members/me');

    expect(sentAuth(), isNull);
  });

  test('토큰이 없으면 헤더 없이 보낸다 (서버가 AUTH401_2로 답한다)', () async {
    storage.token = null;

    await authDio.get('/v8/members/me');

    expect(sentAuth(), isNull);
  });

  test('요청마다 저장소를 다시 읽어, 로그아웃 뒤에는 이전 토큰을 재사용하지 않는다', () async {
    await authDio.get('/v8/members/me');
    expect(sentAuth(), 'Bearer $_jwt');

    storage.token = 'new-token';
    await authDio.get('/v8/members/me');
    expect(sentAuth(), 'Bearer new-token');

    storage.token = null;
    await authDio.get(
      '/v8/members/me',
      options: Options(headers: {'Authorization': 'Bearer stale'}),
    );
    expect(sentAuth(), isNull);
  });

  test('저장소를 읽지 못하면 요청을 보내지 않고 저장소 오류로 끝낸다 (서버 401과 구분)', () async {
    storage.failRead = true;

    await expectLater(
      authDio.get('/v8/members/me'),
      throwsA(
        isA<DioException>()
            .having((e) => e.response, 'response', isNull)
            .having((e) => e.error, 'error', isA<StateError>()),
      ),
    );
    expect(adapter.requests, isEmpty);
  });

  test('TMDB Client에는 MovieLog JWT가 실리지 않고 TMDB Token만 실린다', () async {
    dotenv.loadFromString(envString: 'TMDB_ACCESS_TOKEN=tmdb-read-token');
    final tmdb = createTmdbClient()..httpClientAdapter = adapter;

    await tmdb.get('/movie/popular');

    expect(sentAuth(), 'Bearer tmdb-read-token');
    expect(sentAuth(), isNot(contains(_jwt)));
  });
}
