class Ayah {
  final int number;
  final String arabicText;
  final String? translation; // null while translation fetch is pending/failed
  final String? transliteration; // Latin-script pronunciation guide

  const Ayah({
    required this.number,
    required this.arabicText,
    this.translation,
    this.transliteration,
  });
}
