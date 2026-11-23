import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/core/utils/map_bounded.dart';
import 'package:movielog/view_models/favorite_detail_view_model.dart';
import 'package:movielog/view_models/favorites_view_model.dart';
import 'package:movielog/view_models/load_phase.dart';

import '../fakes/fake_auth.dart';
import '../fakes/fake_favorite_api_service.dart';
import '../fakes/fake_tmdb_movie_service.dart';

const account = 'movie@example.com';

void main() {
  late SessionGuard guard;
  late FakeFavoriteApiService api;
  late int expiredCalls;

  setUp(() {
    guard = SessionGuard()..startSession(account);
    api = FakeFavoriteApiService();
    expiredCalls = 0;
  });

  Future<void> onExpired() async => expiredCalls++;

  group('FavoriteDetailViewModel', () {
    FavoriteDetailViewModel create({int movieId = 550}) =>
        FavoriteDetailViewModel(
          movieId: movieId,
          favoriteApi: api,
          sessionGuard: guard,
          accountId: account,
          onSessionExpired: onExpired,
        );

    test('서버 여부를 불러오고 등록·해제 성공 후에만 상태를 바꾼다', () async {
      final vm = create();
      await vm.load();
      expect(vm.hasLoadedStatus, isTrue);
      expect(vm.isFavorite, isFalse);

      api.toggleGate = Completer<void>();
      final saving = vm.toggle();
      expect(vm.isSaving, isTrue);
      expect(vm.isFavorite, isFalse);
      api.toggleGate!.complete();
      await saving;
      expect(vm.isFavorite, isTrue);

      api.toggleGate = null;
      await vm.toggle();
      expect(vm.isFavorite, isFalse);
      expect(api.calls, ['GET 550', 'POST 550', 'DELETE 550']);
    });

    test('409면 POST를 반복하지 않고 여부 GET으로 맞춘다', () async {
      final vm = create();
      await vm.load();
      api.setFavorites([550]);

      await vm.toggle();
      expect(vm.isFavorite, isTrue);
      expect(vm.errorMessage, isNull);
      expect(api.calls.where((call) => call == 'POST 550'), hasLength(1));
      expect(api.calls.last, 'GET 550');
    });

    test('404면 여부 GET으로 해제 상태를 맞춘다', () async {
      api.setFavorites([550]);
      final vm = create();
      await vm.load();
      api.setFavorites([]);

      await vm.toggle();
      expect(vm.isFavorite, isFalse);
      expect(vm.errorMessage, isNull);
    });

    test('네트워크 실패면 이전 상태를 유지하고 안내 문구를 남긴다', () async {
      final vm = create();
      await vm.load();
      api.addFailure = connectionError();

      await vm.toggle();
      expect(vm.isFavorite, isFalse);
      expect(vm.errorMessage, '즐겨찾기 등록에 실패했습니다.');
    });

    test('세션 만료 코드면 만료 처리를 한 번 호출하고 403·네트워크는 호출하지 않는다', () async {
      final vm = create();
      api.checkFailure = apiError(401, 'AUTH401_3');
      await vm.load();
      expect(expiredCalls, 1);

      api.checkFailure = apiError(403, 'COMMON403');
      await create().load();
      api.checkFailure = connectionError();
      await create().load();
      expect(expiredCalls, 1);
    });

    test('요청 중 세션이 바뀌면 늦은 응답과 401을 반영하지 않는다', () async {
      final vm = create();
      await vm.load();
      api
        ..toggleGate = Completer<void>()
        ..addFailure = apiError(401, 'AUTH401_4');

      final saving = vm.toggle();
      guard.invalidate();
      guard.startSession('other@example.com');
      api.toggleGate!.complete();
      await saving;

      expect(expiredCalls, 0);
      expect(vm.isFavorite, isFalse);
    });
  });

  group('FavoritesViewModel', () {
    late FakeTmdbMovieService tmdb;

    setUp(() => tmdb = FakeTmdbMovieService());

    FavoritesViewModel create() => FavoritesViewModel(
      favoriteApi: api,
      tmdbApi: tmdb,
      sessionGuard: guard,
      accountId: account,
      onSessionExpired: onExpired,
    );

    test('movieId로 TMDB 정보를 붙이고 한 건 실패는 그 카드만 비워 둔다', () async {
      api.setFavorites([1, 2, 3]);
      tmdb.failingMovieIds = {2};
      final vm = create();

      await vm.refresh();
      expect(vm.phase, LoadPhase.ready);
      expect(vm.items.map((item) => item.hasMovie), [true, false, true]);

      tmdb.failingMovieIds = {};
      tmdb.detailCalls.clear();
      await vm.retryMovie(2);
      expect(tmdb.detailCalls, [2]);
      expect(vm.items[1].movie?.title, '영화 2');
    });

    test('빈 목록과 조회 실패를 구분한다', () async {
      final vm = create();
      await vm.refresh();
      expect(vm.phase, LoadPhase.empty);

      api.listFailure = connectionError();
      await vm.refresh();
      expect(vm.phase, LoadPhase.error);
    });

    test('세션이 바뀐 뒤 도착한 이전 계정 목록은 반영하지 않는다', () async {
      api
        ..setFavorites([1])
        ..listGate = Completer<void>();
      final vm = create();

      final loading = vm.refresh();
      guard.invalidate();
      api.listGate!.complete();
      await loading;

      expect(vm.items, isEmpty);
      expect(vm.phase, LoadPhase.loading);
    });

    test('mapBounded는 순서를 유지하고 동시에 최대 5개만 실행한다', () async {
      var running = 0;
      var peak = 0;
      final result = await mapBounded(List.generate(12, (i) => i), 5, (
        value,
      ) async {
        running++;
        peak = running > peak ? running : peak;
        await Future<void>.delayed(Duration.zero);
        running--;
        return value * 10;
      });

      expect(peak, 5);
      expect(result, List.generate(12, (i) => i * 10));
    });
  });
}
