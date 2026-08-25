import '../../../services/quran_text.dart';

class Surah {
  final int number;
  final String nameEnglish;
  final String nameArabic;
  final String meaning;
  final String revelationType; // Meccan / Medinan
  final int ayahCount;
  final int estimatedMinutes;

  const Surah({
    required this.number,
    required this.nameEnglish,
    required this.nameArabic,
    required this.meaning,
    required this.revelationType,
    required this.ayahCount,
    required this.estimatedMinutes,
  });

  factory Surah.fromChapter(Chapter c) => Surah(
    number: c.id,
    nameEnglish: c.nameEn,
    nameArabic: c.nameAr,
    meaning: c.translatedName,
    revelationType: c.revelationPlace == 'makkah' ? 'Meccan' : 'Medinan',
    ayahCount: c.versesCount,
    // Rough reading-pace estimate (~0.6 min/ayah) — not a tracked stat.
    estimatedMinutes: (c.versesCount * 0.6).ceil(),
  );
}
