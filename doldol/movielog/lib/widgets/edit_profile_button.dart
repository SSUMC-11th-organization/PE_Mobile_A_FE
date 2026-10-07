import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class EditProfileButton extends StatelessWidget {
  const EditProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {},   // 1주차는 모양만
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.warmWhite,
        foregroundColor: AppColors.violet,
        elevation: 0,
        side: const BorderSide(color: AppColors.violet),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: const Text('프로필 수정'),
    );
  }
}