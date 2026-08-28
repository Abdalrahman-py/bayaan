import 'package:flutter/material.dart';

import 'mistake_highlights.dart';

/// The ayah with its mistakes marked, drawn as ONE text run.
///
/// Styled `TextSpan`s were the obvious way to do this and the wrong one:
/// Flutter shapes each span as its own run, so any split severs the cursive
/// joins Arabic depends on, and a split before a combining mark strands it on
/// a dotted circle. Splitting at word boundaries dodged both but threw away
/// which *sound* was flagged, which is the point of the screen.
///
/// So the text is laid out once, unbroken and perfectly shaped, and the
/// highlights are painted behind it from the glyph boxes the same
/// [TextPainter] reports. Exact per-sound marking, no shaping damage.
class HighlightedVerse extends StatelessWidget {
  final String text;
  final List<Highlight> highlights;
  final TextStyle style;
  final Color tajweedColor;
  final Color plainColor;

  const HighlightedVerse({
    super.key,
    required this.text,
    required this.highlights,
    required this.style,
    required this.tajweedColor,
    required this.plainColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final painter = _layout(width);
        return CustomPaint(
          size: Size(width, painter.height),
          painter: _VersePainter(
            text: text,
            highlights: highlights,
            style: style,
            tajweedColor: tajweedColor,
            plainColor: plainColor,
          ),
        );
      },
    );
  }

  TextPainter _layout(double maxWidth) => layoutVerse(
    text: text,
    style: style,
    width: maxWidth,
  );
}

/// Lays the ayah out across the FULL width.
///
/// `minWidth` matters: with only a maxWidth the paragraph box shrinks to the
/// text, and TextAlign.center then has nothing to centre inside — a short ayah
/// renders flush against the leading edge.
TextPainter layoutVerse({
  required String text,
  required TextStyle style,
  required double width,
}) => TextPainter(
  text: TextSpan(text: text, style: style),
  textDirection: TextDirection.rtl,
  textAlign: TextAlign.center,
)..layout(minWidth: width, maxWidth: width);

class _VersePainter extends CustomPainter {
  final String text;
  final List<Highlight> highlights;
  final TextStyle style;
  final Color tajweedColor;
  final Color plainColor;

  _VersePainter({
    required this.text,
    required this.highlights,
    required this.style,
    required this.tajweedColor,
    required this.plainColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final painter = layoutVerse(text: text, style: style, width: size.width);

    for (final h in highlights) {
      final color = h.isTajweed ? tajweedColor : plainColor;
      final boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: h.start, extentOffset: h.end),
      );
      for (final box in boxes) {
        final rect = Rect.fromLTRB(box.left, box.top, box.right, box.bottom);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.inflate(2),
            const Radius.circular(4),
          ),
          Paint()..color = color.withValues(alpha: 0.18),
        );
        // A solid rule under the glyphs, so the mark survives a colour-blind
        // reader and a low-contrast screen.
        canvas.drawRect(
          Rect.fromLTRB(rect.left, rect.bottom, rect.right, rect.bottom + 2),
          Paint()..color = color,
        );
      }
    }

    painter.paint(canvas, Offset.zero);
  }

  @override
  bool shouldRepaint(_VersePainter old) =>
      old.text != text ||
      old.highlights != highlights ||
      old.style != style ||
      old.tajweedColor != tajweedColor ||
      old.plainColor != plainColor;
}
