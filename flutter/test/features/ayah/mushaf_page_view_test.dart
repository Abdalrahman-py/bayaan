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


  group('splitIntoSurahBlocks', () {
    Ayah a(int sura, int number) =>
        Ayah(sura: sura, number: number, arabicText: 'نص', pageNumber: 1);

    test('opens a surah that starts at its first ayah', () {
      final blocks = splitIntoSurahBlocks([a(2, 1), a(2, 2)]);
      expect(blocks, hasLength(2));
      expect((blocks[0] as SurahOpening).sura, 2);
      expect((blocks[0] as SurahOpening).showBasmalah, isTrue);
      expect((blocks[1] as AyahRun).ayahs.map((x) => x.number), [1, 2]);
    });

    test('a continuation page opens no surah', () {
      final blocks = splitIntoSurahBlocks([a(2, 6), a(2, 7)]);
      expect(blocks, hasLength(1));
      expect(blocks.single, isA<AyahRun>());
    });

    test('splits a page that runs three surahs, like page 604', () {
      final blocks = splitIntoSurahBlocks([
        a(112, 1), a(112, 2),
        a(113, 1), a(113, 2),
        a(114, 1),
      ]);
      expect(blocks.map((b) => b.runtimeType.toString()), [
        'SurahOpening', 'AyahRun',
        'SurahOpening', 'AyahRun',
        'SurahOpening', 'AyahRun',
      ]);
      expect((blocks[2] as SurahOpening).sura, 113);
    });

    test('a surah ending mid-page is followed by the next surah opening', () {
      final blocks = splitIntoSurahBlocks([a(2, 285), a(2, 286), a(3, 1)]);
      expect(blocks, hasLength(3));
      expect(blocks[0], isA<AyahRun>());
      expect((blocks[1] as SurahOpening).sura, 3);
    });

    test('At-Tawbah opens without a basmalah', () {
      final blocks = splitIntoSurahBlocks([a(9, 1)]);
      expect((blocks[0] as SurahOpening).showBasmalah, isFalse);
    });

    test('Al-Fatihah opens without a separate basmalah, it is ayah one', () {
      final blocks = splitIntoSurahBlocks([a(1, 1)]);
      expect((blocks[0] as SurahOpening).showBasmalah, isFalse);
    });
  });


  group('wrapTokens', () {
    // Widths are supplied by the caller, so the wrapper itself stays pure and
    // testable without a text engine.
    List<List<int>> wrap(List<int> widths, double maxWidth, {double space = 1}) {
      final tokens = List.generate(widths.length, (i) => i);
      return wrapTokens<int>(
        tokens,
        maxWidth: maxWidth,
        spaceWidth: space,
        widthOf: (t) => widths[t].toDouble(),
      );
    }

    test('packs as many tokens as fit, counting the spaces between them', () {
      // 3 + 1 + 3 = 7 fits in 8; adding another 3 would need 11.
      expect(wrap([3, 3, 3, 3], 8), [
        [0, 1],
        [2, 3],
      ]);
    });

    test('keeps everything on one line when it all fits', () {
      expect(wrap([2, 2, 2], 100), [
        [0, 1, 2],
      ]);
    });

    test('gives an oversized token a line of its own rather than dropping it', () {
      expect(wrap([2, 50, 2], 10), [
        [0],
        [1],
        [2],
      ]);
    });

    test('returns no lines for no tokens', () {
      expect(wrap([], 10), isEmpty);
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

      // Page 1 footer medallion visible; page 1 holds both of its ayahs, each
      // word laid out as its own widget, and page 2's ayah is not on it.
      expect(find.text('1'), findsWidgets);
      expect(find.text('نص'), findsNWidgets(2));
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

      // Each word is its own tappable widget now that lines are laid out
      // individually, so tap the first word of ayah 1 directly.
      await tester.tap(find.text('نص').first);
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
              selected: v(2, 1),
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


    testWidgets('selecting an ayah highlights only that surah\'s copy of it', (
      tester,
    ) async {
      Ayah of(int sura, int number) =>
          Ayah(sura: sura, number: number, arabicText: 'نص', pageNumber: 604);

      // Page 604 runs three surahs, each with an ayah 1 — selecting one must
      // not light up the other two.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MushafPageView(
              ayahs: [of(112, 1), of(113, 1), of(114, 1)],
              selected: of(113, 1),
              onAyahTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gold = tester.widgetList<Container>(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color == AppColors.gold,
        ),
      );
      expect(gold, hasLength(1));
    });

    testWidgets('no selection means no highlighted medallion', (
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
