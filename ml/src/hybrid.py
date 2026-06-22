"""Hybrid Decision Layer — merges Class A + Class B into one report and
computes Feedback Grounding Rate (FGR).

    Phonemizer reference  ->  Class A diffs the recognizer's phoneme output
                           +  Class B classifiers judge audio quality
                           ->  unified, character-mapped violation report.

Every violation carries char + char_index (Phonemizer-derived for Class A,
same as before for Class B), so FGR is high by construction — this is the
paper's core contribution, unchanged by the Class A rebuild below.

BREAKING CHANGE (2026-06-21): Class A now requires `waveform` (it runs the
phoneme recognizer over audio, replacing the old Whisper-word-transcript
diff). A `waveform=None` call now yields zero violations from BOTH classes,
not just Class B -- there is no text-only Class A path anymore. Class B
still needs `word_timings` (from Whisper) for audio-slicing; Class A no
longer takes a `transcript` argument at all.
"""
from __future__ import annotations

from dataclasses import dataclass, field

from .tajweed.phoneme_diff import Violation, diff
from .tajweed.phoneme_reference import ghunnah_madd_expectations, reference_for
from .tajweed.phonology import char_to_word_index


@dataclass
class AnalysisResult:
    verse_id: str
    violations: list[dict] = field(default_factory=list)

    @property
    def fgr(self) -> float:
        """Fraction of violations grounded with both char_index and an expected
        description. Engine-derived violations are grounded by construction."""
        if not self.violations:
            return 1.0
        grounded = sum(
            1 for v in self.violations
            if v.get("char_index") is not None and v.get("expected")
        )
        return grounded / len(self.violations)


class HybridDetector:
    def __init__(self, recognizer=None, inference=None, thresholds: dict[str, float] | None = None):
        """`recognizer` is a PhonemeRecognizer (Class A); `inference` is a
        TajweedInference (Class B). Either may be None -> that class is skipped."""
        self.recognizer = recognizer
        self.inference = inference
        self.thresholds = thresholds or {}

    def analyze(
        self,
        verse_text: str,
        verse_ref: str,
        word_timings: list[dict] | None = None,
        waveform=None,
        sample_rate: int = 16_000,
        verse_id: str = "",
    ) -> AnalysisResult:
        violations: list[dict] = []

        if waveform is not None:
            if self.recognizer is not None:
                violations.extend(self._class_a(verse_text, verse_ref, waveform, verse_id))
            if self.inference is not None:
                violations.extend(
                    self._class_b(verse_text, verse_ref, word_timings, waveform, sample_rate, verse_id)
                )

        return AnalysisResult(verse_id=verse_id, violations=violations)

    def _class_a(self, verse_text, verse_ref, waveform, verse_id) -> list[dict]:
        from .phoneme_inference import predict_phonemes

        observed = predict_phonemes(self.recognizer, waveform)
        reference = reference_for(verse_ref, verse_text)
        return [v.to_dict() for v in diff(reference, observed, verse_id=verse_id)]

    def _class_b(self, verse_text, verse_ref, word_timings, waveform, sample_rate, verse_id) -> list[dict]:
        from .asr.whisper_align import clip_for_position

        out: list[dict] = []
        for exp in ghunnah_madd_expectations(verse_ref, verse_text):
            rule_key = exp.rule.lower()
            if rule_key not in getattr(self.inference, "sessions", {}):
                continue
            wi = char_to_word_index(verse_text, exp.char_index)
            start_ms, end_ms = self._timing(word_timings, wi)
            seg = clip_for_position(waveform, start_ms, end_ms, sample_rate)
            p_correct = self.inference.predict_array(rule_key, seg)
            thr = self.thresholds.get(rule_key, 0.5)
            if p_correct < thr:
                out.append(
                    Violation(
                        rule=exp.rule, char=exp.char, char_index=exp.char_index,
                        verse=verse_id, expected=exp.detail,
                        detected=f"P(correct)={p_correct:.2f}",
                        start_ms=start_ms, end_ms=end_ms, rule_class="B",
                    ).to_dict()
                )
        return out

    @staticmethod
    def _timing(word_timings: list[dict] | None, wi: int) -> tuple[int | None, int | None]:
        if not word_timings or wi >= len(word_timings):
            return None, None
        w = word_timings[wi]
        to_ms = lambda s: int(round(float(s) * 1000))
        start = to_ms(w["start"]) if "start" in w else None
        end = to_ms(w["end"]) if "end" in w else None
        return start, end


def corpus_fgr(results: list[AnalysisResult]) -> float:
    """FGR aggregated over many analyses (violation-weighted)."""
    total = sum(len(r.violations) for r in results)
    if total == 0:
        return 1.0
    grounded = sum(
        1 for r in results for v in r.violations
        if v.get("char_index") is not None and v.get("expected")
    )
    return grounded / total
