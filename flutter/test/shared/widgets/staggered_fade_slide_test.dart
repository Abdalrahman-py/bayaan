import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/shared/widgets/staggered_fade_slide.dart';

void main() {
  // MaterialApp wraps its route in a FadeTransition of its own, so scope the
  // lookup to the one this widget builds.
  double opacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.descendant(
          of: find.byType(StaggeredFadeSlide),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;

  Future<void> pumpItem(WidgetTester tester, {required bool animate}) =>
      tester.pumpWidget(
        MaterialApp(
          home: StaggeredFadeSlide(
            index: 8,
            animate: animate,
            child: const Text('row'),
          ),
        ),
      );

  testWidgets('an item appearing with its list fades in', (tester) async {
    await pumpItem(tester, animate: true);
    expect(opacity(tester), 0.0);

    // Advance past the stagger delay first — pumpAndSettle alone returns
    // immediately, because nothing is animating until that timer fires.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(opacity(tester), 1.0);
  });

  testWidgets('an item scrolled into view later is opaque immediately', (
    tester,
  ) async {
    // The list has been on screen for a while; this row is only being built
    // now because the user scrolled to it, so it must not replay the entrance.
    await pumpItem(tester, animate: false);

    expect(opacity(tester), 1.0);
    await tester.pump(const Duration(seconds: 1));
    expect(opacity(tester), 1.0);
  });
}
