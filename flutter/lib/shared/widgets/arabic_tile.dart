import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';

/// A bordered tile holding Arabic text — a teach glyph, or one answer option.
///
/// The size adapts to the content because the content varies by two orders of
/// magnitude: unit 1 shows a single letter (ب) while unit 8 shows a whole ayah
/// (قُلْ أَعُوذُ بِرَبِّ الْفَلَقْ). The old fixed 64/72px square clipped
/// everything longer than about four characters — mid-glyph, so the ayah
/// lessons showed half a word and a stranded ه.
///
/// Short content keeps the square chip the design calls for; longer content
/// grows to a full-width card and steps the font down, wrapping if it still
/// doesn't fit.
class ArabicTile extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color? background;
  final Color borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  /// Shown instead of [text] — the audio options, which have no glyph.
  final IconData? icon;

  const ArabicTile({
    super.key,
    required this.text,
    required this.textColor,
    required this.borderColor,
    this.background,
    this.borderWidth = 1,
    this.onTap,
    this.icon,
  });

  /// Roughly how much room the string needs. Counts only base letters —
  /// tashkeel and Quranic marks stack above or below rather than advancing the
  /// pen, so counting them makes long text shrink far more than it needs to.
  static int weight(String s) => s
      .replaceAll(
        RegExp(r'[ً-ٰٟۖ-ۭ]'),
        '',
      )
      .trim()
      .length;

  @override
  Widget build(BuildContext context) {
    final int w = icon != null ? 1 : weight(text);
    final bool square = w <= 4;
    final double fontSize = w <= 4
        ? 30
        : w <= 10
        ? 26
        : w <= 20
        ? 22
        : 19;

    final child = icon != null
        ? Icon(icon, color: textColor, size: 28)
        : Text(
            text,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: arabic(fontSize: fontSize, color: textColor, height: 1.9),
          );

    return Semantics(
      button: onTap != null,
      label: icon != null ? 'Play audio option' : text,
      child: GestureDetector(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 72,
            minHeight: 72,
            maxWidth: MediaQuery.sizeOf(context).width - 64,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: square ? 10 : 18,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: background ?? Colors.white,
              border: Border.all(color: borderColor, width: borderWidth),
              borderRadius: BorderRadius.circular(16),
            ),
            // widthFactor/heightFactor are what keep the tile hugging its
            // text. A Container with `alignment` set grows to its maximum
            // constraints instead, which is why every tile — a single letter
            // included — came out the full width of the column.
            child: Center(widthFactor: 1, heightFactor: 1, child: child),
          ),
        ),
      ),
    );
  }
}

/// Default border for an untouched tile.
const kTileBorder = Color(0xFFF5F1E6);

/// The gold border the teach card uses for its glyphs.
Color get kGlyphBorder => AppColors.gold;
