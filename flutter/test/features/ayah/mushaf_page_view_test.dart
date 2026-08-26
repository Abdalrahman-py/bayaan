import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/features/ayah/widgets/mushaf_page_view.dart';
import 'package:bayaan/features/ayah/models/ayah.dart';
import 'package:bayaan/core/theme/app_colors.dart';

void main() {
  group('groupAyahsByMushafPage', () {
    Ayah v(int aya, int page) => Ayah(
      number: aya,
      arabicText: 'text',
      pageNumber: page,
    );

    test('groups ayahs by their real mushaf page, preserving ayah order', () {
      final pages = groupAyahsByMushafPage([
        v(1, 1),
        v(2, 1),
        v(3, 1),
        v(4, 2),
        v(5, 2),
        v(6, 3),
        v(7, 3),
      ]);
      expect(pages, hasLength(3));
      expect(pages[0].map((a) => a.number), [1, 2, 3]);
      expect(pages[1].map((a) => a.number), [4, 5]);
      expect(pages[2].map((a) => a.number), [6, 7]);
    });

    test('sorts pages ascending even when input is out of order', () {
      final pages = groupAyahsByMushafPage([v(7, 3), v(1, 1), v(4, 2)]);
      expect(pages.map((p) => p.first.pageNumber), [1, 2, 3]);
    });

    test('returns an empty list for no ayahs', () {
      expect(groupAyahsByMushafPage([]), isEmpty);
    });
  });

  group('MushafPageView', () {
    Ayah v(int aya, int page) => Ayah(
      number: aya,
      arabicText: 'نص',
      pageNumber: page,
    );

    testWidgets('renders one mushaf page per grouped page, footer shows page', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MushafPageView(
              ayahs: [v(1, 1), v(2, 1), v(4, 2)],
              onAyahTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Page 1 footer medallion visible; both ayah texts rendered in the
      // page's single RichText.
      expect(find.text('1'), findsWidgets);
      expect(find.textContaining('نص', findRichText: true), findsOneWidget);
    });

    testWidgets('tapping an ayah invokes onAyahTap with that ayah', (
      tester,
    ) async {
      final tapped = <Ayah>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MushafPageView(
              ayahs: [v(1, 1), v(2, 1)],
              onAyahTap: tapped.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap inside the first ayah span: RTL layout puts it at the top-right
      // of the RichText (first line starts at the right padding edge).
      final rect = tester.getRect(find.byType(RichText).first);
      await tester.tapAt(Offset(rect.right - 20, rect.top + 20));
      await tester.pumpAndSettle();
      expect(tapped, hasLength(1));
      expect(tapped.single.number, 1);
    });

    testWidgets('the selected ayah renders a highlighted medallion', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MushafPageView(
              ayahs: [v(1, 1), v(2, 1)],
              selectedNumber: 2,
              onAyahTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Selected medallion is gold-filled (2 medallions: 1 unselected, 1 selected).
      final goldMedallions = tester.widgetList<Container>(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color == AppColors.gold,
        ),
      );
      expect(goldMedallions, hasLength(1));
    });

    testWidgets('no selectedNumber means no highlighted medallion', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MushafPageView(
              ayahs: [v(1, 1), v(2, 1)],
              onAyahTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final goldMedallions = tester.widgetList<Container>(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color == AppColors.gold,
        ),
      );
      expect(goldMedallions, isEmpty);
    });
  });
}
