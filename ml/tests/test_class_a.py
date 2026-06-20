"""Tests for Class A deterministic violation detection + hybrid FGR.

Correct transcripts must yield zero violations (no false positives);
mispronounced transcripts must be flagged with a grounded char_index.
"""
from src.hybrid import HybridDetector
from src.tajweed.rules_class_a import RuleEngine, transcript_reliability

re = RuleEngine()


def test_idgham_correct_no_violation():
    # "مِنْ مَالٍ" recited correctly -> noon merges -> transcript "مِمّالٍ" (no distinct ن)
    v = re.analyze("مِنْ مَالٍ", "مِمَّالٍ")
    assert v == []


def test_idgham_violation_distinct_noon():
    # Student keeps a distinct ن -> Idgham violation, grounded on the noon.
    v = re.analyze("مِنْ مَالٍ", "مِنْ مَالٍ", verse_id="x")
    idgham = [x for x in v if x.rule == "Idgham"]
    assert idgham, "expected an Idgham violation"
    assert idgham[0].char == "ن" and idgham[0].char_index >= 0


def test_iqlab_violation_keeps_noon():
    # "مِنْ بَعْدِ": correct = meem sound; transcript keeps ن and no م -> violation.
    v = re.analyze("مِنْ بَعْدِ", "مِنْ بَعْدِ")
    assert any(x.rule == "Iqlab" for x in v)


def test_timing_attached():
    timings = [{"word": "مِنْ", "start": 0.84, "end": 1.10}, {"word": "مَالٍ", "start": 1.10, "end": 1.6}]
    v = re.analyze("مِنْ مَالٍ", "مِنْ مَالٍ", word_timings=timings)
    assert v[0].start_ms == 840 and v[0].end_ms == 1100


def test_violation_dict_has_class_key():
    v = re.analyze("مِنْ مَالٍ", "مِنْ مَالٍ")
    d = v[0].to_dict()
    assert d["class"] == "A" and "char_index" in d and d["expected"]


def test_hybrid_fgr_is_one_for_grounded_violations():
    det = HybridDetector(inference=None)  # Class A only
    res = det.analyze("مِنْ مَالٍ", "مِنْ مَالٍ", verse_id="1:1")
    assert res.violations and res.fgr == 1.0


def test_hybrid_no_violation_fgr_defined():
    det = HybridDetector(inference=None)
    res = det.analyze("مِنْ مَالٍ", "مِمَّالٍ")
    assert res.violations == [] and res.fgr == 1.0


# --- transcript sanity guard ------------------------------------------------ #
def test_garbage_transcript_abstains():
    # ASR failure (digits) -> reliability ~0 -> no false-positive violations,
    # even though the engine localizes an Ikhfaa on the noon of مَنْ ذَا.
    assert transcript_reliability("مَنْ ذَا", "9 2 3 4 4 4 4") < 0.5
    assert re.analyze("مَنْ ذَا", "9 2 3 4 4 4 4") == []


def test_empty_transcript_abstains():
    assert re.analyze("مَنْ ذَا", "") == []


def test_reliable_transcript_still_detects():
    # A clean transcript (high reliability) still produces the real violation.
    assert transcript_reliability("مِنْ مَالٍ", "مِنْ مَالٍ") >= 0.5
    assert any(v.rule == "Idgham" for v in re.analyze("مِنْ مَالٍ", "مِنْ مَالٍ"))


def test_hybrid_abstains_on_garbage():
    det = HybridDetector(inference=None)
    assert det.analyze("مَنْ ذَا", "0 0 0 0 0 0").violations == []
