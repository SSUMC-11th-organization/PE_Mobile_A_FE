import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../widgets/stat_item.dart';

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 16,
        title: const Text('내 프로필'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            ProfileHeader(),
            SizedBox(height: 32),
            ProfileStats(),
            SizedBox(height: 16),
            _MyRatingsEntry(),
            SizedBox(height: 16),
            FavoriteGenres(),
            SizedBox(height: 48),
            _TmdbAttribution(),
          ],
        ),
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

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

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
        const Text(
          '무비러버',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            height: 28 / 22,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: const Text(
            '매주 주말엔 영화관으로 출근하는 프로 관람객. 좋은 영화를 보고 기록하는 것을 좋아합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 24 / 16,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const EditProfileButton(),
      ],
    );
  }
}

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
      onPressed: () {
        debugPrint('프로필 수정 버튼 눌림');
      },
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
