class SessionRecord {
  final int surahNumber;
  final String surahNameEnglish;
  final String surahNameArabic;
  final int ayahNumber;
  final int score;
  final String time;
  final String duration;
  final int mistakesCount;
  final List<String> tags;

  const SessionRecord({
    required this.surahNumber,
    required this.surahNameEnglish,
    required this.surahNameArabic,
    required this.ayahNumber,
    required this.score,
    required this.time,
    required this.duration,
    required this.mistakesCount,
    required this.tags,
  });
}

const List<SessionRecord> mockSessionRecords = [
  SessionRecord(
    surahNumber: 1,
    surahNameEnglish: 'Al-Fatihah',
    surahNameArabic: 'الفاتحة',
    ayahNumber: 1,
    score: 94,
    time: '10:24 AM',
    duration: '0:52',
    mistakesCount: 2,
    tags: ['Madd', 'Ghunnah'],
  ),
  SessionRecord(
    surahNumber: 1,
    surahNameEnglish: 'Al-Fatihah',
    surahNameArabic: 'الفاتحة',
    ayahNumber: 2,
    score: 88,
    time: '09:15 AM',
    duration: '1:12',
    mistakesCount: 3,
    tags: ['Qalqalah', 'Madd'],
  ),
  SessionRecord(
    surahNumber: 112,
    surahNameEnglish: 'Al-Ikhlas',
    surahNameArabic: 'الإخلاص',
    ayahNumber: 1,
    score: 98,
    time: 'Yesterday',
    duration: '0:35',
    mistakesCount: 0,
    tags: ['Perfect'],
  ),
];
