import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/member_info.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/movie_format.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/favorite_genres.dart';
import '../widgets/movielog_button.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_stats.dart';

// 마이페이지는 MainScreen이 불러온 내 정보(AuthViewModel.member)를 구독해서 보여줍니다.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final auth = context.read<AuthViewModel>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    // 상태가 signedOut이 되면 Router가 /login으로 보냅니다.
    if (confirmed == true) await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final member = auth.member;

    return Scaffold(
      appBar: CommonAppBar(
        title: '내 프로필',
        actions: [
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
            onPressed: auth.storageCleanupInProgress
                ? null
                : () => _confirmLogout(context),
          ),
        ],
      ),
      body: SafeArea(
        // Challenge: 내 정보를 불러오는 동안은 화면 전체 인디케이터, 실패하면 재시도 버튼을 보여줍니다.
        child: switch ((member, auth.memberStatus)) {
          (final MemberInfo member, _) => _ProfileBody(member: member),
          (null, MemberLoadStatus.error) => _MemberLoadError(
            message: auth.message ?? '내 정보를 불러오지 못했어요.',
            onRetry: () => auth.loadMember(force: true),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.member});

  final MemberInfo member;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          // Challenge: 닉네임 아래에 가입일을 '2026.10.10 가입' 형식으로 표시합니다.
          ProfileHeader(
            nickname: member.nickname,
            caption: '${formatDate(member.createdAt)} 가입',
          ),
          const SizedBox(height: 4),
          Text(member.email, style: AppTextStyles.bodySmall),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.push('/my/profile/edit'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.violet,
              side: const BorderSide(color: AppColors.violet),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('프로필 수정'),
          ),
          const SizedBox(height: 24),
          // 통계·선호 장르는 기존 디자인 예시입니다. v7 GET me에는 이메일·닉네임·가입일만 옵니다.
          const ProfileStats(),
          const SizedBox(height: 24),
          const Align(alignment: Alignment.centerLeft, child: FavoriteGenres()),
          const SizedBox(height: 24),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('내가 등록한 평점'),
              subtitle: const Text('이번 로그인에서 등록한 평점'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/my/ratings'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberLoadError extends StatelessWidget {
  const _MemberLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            MovieLogButton(label: '다시 시도', width: 120, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
