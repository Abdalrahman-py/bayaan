import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/features/audio_compare/widgets/audio_compare_card.dart';

void main() {
  const errorRed = Color(0xFFE11D48);
  const teal = Color(0xFF0F766E);

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('AudioCompareCard', () {
    testWidgets('renders badge, trailing text, and one bar per height', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          AudioCompareCard(
            badgeLabel: 'Master Recitation',
            badgeBg: Colors.white,
            badgeTextColor: Colors.black,
            trailingText: 'Sheikh Al-Husary',
            trailingTextColor: Colors.black,
            playButtonColor: teal,
            iconColor: Colors.white,
            borderColor: Colors.grey,
            waveformHeights: const [4, 8, 12, 16],
            waveformColor: teal,
          ),
        ),
      );

      expect(find.text('MASTER RECITATION'), findsOneWidget);
      expect(find.text('Sheikh Al-Husary'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('renders error bars in red for the given indices', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          AudioCompareCard(
            badgeLabel: 'Your Recitation',
            badgeBg: Colors.white,
            badgeTextColor: Colors.black,
            trailingText: '86% Accuracy',
            trailingTextColor: Colors.black,
            playButtonColor: Colors.grey,
            iconColor: Colors.black,
            borderColor: Colors.grey,
            waveformHeights: const [4, 8, 12, 16],
            waveformColor: teal,
            errorBarIndices: const {1, 3},
          ),
        ),
      );

      final redBars = tester.widgetList<Container>(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color == errorRed,
        ),
      );
      expect(redBars, hasLength(2));
    });

    testWidgets('play button toggles to pause and back after the clip', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          AudioCompareCard(
            badgeLabel: 'Your Recitation',
            badgeBg: Colors.white,
            badgeTextColor: Colors.black,
            trailingText: '86% Accuracy',
            trailingTextColor: Colors.black,
            playButtonColor: Colors.grey,
            iconColor: Colors.black,
            borderColor: Colors.grey,
            waveformHeights: const [4, 8, 12, 16],
            waveformColor: teal,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      expect(find.byIcon(Icons.pause), findsOneWidget);

      // Clip duration is 3s; after it completes the button resets.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });
  });
}
