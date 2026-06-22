"""Tests for the phoneme-diff Class A path (replaces test_class_a.py).

Uses synthetic PhonemeReference fixtures with known injected errors at known
rule positions -- fast, deterministic, no audio/network needed, matching the
existing test suite's convention (test_engine.py, test_class_a.py).
"""
from src.tajweed.phoneme_diff import diff, phoneme_reliability
from src.tajweed.phoneme_reference import PhonemeReference


def make_ref(verse_text: str, phonemes: list[str], rule_tags: dict[int, list[str]]) -> PhonemeReference:
    # one phoneme per char for these small fixtures -> trivial char_index map
    char_index = {i: i for i in range(len(phonemes))}
    return PhonemeReference(
        verse_ref="test:1",
        verse_text=verse_text,
        phoneme_sequence=phonemes,
        rule_tags_by_phoneme_index=rule_tags,
        char_index_by_phoneme_index=char_index,
    )


def test_correct_recitation_no_violations():
    ref = make_ref("xyz", ["n", "a", "b"], {0: ["iqlab_noon"]})
    assert diff(ref, ["n", "a", "b"]) == []


def test_iqlab_mismatch_flagged_major():
    # observed drops the meem-sound substitution -- noon stays distinct at
    # the iqlab position -- a mismatch at a rule-tagged index.
    ref = make_ref("xyz", ["n", "a", "b"], {0: ["iqlab_noon"]})
    v = diff(ref, ["m", "a", "b"])
    assert len(v) == 1
    assert v[0].rule == "Iqlab" and v[0].char_index == 0 and v[0].severity == "major"


def test_tafkheem_mismatch_not_flagged_out_of_scope():
    # tafkheem is explicitly out of MVP scope (not one of the four declared
    # rule families) -- a mismatch there must not be a violation.
    ref = make_ref("xyz", ["r", "a", "b"], {0: ["tafkheem"]})
    assert diff(ref, ["l", "a", "b"]) == []


def test_mismatch_at_untagged_position_not_a_violation():
    # A real ASR/transcription discrepancy at a position with no Tajweed rule
    # tag is out of Bayaan's declared scope -- not a Tajweed violation.
    ref = make_ref("xyz", ["n", "a", "b"], {})
    assert diff(ref, ["m", "a", "b"]) == []


def test_dropped_phoneme_at_rule_position_flagged():
    ref = make_ref("xyz", ["n", "a", "b"], {0: ["ikhfaa_noon"]})
    v = diff(ref, ["a", "b"])
    assert len(v) == 1 and v[0].rule == "Ikhfaa"


def test_violation_dict_has_class_key():
    ref = make_ref("xyz", ["n", "a", "b"], {0: ["iqlab_noon"]})
    d = diff(ref, ["m", "a", "b"])[0].to_dict()
    assert d["class"] == "A" and d["char_index"] == 0 and d["expected"]


def test_garbage_observed_abstains():
    ref = make_ref("nab nab nab", ["n", "a", "b", "n", "a", "b", "n", "a", "b"],
                    {0: ["iqlab_noon"]})
    garbage = ["x", "y", "z", "q", "w"]
    assert phoneme_reliability(ref.phoneme_sequence, garbage) < 0.5
    assert diff(ref, garbage) == []


def test_empty_observed_abstains():
    ref = make_ref("xyz", ["n", "a", "b"], {0: ["iqlab_noon"]})
    assert diff(ref, []) == []


def test_non_tajweed_phonological_tag_not_flagged():
    # The Phonemizer tags default Arabic phonology too (hamza al-wasl, lam
    # shamsiyah). Those aren't Tajweed mistakes -- they belong to the separate
    # Arabic-learning track -- so a mismatch there must not be a violation.
    ref = make_ref("xyz", ["n", "a", "b"], {0: ["lam_shamsiyah"]})
    assert diff(ref, ["m", "a", "b"]) == []
