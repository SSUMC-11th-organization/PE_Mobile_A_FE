import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'edit_profile_button.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(2), // Padding: 테두리와 사진 사이 안쪽 여백
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.violet, width: 2),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/profile/profile_movielog.jpg',
              width: 88,
              height: 88,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('무비러버', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16), // Margin: 소개글과 화면 좌우 사이 바깥 여백
          child: Text(
            '매주 주말엔 영화관으로 출근하는 프로 관람객. 좋은 영화를 보고 기록하는 것을 좋아합니다.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const EditProfileButton(),
      ],
    );
  }
}