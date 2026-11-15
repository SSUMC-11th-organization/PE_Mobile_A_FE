import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/member_info.dart';
import '../theme/app_colors.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/movielog_button.dart';
import '../widgets/stat_item.dart';

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // read가 아니라 watch로 구독해야 닉네임이 바뀌면 다시 그려진다.
    final auth = context.watch<AuthViewModel>();
    final member = auth.member;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 16,
        title: const Text('내 프로필'),
        actions: [
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout, size: 22),
            color: AppColors.textSecondary,
            // 토큰과 내 정보를 지우면 Router가 로그인 화면으로 보낸다.
            onPressed: auth.storageCleanupInProgress ? null : auth.logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: switch (member) {
        final MemberInfo member => _MyPageContent(member: member),
        // 내 정보를 불러오지 못했으면 로그아웃하지 않고 다시 시도할 수 있게 한다.
        null when auth.memberStatus == MemberLoadStatus.error =>
          _MemberLoadError(onRetry: () => auth.loadMember(force: true)),
        null => const Center(
          child: CircularProgressIndicator(color: AppColors.violet),
        ),
      },
    );
  }
}

class _MyPageContent extends StatelessWidget {
  const _MyPageContent({required this.member});

  final MemberInfo member;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileHeader(member: member),
          const SizedBox(height: 32),
          const ProfileStats(),
          const SizedBox(height: 16),
          const _MyRatingsEntry(),
          const SizedBox(height: 16),
          const FavoriteGenres(),
          const SizedBox(height: 48),
          const _TmdbAttribution(),
        ],
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
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          const Text(
            '내 정보를 불러오지 못했어요.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          MovieLogButton(label: '다시 시도', onPressed: onRetry),
        ],
      ),
    );
  }
}

/// 마이페이지 위에 자식 화면(/my/ratings)을 여는 진입 행.
class _MyRatingsEntry extends StatelessWidget {
  const _MyRatingsEntry();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      tileColor: AppColors.violetback,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: const Icon(Icons.star_rounded, color: AppColors.violet),
      title: const Text('내가 등록한 평점'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/my/ratings'),
    );
  }
}

/// TMDB 데이터를 사용하는 앱이 표기해야 하는 출처 문구.
class _TmdbAttribution extends StatelessWidget {
  const _TmdbAttribution();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'This product uses the TMDB API but is not endorsed or certified by TMDB.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        height: 16 / 12,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// GET me로 받은 내 정보(닉네임·이메일·가입일)를 보여준다. 사진은 디자인 예시다.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.member});

  final MemberInfo member;

  /// "2026.10.10 가입" 형식
  static String formatJoinedAt(DateTime createdAt) {
    final local = createdAt.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}.$month.$day 가입';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 128,
          height: 128,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.avatarBorder, width: 2),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/profile/profile_movielog.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.35),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          member.nickname,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            height: 28 / 22,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          formatJoinedAt(member.createdAt),
          style: const TextStyle(
            fontSize: 13,
            height: 18 / 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          member.email,
          style: const TextStyle(
            fontSize: 14,
            height: 20 / 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        const EditProfileButton(),
      ],
    );
  }
}

/// 통계 수치는 디자인 예시다. (v7 GET me 응답에는 이메일·닉네임·가입일만 있다.)
class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: StatItem(label: '본 영화', value: '342'),
        ),
        SizedBox(width: 8),
        Expanded(
          child: StatItem(label: '평점', value: '4.2'),
        ),
        SizedBox(width: 8),
        Expanded(
          child: StatItem(label: '즐겨찾기', value: '58'),
        ),
      ],
    );
  }
}

class FavoriteGenres extends StatelessWidget {
  const FavoriteGenres({super.key});

  @override
  Widget build(BuildContext context) {
    const genres = ['드라마', 'SF', '애니메이션'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '선호하는 장르',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 24 / 16,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final genre in genres) Chip(label: Text(genre))],
        ),
      ],
    );
  }
}

class EditProfileButton extends StatelessWidget {
  const EditProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => context.push('/my/profile/edit'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.violet,
        side: const BorderSide(color: AppColors.violet),
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 24 / 16,
        ),
      ),
      child: const Text('프로필 수정'),
    );
  }
}
