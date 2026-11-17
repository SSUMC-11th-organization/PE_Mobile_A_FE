import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/movie_detail_view_model.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_card.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/tmdb_poster_image.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isFavorite = false;
  Map<int, String> _genreNames = const {};

  @override
  void initState() {
    super.initState();
    _loadGenreNames();
  }

  Future<void> _loadGenreNames() async {
    try {
      final genres = await context.read<TmdbMovieService>().fetchGenres();
      if (!mounted) return;
      setState(() {
        _genreNames = {for (final genre in genres) genre.id: genre.name};
      });
    } on DioException {
      return;
    }
  }

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
    final viewModel = context.read<MovieDetailViewModel>();
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RatingDialog(
        onSubmit: (score, comment) async {
          await viewModel.createRating(score: score, comment: comment);
          if (viewModel.submitStatus != SubmitStatus.success) {
            final message = viewModel.submitMessage ?? '저장에 실패했습니다.';
            if (mounted) _showSnackBar(message);
            throw StateError(message);
          }
        },
      ),
    );

    if (!mounted || saved != true) return;
    _showSnackBar('평점을 등록했습니다. 마이페이지의 "내가 등록한 평점"에서 확인할 수 있습니다.');
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<MovieDetailViewModel>();
    final movie = viewModel.movie;

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
          _MovieInfoSection(movie: movie, genreNames: _genreNames),
          const Divider(height: 1),
          _SynopsisSection(overview: movie.overview),
        ],
      ),
      bottomNavigationBar: _DetailActionBar(
        isFavorite: _isFavorite,
        onFavoritePressed: _toggleFavorite,
        onRatePressed: viewModel.memberId == null ? null : _openRatingDialog,
        onSignUpPressed: () => context.push('/register'),
      ),
    );
  }
}

class _MovieInfoSection extends StatelessWidget {
  const _MovieInfoSection({required this.movie, required this.genreNames});

  final TmdbMovieDto movie;
  final Map<int, String> genreNames;

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
    required this.onFavoritePressed,
    required this.onRatePressed,
    required this.onSignUpPressed,
  });

  final bool isFavorite;
  final VoidCallback onFavoritePressed;
  final VoidCallback? onRatePressed;
  final VoidCallback onSignUpPressed;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onRatePressed == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '평점을 남기려면 학습용 회원가입이 필요합니다.',
                          style: TextStyle(fontSize: 13, color: AppColors.gray),
                        ),
                      ),
                      TextButton(
                        onPressed: onSignUpPressed,
                        child: const Text('회원가입'),
                      ),
                    ],
                  ),
                ),
              Row(
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
                      label: const Text('평점 남기기'),
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
            ],
          ),
        ),
      ),
    );
  }
}
