"""Precompute frozen-backbone embeddings for a rule, cache to disk.

The XLSR backbone is frozen, so its pooled output for each clip never changes.
Computing it once (here) and training the head on the cache turns 50 epochs from
hours into seconds and avoids holding the 300M-param backbone in VRAM during
training — important on a 4 GB GPU.

    python -m src.extract_features --rule ghunnah
    python -m src.extract_features --rule madd

Output: data/processed/feat_{rule}.npz  with arrays X (N,H), label, split, filename.
"""
from __future__ import annotations

import argparse

import numpy as np
import pandas as pd
import torch
from tqdm import tqdm

from . import config as C
from .classifier import TajweedClassifier
from .dataset import WAV_DIR, load_clip


def feat_path(rule: str):
    return C.PROCESSED_DIR / f"feat_{rule}.npz"


@torch.no_grad()
def extract(rule: str, batch_size: int = 1, device: str | None = None):
    device = device or ("cuda" if torch.cuda.is_available() else "cpu")
    df = pd.read_csv(C.LABELS_CSV)
    df = df[df.rule == rule].reset_index(drop=True)
    if df.empty:
        raise ValueError(f"No rows for rule '{rule}' in {C.LABELS_CSV}")

    print(f"[extract] {rule}: {len(df)} clips on {device}", flush=True)
    model = TajweedClassifier().to(device).eval()

    # Variable-length clips (true duration); batch_size=1 keeps a 4 GB GPU safe.
    embs = np.zeros((len(df), model.backbone.config.hidden_size), dtype=np.float32)
    for i, fn in enumerate(tqdm(df.filename, desc=f"embed {rule}")):
        wav = load_clip(WAV_DIR / fn, pad=False).unsqueeze(0).to(device)  # (1, samples)
        embs[i] = model.pool(wav).cpu().numpy()[0]

    out = feat_path(rule)
    np.savez(
        out,
        X=embs,
        label=df.label.to_numpy(np.float32),
        split=df.split.to_numpy(str),
        filename=df.filename.to_numpy(str),
    )
    print(f"[extract] wrote {out}  (X shape {embs.shape})")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rule", required=True, choices=list(C.CLASS_B_RULES))
    ap.add_argument("--batch-size", type=int, default=4)
    ap.add_argument("--device", default=None)
    args = ap.parse_args()
    extract(args.rule, args.batch_size, args.device)


if __name__ == "__main__":
    main()
