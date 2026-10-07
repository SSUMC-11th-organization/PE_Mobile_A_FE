import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class ShareSheet extends StatelessWidget {
  const ShareSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('공유하기', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.link, color: AppColors.violet),
              title: const Text('링크 복사'),
              onTap: () => Navigator.pop(context, '링크 복사'),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline,
                  color: AppColors.violet),
              title: const Text('메시지로 보내기'),
              onTap: () => Navigator.pop(context, '메시지 보내기'),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share, color: AppColors.violet),
              title: const Text('다른 앱으로 공유'),
              onTap: () => Navigator.pop(context, '다른 앱 공유'),
            ),
          ],
        ),
      ),
    );
  }
}