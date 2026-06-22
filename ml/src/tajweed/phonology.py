"""Arabic letter/diacritic primitives still in use after the 2026-06-21
phoneme-recognizer rebuild.

Most of this module's old content (rule-trigger constants, strip_diacritics,
arabic_letters_only, word_spans, base_letter_offset) was the old word-
transcript engine's machinery, deleted along with `engine.py`/
`rules_class_a.py` -- the Phonemizer's own structured rule tags (see
`phoneme_reference.py`) replace all of it.

What survives and why:
- `char_to_word_index` -- still used by `hybrid.py._class_b()`.
- `is_arabic_letter`, `Letter`, `parse_letters`, and the `NOON`/`MEEM`/`BAA`/
  `DAGGER_ALIF` constants -- still imported directly by `quranmb_mapping.py`
  (left untouched by the rebuild; it does its own char-to-phoneme alignment
  for the IQRA-comparable scoring and needs these primitives independently
  of the Class A/B rule logic).
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

HAMZA_FORMS = {"ء", "أ", "إ", "ؤ", "ئ", "ا"}


def is_arabic_letter(ch: str) -> bool:
    """True for a base Arabic consonant/vowel letter (not a diacritic)."""
    return "ء" <= ch <= "ي" or ch == DAGGER_ALIF or ch in HAMZA_FORMS


@dataclass
class Letter:
    """A base letter with its index in the original string and its harakat."""
    char: str
    index: int          # index into the ORIGINAL (diacritized) string
    marks: set[str]


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
