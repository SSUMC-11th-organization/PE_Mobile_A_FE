import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';

import '../models/movie.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/rating_dialog.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movie});

  // Path Parameter의 ID로 찾지 못하면 null입니다.
  final Movie? movie;

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

  Future<void> _openRatingDialog(Movie movie) async {
    final rating = await showDialog<double>(
      context: context,
      builder: (dialogContext) => RatingDialog(movieTitle: movie.title),
    );
    // 취소하거나 바깥을 눌러 닫으면 null이 돌아옵니다.
    if (rating == null || !mounted) return;
    setState(() => _myRating = rating);
    _showSnackBar('${rating.toStringAsFixed(1)}점을 남겼어요');
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
                    aspectRatio: 3 / 4,
                    child: Image.asset(movie.posterAsset, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 16),
                Text(movie.title, style: AppTextStyles.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${movie.genre} · ${movie.year}',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    RatingBarIndicator(
                      rating: mockAverageRating,
                      itemCount: 5,
                      itemSize: 20,
                      itemBuilder: (context, index) =>
                          const Icon(Icons.star, color: Colors.amber),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '평균 $mockAverageRating',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(movie.summary, style: AppTextStyles.bodyMedium),
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
