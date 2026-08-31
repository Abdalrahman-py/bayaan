import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Context-aware color palette resolving light vs dark values dynamically.
/// Use this in UI screens and widgets instead of hardcoding light colors.
class AppPalette {
  final Color background;
  final Color cardBg;
  final Color paperBg; // Parchment background for Mushaf pages
  final Color textPrimary;
  final Color textMuted;
  final Color borderColor;
  final Color tealStart;
  final Color tealEnd;
  final Color gold;
  final Color cream;
  final bool isDark;

  const AppPalette({
    required this.background,
    required this.cardBg,
    required this.paperBg,
    required this.textPrimary,
    required this.textMuted,
    required this.borderColor,
    required this.tealStart,
    required this.tealEnd,
    required this.gold,
    required this.cream,
    required this.isDark,
  });

  factory AppPalette.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const AppPalette(
        background: AppColorsDark.lightBg,
        cardBg: AppColorsDark.cardBg,
        paperBg: AppColorsDark.paperBg,
        textPrimary: AppColorsDark.textDark,
        textMuted: AppColorsDark.textMuted,
        borderColor: AppColorsDark.borderColor,
        tealStart: AppColorsDark.tealStart,
        tealEnd: AppColorsDark.tealEnd,
        gold: AppColorsDark.gold,
        cream: AppColorsDark.cream,
        isDark: true,
      );
    }
    return const AppPalette(
      background: AppColors.lightBg,
      cardBg: Colors.white,
      paperBg: Color(0xFFFFFDF7),
      textPrimary: AppColors.textDark,
      textMuted: AppColors.textMuted,
      borderColor: Color(0xFFF5F1E6),
      tealStart: AppColors.tealStart,
      tealEnd: AppColors.tealEnd,
      gold: AppColors.gold,
      cream: AppColors.cream,
      isDark: false,
    );
  }
}
