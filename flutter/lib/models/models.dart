/// Ported 1:1 from android/.../ui/model/Models.kt
class Verse {
  final int sura;
  final int aya;
  final String surahNameEn;
  final String surahNameAr;
  final String uthmani;

  /// Real mushaf page number (Madani 604-page convention), e.g. 2:255 → 42.
  final int pageNumber;
  const Verse({
    required this.sura,
    required this.aya,
    required this.surahNameEn,
    required this.surahNameAr,
    required this.uthmani,
    this.pageNumber = 1,
  });

  Verse copyWith({String? uthmani}) => Verse(
    sura: sura,
    aya: aya,
    surahNameEn: surahNameEn,
    surahNameAr: surahNameAr,
    uthmani: uthmani ?? this.uthmani,
    pageNumber: pageNumber,
  );
}

class CharRange {
  final int start;
  final int end; // exclusive
  const CharRange(this.start, this.end);
}

class Mistake {
  final CharRange charRange; // [start, end) into Verse.uthmani
  final bool isTajweed;
  final String kind; // "replace" | "insert" | "delete"
  final String? ruleNameEn;
  final String? ruleNameAr;
  final int? expectedLen;
  final int? gotLen;
  const Mistake({
    required this.charRange,
    required this.isTajweed,
    required this.kind,
    this.ruleNameEn,
    this.ruleNameAr,
    this.expectedLen,
    this.gotLen,
  });
}

class SifatError {
  final String phonemesGroup;
  final String attribute;
  final String predicted;
  final String expected;
  final double? confidence;
  const SifatError({
    required this.phonemesGroup,
    required this.attribute,
    required this.predicted,
    required this.expected,
    this.confidence,
  });
}

sealed class RecitationUiState {
  final Verse verse;
  RecitationUiState(this.verse);

  factory RecitationUiState.ready(Verse v) = Ready;
  factory RecitationUiState.recording(Verse v, int elapsedSec) = Recording;
  factory RecitationUiState.uploading(Verse v) = Uploading;
  factory RecitationUiState.result(
    Verse v,
    List<Mistake> m,
    List<SifatError> s,
    bool allCorrect,
  ) = ResultState;
  factory RecitationUiState.error(Verse v, String msg) = ErrorState;
}

class Ready extends RecitationUiState {
  Ready(super.verse);
}

class Recording extends RecitationUiState {
  final int elapsedSec;
  Recording(super.verse, this.elapsedSec);
}

class Uploading extends RecitationUiState {
  Uploading(super.verse);
}

class ResultState extends RecitationUiState {
  final List<Mistake> mistakes;
  final List<SifatError> sifatErrors;
  final bool allCorrect;
  ResultState(super.verse, this.mistakes, this.sifatErrors, this.allCorrect);
}

class ErrorState extends RecitationUiState {
  final String message;
  ErrorState(super.verse, this.message);
}

/// One printed mushaf page (Madani 604-page convention): the ayahs that
/// appear on it and the surah its opening line belongs to.
class MushafPage {
  final int pageNumber;
  final int sura;
  final String surahNameEn;
  final String surahNameAr;
  final List<Verse> ayahs;

  const MushafPage({
    required this.pageNumber,
    required this.sura,
    required this.surahNameEn,
    required this.surahNameAr,
    required this.ayahs,
  });
}
