import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class StatItem extends StatelessWidget {
  const StatItem({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.violetback,
        border: Border.all(color: AppColors.violetBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 16 / 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
              color: AppColors.violetNumber,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 28 / 22,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
