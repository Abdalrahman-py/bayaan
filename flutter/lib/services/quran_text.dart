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
  }

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
