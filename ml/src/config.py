"""Central configuration: paths, audio params, rule definitions, hyperparameters.

Single source of truth so train / export / inference / eval never disagree
about sample rate, clip length, or which QDAT column backs which rule.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

# --------------------------------------------------------------------------- #
# Paths
# --------------------------------------------------------------------------- #
ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
RAW_DIR = DATA_DIR / "raw"
PROCESSED_DIR = DATA_DIR / "processed"
LABELS_CSV = PROCESSED_DIR / "labels.csv"
CHECKPOINT_DIR = ROOT / "checkpoints"
MODELS_DIR = ROOT / "models"

for _d in (RAW_DIR, PROCESSED_DIR, CHECKPOINT_DIR, MODELS_DIR):
    _d.mkdir(parents=True, exist_ok=True)

# --------------------------------------------------------------------------- #
# Audio
# --------------------------------------------------------------------------- #
SAMPLE_RATE = 16_000          # wav2vec2-xlsr expects 16 kHz mono
CLIP_SECONDS = 12             # fixed length for ONNX export
CLIP_SAMPLES = SAMPLE_RATE * CLIP_SECONDS   # 192_000  (matches ONNX [1, 192000])

# --------------------------------------------------------------------------- #
# Model
# --------------------------------------------------------------------------- #
BACKBONE = "jonatasgrosman/wav2vec2-large-xlsr-53-arabic"
FREEZE_BACKBONE = True        # large model + small data -> head-only training
HEAD_HIDDEN = 256             # 2-layer head: hidden_size -> HEAD_HIDDEN -> 1

# --------------------------------------------------------------------------- #
# Class B rules: name -> QDAT column + metadata
# Label semantics (LOCKED): label == 1 -> correct, label == 0 -> incorrect.
# Classifier outputs P(correct); a violation is flagged when P(correct) < thr.
# --------------------------------------------------------------------------- #
@dataclass(frozen=True)
class RuleSpec:
    name: str
    qdat_column: str          # column in obadx/qdat that carries the label
    arabic: str
    description: str
    default_threshold: float = 0.5


CLASS_B_RULES: dict[str, RuleSpec] = {
    "ghunnah": RuleSpec(
        name="ghunnah",
        qdat_column="the_tight_noon",
        arabic="الغُنّة (النون المشددة)",
        description="2-beat (~500ms) nasalization on ن/م مشددة",
    ),
    "madd": RuleSpec(
        name="madd",
        qdat_column="separate_tide",
        arabic="المد المنفصل",
        description="vowel prolongation duration (2/4/6 counts)",
    ),
    # Qalqalah is paper-only / optional — not from QDAT. Added later if in scope.
}

# --------------------------------------------------------------------------- #
# Training
# --------------------------------------------------------------------------- #
@dataclass
class TrainConfig:
    rule: str = "ghunnah"
    epochs: int = 50
    batch_size: int = 8
    lr: float = 3e-4
    weight_decay: float = 1e-4
    val_fraction: float = 0.15
    test_fraction: float = 0.15
    seed: int = 42
    early_stop_patience: int = 8     # epochs without val-F1 improvement
    num_workers: int = 0             # 0 is safest on Windows
    use_pos_weight: bool = True      # handle QDAT class imbalance (Ghunnah ~4:1)
    device: str = "cuda"             # falls back to cpu in train.py if unavailable


SPLITS = ("train", "val", "test")

# --------------------------------------------------------------------------- #
# Class A (phoneme recognizer) — replaces the old Whisper-transcript path.
# Verified 2026-06-20 by phonemizing all 6,236 verses of the Quran via
# `quranic_phonemizer` and collecting `get_mapping().phoneme_sequence` — do
# not trust any other quoted vocab size (e.g. "71") without re-deriving this.
# --------------------------------------------------------------------------- #
MVP_SURAHS: tuple[int, ...] = (1, 98)  # Al-Fatihah + Al-Bayyinah

PHONEMES: tuple[str, ...] = tuple(sorted([
    "Q", "a", "a:", "aˤ", "aˤ:", "b", "bb", "d", "dd", "dˤ", "dˤdˤ",
    "f", "ff", "h", "hh", "i", "i:", "j", "jj", "j̃", "k", "kk", "l", "ll", "lˤlˤ",
    "m", "m̃", "n", "q", "qq", "r", "rr", "rˤ", "rˤrˤ", "s", "ss", "sˤ", "sˤsˤ",
    "t", "tt", "tˤ", "tˤtˤ", "u", "u:", "w", "ww", "w̃", "x", "xx", "z", "zz",
    "ð", "ðð", "ðˤ", "ðˤðˤ", "ñ", "ħ", "ħħ",
    "ŋ", "ɣ", "ʃ", "ʃʃ", "ʒ", "ʒʒ", "ʔ", "ʕ", "ʕʕ",
    "θ", "θθ",
]))
assert len(PHONEMES) == 69, f"expected 69 phonemes, got {len(PHONEMES)} — re-verify against the Phonemizer"

PHONEME_BLANK_ID = 0  # reserved for CTC blank
PHON_TO_ID: dict[str, int] = {p: i + 1 for i, p in enumerate(PHONEMES)}
ID_TO_PHON: dict[int, str] = {i: p for p, i in PHON_TO_ID.items()}
PHONEME_VOCAB_SIZE = len(PHONEMES) + 1  # 70, incl. blank

# Class A's declared scope: exactly the four Tajweed rule families
# (Idgham-with-ghunnah, Iqlab, Ikhfaa, Qalqala) — keyed by the Phonemizer's
# own `TajweedRule.value` strings. Deliberately excludes default Arabic
# phonological rules the Phonemizer also tags (hamza al-wasl, lam shamsiyah,
# etc.) -- those are normal speech, not Tajweed mistakes, and belong to the
# separate Arabic-learning track, not this model. Also excludes `tafkheem`,
# explicitly out of MVP scope per the project's own prior research (listed as
# "unexplored future work", not part of the four declared families).
# phoneme_diff.diff() filters every mismatch position against this set before
# treating it as a violation.
CLASS_A_RULE_TAGS: frozenset[str] = frozenset({
    "iqlab_noon", "iqlab_tanween",
    "idgham_ghunnah_noon", "idgham_ghunnah_tanween",
    "ikhfaa_noon", "ikhfaa_tanween", "ikhfaa_shafawi",
    "qalqala_sughra", "qalqala_kubra",
})

# Severity for a phoneme-diff mismatch, keyed the same way. Mirrors
# CLASS_B_RULES' "in-scope subset only" shape -- every tag here is also in
# CLASS_A_RULE_TAGS, so DEFAULT_RULE_SEVERITY is unreachable in practice
# (kept only as a defensive fallback, not because anything currently maps to it).
SEVERITY_BY_RULE_TAG: dict[str, str] = {
    "iqlab_noon": "major",
    "iqlab_tanween": "major",
    "idgham_ghunnah_noon": "major",
    "idgham_ghunnah_tanween": "major",
    "ikhfaa_noon": "major",
    "ikhfaa_tanween": "major",
    "ikhfaa_shafawi": "major",
    "qalqala_sughra": "major",
    "qalqala_kubra": "major",
}
DEFAULT_RULE_SEVERITY = "minor"
