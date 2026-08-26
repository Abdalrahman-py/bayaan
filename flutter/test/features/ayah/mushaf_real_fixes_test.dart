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

    testWidgets('a full page of text scrolls instead of being clipped', (
      tester,
    ) async {
      // 15 long ayahs on one page — more text than the viewport can show.
      final ayahs = List.generate(
        15,
        (i) => v(
          i + 1,
          1,
          text:
              'هذا نص طويل جدا لآية قرآنية ممتدة على عدة أسطر لضمان تجاوز الارتفاع المحدد للصفحة في بيئة الاختبار',
        ),
      );
      await tester.pumpWidget(wrap(ayahs, (_) {}));
      await tester.pumpAndSettle();

      final scrollable = find.descendant(
        of: find.byType(MushafPageView),
        matching: find.byType(SingleChildScrollView),
      );
      final before = tester.state<ScrollableState>(
        find.descendant(of: scrollable, matching: find.byType(Scrollable)),
      ).position.pixels;
      await tester.drag(scrollable.first, const Offset(0, -200));
      await tester.pumpAndSettle();
      final after = tester.state<ScrollableState>(
        find.descendant(of: scrollable, matching: find.byType(Scrollable)),
      ).position.pixels;
      expect(after, greaterThan(before));
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
