"""QDAT data preparation + PyTorch Dataset for Class B classifiers.

`prepare_labels()` downloads obadx/qdat (HuggingFace), exports each clip to a
16 kHz mono WAV, and writes data/processed/labels.csv with columns:

    filename, rule, label, split

Label semantics (LOCKED): label == 1 -> correct, label == 0 -> incorrect.

`TajweedClipDataset` reads that CSV filtered by (rule, split) and yields
fixed-length waveforms ready for the wav2vec2 backbone.
"""
from __future__ import annotations

import argparse
import io
from pathlib import Path

import numpy as np
import pandas as pd
import soundfile as sf
import torch
from sklearn.model_selection import train_test_split
from torch.utils.data import Dataset

from . import config as C

WAV_DIR = C.PROCESSED_DIR / "wav"


# --------------------------------------------------------------------------- #
# Preparation (run once, offline)
# --------------------------------------------------------------------------- #
def _coerce_label(value) -> int | None:
    """Map a QDAT cell to {0, 1}; return None if the rule does not apply here."""
    if value is None:
        return None
    try:
        if isinstance(value, float) and np.isnan(value):
            return None
    except TypeError:
        pass
    s = str(value).strip().lower()
    if s in {"1", "1.0", "true", "correct"}:
        return 1
    if s in {"0", "0.0", "false", "incorrect"}:
        return 0
    return None


def _resample(wav: np.ndarray, sr: int, target: int = C.SAMPLE_RATE) -> np.ndarray:
    if sr == target:
        return wav
    from math import gcd
    from scipy.signal import resample_poly
    g = gcd(sr, target)
    return resample_poly(wav, target // g, sr // g).astype(np.float32)


def _decode_audio(audio: dict) -> np.ndarray:
    """Decode a datasets Audio(decode=False) cell -> 16 kHz mono float32."""
    raw = audio.get("bytes")
    src = io.BytesIO(raw) if raw else audio["path"]
    wav, sr = sf.read(src, dtype="float32")
    if wav.ndim > 1:
        wav = wav.mean(axis=1)
    return _resample(wav, sr)


def prepare_labels(hf_id: str = "obadx/qdat", split: str = "train") -> Path:
    """Download QDAT, export WAVs, write labels.csv. Returns the CSV path."""
    from datasets import Audio, load_dataset  # imported lazily (heavy)

    print(f"[prepare] loading {hf_id} ...")
    ds = load_dataset(hf_id, split=split, cache_dir=str(C.RAW_DIR))
    audio_col = next(
        (k for k, v in ds.features.items() if v.__class__.__name__ == "Audio"),
        "audio",
    )
    # decode=False -> we get raw {bytes, path} and decode with soundfile,
    # avoiding the torchcodec/ffmpeg dependency that datasets 5.x needs.
    ds = ds.cast_column(audio_col, Audio(decode=False))
    print(f"[prepare] {len(ds)} rows; audio column = '{audio_col}'")
    print(f"[prepare] columns: {list(ds.features.keys())}")

    WAV_DIR.mkdir(parents=True, exist_ok=True)
    rule_columns = {r.qdat_column: name for name, r in C.CLASS_B_RULES.items()}

    rows: list[dict] = []
    exported: set[int] = set()
    for i, ex in enumerate(ds):
        wav_path = WAV_DIR / f"clip_{i:05d}.wav"
        for col, rule_name in rule_columns.items():
            if col not in ex:
                continue
            label = _coerce_label(ex[col])
            if label is None:
                continue
            if i not in exported:  # write the WAV once, on first use
                arr = _decode_audio(ex[audio_col])
                sf.write(wav_path, arr, C.SAMPLE_RATE, subtype="PCM_16")
                exported.add(i)
            rows.append(
                {"filename": wav_path.name, "rule": rule_name, "label": label}
            )

    df = pd.DataFrame(rows)
    if df.empty:
        raise RuntimeError(
            "No labelled rows found. Inspect the columns printed above and "
            "update CLASS_B_RULES[*].qdat_column in config.py."
        )

    df = _assign_splits(df)
    C.LABELS_CSV.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(C.LABELS_CSV, index=False)

    print(f"[prepare] wrote {C.LABELS_CSV}  ({len(df)} rows, {len(exported)} clips)")
    for rule in C.CLASS_B_RULES:
        sub = df[df.rule == rule]
        print(
            f"   {rule:8s}: {len(sub):5d} rows  "
            f"(correct={int((sub.label == 1).sum())}, "
            f"incorrect={int((sub.label == 0).sum())})  "
            f"splits={dict(sub.split.value_counts())}"
        )
    return C.LABELS_CSV


def _assign_splits(df: pd.DataFrame) -> pd.DataFrame:
    """Stratified train/val/test split per rule (on the label)."""
    cfg = C.TrainConfig()
    out = []
    for rule, sub in df.groupby("rule"):
        sub = sub.reset_index(drop=True)
        idx = np.arange(len(sub))
        train_idx, tmp_idx = train_test_split(
            idx,
            test_size=cfg.val_fraction + cfg.test_fraction,
            stratify=sub.label,
            random_state=cfg.seed,
        )
        rel = cfg.test_fraction / (cfg.val_fraction + cfg.test_fraction)
        val_idx, test_idx = train_test_split(
            tmp_idx, test_size=rel, stratify=sub.label.iloc[tmp_idx], random_state=cfg.seed
        )
        sub["split"] = "train"
        sub.loc[val_idx, "split"] = "val"
        sub.loc[test_idx, "split"] = "test"
        out.append(sub)
    return pd.concat(out, ignore_index=True)


# --------------------------------------------------------------------------- #
# Audio helpers
# --------------------------------------------------------------------------- #
def load_clip(path: Path | str, n_samples: int = C.CLIP_SAMPLES,
              pad: bool = True) -> torch.Tensor:
    """Load a WAV as mono float32 @ 16 kHz.

    pad=True  -> fixed length n_samples (for fixed-shape ONNX input).
    pad=False -> true length (used for feature extraction; the frozen backbone
                 pools over real frames only, avoiding padding artifacts and the
                 truncation of long QDAT clips, up to ~17 s).
    """
    wav, sr = sf.read(str(path), dtype="float32")
    if wav.ndim > 1:                       # stereo -> mono
        wav = wav.mean(axis=1)
    wav = _resample(wav, sr)
    if pad:
        wav = fix_length(wav, n_samples)
    return torch.from_numpy(np.ascontiguousarray(wav))


def fix_length(wav: np.ndarray, n: int) -> np.ndarray:
    if len(wav) >= n:
        return wav[:n]
    return np.pad(wav, (0, n - len(wav)))


# --------------------------------------------------------------------------- #
# PyTorch Dataset
# --------------------------------------------------------------------------- #
class TajweedClipDataset(Dataset):
    def __init__(self, rule: str, split: str, labels_csv: Path | str = C.LABELS_CSV):
        df = pd.read_csv(labels_csv)
        self.df = df[(df.rule == rule) & (df.split == split)].reset_index(drop=True)
        if self.df.empty:
            raise ValueError(f"No rows for rule='{rule}', split='{split}' in {labels_csv}")
        self.rule = rule
        self.split = split

    def __len__(self) -> int:
        return len(self.df)

    def __getitem__(self, i: int):
        row = self.df.iloc[i]
        wav = load_clip(WAV_DIR / row.filename)
        label = torch.tensor(float(row.label), dtype=torch.float32)
        return wav, label

    def pos_weight(self) -> torch.Tensor:
        """neg/pos ratio for BCEWithLogitsLoss (handles class imbalance)."""
        pos = int((self.df.label == 1).sum())
        neg = int((self.df.label == 0).sum())
        return torch.tensor([neg / max(pos, 1)], dtype=torch.float32)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Prepare QDAT -> labels.csv")
    ap.add_argument("--hf-id", default="obadx/qdat")
    ap.add_argument("--split", default="train")
    prepare_labels(**vars(ap.parse_args()))
