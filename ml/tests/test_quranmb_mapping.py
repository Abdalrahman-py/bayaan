"""Tests for the QuranMB phoneme-deviation bridge.

Ground-truth extraction and scoring are deterministic and tested exactly.
The char->phoneme mapping is a heuristic first pass; we test that a noon-rule
violation lands on the corresponding 'n' phoneme.
"""
import numpy as np

from src.quranmb_mapping import (
    ground_truth_deviations,
    map_to_deviations,
    mdd_prf,
)
from src.tajweed import phonology as P


def test_gt_equal_length_substitution():
    dev = ground_truth_deviations("m i n m aa l", "m i n b aa l")
    assert list(dev) == [0, 0, 0, 1, 0, 0]


def test_gt_all_correct():
    dev = ground_truth_deviations("f ii h i nn a", "f ii h i nn a")
    assert dev.sum() == 0


def test_gt_unequal_length_deletion():
    # "a b c" vs "a c": the 'b' (ref index 1) is deleted -> deviation there
    dev = ground_truth_deviations("a b c", "a c")
    assert dev[1] == 1 and len(dev) == 3


def test_mdd_prf_counts():
    m = mdd_prf(np.array([1, 0, 1, 0]), np.array([1, 1, 0, 0]))
    assert (m["tp"], m["fp"], m["fn"]) == (1, 1, 1)
    assert abs(m["precision"] - 0.5) < 1e-9 and abs(m["recall"] - 0.5) < 1e-9
    assert abs(m["f1"] - 0.5) < 1e-9


def test_map_violation_snaps_to_noon_phoneme():
    verse = "مِنْ مَالٍ"
    phoneme_ref = "m i n m aa l"               # the noon -> 'n' at index 2
    noon = next(l for l in P.parse_letters(verse) if l.char == P.NOON)
    violations = [{"char_index": noon.index, "char": "ن", "rule": "Idgham"}]
    pred = map_to_deviations(verse, violations, phoneme_ref)
    assert pred[2] == 1
    assert pred.sum() == 1                      # only the noon position flagged


def test_map_empty_violations_predicts_nothing():
    pred = map_to_deviations("مِنْ مَالٍ", [], "m i n m aa l")
    assert pred.sum() == 0


def test_end_to_end_prf_on_synthetic():
    # ground truth says the noon position is wrong; our violation flags it -> TP
    verse = "مِنْ مَالٍ"
    ref, aug = "m i n m aa l", "m i nn m aa l"  # noon mispronounced
    noon = next(l for l in P.parse_letters(verse) if l.char == P.NOON)
    pred = map_to_deviations(verse, [{"char_index": noon.index}], ref)
    gt = ground_truth_deviations(ref, aug)
    m = mdd_prf(pred, gt)
    assert m["tp"] == 1 and m["f1"] == 1.0
