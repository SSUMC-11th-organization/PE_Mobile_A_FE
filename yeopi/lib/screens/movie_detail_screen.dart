import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/movie_format.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/tmdb_poster_image.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movie});

  // 목록에서 넘겨받은 영화가 없으면(주소로 직접 진입 등) null입니다.
  final TmdbMovieDto? movie;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isFavorite = false;
  double? _myRating;

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    _showSnackBar(_isFavorite ? '즐겨찾기에 추가했어요' : '즐겨찾기에서 삭제했어요');
  }

  Future<void> _openRatingDialog(TmdbMovieDto movie) async {
    final submission = await showDialog<RatingSubmission>(
      context: context,
      builder: (dialogContext) =>
          RatingDialog(movieId: movie.id, movieTitle: movie.title),
    );
    // 취소하거나 바깥을 눌러 닫으면 null이 돌아옵니다.
    if (submission == null || !mounted) return;
    debugPrint(
      '평점 저장 대상 movieId=${submission.movieId}, score=${submission.score}',
    );
    setState(() => _myRating = submission.score);
    _showSnackBar('${submission.score.toStringAsFixed(1)}점을 남겼어요');
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;

    return Scaffold(
      appBar: CommonAppBar(
        title: movie?.title ?? '영화 상세',
        onBack: () => context.pop(),
        actions: [
          if (movie != null)
            IconButton(
              tooltip: _isFavorite ? '즐겨찾기 삭제' : '즐겨찾기 추가',
              onPressed: _toggleFavorite,
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? AppColors.error : null,
              ),
            ),
        ],
      ),
      body: movie == null
          ? const Center(child: Text('영화를 찾을 수 없어요'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: TmdbPosterImage(posterPath: movie.posterPath),
                  ),
                ),
                const SizedBox(height: 16),
                Text(movie.title, style: AppTextStyles.titleLarge),
                const SizedBox(height: 4),
                Text(movieMetaLabel(movie), style: AppTextStyles.bodySmall),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // TMDB 평점은 10점 만점이라 별 5개에 맞춰 절반으로 표시합니다.
                    RatingBarIndicator(
                      rating: movie.voteAverage / 2,
                      itemCount: 5,
                      itemSize: 20,
                      itemBuilder: (context, index) =>
                          const Icon(Icons.star, color: Colors.amber),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TMDB ${movie.voteAverage.toStringAsFixed(1)} / 10',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (movie.overview.isEmpty)
                  Text(
                    '줄거리 정보가 없어요.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.gray,
                    ),
                  )
                else
                  Text(movie.overview, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 24),
                if (_myRating != null) ...[
                  Text(
                    '내 평점 ${_myRating!.toStringAsFixed(1)}점',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton.icon(
                  onPressed: () => _openRatingDialog(movie),
                  icon: const Icon(Icons.star_outline),
                  label: Text(_myRating == null ? '평점 남기기' : '평점 다시 남기기'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.violet,
                    foregroundColor: AppColors.white,
                  ),
                ),
              ],
            ),
    );
  }
}
