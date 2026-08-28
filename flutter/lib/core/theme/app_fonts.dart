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
  fontWeight: fontWeight.value < FontWeight.w500.value
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

/// Arabic runs inside an English sentence, wrapped in Unicode isolates
/// (FSI…PDI) so the bidi algorithm treats each run as one neutral unit.
///
/// Without this, a trailing comma or period after an Arabic word is a neutral
/// character between an RTL run and the paragraph's LTR direction, so it
/// jumps to the wrong side — the teach narration rendered "keeps its ,ل" and
/// "شَمس swallows it." with the phrase order reversed. Isolating each run
/// fixes the punctuation and the word order without touching the content.
String bidi(String text) => text.replaceAllMapped(
  // Arabic block + Arabic Supplement/Extended-A + presentation forms, plus the
  // tashkeel and Quranic marks that sit inside a run.
  RegExp(r'[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]+'),
  (m) => '\u2068${m[0]}\u2069',
);
