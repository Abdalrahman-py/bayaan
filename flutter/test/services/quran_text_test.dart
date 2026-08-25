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
  });
}
