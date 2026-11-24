import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../view_models/favorite_detail_view_model.dart';

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key});

  Future<void> _toggle(BuildContext context, FavoriteDetailViewModel vm) async {
    final messenger = ScaffoldMessenger.of(context);
    final wasFavorite = vm.isFavorite;
    await vm.toggle();
    if (!context.mounted || vm.isDisposed) return;
    if (vm.errorMessage == null && vm.isFavorite == wasFavorite) return;
    final message =
        vm.errorMessage ?? (vm.isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 삭제했습니다.');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoriteDetailViewModel>(
      builder: (context, vm, _) {
        final busy = vm.isLoading || vm.isSaving;
        final failedToLoad = !vm.hasLoadedStatus && !vm.isLoading;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.skeleton, width: 1.5),
              ),
              child: busy
                  ? const Center(
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.violet,
                        ),
                      ),
                    )
                  : failedToLoad
                  ? IconButton(
                      tooltip: '여부 다시 확인',
                      color: AppColors.violet,
                      onPressed: vm.load,
                      icon: const Icon(Icons.refresh),
                    )
                  : IconButton(
                      tooltip: vm.isFavorite ? '즐겨찾기 해제' : '즐겨찾기 등록',
                      color: AppColors.violet,
                      iconSize: 30,
                      onPressed: () => _toggle(context, vm),
                      icon: Icon(
                        vm.isFavorite ? Icons.bookmark : Icons.bookmark_border,
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            const Text(
              '즐겨찾기',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.violet,
              ),
            ),
          ],
        );
      },
    );
  }
}
