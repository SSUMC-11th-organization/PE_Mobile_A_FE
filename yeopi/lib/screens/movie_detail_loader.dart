import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../view_models/learning_member_session.dart';
import '../view_models/movie_detail_view_model.dart';
import '../widgets/common_app_bar.dart';
import 'movie_detail_screen.dart';

// 목록에서 넘긴 영화(extra)가 있으면 그대로 쓰고, 주소로 직접 들어오면 TMDB 상세로 다시 조회합니다.
class MovieDetailLoader extends StatefulWidget {
  const MovieDetailLoader({
    super.key,
    required this.movieId,
    this.initialMovie,
  });

  final int movieId;
  final TmdbMovieDto? initialMovie;

  @override
  State<MovieDetailLoader> createState() => _MovieDetailLoaderState();
}

class _MovieDetailLoaderState extends State<MovieDetailLoader> {
  // build마다 새 Future를 만들지 않도록 initState에서 한 번만 만듭니다.
  late final Future<TmdbMovieDto> _movieFuture = widget.initialMovie != null
      ? Future.value(widget.initialMovie!)
      : context.read<TmdbMovieService>().fetchMovieDetail(widget.movieId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TmdbMovieDto>(
      future: _movieFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final movie = snapshot.data;
        if (snapshot.hasError || movie == null) {
          return Scaffold(
            appBar: CommonAppBar(title: '영화 상세', onBack: () => context.pop()),
            body: const Center(child: Text('영화를 불러오지 못했습니다.')),
          );
        }
        return ChangeNotifierProvider<MovieDetailViewModel>(
          create: (context) => MovieDetailViewModel(
            context.read<RatingApiService>(),
            context.read<LearningMemberSession>().memberId,
            movie,
          ),
          child: const MovieDetailScreen(),
        );
      },
    );
  }
}
