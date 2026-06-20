"""Arabic phonology primitives for the Tajweed engine.

Unicode-aware constants and helpers for noon-sakinah / tanween rules,
ghunnah (shadda on ن/م), and madd letters. Kept deliberately small and
testable — this is the deterministic foundation the whole system relies on.
"""
from __future__ import annotations

from dataclasses import dataclass

# --------------------------------------------------------------------------- #
# Diacritics (harakat) — code points
# --------------------------------------------------------------------------- #
FATHA = "َ"
DAMMA = "ُ"
KASRA = "ِ"
SUKOON = "ْ"
SHADDA = "ّ"
FATHATAN = "ً"   # ً  tanween fath
DAMMATAN = "ٌ"   # ٌ  tanween damm
KASRATAN = "ٍ"   # ٍ  tanween kasr
DAGGER_ALIF = "ٰ"  # ٰ  superscript alif (madd)
MADDAH = "ٓ"     # ٓ  maddah sign
TATWEEL = "ـ"    # ـ  kashida

TANWEEN = {FATHATAN, DAMMATAN, KASRATAN}
HARAKAT = {FATHA, DAMMA, KASRA, SUKOON, SHADDA, *TANWEEN, DAGGER_ALIF, MADDAH}

# --------------------------------------------------------------------------- #
# Letters
# --------------------------------------------------------------------------- #
NOON = "ن"   # ن
MEEM = "م"   # م
BAA = "ب"    # ب

# Hamza family (all behave as throat / Izhar trigger via hamza)
HAMZA_FORMS = {"ء", "أ", "إ", "ؤ", "ئ", "ا"}

# noon-sakinah / tanween rule groups (by the FOLLOWING letter)
THROAT_IZHAR = {"ء", "ه", "ع", "ح", "غ", "خ"}  # ء ه ع ح غ خ
YARMALOON_IDGHAM = {"ي", "ر", "م", "ل", "و", NOON}  # ي ر م ل و ن
IDGHAM_WITH_GHUNNAH = {"ي", NOON, MEEM, "و"}                       # ينمو
IDGHAM_NO_GHUNNAH = {"ل", "ر"}                                     # ل ر
IQLAB_TRIGGER = {BAA}                                                        # ب  (-> meem sound)
IKHFAA_15 = {
    "ت", "ث", "ج", "د", "ذ", "ز", "س",
    "ش", "ص", "ض", "ط", "ظ", "ف", "ق", "ك",
}  # ت ث ج د ذ ز س ش ص ض ط ظ ف ق ك  (15 letters)

# madd letters (long vowels)
MADD_LETTERS = {"ا", "و", "ي", DAGGER_ALIF}  # ا و ي ٰ


def is_arabic_letter(ch: str) -> bool:
    """True for a base Arabic consonant/vowel letter (not a diacritic)."""
    return "ء" <= ch <= "ي" or ch == DAGGER_ALIF or ch in HAMZA_FORMS


def strip_diacritics(text: str) -> str:
    return "".join(c for c in text if c not in HARAKAT and c != TATWEEL)


def arabic_letters_only(text: str) -> str:
    """Base-letter skeleton: only Arabic letters (no diacritics, digits, latin)."""
    return "".join(c for c in text if is_arabic_letter(c))


@dataclass
class Letter:
    """A base letter with its index in the original string and its harakat."""
    char: str
    index: int          # index into the ORIGINAL (diacritized) string
    marks: set[str]

    @property
    def has_sukoon(self) -> bool:
        return SUKOON in self.marks

    @property
    def has_shadda(self) -> bool:
        return SHADDA in self.marks

    @property
    def tanween(self) -> str | None:
        for t in self.marks:
            if t in TANWEEN:
                return t
        return None

    @property
    def is_bare(self) -> bool:
        """No vowel and no shadda (implicit sukoon in some orthographies)."""
        return not (self.marks & {FATHA, DAMMA, KASRA, SHADDA, *TANWEEN})


def parse_letters(text: str) -> list[Letter]:
    """Tokenize diacritized Arabic text into Letters, preserving original indices.

    Each base letter absorbs the diacritics that immediately follow it.
    """
    letters: list[Letter] = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if is_arabic_letter(ch):
            marks: set[str] = set()
            j = i + 1
            while j < n and (text[j] in HARAKAT):
                marks.add(text[j])
                j += 1
            letters.append(Letter(char=ch, index=i, marks=marks))
            i = j
        else:
            i += 1
    return letters


def char_to_word_index(text: str, char_index: int) -> int:
    """Word number (0-based) that the character at char_index belongs to."""
    return len(text[:char_index].split()) - 1 if text[:char_index].strip() else 0


def word_spans(text: str) -> list[tuple[int, int]]:
    """(start, end) index spans for each whitespace-delimited word."""
    spans, start = [], None
    for i, ch in enumerate(text):
        if ch.isspace():
            if start is not None:
                spans.append((start, i))
                start = None
        elif start is None:
            start = i
    if start is not None:
        spans.append((start, len(text)))
    return spans


def base_letter_offset(text: str, word_start: int, char_index: int) -> int:
    """Number of base letters from word_start up to (not including) char_index."""
    return sum(1 for c in text[word_start:char_index] if is_arabic_letter(c))
