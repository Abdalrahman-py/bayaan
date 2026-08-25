import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/shared/widgets/dashed_circle_painter.dart';

void main() {
  const gold = Color(0xFFC9A227);

  /// Renders the painter into a 100x100 image and counts painted pixels.
  Future<int> paintedPixelCount(DashedCirclePainter painter) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Size(100, 100));
    final image = await recorder.endRecording().toImage(100, 100);
    final data = await image.toByteData();
    var painted = 0;
    for (var i = 3; i < data!.lengthInBytes; i += 4) {
      if (data.getUint8(i) > 0) painted++;
    }
    return painted;
  }

  group('DashedCirclePainter', () {
    test('shouldRepaint is false when config is identical', () {
      const a = DashedCirclePainter(color: gold);
      const b = DashedCirclePainter(color: gold);
      expect(a.shouldRepaint(b), isFalse);
    });

    test('shouldRepaint is true when color, strokeWidth, or dashCount changes', () {
      const a = DashedCirclePainter(color: gold);
      expect(
        a.shouldRepaint(const DashedCirclePainter(color: Colors.black)),
        isTrue,
      );
      expect(
        a.shouldRepaint(const DashedCirclePainter(color: gold, strokeWidth: 3)),
        isTrue,
      );
      expect(
        a.shouldRepaint(const DashedCirclePainter(color: gold, dashCount: 20)),
        isTrue,
      );
    });

    test('paint draws a dashed ring, not a solid disc', () async {
      const painter = DashedCirclePainter(color: gold, dashCount: 40);
      final painted = await paintedPixelCount(painter);
      // A full disc would be ~7,800 px; dashes (half arcs, thin stroke) are a
      // few hundred. This catches both "paints nothing" and "fills the disc".
      expect(painted, greaterThan(50));
      expect(painted, lessThan(2000));
    });

    test('fewer dashes paints fewer pixels', () async {
      const solid = DashedCirclePainter(color: gold, dashCount: 200);
      const sparse = DashedCirclePainter(color: gold, dashCount: 6);
      final solidPixels = await paintedPixelCount(solid);
      final sparsePixels = await paintedPixelCount(sparse);
      expect(sparsePixels, lessThan(solidPixels));
    });
  });
}
