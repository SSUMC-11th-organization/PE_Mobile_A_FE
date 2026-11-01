import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Manrope',
      scaffoldBackgroundColor: AppColors.warmWhite,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.violet,
        primary: AppColors.violet,
        surface: AppColors.warmWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Manrope',
          color: AppColors.violet,
          fontSize: 22,
          fontWeight: FontWeight.w500,
          height: 28 / 22,
          letterSpacing: 0,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        backgroundColor: AppColors.warmWhite,
        indicatorColor: AppColors.violetpink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 16 / 12,
            color: states.contains(WidgetState.selected)
                ? AppColors.navLabelSelected
                : AppColors.textSecondary,
          ),
        ),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: AppColors.textSecondary),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.violetpink,
        side: BorderSide.none,
        labelStyle: const TextStyle(
          fontFamily: 'Manrope',
          color: AppColors.violetDark,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 16 / 12,
          letterSpacing: 0,
        ),
        labelPadding: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: const StadiumBorder(),
        elevation: 0,
        pressElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
