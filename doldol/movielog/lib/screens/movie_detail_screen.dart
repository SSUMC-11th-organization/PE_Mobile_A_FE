import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/movie_detail_view_model.dart';
import '../view_models/submit_status.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/share_sheet.dart';
import '../widgets/tmdb_poster_image.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isFavorite = false; // 화면 내부 상태 (Mock)

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
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막는다
      builder: (_) => RatingDialog(
        onSubmit: (score, comment) async {
          final viewModel = context.read<MovieDetailViewModel>();
          await viewModel.createRating(score: score, comment: comment);
          if (viewModel.submitStatus != SubmitStatus.success) {
            throw StateError(viewModel.submitMessage ?? '저장에 실패했습니다.');
          }
        },
      ),
    );
    if (!mounted || saved != true) return;

    _showSnackBar(
      '평점을 등록했습니다. 마이페이지의 "내가 등록한 평점"에서 확인할 수 있습니다.',
    );
  }

  Future<void> _openShareSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.warmWhite,
      builder: (sheetContext) => const ShareSheet(),
    );
    if (selected == null || !mounted) return;
    _showSnackBar('$selected 완료 (Mock)');
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<MovieDetailViewModel>();
    final movie = viewModel.movie;
    final hasMember = viewModel.memberId != null;
    final year = movie.releaseYear; // 없으면 null

    return Scaffold(
      appBar: CommonAppBar(
        title: 'Cinema Archive',
        centerTitle: true,
        titleStyle: AppTextStyles.titleMedium.copyWith(color: AppColors.violet),
        onBack: () => context.canPop() ? context.pop() : context.go('/movies'),
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
                  if (year != null) ...[
                    const SizedBox(height: 4),
                    Text('$year년 개봉', style: AppTextStyles.bodySmall),
                  ],
                  const SizedBox(height: 12),
                  // TMDB 평점은 10점 만점이라 별 5개로 보여주려면 2로 나눈다
                  Row(
                    children: [
                      RatingBarIndicator(
                        rating:
                            (movie.voteAverage / 2).clamp(0.0, 5.0).toDouble(),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!hasMember)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '학습용 회원가입을 완료하면 평점을 남길 수 있어요.',
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                  ),
                ),
              Row(
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
                        // 회원가입 결과의 memberId가 없으면 비활성화
                        onPressed: hasMember ? _openRatingDialog : null,
                        icon: const Icon(Icons.rate_review_outlined, size: 18),
                        label: const Text('평점 남기기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.violet,
                          foregroundColor: AppColors.white,
                          disabledBackgroundColor: AppColors.disabledViolet,
                          disabledForegroundColor: AppColors.white,
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
            ],
          ),
        ),
      ),
    );
  }
}