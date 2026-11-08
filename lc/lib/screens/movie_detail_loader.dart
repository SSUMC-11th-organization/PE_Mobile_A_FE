import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../models/movie_detail_args.dart';
import '../theme/app_colors.dart';
import '../utils/tmdb_movie_format.dart';
import '../view_models/learning_member_session.dart';
import '../view_models/movie_detail_view_model.dart';
import '../widgets/movie_list_error.dart';
import 'movie_detail_screen.dart';

/// 상세 화면의 시작점. 목록에서 넘어오면 받은 영화 정보를 그대로 쓰고,
/// 주소로 바로 들어오거나 Deep Link라서 영화 정보가 없으면 TMDB 상세 API로 다시 조회한다.
class MovieDetailLoader extends StatefulWidget {
  const MovieDetailLoader({super.key, required this.movieId, this.initialArgs});

  /// 주소의 영화 id. 서버 평점의 movieId와 같은 TMDB id다.
  final int movieId;
  final MovieDetailArgs? initialArgs;

  @override
  State<MovieDetailLoader> createState() => _MovieDetailLoaderState();
}

class _MovieDetailLoaderState extends State<MovieDetailLoader> {
  late Future<MovieDetailArgs> _future;

  @override
  void initState() {
    super.initState();
    // build마다 새 Future를 만들지 않도록 State에 한 번만 보관한다.
    _future = widget.initialArgs != null
        ? Future.value(widget.initialArgs!)
        : _load();
  }

  Future<MovieDetailArgs> _load() async {
    final service = context.read<TmdbMovieService>();
    final movie = await service.fetchMovieDetail(widget.movieId);

    // 장르 이름은 보조 정보라서 실패해도 영화 상세는 보여준다.
    var names = <int, String>{};
    try {
      final genres = await service.fetchGenres();
      names = {for (final genre in genres) genre.id: genre.name};
    } catch (_) {}
    return MovieDetailArgs(movie: movie, genreNames: movie.genreNamesIn(names));
  }

  void _retry() {
    // setState의 콜백이 Future를 돌려주면 안 되므로 블록으로 대입한다.
    setState(() {
      _future = _load();
    });
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MovieDetailArgs>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _SimpleScaffold(
            onBack: _goBack,
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.violet),
            ),
          );
        }
        final args = snapshot.data;
        if (snapshot.hasError || args == null) {
          return _SimpleScaffold(
            onBack: _goBack,
            child: MovieListError(
              message: '영화를 불러오지 못했습니다.',
              onRetry: _retry,
            ),
          );
        }
        return ChangeNotifierProvider<MovieDetailViewModel>(
          create: (context) => MovieDetailViewModel(
            context.read<RatingApiService>(),
            context.read<LearningMemberSession>().memberId,
            args.movie,
          ),
          child: MovieDetailScreen(args: args),
        );
      },
    );
  }
}

class _SimpleScaffold extends StatelessWidget {
  const _SimpleScaffold({required this.onBack, required this.child});

  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '뒤로가기',
          icon: const Icon(Icons.arrow_back, size: 20),
          color: AppColors.violet,
          onPressed: onBack,
        ),
      ),
      body: child,
    );
  }
}
