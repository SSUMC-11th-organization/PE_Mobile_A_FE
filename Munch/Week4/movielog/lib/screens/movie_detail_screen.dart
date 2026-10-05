import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';

import '../data/mock_movies.dart';
import '../models/movie.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/rating_dialog.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movieId});

  final int? movieId;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isFavorite = false;
  double? _myRating;

  // URL로 바로 들어온 경우처럼 이전 화면이 없으면 홈으로 보낸다.
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

  Future<void> _openRatingDialog() async {
    final rating = await showDialog<double>(
      context: context,
      builder: (context) => RatingDialog(initialRating: _myRating ?? 0),
    );
    if (rating == null || !mounted) return;

    setState(() => _myRating = rating == 0 ? null : rating);
    _showSnackBar(
      rating == 0 ? '평점을 삭제했어요.' : '${rating.toStringAsFixed(1)}점을 남겼어요.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final movie = findMovieById(widget.movieId);

    if (movie == null) {
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
            child: Image.asset(movie.posterAsset, fit: BoxFit.cover),
          ),
          _MovieInfoSection(movie: movie, myRating: _myRating),
          const Divider(height: 1),
          _SynopsisSection(synopsis: movie.synopsis),
        ],
      ),
      bottomNavigationBar: _DetailActionBar(
        isFavorite: _isFavorite,
        hasRated: _myRating != null,
        onFavoritePressed: _toggleFavorite,
        onRatePressed: _openRatingDialog,
      ),
    );
  }
}

class _MovieInfoSection extends StatelessWidget {
  const _MovieInfoSection({required this.movie, required this.myRating});

  final Movie movie;
  final double? myRating;

  String _formatCount(int count) {
    return count.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 6),
          Text(
            '${movie.year} • ${movie.genres.join('/')} • ${movie.runtime}분',
            style: AppTextStyles.bodyMedium.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              RatingBarIndicator(
                rating: movie.rating,
                itemCount: 5,
                itemSize: 22,
                itemBuilder: (context, index) {
                  return const Icon(Icons.star, color: AppColors.violet);
                },
              ),
              const SizedBox(width: 8),
              Text(
                movie.rating.toStringAsFixed(1),
                style: AppTextStyles.bodySmall.copyWith(fontSize: 16),
              ),
              const SizedBox(width: 4),
              Text(
                '(${_formatCount(movie.ratingCount)})',
                style: AppTextStyles.bodyMedium.copyWith(fontSize: 14),
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
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: movie.tags.map((tag) {
              return Chip(
                label: Text(tag),
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
      ),
    );
  }
}

class _SynopsisSection extends StatelessWidget {
  const _SynopsisSection({required this.synopsis});

  final String synopsis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('시놉시스', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          Text(
            synopsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.black,
              height: 1.7,
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
