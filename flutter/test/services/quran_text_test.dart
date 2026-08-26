import 'package:flutter_test/flutter_test.dart';
import 'package:bayaan/services/quran_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuranText', () {
    test('loads all 6236 verses and 114 chapters from bundled assets', () async {
      await QuranText.ensureLoaded();
      expect(QuranText.chapters, hasLength(114));
      expect(QuranText.verseCount(2), 286);
      expect(QuranText.verseCount(114), 6);
    });

    test('looks up chapters by id, not list position', () async {
      await QuranText.ensureLoaded();
      final v = QuranText.verse(2, 255);
      expect(v, isNotNull);
      expect(v!.surahNameEn, 'Al-Baqarah');
      expect(v.uthmani, isNotEmpty);
    });

    test('the longest ayah (2:282) resolves with its full text', () async {
      await QuranText.ensureLoaded();
      final v = QuranText.verse(2, 282);
      expect(v, isNotNull);
      expect(v!.uthmani.length, greaterThan(1000));
    });

    test('verseFor falls back to Al-Fatihah demo for unknown verses', () async {
      await QuranText.ensureLoaded();
      final v = QuranText.verseFor(999, 1); // invalid sura
      expect(v.surahNameEn, 'Al-Fatihah');
      expect(v.uthmani, contains('بِسْمِ'));
    });

    test('verseFor survives when assets never loaded', () {
      // Fresh isolate state: no ensureLoaded, _byId is null → null-safe path.
      final v = QuranText.verseFor(1, 1);
      expect(v.surahNameEn, 'Al-Fatihah');
    });

    test('every verse carries its real mushaf page number', () async {
      await QuranText.ensureLoaded();
      final v = QuranText.verse(2, 255); // Ayat al-Kursi
      expect(v, isNotNull);
      expect(v!.pageNumber, 42);
      expect(QuranText.verse(67, 1)!.pageNumber, 562); // Surah Mulk
      expect(QuranText.verse(1, 7)!.pageNumber, 1); // last ayah of Fatihah
    });

    test('mushafPages spans the full 604-page mushaf in order', () async {
      await QuranText.ensureLoaded();
      final pages = QuranText.mushafPages();
      expect(pages, hasLength(604));
      expect(pages.first.pageNumber, 1);
      expect(pages.last.pageNumber, 604);
      for (var i = 1; i < pages.length; i++) {
        expect(pages[i].pageNumber, pages[i - 1].pageNumber + 1);
      }
    });

    test('mushafPages groups ayahs exactly like the printed mushaf', () async {
      await QuranText.ensureLoaded();
      final pages = QuranText.mushafPages();
      // Page 1 = all seven ayahs of Al-Fatihah; page 2 opens Al-Baqarah.
      expect(pages[0].ayahs.map((v) => v.aya), [1, 2, 3, 4, 5, 6, 7]);
      expect(pages[0].surahNameEn, 'Al-Fatihah');
      expect(pages[1].ayahs.first.sura, 2);
      expect(pages[1].surahNameEn, 'Al-Baqarah');
      // Ayat al-Kursi sits on page 42; the last page closes the Quran.
      expect(
        pages[41].ayahs.any((v) => v.sura == 2 && v.aya == 255),
        isTrue,
      );
      expect(pages[603].ayahs.last.aya, 6); // 114:6
    });
  });
}

// Appended: continuous mushaf pagination tests (quran.com-style global pages).
