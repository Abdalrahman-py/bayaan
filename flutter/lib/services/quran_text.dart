import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/models.dart';

/// Supabase project config — the single source of truth. Both main.dart and
/// the recitation controller import from here.
const kSupabaseUrl = 'https://djcuxaziipgjlmdfkeqz.supabase.co';
const kAnonKey = 'sb_publishable_2_fHjweJj84IuJkP9elIGw_31m1xWQY';

/// Ported from android/.../ui/model/QuranText.kt — full Uthmani text +
/// chapter metadata loaded from bundled assets.
class QuranText {
  static Map<String, String> _texts = {};
  static List<Chapter> _chapters = [];
  static Map<int, Chapter>? _byId; // id → chapter, immune to list ordering
  static Map<String, int> _pages = {}; // "sura:aya" → mushaf page number

  static Future<void> ensureLoaded() async {
    if (_texts.isNotEmpty) return;
    final raw = await rootBundle.loadString('assets/quran/uthmani.json');
    final obj = jsonDecode(raw) as Map<String, dynamic>;
    _texts = obj.map((k, v) => MapEntry(k, v as String));

    final chRaw = await rootBundle.loadString('assets/quran/chapters.json');
    final list = jsonDecode(chRaw) as List<dynamic>;
    _chapters = list
        .map(
          (e) => Chapter(
            id: e['id'] as int,
            nameEn: e['name'] as String,
            nameAr: e['name_arabic'] as String,
            translatedName: e['translated_name'] as String,
            versesCount: e['verses_count'] as int,
            revelationPlace: e['revelation_place'] as String,
          ),
        )
        .toList();
    _byId = {for (final c in _chapters) c.id: c};

    final pageRaw = await rootBundle.loadString('assets/quran/pages.json');
    final pageObj = jsonDecode(pageRaw) as Map<String, dynamic>;
    final inner = pageObj['sura:aya'] as Map<String, dynamic>;
    _pages = inner.map((k, v) => MapEntry(k, v as int));
  }

  /// Mushaf page number for (sura, aya), or null if assets never loaded.
  static int? pageFor(int sura, int aya) => _pages['$sura:$aya'];

  static int verseCount(int sura) => _byId?[sura]?.versesCount ?? 0;

  static Verse? verse(int sura, int aya) {
    final text = _texts['$sura:$aya'];
    final ch = _byId?[sura];
    if (text == null || ch == null) return null;
    return Verse(
      sura: sura,
      aya: aya,
      surahNameEn: ch.nameEn,
      surahNameAr: ch.nameAr,
      uthmani: text,
      pageNumber: _pages['$sura:$aya'] ?? 1,
    );
  }

  /// Canonical Verse for (sura, aya); demo Fatihah fallback like the Android app.
  static Verse verseFor(int sura, int aya) {
    final v = verse(sura, aya);
    if (v != null) return v;
    return Verse(
      sura: sura,
      aya: aya,
      surahNameEn: 'Al-Fatihah',
      surahNameAr: 'الفاتحة',
      uthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
    );
  }

  static List<Chapter> get chapters => _chapters;

  static List<MushafPage>? _mushafPages;

  /// The full mushaf as 604 continuous pages (quran.com-style global
  /// pagination): every ayah grouped onto its real printed page, in page
  /// order, with the surah its opening line belongs to.
  static List<MushafPage> mushafPages() {
    if (_mushafPages != null) return _mushafPages!;
    final grouped = <int, List<Verse>>{};
    for (final key in _pages.keys) {
      final parts = key.split(':');
      final sura = int.parse(parts[0]);
      final aya = int.parse(parts[1]);
      final v = verse(sura, aya);
      if (v == null) continue;
      grouped.putIfAbsent(_pages[key]!, () => []).add(v);
    }
    final sortedPages = grouped.keys.toList()..sort();
    _mushafPages = sortedPages.map((page) {
      final ayahs = grouped[page]!;
      final first = ayahs.first;
      return MushafPage(
        pageNumber: page,
        sura: first.sura,
        surahNameEn: first.surahNameEn,
        surahNameAr: first.surahNameAr,
        ayahs: ayahs,
      );
    }).toList();
    return _mushafPages!;
  }
}

class Chapter {
  final int id;
  final String nameEn;
  final String nameAr;
  final String translatedName;
  final int versesCount;
  final String revelationPlace;
  const Chapter({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.translatedName,
    required this.versesCount,
    required this.revelationPlace,
  });
}
