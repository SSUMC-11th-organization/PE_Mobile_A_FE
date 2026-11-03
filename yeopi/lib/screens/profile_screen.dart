import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/favorite_genres.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_stats.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: '내 프로필'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const ProfileHeader(),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  debugPrint('프로필 수정 버튼을 눌렀습니다.');
                },
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
              const ProfileStats(),
              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: FavoriteGenres(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
