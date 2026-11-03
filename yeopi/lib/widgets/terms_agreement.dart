import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

// 체크 상태는 부모(SignUpScreen)가 관리하고, 이 Widget은 값과 콜백만 받아 그립니다.
class TermsAgreement extends StatelessWidget {
  const TermsAgreement({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Checkbox(
            value: value,
            activeColor: AppColors.violet,
            onChanged: (checked) => onChanged(checked ?? false),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: '[필수] ',
                    style: TextStyle(color: AppColors.violet),
                  ),
                  TextSpan(
                    text: '서비스 이용약관 및 개인정보 처리방침에 동의합니다.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
