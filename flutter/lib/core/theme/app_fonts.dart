import 'package:flutter/material.dart';

/// Bundled fonts only — no runtime Google Fonts download, so the app looks
/// right offline. Drop-in replacement for GoogleFonts.plusJakartaSans/inter
/// (same named params) backed by assets/fonts instead of a network fetch.
TextStyle pjs({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w500,
  Color? color,
  double? height,
  double? letterSpacing,
}) => TextStyle(
  fontFamily: 'PlusJakartaSans',
  fontSize: fontSize,
  // Only 500/600/700/800 are bundled — anything lighter falls back to 500.
  fontWeight: fontWeight.index < FontWeight.w500.index
      ? FontWeight.w500
      : fontWeight,
  color: color,
  height: height,
  letterSpacing: letterSpacing,
);

/// Arabic glyphs (letters, ayah snippets) — always Amiri Quran, never the
/// Latin UI font, so tashkeel renders correctly.
TextStyle arabic({
  double fontSize = 16,
  FontWeight fontWeight = FontWeight.normal,
  Color? color,
  double? height,
}) => TextStyle(
  fontFamily: 'AmiriQuran',
  fontSize: fontSize,
  fontWeight: fontWeight,
  color: color,
  height: height,
);
