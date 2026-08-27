import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/features/ayah/widgets/mushaf_page_view.dart';
import 'package:bayaan/features/ayah/models/ayah.dart';

void main() {
  Ayah v(int aya, int page, {String text = 'نص'}) => Ayah(
    number: aya,
    arabicText: text,
    pageNumber: page,
  );

  Widget wrap(List<Ayah> ayahs, ValueChanged<Ayah> onTap) => MaterialApp(
    home: Scaffold(
      body: MushafPageView(ayahs: ayahs, onAyahTap: onTap),
    ),
  );

  group('MushafPageView real-device behavior', () {
    testWidgets('taps on a later page hit that page\'s ayahs, not stale ones', (
      tester,
    ) async {
      final tapped = <Ayah>[];
      // Two pages: page 1 has ayah 1, page 2 has ayah 5. PageView recycles
      // element slots, so page 2 must rebuild its recognizers.
      await tester.pumpWidget(
        wrap([v(1, 1), v(5, 2, text: 'خمسة')], tapped.add),
      );
      await tester.pumpAndSettle();

      // Swipe to page 2 (RTL: drag positive offset to advance).
      await tester.drag(find.byType(PageView), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining('خمسة', findRichText: true), findsOneWidget);

      // Tap inside the ayah span on page 2.
      await tester.tap(find.textContaining('خمسة', findRichText: true));
      await tester.pumpAndSettle();
      expect(tapped.single.number, 5);
    });

    testWidgets('a dense page shrinks its text to fit instead of overflowing', (
      tester,
    ) async {
      const long =
          'هذا نص طويل جدا لآية قرآنية ممتدة على عدة أسطر لضمان تجاوز الارتفاع المحدد للصفحة في بيئة الاختبار';

      double firstWordSize() => tester
          .widgetList<Text>(find.textContaining('هذا'))
          .first
          .style!
          .fontSize!;

      await tester.pumpWidget(
        wrap([v(1, 1, text: long), v(2, 1, text: long)], (_) {}),
      );
      await tester.pumpAndSettle();
      final sparse = firstWordSize();

      // 15 of the same long ayahs on one page — far more than fits at that size.
      await tester.pumpWidget(
        wrap(List.generate(15, (i) => v(i + 1, 1, text: long)), (_) {}),
      );
      await tester.pumpAndSettle();

      expect(firstWordSize(), lessThan(sparse));
      expect(tester.takeException(), isNull);
    });

    testWidgets('swiping navigates between pages and renders page medallion', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap([v(1, 1), v(2, 1), v(5, 2), v(9, 3)], (_) {}),
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsWidgets);

      await tester.drag(find.byType(PageView), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsWidgets);
    });
  });
}
