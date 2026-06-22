"""Phoneme reference + Class B localization, wrapping `quranic_phonemizer`.

Replaces `tajweed/engine.py`'s role as Class A's *deterministic* reference:
the Phonemizer's own `LetterMapping.tajweed_rules` already tags every rule
occurrence (a strict superset of the old hand-built engine), so there is
nothing left to re-derive there. What's new here is the adapter resolving
the Phonemizer's own `(word_index, letter_index)` addressing back into an
index into Bayaan's flat `verse_text` string, since the rest of the system
(FGR, hybrid.py) is grounded in that space.
"""
from __future__ import annotations

from dataclasses import dataclass

from quranic_phonemizer import Phonemizer

# Rule tags (TajweedRule.value strings) that localize Ghunnah. Class B still
# judges *quality* (duration, nasalization) acoustically; this only answers
# "where does the rule occur in the text." Madd is NOT tagged this way --
# verified directly against the package: madd occurrences live in each
# WordMapping's own `madd_mappings` list (a separate structure, word-relative
# `letter_index`), not in `LetterMapping.tajweed_rules` like every other rule.
# `madd_type` on a MaddMapping is frequently None even for real madd
# occurrences (e.g. lafdh-jalalah) -- presence of the entry is what counts,
# not the subtype classification.
GHUNNAH_TAGS = {"noon_ghunnah", "meem_ghunnah"}


@dataclass
class Expectation:
    """Class B localization shape (the subset of the old engine.py's
    Expectation that hybrid.py._class_b() actually reads)."""
    rule: str           # "Ghunnah" | "Madd"
    rule_class: str     # always "B" here
    char: str
    char_index: int
    detail: str


@dataclass
class PhonemeReference:
    verse_ref: str                              # "98:4" (surah:ayah)
    verse_text: str                             # Bayaan's own diacritized verse text
    phoneme_sequence: list[str]                  # flat reference phoneme sequence
    rule_tags_by_phoneme_index: dict[int, list[str]]   # phoneme_index -> [TajweedRule.value, ...]
    char_index_by_phoneme_index: dict[int, int]        # phoneme_index -> index into verse_text


def _word_spans(text: str) -> list[tuple[int, int]]:
    """(start, end) char-index span for each whitespace-delimited word."""
    spans: list[tuple[int, int]] = []
    start: int | None = None
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


def _is_arabic_letter(ch: str) -> bool:
    return "ء" <= ch <= "ي" or ch == "ٰ"  # dagger alif


def char_index_for(verse_text: str, word_index: int, letter_index: int) -> int | None:
    """Resolve the Phonemizer's (word_index, letter_index) -- both 0-based,
    letter_index counts Arabic base letters within the word -- into an
    absolute index into `verse_text`. None if out of range."""
    spans = _word_spans(verse_text)
    if word_index >= len(spans):
        return None
    start, end = spans[word_index]
    positions = [i for i in range(start, end) if _is_arabic_letter(verse_text[i])]
    if letter_index >= len(positions):
        return None
    return positions[letter_index]


def reference_for(verse_ref: str, verse_text: str) -> PhonemeReference:
    """verse_ref like "1:1" or "98:4" (surah:ayah, the Phonemizer's own format)."""
    mapping = Phonemizer().phonemize(verse_ref).get_mapping()

    tags_by_letter: dict[tuple[int, int], list[str]] = {}
    for word_idx, word in enumerate(mapping.words):
        for letter in word.letter_mappings:
            if letter.tajweed_rules:
                tags_by_letter[(word_idx, letter.index)] = [
                    t.rule.value for t in letter.tajweed_rules
                ]

    rule_tags: dict[int, list[str]] = {}
    char_index: dict[int, int] = {}
    for entry in mapping.alignment:
        key = (entry.word_index, entry.letter_index)
        if key in tags_by_letter:
            rule_tags[entry.phoneme_index] = tags_by_letter[key]
        ci = char_index_for(verse_text, entry.word_index, entry.letter_index)
        if ci is not None:
            char_index[entry.phoneme_index] = ci

    return PhonemeReference(
        verse_ref=verse_ref,
        verse_text=verse_text,
        phoneme_sequence=mapping.phoneme_sequence,
        rule_tags_by_phoneme_index=rule_tags,
        char_index_by_phoneme_index=char_index,
    )


def ghunnah_madd_expectations(verse_ref: str, verse_text: str) -> list[Expectation]:
    """Class B localization: where Ghunnah/Madd occur in this verse, per the
    Phonemizer's own structural info. Replaces engine.py's role for
    hybrid.py._class_b()."""
    mapping = Phonemizer().phonemize(verse_ref).get_mapping()
    out: list[Expectation] = []
    for word_idx, word in enumerate(mapping.words):
        for letter in word.letter_mappings:
            tags = {t.rule.value for t in letter.tajweed_rules}
            if not (tags & GHUNNAH_TAGS):
                continue
            ci = char_index_for(verse_text, word_idx, letter.index)
            if ci is not None:
                out.append(Expectation("Ghunnah", "B", letter.char, ci,
                                        "2-beat nasalization (ghunnah)"))
        for madd in word.madd_mappings:
            ci = char_index_for(verse_text, word_idx, madd.letter_index)
            if ci is None:
                continue
            letter = (
                word.letter_mappings[madd.letter_index]
                if madd.letter_index < len(word.letter_mappings) else None
            )
            out.append(Expectation("Madd", "B", letter.char if letter else "", ci,
                                    "vowel prolongation (madd)"))
    return out
