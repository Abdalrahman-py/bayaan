import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/shared/widgets/recording_wavebars.dart';

void main() {
  group('waveBarHeight', () {
    test('idle bars keep their base height', () {
      expect(waveBarHeight(0, 12, 0.3, active: false), 12);
      expect(waveBarHeight(3, 20, 0.9, active: false), 20);
    });

    test('active bars move with an alternating phase', () {
      // Even index follows t directly.
      expect(waveBarHeight(0, 10, 0, active: true), 10 * 0.5);
      expect(waveBarHeight(0, 10, 1, active: true), 10 * 1.4);
      // Odd index follows 1 - t.
      expect(waveBarHeight(1, 10, 0, active: true), 10 * 1.4);
      expect(waveBarHeight(1, 10, 1, active: true), 10 * 0.5);
    });
  });

  group('RecordingWavebars', () {
    testWidgets('renders one bar per base height', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RecordingWavebars(active: false)),
        ),
      );
      await tester.pumpAndSettle();

      // Bars are the 3px-wide Containers inside the widget.
      final bars = tester.widgetList<Container>(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints?.minWidth == 3 &&
              w.constraints?.maxWidth == 3,
        ),
      );
      expect(bars, hasLength(7));
    });
  });
}
