import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 목록 위에 어두운 막과 중앙 인디케이터만 올려 요청이 끝나기 전의 조작을 막는다.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Colors.black45),
          ),
        if (isLoading)
          const Center(child: CircularProgressIndicator(color: AppColors.white)),
      ],
    );
  }
}
