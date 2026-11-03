import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 기본 · 통신 중 · 비활성 세 상태와 너비(null / double.infinity / 고정값)를 표현하는 공용 버튼.
/// 상태를 스스로 바꾸지 않고, 화면(ViewModel)이 넘겨준 값만 그린다.
class MovieLogButton extends StatelessWidget {
  const MovieLogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.width,
  });

  final String label;

  /// null이면 조건이 충족되지 않은 비활성 상태다.
  final VoidCallback? onPressed;

  /// true면 onPressed와 관계없이 비활성이며 라벨 대신 인디케이터만 보인다.
  final bool isLoading;

  /// null: 내용 기반 크기, double.infinity: 부모가 허용하는 최대 너비, 숫자: 고정 너비.
  final double? width;

  bool get _disabled => isLoading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 44,
      child: ElevatedButton(
        onPressed: _disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.violet,
          disabledBackgroundColor: AppColors.gray,
          foregroundColor: AppColors.white,
          disabledForegroundColor: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
