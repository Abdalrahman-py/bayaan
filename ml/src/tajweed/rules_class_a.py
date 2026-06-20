"""Class A — deterministic violation detection from text + ASR transcript.

The engine localizes every noon-sakinah / tanween rule occurrence. This module
judges whether the transcript honoured the expected realization:

    Idgham : the noon should merge (vanish) into the next letter
    Iqlab  : the noon should be realized as a meem (م) sound
    Ikhfaa : the noon should be hidden but nasalized (still ~present)

NOTE ON FIDELITY (honest limitation): a standard ASR transcript is largely
orthographic, so transcript-based detection is reliable for *explicit-noon*
cases (where merge/convert produces a visibly different base-letter sequence)
and weak for tanween cases (no base letter to compare). Tanween-driven rules
are therefore better confirmed acoustically. This is documented in the paper's
limitations and is why the system is hybrid.
"""
from __future__ import annotations

from dataclasses import asdict, dataclass
from difflib import SequenceMatcher

from . import phonology as P
from .engine import Expectation, TajweedEngine

_CLASS_A = {"Idgham", "Iqlab", "Ikhfaa"}

# Minimum letter-skeleton similarity between transcript and reference for the
# transcript to be trusted. Below this, the ASR likely failed catastrophically
# (e.g. garbage output) and Class A abstains rather than emit false positives.
# A localized mispronunciation keeps similarity well above this; tune on val.
MIN_TRANSCRIPT_RELIABILITY = 0.5


def transcript_reliability(verse_text: str, transcript: str) -> float:
    """Letter-skeleton similarity in [0, 1] between transcript and reference."""
    ref = P.arabic_letters_only(verse_text)
    obs = P.arabic_letters_only(transcript)
    if not ref:
        return 1.0
    return SequenceMatcher(None, ref, obs).ratio()


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


class RuleEngine:
    def __init__(self):
        self.engine = TajweedEngine()

    def analyze(
        self,
        verse_text: str,
        transcript: str,
        word_timings: list[dict] | None = None,
        verse_id: str = "",
        min_reliability: float = MIN_TRANSCRIPT_RELIABILITY,
    ) -> list[Violation]:
        # Sanity gate: an unreliable transcript (failed ASR) would produce
        # spurious "letter dropped/changed" violations — abstain instead.
        if transcript_reliability(verse_text, transcript) < min_reliability:
            return []
        expectations = [
            e for e in self.engine.expected(verse_text) if e.rule in _CLASS_A
        ]
        trans_words = transcript.split()
        spans = P.word_spans(verse_text)
        violations: list[Violation] = []

        for exp in expectations:
            wi = P.char_to_word_index(verse_text, exp.char_index)
            trans_word = trans_words[wi] if wi < len(trans_words) else ""
            word_start = spans[wi][0] if wi < len(spans) else 0
            off = P.base_letter_offset(verse_text, word_start, exp.char_index)
            detected = self._check(exp, trans_word, off)
            if detected is None:
                continue
            start_ms, end_ms = self._timing(word_timings, wi)
            violations.append(
                Violation(
                    rule=exp.rule, char=exp.char, char_index=exp.char_index,
                    verse=verse_id, expected=exp.detail, detected=detected,
                    start_ms=start_ms, end_ms=end_ms,
                )
            )
        return violations

    # ----- per-rule comparison --------------------------------------------- #
    def _check(self, exp: Expectation, trans_word: str, off: int) -> str | None:
        """Compare the OBSERVED realization at the noon's position against what
        the rule requires. Returns a 'detected' description if violated, else None.

        Contract: `trans_word` is the phonetic/observed rendering of the word.
        We inspect the single base letter at the noon's within-word offset `off`,
        so a meem elsewhere in the word (e.g. the م of مِنْ) never causes a false
        positive. Only explicit-noon cases are judged here; tanween defers to
        the acoustic path (see module docstring)."""
        if exp.char != P.NOON:
            return None

        t_base = P.strip_diacritics(trans_word)
        observed = t_base[off] if off < len(t_base) else None  # None -> letter dropped

        if exp.rule == "Idgham":
            # Correct merge means the noon is gone; a noon still at this spot = violation.
            if observed == P.NOON:
                return f"ن pronounced distinctly (expected merge into '{exp.following_char}')"
        elif exp.rule == "Iqlab":
            # Correct realization is a meem sound at the noon's position.
            if observed == P.NOON:
                return "ن pronounced (expected conversion to م sound)"
        elif exp.rule == "Ikhfaa":
            # Over-merge: noon dropped entirely where it should stay (hidden + nasal).
            if observed is None or observed != P.NOON:
                return "ن dropped (expected hidden nasalization, not full merge)"
        return None

    @staticmethod
    def _timing(word_timings: list[dict] | None, wi: int) -> tuple[int | None, int | None]:
        if not word_timings or wi >= len(word_timings):
            return None, None
        w = word_timings[wi]
        to_ms = lambda s: int(round(float(s) * 1000))
        start = to_ms(w["start"]) if "start" in w else None
        end = to_ms(w["end"]) if "end" in w else None
        return start, end
