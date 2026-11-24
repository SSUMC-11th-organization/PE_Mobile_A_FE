import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../models/movie_detail_args.dart';
import '../theme/app_colors.dart';
import '../utils/tmdb_movie_format.dart';
import '../view_models/favorite_detail_view_model.dart';
import '../view_models/movie_detail_view_model.dart';
import '../view_models/submit_status.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/tmdb_poster_image.dart';

/// 영화 한 편의 상세 화면. 영화 정보는 [MovieDetailLoader]가 준비해서 넘기고,
/// 평점 등록 상태는 위에서 제공한 [MovieDetailViewModel]이 관리한다.
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.args});

  final MovieDetailArgs args;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  int _myRating = 0;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _toggleFavorite() async {
    final favorite = context.read<FavoriteDetailViewModel>();
    final wasFavorite = favorite.isFavorite;
    final ok = await favorite.toggle();
    if (!mounted) return;
    if (ok) {
      _showMessage(wasFavorite ? '즐겨찾기에서 삭제했습니다.' : '즐겨찾기에 추가했습니다.');
    } else if (favorite.errorMessage != null) {
      _showMessage(favorite.errorMessage!);
    }
  }

  Future<void> _openRatingDialog() async {
    // await 뒤에는 context를 쓰지 않도록 ViewModel을 먼저 꺼내 둔다.
    final viewModel = context.read<MovieDetailViewModel>();
    final favorite = context.read<FavoriteDetailViewModel>();
    // 즐겨찾기 여부를 아직 모르거나 이미 즐겨찾기한 영화는 체크박스를 숨기고 평점만 저장한다.
    final canAddFavorite = favorite.hasLoadedStatus && !favorite.isFavorite;
    var savedScore = 0;
    String? dismissMessage;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막는다.
      builder: (_) => RatingDialog(
        showAddToFavorite: canAddFavorite,
        onSubmit: (score, comment, addToFavorites) async {
          if (canAddFavorite) {
            await viewModel.saveRecord(
              score: score,
              comment: comment,
              addToFavorites: addToFavorites,
            );
          } else {
            await viewModel.createRating(score: score, comment: comment);
          }
          if (viewModel.submitStatus != SubmitStatus.success) {
            final message = viewModel.submitMessage ?? '저장에 실패했습니다.';
            if (viewModel.dismissOnError) dismissMessage = message;
            throw RatingWriteException(
              message,
              dismissDialog: viewModel.dismissOnError,
            );
          }
          savedScore = score;
        },
      ),
    );
    if (!mounted) return;
    if (dismissMessage != null) {
      _showMessage(dismissMessage!);
      favorite.load(); // 서버 값으로 북마크를 다시 맞춘다.
      return;
    }
    if (saved != true) return;

    setState(() => _myRating = savedScore);
    favorite.load(); // 한 번에 저장한 즐겨찾기를 서버 값으로 반영한다.
    _showMessage('평점을 저장했습니다.');
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
    final movie = widget.args.movie;

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
      body: Column(
        children: [
          Expanded(child: _buildContent(movie, widget.args.genreNames)),
          _buildActionBar(),
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

  Widget _buildActionBar() {
    final favorite = context.watch<FavoriteDetailViewModel>();
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.warmWhite,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: favorite.hasLoadedStatus && !favorite.isSaving
                      ? _toggleFavorite
                      : null,
                  icon: Icon(
                    favorite.isFavorite ? Icons.bookmark : Icons.bookmark_border,
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
                  onPressed: _openRatingDialog,
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
