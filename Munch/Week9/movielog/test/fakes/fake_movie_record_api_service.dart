import 'package:dio/dio.dart';
import 'package:movielog/data/models/movie_record_models.dart';
import 'package:movielog/data/services/movie_record_api_service.dart';

import 'fake_auth.dart';
import 'fake_favorite_api_service.dart';
import 'fake_rating_api_service.dart';

class FakeMovieRecordApiService extends MovieRecordApiService {
  FakeMovieRecordApiService({FakeFavoriteApiService? favorites})
    : favorites = favorites ?? FakeFavoriteApiService(),
      super(Dio());

  final FakeFavoriteApiService favorites;
  final requests = <MovieRecordRequest>[];
  DioException? failure;

  @override
  Future<MovieRecordResponse> saveRecord(MovieRecordRequest request) async {
    requests.add(request);
    final error = failure;
    if (error != null) throw error;
    if (request.addToFavorites &&
        favorites.movieIds.contains(request.movieId)) {
      throw apiError(409, 'FAVORITE409_1');
    }
    final favorite = request.addToFavorites
        ? await favorites.addFavorite(movieId: request.movieId)
        : null;
    return MovieRecordResponse(
      rating: ratingFixture(
        200 + requests.length,
        request.movieId,
        score: request.score,
        comment: request.comment,
      ),
      favorite: favorite,
    );
  }
}
