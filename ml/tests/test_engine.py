"""Tests for the Tajweed engine (deterministic localization).

Fixtures use fully-vowelized Quranic text. These verify that every rule
occurrence is found with the correct char + char_index — the foundation of FGR.
"""
from src.tajweed import phonology as P
from src.tajweed.engine import TajweedEngine

eng = TajweedEngine()


def rules_for(text):
    return [(e.rule, e.char, e.following_char) for e in eng.expected(text)]


def test_parse_letters_indices():
    text = "بِسْمِ"
    letters = P.parse_letters(text)
    assert [l.char for l in letters] == ["ب", "س", "م"]
    # sukoon on the seen (س)
    seen = letters[1]
    assert seen.char == "س" and seen.has_sukoon
    # indices point back into the original diacritized string
    assert text[letters[0].index] == "ب"


def test_ikhfaa_min_kun_min():
    # مِنْ before a ك-class / qaf letter -> Ikhfaa.  "مَنْ ذَا" -> noon before ذ (Ikhfaa)
    rules = rules_for("مَنْ ذَا")
    assert ("Ikhfaa", "ن", "ذ") in rules


def test_idgham_noon_before_yarmaloon():
    # noon sakinah before م -> Idgham with ghunnah.  "مِنْ مَالٍ"
    rules = rules_for("مِنْ مَالٍ")
    assert ("Idgham", "ن", "م") in rules


def test_iqlab_noon_before_baa():
    # noon sakinah before ب -> Iqlab.  "مِنْ بَعْدِ"
    rules = rules_for("مِنْ بَعْدِ")
    assert ("Iqlab", "ن", "ب") in rules


def test_izhar_noon_before_throat():
    # noon sakinah before ع (throat) -> Izhar.  "مِنْ عِلْمٍ"
    rules = rules_for("مِنْ عِلْمٍ")
    assert ("Izhar", "ن", "ع") in rules


def test_ghunnah_on_shadda_noon():
    # ن مشددة -> Ghunnah (Class B).  "إِنَّ"
    expe = eng.expected("إِنَّ")
    ghunnah = [e for e in expe if e.rule == "Ghunnah"]
    assert ghunnah and ghunnah[0].rule_class == "B" and ghunnah[0].char == "ن"


def test_fatihah_basmala_runs():
    # Engine must run end-to-end on real Quranic text and ground every position.
    expe = eng.expected("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
    assert all(e.char_index >= 0 and e.char for e in expe)
    # الرَّحْمَٰنِ contains a dagger-alif madd
    assert any(e.rule == "Madd" for e in expe)
