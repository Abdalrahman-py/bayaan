import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/features/recitation/celebration_screen.dart';
import 'package:bayaan/services/recitation_controller.dart';
import 'package:bayaan/shared/widgets/dashed_circle_painter.dart';

void main() {
  group('interpolateScore', () {
    test('returns the start score at t=0 and the end score at t=1', () {
      expect(interpolateScore(0, from: 40, to: 100), 40);
      expect(interpolateScore(1, from: 40, to: 100), 100);
    });

    test('interpolates linearly mid-way', () {
      expect(interpolateScore(0.5, from: 40, to: 100), 70);
    });

    test('rounds intermediate values', () {
      expect(interpolateScore(0.33, from: 0, to: 100), 33);
    });
  });

  group('CelebrationScreen', () {
    testWidgets('renders the count-up score, mashaallah, stars and CTA', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CelebrationScreen(
            controller: RecitationController(),
            sura: 1,
            aya: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MASHAALLAH'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('Continue Journey'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets); // dashed ring painter
    });

    testWidgets('renders the dashed circle ring via DashedCirclePainter', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CelebrationScreen(
            controller: RecitationController(),
            sura: 1,
            aya: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<DashedCirclePainter>();
      expect(painters, hasLength(1));
    });
  });
}
