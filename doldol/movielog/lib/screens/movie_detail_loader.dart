import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/learning_member_session.dart';
import '../view_models/movie_detail_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_list_loading.dart';
import 'movie_detail_screen.dart';

/// 영화 정보는 extra가 있으면 그대로 쓰고, 없으면(직접 접근, Deep Link) TMDB에서 다시 조회한다.
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
  late final Future<TmdbMovieDto> _movieFuture;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMovie;
    _movieFuture = initial != null
        ? Future.value(initial)
        : context.read<TmdbMovieService>().fetchMovieDetail(widget.movieId);
  }

  PreferredSizeWidget _appBar() {
    return CommonAppBar(
      title: 'Cinema Archive',
      centerTitle: true,
      titleStyle: AppTextStyles.titleMedium.copyWith(color: AppColors.violet),
      onBack: () => context.canPop() ? context.pop() : context.go('/movies'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TmdbMovieDto>(
      future: _movieFuture, // build마다 새 Future를 만들지 않는다
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(appBar: _appBar(), body: const MovieListLoading());
        }

        final movie = snapshot.data;
        if (snapshot.hasError || movie == null) {
          return Scaffold(
            appBar: _appBar(),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '영화를 불러오지 못했습니다.',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/movies'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.violet,
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text('목록으로'),
                  ),
                ],
              ),
            ),
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