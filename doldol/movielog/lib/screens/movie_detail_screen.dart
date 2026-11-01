import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/share_sheet.dart';
import '../widgets/tmdb_poster_image.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movieId, this.movie});

  final int? movieId; // 경로(Path Parameter)로 받은 TMDB id
  final TmdbMovieDto? movie; // extra로 받은 영화 정보

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isFavorite = false; // 화면 내부 상태 (Mock)
  double _myRating = 0; // 내가 남긴 평점 (Mock)

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    _showSnackBar(
      _isFavorite ? '즐겨찾기에 추가했어요.' : '즐겨찾기에서 삭제했어요.',
    );
  }

  Future<void> _openRatingDialog(TmdbMovieDto movie) async {
    final result = await showDialog<RatingSubmission>(
      context: context,
      // 평점 Dialog에 TMDB id를 전달한다
      builder: (dialogContext) => RatingDialog(movieId: movie.id),
    );
    if (result == null || !mounted) return;

    setState(() => _myRating = result.score);
    // 이후 주차에서 이 movieId와 score를 자체 백엔드로 보낸다
    debugPrint('[평점] movieId=${result.movieId}, score=${result.score}');
    _showSnackBar('평점 ${result.score}점을 남겼어요.');
  }

  Future<void> _openShareSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.warmWhite,
      builder: (sheetContext) => const ShareSheet(),
    );
    // BottomSheet가 닫힌 뒤에 Snackbar를 표시
    if (selected == null || !mounted) return;
    _showSnackBar('$selected 완료 (Mock)');
  }

  PreferredSizeWidget _buildAppBar({List<Widget>? actions}) {
    return CommonAppBar(
      title: 'Cinema Archive',
      centerTitle: true,
      titleStyle: AppTextStyles.titleMedium.copyWith(color: AppColors.violet),
      onBack: () => context.pop(),
      actions: actions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;

    // extra가 없거나 경로의 id와 다르면 영화 정보를 그릴 수 없다
    if (movie == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.movie_outlined,
                    size: 48, color: AppColors.gray),
                const SizedBox(height: 12),
                const Text(
                  '영화 정보를 불러올 수 없어요.',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  '목록에서 영화를 다시 선택해 주세요.',
                  style: AppTextStyles.bodySmall,
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
        ),
      );
    }

    final year = movie.releaseYear; // 없으면 null

    return Scaffold(
      appBar: _buildAppBar(
        actions: [
          IconButton(
            onPressed: _openShareSheet,
            icon: const Icon(Icons.share_outlined, color: AppColors.violet),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TmdbPosterImage(
              posterPath: movie.posterPath,
              width: double.infinity,
              height: 280,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    style: AppTextStyles.titleLarge.copyWith(fontSize: 22),
                  ),
                  // 출시 연도가 없으면 표시하지 않는다
                  if (year != null) ...[
                    const SizedBox(height: 4),
                    Text('$year년 개봉', style: AppTextStyles.bodySmall),
                  ],
                  const SizedBox(height: 12),
                  // TMDB 평점은 10점 만점이라 별 5개로 보여주려면 2로 나눈다
                  Row(
                    children: [
                      RatingBarIndicator(
                        rating: (movie.voteAverage / 2).clamp(0.0, 5.0).toDouble(),
                        itemCount: 5,
                        itemSize: 18,
                        unratedColor: AppColors.starEmpty,
                        itemBuilder: (context, index) => const Icon(
                          Icons.star_rounded,
                          color: AppColors.violet,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${movie.voteAverage.toStringAsFixed(1)} / 10',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  if (_myRating > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '내 평점 ★ $_myRating',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.violet,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.cardBorder),
                  const SizedBox(height: 12),
                  const Text('시놉시스', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  if (movie.overview.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          '줄거리 정보가 없어요.',
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                    )
                  else
                    Text(
                      movie.overview,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _toggleFavorite,
                    icon: Icon(
                      _isFavorite ? Icons.bookmark : Icons.bookmark_border,
                      size: 18,
                    ),
                    label: const Text('즐겨찾기'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.violet,
                      side: const BorderSide(color: AppColors.violet),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _openRatingDialog(movie),
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: const Text('평점 남기기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.violet,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
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