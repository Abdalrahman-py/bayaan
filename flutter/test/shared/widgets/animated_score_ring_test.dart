import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/shared/widgets/animated_score_ring.dart';
import 'package:bayaan/shared/widgets/progress_ring_painter.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('counts up to the final score after the animation settles', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const AnimatedScoreRing(score: 86)));
    await tester.pumpAndSettle();

    expect(find.text('86'), findsOneWidget);
    expect(find.text('/100'), findsOneWidget);
  });

  testWidgets('renders the progress ring painter', (tester) async {
    await tester.pumpWidget(wrap(const AnimatedScoreRing(score: 50)));
    await tester.pumpAndSettle();

    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<ProgressRingPainter>();
    expect(painters, hasLength(1));
  });
}
