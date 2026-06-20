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
