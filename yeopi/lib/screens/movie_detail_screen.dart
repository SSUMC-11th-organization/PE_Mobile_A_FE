import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/movie_format.dart';
import '../view_models/movie_detail_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/tmdb_poster_image.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isFavorite = false;

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

  Future<void> _openRatingDialog() async {
    final viewModel = context.read<MovieDetailViewModel>();
    final saved = await showDialog<bool>(
      context: context,
      // 저장 중 바깥 탭으로 닫히지 않게 막습니다. (뒤로가기는 Dialog 안의 PopScope가 막습니다.)
      barrierDismissible: false,
      builder: (dialogContext) => RatingDialog(
        movieTitle: viewModel.movie.title,
        // movieId는 ViewModel이 이미 가진 TMDB id라 콜백 밖으로 따로 넘기지 않습니다.
        onSubmit: (score, comment) =>
            viewModel.createRating(score: score, comment: comment),
      ),
    );
    // 저장 요청과 Snackbar 사이에 화면이 사라졌을 수 있으므로 다시 확인합니다.
    if (!mounted || saved != true) return;
    _showSnackBar('평점을 등록했습니다. 마이페이지의 "내가 등록한 평점"에서 확인할 수 있습니다.');
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MovieDetailViewModel>();
    final movie = viewModel.movie;

    return Scaffold(
      appBar: CommonAppBar(
        title: movie.title,
        onBack: () => context.pop(),
        actions: [
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
      body: ListView(
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
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.gray),
            )
          else
            Text(movie.overview, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            // 학습용 회원가입으로 받은 memberId가 없으면 등록할 수 없습니다.
            onPressed: viewModel.canRate ? _openRatingDialog : null,
            icon: const Icon(Icons.star_outline),
            label: const Text('평점 남기기'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.violet,
              foregroundColor: AppColors.white,
            ),
          ),
          if (!viewModel.canRate) ...[
            const SizedBox(height: 8),
            Text(
              '평점을 남기려면 먼저 학습용 회원가입을 완료해 주세요.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
            TextButton(
              onPressed: () => context.push('/register'),
              child: const Text('회원가입하러 가기'),
            ),
          ],
        ],
      ),
    );
  }
}
