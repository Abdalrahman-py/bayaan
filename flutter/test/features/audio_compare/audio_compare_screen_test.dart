import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bayaan/services/reciter_audio.dart';

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
        AudioCompareScreen(verse: verse(), mistakes: const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Compare Recitations'), findsOneWidget);
    expect(find.text('MASTER RECITATION'), findsOneWidget);
    expect(find.text(Reciter.fallback.shortName), findsOneWidget);
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

  testWidgets('reports how close the attempt was and what to focus on', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      wrap(
        AudioCompareScreen(
          verse: verse(),
          mistakes: [
            Mistake(
              charRange: const CharRange(0, 4),
              isTajweed: true,
              kind: 'replace',
              ruleNameEn: 'Ghunnah',
            ),
            Mistake(
              charRange: const CharRange(5, 9),
              isTajweed: true,
              kind: 'replace',
              ruleNameEn: 'Ghunnah',
            ),
          ],
          sifatErrors: const [
            SifatError(
              phonemesGroup: 'د',
              attribute: 'shidda',
              predicted: 'rikhwa',
              expected: 'shadida',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 3 issues x 12 points off.
    expect(find.text('64%'), findsOneWidget);
    expect(find.text('3 differences from Al-Husary\'s recitation.'),
        findsOneWidget);
    // Repeated rules are ranked and counted, not listed twice.
    expect(find.text('Ghunnah ×2'), findsOneWidget);
    expect(find.text('shidda'), findsOneWidget);
  });
}
