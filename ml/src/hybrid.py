"""Hybrid Decision Layer — merges Class A + Class B into one report and
computes Feedback Grounding Rate (FGR).

    Engine localizes  ->  Class A rules judge text  +  Class B classifiers judge audio
                       ->  unified, character-mapped violation report.

Every violation carries char + char_index (engine-derived), so FGR is high by
construction — this is the paper's core contribution.
"""
from __future__ import annotations

from dataclasses import dataclass, field

from .tajweed import phonology as P
from .tajweed.engine import TajweedEngine
from .tajweed.rules_class_a import MIN_TRANSCRIPT_RELIABILITY, RuleEngine, Violation


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
    def __init__(self, inference=None, thresholds: dict[str, float] | None = None,
                 class_a_min_reliability: float = MIN_TRANSCRIPT_RELIABILITY):
        """`inference` is a TajweedInference (Class B); None -> Class A only."""
        self.rule_engine = RuleEngine()
        self.engine = TajweedEngine()
        self.inference = inference
        self.thresholds = thresholds or {}
        self.class_a_min_reliability = class_a_min_reliability

    def analyze(
        self,
        verse_text: str,
        transcript: str,
        word_timings: list[dict] | None = None,
        waveform=None,
        sample_rate: int = 16_000,
        verse_id: str = "",
    ) -> AnalysisResult:
        violations: list[dict] = []

        # Class A — deterministic (abstains if the transcript looks unreliable)
        for v in self.rule_engine.analyze(
            verse_text, transcript, word_timings, verse_id,
            min_reliability=self.class_a_min_reliability,
        ):
            violations.append(v.to_dict())

        # Class B — acoustic (only if classifiers + audio are available)
        if self.inference is not None and waveform is not None:
            violations.extend(
                self._class_b(verse_text, word_timings, waveform, sample_rate, verse_id)
            )

        return AnalysisResult(verse_id=verse_id, violations=violations)

    def _class_b(self, verse_text, word_timings, waveform, sample_rate, verse_id) -> list[dict]:
        from .asr.whisper_align import clip_for_position

        out: list[dict] = []
        for exp in self.engine.expected(verse_text):
            if exp.rule_class != "B":
                continue
            rule_key = exp.rule.lower()
            if rule_key not in getattr(self.inference, "sessions", {}):
                continue
            wi = P.char_to_word_index(verse_text, exp.char_index)
            start_ms, end_ms = RuleEngine._timing(word_timings, wi)
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
