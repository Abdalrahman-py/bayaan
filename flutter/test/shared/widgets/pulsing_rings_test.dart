import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/shared/widgets/pulsing_rings.dart';

void main() {
  group('PulsingRings', () {
    testWidgets('idle renders static rings only (no pulsing ring)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PulsingRings(active: false))),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('pulsing-ring')), findsNothing);
    });

    testWidgets('active renders the animated pulsing ring', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PulsingRings(active: true))),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('pulsing-ring')), findsOneWidget);
    });
  });
}
