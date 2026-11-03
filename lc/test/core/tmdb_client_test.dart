import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/core/network/tmdb_client.dart';

import '../data/tmdb_movie_service_test.dart' show RecordingAdapter;
import '../test_helpers.dart';

const _secret = 'secret-token-1234567890';

void main() {
  setUp(() {
    dotenv.loadFromString(envString: 'TMDB_ACCESS_TOKEN=$_secret');
  });

  test('요청에는 Bearer Token 헤더가 실제로 붙는다', () async {
    final adapter = RecordingAdapter(
      body: {'page': 1, 'results': [], 'total_pages': 1, 'total_results': 0},
    );
    final dio = createTmdbClient()..httpClientAdapter = adapter;

    await dio.get('/movie/popular');

    expect(adapter.requests.single.headers['Authorization'], 'Bearer $_secret');
  });

  test('로그에는 Token 원문이 남지 않고 마스킹된다', () async {
    final adapter = RecordingAdapter(
      body: {'page': 1, 'results': [], 'total_pages': 1, 'total_results': 0},
    );
    final dio = createTmdbClient()..httpClientAdapter = adapter;

    final logs = await collectDebugPrint(() async {
      await dio.get('/movie/popular', queryParameters: {'page': 1});
    });

    final joined = logs.join('\n');
    expect(joined, contains('[TMDB 요청] GET'));
    expect(joined, contains('[TMDB 응답] 200'));
    expect(joined, contains('Bearer ***'));
    expect(joined, isNot(contains(_secret)));
  });

  test('실패한 요청은 URL과 상태 코드를 로그로 남기되 Token은 남기지 않는다', () async {
    final adapter = RecordingAdapter(
      statusCode: 401,
      body: {'status_message': 'Invalid API key'},
    );
    final dio = createTmdbClient()..httpClientAdapter = adapter;

    final logs = await collectDebugPrint(() async {
      await expectLater(
        dio.get('/movie/popular'),
        throwsA(isA<DioException>()),
      );
    });

    final joined = logs.join('\n');
    expect(joined, contains('[TMDB 오류] 401'));
    expect(joined, contains('/movie/popular'));
    expect(joined, isNot(contains(_secret)));
  });
}
