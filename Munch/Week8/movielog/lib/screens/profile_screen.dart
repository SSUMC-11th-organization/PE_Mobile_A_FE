import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/member_info.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movielog_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final member = auth.member;

    return Scaffold(
      appBar: CommonAppBar(
        title: '내 프로필',
        actions: [
          TextButton(
            onPressed: auth.storageCleanupInProgress ? null : auth.logout,
            child: const Text(
              '로그아웃',
              style: TextStyle(color: AppColors.violet),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: member != null
            ? SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ProfileHeader(member: member),
                    const SizedBox(height: 40),
                    const ProfileStats(),
                    const SizedBox(height: 24),
                    const MyRatingsEntry(),
                    const SizedBox(height: 32),
                    const FavoriteGenres(),
                  ],
                ),
              )
            : auth.memberStatus == MemberLoadStatus.error
            ? _MemberLoadError(onRetry: () => auth.loadMember(force: true))
            : const Center(
                child: CircularProgressIndicator(color: AppColors.violet),
              ),
      ),
    );
  }
}

class _MemberLoadError extends StatelessWidget {
  const _MemberLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('내 정보를 불러오지 못했어요.', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 16),
          MovieLogButton(
            label: '다시 시도',
            width: 220,
            height: 44,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

String formatJoinedDate(DateTime createdAt) {
  final local = createdAt.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}.$month.$day 가입';
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.member});

  final MemberInfo member;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipOval(
          child: Image.asset(
            'assets/images/profile/profile_movielog.jpg',
            width: 120,
            height: 120,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 16),
        Text(member.nickname, style: AppTextStyles.titleLarge),
        const SizedBox(height: 8),
        Text(
          formatJoinedDate(member.createdAt),
          style: const TextStyle(fontSize: 13, color: AppColors.gray),
        ),
        const SizedBox(height: 4),
        Text(
          member.email,
          style: const TextStyle(fontSize: 14, color: AppColors.gray),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.push('/my/profile/edit'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.warmWhite,
            foregroundColor: AppColors.violet,
            elevation: 0,
            side: const BorderSide(color: AppColors.violet),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            '프로필 수정',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
      ],
    );
  }
}

class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key});

  @override
  Widget build(BuildContext context) {
    final statData = [
      {'label': '본 영화', 'value': '342', 'icon': 'assets/icons/movie.svg'},
      {'label': '평점', 'value': '4.2', 'icon': 'assets/icons/star.svg'},
      {'label': '즐겨찾기', 'value': '58', 'icon': 'assets/icons/bookmark.svg'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: statData.map((data) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: StatItem(
              label: data['label']!,
              value: data['value']!,
              iconAsset: data['icon']!,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class MyRatingsEntry extends StatelessWidget {
  const MyRatingsEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.violet.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/my/ratings'),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Expanded(
                child: Text('내가 등록한 평점', style: AppTextStyles.titleMedium),
              ),
              Icon(Icons.chevron_right, color: AppColors.violet, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class FavoriteGenres extends StatelessWidget {
  const FavoriteGenres({super.key});

  @override
  Widget build(BuildContext context) {
    final genreData = ['드라마', 'SF', '애니메이션'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('선호하는 장르', style: AppTextStyles.titleMedium),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: genreData.map((genre) {
            return Chip(
              label: Text(genre),
              labelStyle: const TextStyle(
                color: AppColors.violet,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              backgroundColor: AppColors.violet.withValues(alpha: 0.1),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class StatItem extends StatelessWidget {
  const StatItem({
    super.key,
    required this.label,
    required this.value,
    required this.iconAsset,
  });

  final String label;
  final String value;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SvgPicture.asset(
            iconAsset,
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(
              AppColors.violet,
              BlendMode.srcIn,
            ),
            semanticsLabel: label,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.violet,
              fontSize: 26,
            ),
          ),
        ],
      ),
    );
  }
}
