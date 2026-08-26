import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/features/audio_compare/audio_compare_screen.dart';
import 'package:bayaan/models/models.dart';

void main() {
  const errorRed = Color(0xFFE11D48);

  Verse verse({String? text}) => Verse(
    sura: 1,
    aya: 1,
    surahNameEn: 'Al-Fatihah',
    surahNameAr: 'الفاتحة',
    uthmani: text ?? List.filled(100, 'x').join(),
  );

  Mistake m(int start, int end) => Mistake(
    charRange: CharRange(start, end),
    isTajweed: true,
    kind: 'replace',
  );

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('renders reference plate, master and user cards', (tester) async {
    await tester.pumpWidget(
      wrap(
        AudioCompareScreen(
          verse: verse(),
          mistakes: const [],
          masterName: 'Sheikh Al-Husary',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Compare Recitations'), findsOneWidget);
    expect(find.text('MASTER RECITATION'), findsOneWidget);
    expect(find.text('Sheikh Al-Husary'), findsOneWidget);
    expect(find.text('YOUR RECITATION'), findsOneWidget);
  });

  testWidgets('shows a perfect score when there are no mistakes', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        AudioCompareScreen(verse: verse(), mistakes: const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('95% Accuracy'), findsOneWidget);
  });

  testWidgets('derives accuracy and red error bars from real mistakes', (
    tester,
  ) async {
    // 2 mistakes → 100 - 2*12 = 76%.
    await tester.pumpWidget(
      wrap(
        AudioCompareScreen(
          verse: verse(),
          mistakes: [m(0, 10), m(50, 60)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('76% Accuracy'), findsOneWidget);

    final redBars = tester.widgetList<Container>(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color == errorRed,
      ),
    );
    expect(redBars, isNotEmpty);
  });
}
