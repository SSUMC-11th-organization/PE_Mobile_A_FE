import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class TermsCheckbox extends StatelessWidget {
  const TermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: [
          SizedBox(
            width: compact ? 20 : 24,
            height: compact ? 20 : 24,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.violet,
              checkColor: Colors.white,
              side: BorderSide(
                color: compact ? AppColors.gray : AppColors.outline,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '필수 약관에 동의합니다',
            style:
                (compact
                        ? AppTextStyles.labelSmall
                        : AppTextStyles.sectionTitle)
                    .copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
