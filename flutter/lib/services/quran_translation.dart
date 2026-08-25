import 'dart:convert';

import 'package:http/http.dart' as http;

/// English translation/transliteration text, fetched lazily per surah and
/// cached in memory. Best-effort only — the Arabic text and grading always
/// work without it; a failed fetch just means the card doesn't show.
/// ponytail: no bundled translation asset (~1MB+ for the whole Quran) — one
/// small network call per surah, cached, is the simplest thing that works.
class QuranTranslation {
  static final Map<int, Map<int, String>> _translationCache = {};
  static final Map<int, Map<int, String>> _transliterationCache = {};

  static Future<Map<int, String>?> forSurah(int sura) =>
      _fetch(sura, 'en.sahih', _translationCache);

  /// Latin-script pronunciation guide (e.g. "Bismillaahir Rahmaanir Raheem")
  /// — lets a non-Arabic-reading user attempt the sounds before recording.
  static Future<Map<int, String>?> transliterationForSurah(int sura) =>
      _fetch(sura, 'en.transliteration', _transliterationCache);

  static Future<Map<int, String>?> _fetch(
    int sura,
    String edition,
    Map<int, Map<int, String>> cache,
  ) async {
    final cached = cache[sura];
    if (cached != null) return cached;
    try {
      final res = await http
          .get(Uri.parse('https://api.alquran.cloud/v1/surah/$sura/$edition'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final ayahs = (body['data']?['ayahs'] as List<dynamic>?) ?? [];
      final map = <int, String>{
        for (final a in ayahs)
          (a as Map<String, dynamic>)['numberInSurah'] as int:
              a['text'] as String,
      };
      cache[sura] = map;
      return map;
    } catch (_) {
      return null;
    }
  }
}
