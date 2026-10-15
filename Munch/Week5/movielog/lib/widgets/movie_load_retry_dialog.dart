import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 목록 요청 실패 안내. "다시 시도"는 true, "취소"는 false를 반환한다.
class MovieLoadRetryDialog extends StatelessWidget {
  const MovieLoadRetryDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final retry = await showDialog<bool>(
      context: context,
      builder: (context) => const MovieLoadRetryDialog(),
    );
    return retry ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.fieldFill,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.refresh,
                color: AppColors.violet,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '영화를 불러오지 못했어요',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleMedium.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            const Text(
              '네트워크 상태를 확인하고\n다시 시도해 주세요.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.fieldFill,
                      foregroundColor: AppColors.violet,
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      '취소',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.violet,
                      foregroundColor: AppColors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      '다시 시도',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
