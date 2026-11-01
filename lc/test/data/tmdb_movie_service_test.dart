import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/services/tmdb_movie_service.dart';

/// 네트워크 대신 정해진 JSON을 돌려주고, 보낸 요청을 기록한다.
class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter({this.statusCode = 200, this.body = const {}});

  final int statusCode;
  final Map<String, dynamic> body;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

TmdbMovieService serviceWith(RecordingAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/3'))
    ..httpClientAdapter = adapter;
  return TmdbMovieService(dio);
}

const _emptyPage = {
  'page': 1,
  'results': <Object>[],
  'total_pages': 1,
  'total_results': 0,
};

void main() {
  test('fetchPopular는 /movie/popular에 한국어와 page를 보낸다', () async {
    final adapter = RecordingAdapter(body: _emptyPage);

    await serviceWith(adapter).fetchPopular();

    final request = adapter.requests.single;
    expect(request.path, '/movie/popular');
    expect(request.queryParameters['language'], 'ko-KR');
    expect(request.queryParameters['page'], 1);
  });

  test('최종 요청 주소에는 baseUrl의 /3 버전 경로가 유지된다', () async {
    final adapter = RecordingAdapter(body: _emptyPage);
    final service = serviceWith(adapter);

    await service.fetchPopular();
    await service.discoverMovies(page: 1, genreId: 28);
    await service.fetchGenres();

    final paths = adapter.requests.map((request) => request.uri.path).toList();
    expect(paths, ['/3/movie/popular', '/3/discover/movie', '/3/genre/movie/list']);
  });

  test('장르가 없으면 discover는 with_genres를 보내지 않는다', () async {
    final adapter = RecordingAdapter(body: _emptyPage);

    await serviceWith(adapter).discoverMovies(page: 1);

    final query = adapter.requests.single.queryParameters;
    expect(adapter.requests.single.path, '/discover/movie');
    expect(query.containsKey('with_genres'), isFalse);
    expect(query['sort_by'], 'popularity.desc');
    expect(query['include_adult'], false);
    expect(query['include_video'], false);
  });

  test('장르를 고르면 discover는 with_genres로 id를 보낸다', () async {
    final adapter = RecordingAdapter(body: _emptyPage);

    await serviceWith(adapter).discoverMovies(page: 3, genreId: 28);

    final query = adapter.requests.single.queryParameters;
    expect(query['with_genres'], 28);
    expect(query['page'], 3);
  });

  test('fetchGenres는 genres 배열을 장르 DTO로 바꾼다', () async {
    final adapter = RecordingAdapter(
      body: {
        'genres': [
          {'id': 28, 'name': '액션'},
          {'id': 12, 'name': '모험'},
        ],
      },
    );

    final genres = await serviceWith(adapter).fetchGenres();

    expect(adapter.requests.single.path, '/genre/movie/list');
    expect(adapter.requests.single.queryParameters['language'], 'ko');
    expect(genres.map((genre) => genre.name), ['액션', '모험']);
  });

  test('401 응답은 DioException으로 전달된다', () async {
    final adapter = RecordingAdapter(
      statusCode: 401,
      body: {'status_message': 'Invalid API key'},
    );

    expect(
      serviceWith(adapter).fetchPopular(),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
  });
}
