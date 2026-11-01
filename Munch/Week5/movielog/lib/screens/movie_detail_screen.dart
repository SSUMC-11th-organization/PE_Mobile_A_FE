import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_card.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/tmdb_poster_image.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({
    super.key,
    required this.movieId,
    required this.movie,
    this.genreNames = const {},
  });

  /// TMDB 영화 id. 이후 평점 API의 movieId로 그대로 전달한다.
  final int? movieId;
  final TmdbMovieDto? movie;
  final Map<int, String> genreNames;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isFavorite = false;
  double? _myRating;

  void _goBack() => context.canPop() ? context.pop() : context.go('/home');

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    _showSnackBar(_isFavorite ? '즐겨찾기에 추가했어요.' : '즐겨찾기에서 삭제했어요.');
  }

  Future<void> _openRatingDialog(int movieId) async {
    final rating = await showDialog<double>(
      context: context,
      builder: (context) =>
          RatingDialog(movieId: movieId, initialRating: _myRating ?? 0),
    );
    if (rating == null || !mounted) return;

    setState(() => _myRating = rating == 0 ? null : rating);
    _showSnackBar(
      rating == 0 ? '평점을 삭제했어요.' : '${rating.toStringAsFixed(1)}점을 남겼어요.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;

    if (movie == null || movie.id != widget.movieId) {
      return Scaffold(
        appBar: CommonAppBar(title: '영화 상세', onBack: _goBack),
        body: const Center(
          child: Text('영화를 찾을 수 없어요.', style: AppTextStyles.bodyMedium),
        ),
      );
    }

    return Scaffold(
      appBar: CommonAppBar(
        title: 'Cinema Archive',
        centerTitle: true,
        onBack: _goBack,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
        ],
      ),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: TmdbPosterImage(posterPath: movie.posterPath, size: 'w780'),
          ),
          _MovieInfoSection(
            movie: movie,
            genreNames: widget.genreNames,
            myRating: _myRating,
          ),
          const Divider(height: 1),
          _SynopsisSection(overview: movie.overview),
        ],
      ),
      bottomNavigationBar: _DetailActionBar(
        isFavorite: _isFavorite,
        hasRated: _myRating != null,
        onFavoritePressed: _toggleFavorite,
        onRatePressed: () => _openRatingDialog(movie.id),
      ),
    );
  }
}

class _MovieInfoSection extends StatelessWidget {
  const _MovieInfoSection({
    required this.movie,
    required this.genreNames,
    required this.myRating,
  });

  final TmdbMovieDto movie;
  final Map<int, String> genreNames;
  final double? myRating;

  @override
  Widget build(BuildContext context) {
    final year = releaseYearOf(movie.releaseDate);
    final genres = movie.genreIds
        .map((id) => genreNames[id])
        .whereType<String>()
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            movie.title,
            style: AppTextStyles.titleLarge.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (year != null || genres.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              [?year, if (genres.isNotEmpty) genres.join('/')].join(' • '),
              style: AppTextStyles.bodyMedium.copyWith(fontSize: 14),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              // TMDB 평점은 10점 만점이라 별 5개에 맞춰 절반으로 표시한다.
              RatingBarIndicator(
                rating: movie.voteAverage / 2,
                itemCount: 5,
                itemSize: 22,
                itemBuilder: (context, index) {
                  return const Icon(Icons.star, color: AppColors.violet);
                },
              ),
              const SizedBox(width: 8),
              Text(
                '${movie.voteAverage.toStringAsFixed(1)} / 10',
                style: AppTextStyles.bodySmall.copyWith(fontSize: 16),
              ),
            ],
          ),
          if (myRating != null) ...[
            const SizedBox(height: 8),
            Text(
              '내 평점 ${myRating!.toStringAsFixed(1)}점',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.violet),
            ),
          ],
          if (genres.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: genres.map((genre) {
                return Chip(
                  label: Text(genre),
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    color: AppColors.black,
                  ),
                  backgroundColor: Colors.black.withValues(alpha: 0.06),
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SynopsisSection extends StatelessWidget {
  const _SynopsisSection({required this.overview});

  final String overview;

  @override
  Widget build(BuildContext context) {
    final hasOverview = overview.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('시놉시스', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          if (hasOverview)
            Text(
              overview,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.black,
                height: 1.7,
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('줄거리 정보가 없어요.', style: AppTextStyles.bodyMedium),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailActionBar extends StatelessWidget {
  const _DetailActionBar({
    required this.isFavorite,
    required this.hasRated,
    required this.onFavoritePressed,
    required this.onRatePressed,
  });

  final bool isFavorite;
  final bool hasRated;
  final VoidCallback onFavoritePressed;
  final VoidCallback onRatePressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onFavoritePressed,
                  icon: Icon(
                    isFavorite ? Icons.bookmark : Icons.bookmark_border,
                  ),
                  label: const Text('즐겨찾기'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.violet,
                    side: const BorderSide(color: AppColors.violet),
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onRatePressed,
                  icon: const Icon(Icons.rate_review_outlined),
                  label: Text(hasRated ? '평점 수정' : '평점 남기기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
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
