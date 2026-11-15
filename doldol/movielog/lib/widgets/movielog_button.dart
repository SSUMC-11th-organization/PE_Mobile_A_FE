import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MovieLogButton extends StatelessWidget {
  const MovieLogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.width,
    this.backgroundColor = AppColors.violet,
    this.foregroundColor = AppColors.white,
    this.disabledColor = AppColors.gray,
    this.radius = 12,
  });

  final String label;
  final VoidCallback? onPressed; // null이면 비활성
  final bool isLoading; // true면 통신 중 (항상 비활성, 회색)
  final double? width; // null: 내용 기반, double.infinity: 최대 너비, 값: 고정
  final Color backgroundColor;
  final Color foregroundColor;
  final Color disabledColor; // 통신 중이 아닌 비활성 상태의 배경색
  final double radius;

  bool get _disabled => isLoading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 44,
      child: ElevatedButton(
        onPressed: _disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          // 통신 중에는 항상 회색
          disabledBackgroundColor: isLoading ? AppColors.gray : disabledColor,
          disabledForegroundColor: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}