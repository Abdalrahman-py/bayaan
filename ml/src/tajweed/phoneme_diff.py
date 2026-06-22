"""Class A — deterministic violation detection from the phoneme recognizer's
output vs. the Phonemizer's reference sequence. Replaces `rules_class_a.py`'s
RuleEngine (word-transcript diff) with a phoneme-sequence diff.

Only mismatches at phoneme positions the Phonemizer tagged with a Tajweed
rule are violations -- a generic ASR/phoneme error elsewhere (no rule tag)
is out of Bayaan's declared scope, not a Tajweed violation.
"""
from __future__ import annotations

from dataclasses import asdict, dataclass
from difflib import SequenceMatcher

from .. import config as C
from .phoneme_reference import PhonemeReference

# Minimum phoneme-sequence similarity between observed and reference for the
# recognizer output to be trusted. Below this, the recognizer likely failed
# catastrophically -- abstain rather than emit false positives (mirrors the
# old transcript_reliability()'s 0.5 threshold).
MIN_PHONEME_RELIABILITY = 0.5

_SEVERITY_RANK = {"major": 2, "minor": 1}

# TajweedRule.value -> the Class A rule name used elsewhere in the system
# (engine.py's old naming convention). Only the MVP's four declared rule
# families; anything else still gets a Violation (DEFAULT_RULE_SEVERITY
# handles severity), just with a less specific rule label.
_RULE_NAME_BY_TAG = {
    "iqlab_noon": "Iqlab", "iqlab_tanween": "Iqlab",
    "idgham_ghunnah_noon": "Idgham", "idgham_ghunnah_tanween": "Idgham",
    "ikhfaa_noon": "Ikhfaa", "ikhfaa_tanween": "Ikhfaa", "ikhfaa_shafawi": "Ikhfaa",
    "qalqala_sughra": "Qalqala", "qalqala_kubra": "Qalqala",
}


@dataclass
class Violation:
    rule: str
    char: str
    char_index: int
    verse: str
    expected: str
    detected: str
    start_ms: int | None = None
    end_ms: int | None = None
    severity: str = "major"
    rule_class: str = "A"

    def to_dict(self) -> dict:
        d = asdict(self)
        d["class"] = d.pop("rule_class")
        return d


def phoneme_reliability(reference: list[str], observed: list[str]) -> float:
    """Sequence similarity in [0, 1] between observed and reference phonemes."""
    if not reference:
        return 1.0
    return SequenceMatcher(a=reference, b=observed, autojunk=False).ratio()


def _severity_for(tags: list[str]) -> str:
    return max(
        (C.SEVERITY_BY_RULE_TAG.get(t, C.DEFAULT_RULE_SEVERITY) for t in tags),
        key=lambda s: _SEVERITY_RANK.get(s, 0),
        default=C.DEFAULT_RULE_SEVERITY,
    )


def _rule_name_for(tags: list[str]) -> str:
    for t in tags:
        if t in _RULE_NAME_BY_TAG:
            return _RULE_NAME_BY_TAG[t]
    return tags[0]


def diff(
    reference: PhonemeReference,
    observed: list[str],
    verse_id: str = "",
    min_reliability: float = MIN_PHONEME_RELIABILITY,
) -> list[Violation]:
    """Diff the recognizer's `observed` phoneme sequence against `reference`.

    Abstains (returns []) when `observed` looks unreliable overall -- a bad
    recognizer run should produce silence, not false accusations.
    """
    if phoneme_reliability(reference.phoneme_sequence, observed) < min_reliability:
        return []

    violations: list[Violation] = []
    matcher = SequenceMatcher(a=reference.phoneme_sequence, b=observed, autojunk=False)
    for tag, i1, i2, j1, _j2 in matcher.get_opcodes():
        if tag == "equal":
            continue
        ref_indices = range(i1, i2) if i1 < i2 else [i1]  # insertion -> flag the adjacent ref slot
        for ri in ref_indices:
            all_tags = reference.rule_tags_by_phoneme_index.get(ri)
            if not all_tags:
                continue  # not a rule-tagged position at all
            tags = [t for t in all_tags if t in C.CLASS_A_RULE_TAGS]
            if not tags:
                continue  # tagged, but not one of the four declared Tajweed rule
                # families (e.g. hamza al-wasl, lam shamsiyah) -- normal Arabic
                # phonology, not a Tajweed mistake; out of Class A's declared scope
            ci = reference.char_index_by_phoneme_index.get(ri)
            if ci is None:
                continue
            observed_phoneme = observed[j1] if j1 < len(observed) else None
            violations.append(Violation(
                rule=_rule_name_for(tags),
                char=reference.verse_text[ci] if ci < len(reference.verse_text) else "",
                char_index=ci,
                verse=verse_id,
                expected=f"expected phoneme '{reference.phoneme_sequence[ri]}'",
                detected=f"got '{observed_phoneme}'" if observed_phoneme else "dropped",
                severity=_severity_for(tags),
            ))
    return violations
