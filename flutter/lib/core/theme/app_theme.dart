import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'PlusJakartaSans',
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      cardColor: Colors.white,
      dividerColor: const Color(0xFFF5F1E6),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.tealStart,
        primary: AppColors.tealStart,
        secondary: AppColors.gold,
        surface: Colors.white,
        brightness: Brightness.light,
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'PlusJakartaSans',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColorsDark.lightBg,
      cardColor: AppColorsDark.cardBg,
      dividerColor: AppColorsDark.borderColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColorsDark.tealStart,
        primary: AppColorsDark.tealStart,
        secondary: AppColorsDark.gold,
        surface: AppColorsDark.cardBg,
        brightness: Brightness.dark,
      ),
    );
  }
}
