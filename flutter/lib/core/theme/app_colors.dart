import 'package:flutter/material.dart';

class AppColors {
  static const Color tealStart = Color(0xFF0F766E);
  static const Color tealEnd = Color(0xFF0C4A45);
  static const Color gold = Color(0xFFC9A227);
  static const Color cream = Color(0xFFF0E4C3);

  // ألوان الشاشات الفاتحة (Onboarding, Sign-in, Home...)
  static const Color lightBg = Color(0xFFFAF8F2);
  static const Color textDark = Color(0xFF2C3531);
  static const Color textMuted = Color(0xFF6D7A75);
  static const Color primaryTeal = Color(0xFF0F766E);

  // Recitation feedback (tajweed vs plain speech vs sifat errors).
  static const Color tajweedError = Color(0xFFD95A3B);
  static const Color plainError = Color(0xFFC084FC);
  static const Color sifatError = Color(0xFF2B7AB3);
  static const Color success = Color(0xFF16A34A);

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tealStart, tealEnd],
  );
}
