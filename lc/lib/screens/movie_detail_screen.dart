import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../models/movie_detail_args.dart';
import '../models/rating_submission.dart';
import '../theme/app_colors.dart';
import '../utils/tmdb_movie_format.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/tmdb_poster_image.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.args});

  /// 목록에서 넘겨받은 값. 앱을 다시 켜거나 주소로 바로 들어오면 null이다.
  final MovieDetailArgs? args;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isFavorite = false;
  double _myRating = 0;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    _showMessage(_isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 삭제했습니다.');
  }

  Future<void> _openRatingDialog(TmdbMovieDto movie) async {
    final submission = await showDialog<RatingSubmission>(
      context: context,
      // 배열 index가 아니라 TMDB 영화 id를 Dialog에 전달한다.
      builder: (context) =>
          RatingDialog(movieId: movie.id, initialRating: _myRating),
    );
    if (submission == null || !mounted) return;

    setState(() => _myRating = submission.score);
    // TODO(평점 저장 API): submission.movieId와 score를 자체 백엔드로 전달한다.
    debugPrint(
      '평점 저장 준비: movieId=${submission.movieId}, score=${submission.score}',
    );
    _showMessage('${submission.score}점을 남겼습니다.');
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
    final movie = widget.args?.movie;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        centerTitle: true,
        title: const Text(
          'Cinema Archive',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 28 / 22,
            color: AppColors.violet,
          ),
        ),
        leading: IconButton(
          tooltip: '뒤로가기',
          icon: const Icon(Icons.arrow_back, size: 20),
          color: AppColors.violet,
          onPressed: _goBack,
        ),
        actions: [
          IconButton(
            tooltip: '공유',
            icon: const Icon(Icons.share_outlined, size: 20),
            color: AppColors.violet,
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: movie == null
          ? const _MissingMovie()
          : Column(
              children: [
                Expanded(child: _buildContent(movie, widget.args!.genreNames)),
                _buildActionBar(movie),
              ],
            ),
    );
  }

  Widget _buildContent(TmdbMovieDto movie, List<String> genreNames) {
    final year = movie.releaseYear;
    final info = [
      if (year != null) '$year',
      if (genreNames.isNotEmpty) genreNames.take(2).join('/'),
    ].join(' • ');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: TmdbPosterImage(posterPath: movie.posterPath),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    height: 36 / 28,
                    color: AppColors.textDetail,
                  ),
                ),
                if (info.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    info,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: 0.25,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    RatingBarIndicator(
                      rating: movie.ratingOutOfFive,
                      itemCount: 5,
                      itemSize: 16.67,
                      unratedColor: const Color(0xFFDDD8E8),
                      itemBuilder: (context, index) => const Icon(
                        Icons.star_rounded,
                        color: AppColors.violet,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      movie.ratingLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 24 / 16,
                        letterSpacing: 0.15,
                        color: AppColors.textDetail,
                      ),
                    ),
                  ],
                ),
                if (_myRating > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '내 평점 $_myRating점',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.violet,
                    ),
                  ),
                ],
                if (genreNames.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final name in genreNames) _GenreTag(name: name),
                    ],
                  ),
                ],
              ],
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.outline)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 17, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '시놉시스',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      height: 28 / 22,
                      color: AppColors.textDetail,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (movie.overview.trim().isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          '줄거리 정보가 없어요.',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      movie.overview,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 26 / 16,
                        letterSpacing: 0.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(TmdbMovieDto movie) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.warmWhite,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _toggleFavorite,
                  icon: Icon(
                    _isFavorite ? Icons.bookmark : Icons.bookmark_border,
                    size: 20,
                  ),
                  label: const Text('즐겨찾기'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.violet,
                    side: const BorderSide(color: AppColors.violet),
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openRatingDialog(movie),
                  icon: const Icon(Icons.rate_review_outlined, size: 20),
                  label: const Text('평점 남기기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenreTag extends StatelessWidget {
  const _GenreTag({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.tagBackground,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          name,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 20 / 14,
            letterSpacing: 0.1,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// 목록을 거치지 않고 상세 주소로 바로 들어온 경우의 안내.
class _MissingMovie extends StatelessWidget {
  const _MissingMovie();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '영화 정보를 찾을 수 없어요.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '영화 목록에서 다시 선택해 주세요.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
