class Ayah {
  final int number;
  final String arabicText;
  final String? translation; // null while translation fetch is pending/failed
  final String? transliteration; // Latin-script pronunciation guide

  /// Real mushaf page number (Madani 604-page convention); 1 when unknown.
  final int pageNumber;

  const Ayah({
    required this.number,
    required this.arabicText,
    this.translation,
    this.transliteration,
    this.pageNumber = 1,
  });
}
