import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/data/models/favorite_check_dto.dart';
import 'package:movielog/data/models/favorite_response_dto.dart';
import 'package:movielog/data/services/favorite_api_service.dart';

import 'fake_auth.dart';

class FakeFavoriteApiService extends FavoriteApiService {
  FakeFavoriteApiService({Iterable<int> movieIds = const []}) : super(Dio()) {
    movieIds.forEach(_store);
  }

  final _favorites = <int, FavoriteResponseDto>{};
  var _nextId = 1;

  DioException? listFailure;
  DioException? checkFailure;
  DioException? addFailure;
  DioException? deleteFailure;
  Completer<void>? listGate;
  Completer<void>? toggleGate;
  final calls = <String>[];

  Set<int> get movieIds => _favorites.keys.toSet();

  void _store(int movieId) {
    _favorites[movieId] = FavoriteResponseDto(
      favoriteId: _nextId++,
      movieId: movieId,
      createdAt: DateTime(2026, 11, 1),
    );
  }

  void setFavorites(Iterable<int> movieIds) {
    _favorites.clear();
    movieIds.forEach(_store);
  }

  @override
  Future<FavoriteResponseDto> addFavorite({required int movieId}) async {
    calls.add('POST $movieId');
    await toggleGate?.future;
    final error = addFailure;
    if (error != null) throw error;
    if (_favorites.containsKey(movieId)) {
      throw apiError(409, 'FAVORITE409_1');
    }
    _store(movieId);
    return _favorites[movieId]!;
  }

  @override
  Future<List<FavoriteResponseDto>> fetchMyFavorites() async {
    calls.add('GET list');
    await listGate?.future;
    final error = listFailure;
    if (error != null) throw error;
    return _favorites.values.toList();
  }

  @override
  Future<FavoriteCheckDto> checkFavorite({required int movieId}) async {
    calls.add('GET $movieId');
    final error = checkFailure;
    if (error != null) throw error;
    return FavoriteCheckDto(
      movieId: movieId,
      isFavorite: _favorites.containsKey(movieId),
    );
  }

  @override
  Future<void> deleteFavorite({required int movieId}) async {
    calls.add('DELETE $movieId');
    await toggleGate?.future;
    final error = deleteFailure;
    if (error != null) throw error;
    if (_favorites.remove(movieId) == null) {
      throw apiError(404, 'FAVORITE404_1');
    }
  }
}
