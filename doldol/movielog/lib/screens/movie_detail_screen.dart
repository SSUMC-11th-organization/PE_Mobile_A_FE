import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import '../data/movie_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_poster.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/share_sheet.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movieId});

  final String? movieId;

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

  Future<void> _openRatingDialog() async {
    final rating = await showDialog<double>(
      context: context,
      builder: (dialogContext) => const RatingDialog(),
    );
    if (rating == null || !mounted) return;

    setState(() => _myRating = rating);
    _showSnackBar('평점 $rating점을 남겼어요.');
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

  String _formatCount(int count) {
    return count.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
        );
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
    final movie = findMovieById(int.tryParse(widget.movieId ?? ''));

    if (movie == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(
          child: Text('영화를 찾을 수 없어요.', style: AppTextStyles.bodySmall),
        ),
      );
    }

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
            MoviePoster(
              asset: movie.posterAsset,
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
                  const SizedBox(height: 4),
                  Text(
                    '${movie.year} · ${movie.genreLabel} · ${movie.runtime}분',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  // 평균 평점은 읽기 전용 RatingBarIndicator
                  Row(
                    children: [
                      RatingBarIndicator(
                        rating: movie.rating,
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
                        '${movie.rating}',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${_formatCount(movie.ratingCount)})',
                        style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
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
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: movie.tags
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            labelStyle: AppTextStyles.label,
                            backgroundColor: AppColors.chipGray,
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.cardBorder),
                  const SizedBox(height: 12),
                  const Text('시놉시스', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    movie.synopsis,
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
                    onPressed: _openRatingDialog,
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