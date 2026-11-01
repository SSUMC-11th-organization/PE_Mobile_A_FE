import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../view_models/my_ratings_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';
import '../widgets/my_rating_card.dart';

/// 마이페이지 위에 열리는 자식 화면. 하단 NavigationBar 없이 뒤로가기와 중앙 제목만 둔다.
class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(
        title: '내가 등록한 평점',
        centerTitle: true,
        showBackButton: true,
      ),
      body: Consumer<MyRatingsViewModel>(
        builder: (context, viewModel, child) {
          return switch (viewModel.status) {
            MyRatingsLoadStatus.idle ||
            MyRatingsLoadStatus.loading => const MovieListLoading(
              message: '평점을 불러오는 중이에요',
            ),
            MyRatingsLoadStatus.error => MovieListError(
              message: viewModel.message,
              description: '문제가 계속되면 잠시 후 다시 시도해 주세요.',
              onRetry: viewModel.load,
            ),
            MyRatingsLoadStatus.empty => const MovieListEmpty(
              title: '아직 등록한 평점이 없어요.',
              description: '영화에 평점을 남기면 여기에 모여요.',
            ),
            MyRatingsLoadStatus.success => _RatingsList(viewModel: viewModel),
          };
        },
      ),
    );
  }
}

class _RatingsList extends StatelessWidget {
  const _RatingsList({required this.viewModel});

  final MyRatingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final message = viewModel.message;
    final ratings = viewModel.ratings;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      // 맨 위 안내 1줄 + (일부 영화 정보 실패 문구) + 평점 카드들
      itemCount: ratings.length + 1 + (message == null ? 0 : 1),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) return _SampleNotice(memberId: viewModel.memberId);
        if (message != null && index == 1) return _PartialFailureNotice(message);
        final offset = message == null ? 1 : 2;
        return MyRatingCard(entry: ratings[index - offset]);
      },
    );
  }
}

/// 로그인 기능이 없어 현재 사용자의 평점이 아니라는 점을 숨기지 않는다.
class _SampleNotice extends StatelessWidget {
  const _SampleNotice({required this.memberId});

  final int memberId;

  @override
  Widget build(BuildContext context) {
    return Text(
      '학습용 회원(memberId $memberId)의 샘플 평점이에요.',
      style: const TextStyle(
        fontSize: 12,
        height: 16 / 12,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _PartialFailureNotice extends StatelessWidget {
  const _PartialFailureNotice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 12,
          height: 16 / 12,
          color: AppColors.error,
        ),
      ),
    );
  }
}
