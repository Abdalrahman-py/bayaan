"""hetchyy/everyayah-phonemes -> manifest + PyTorch Dataset for the Class A
phoneme recognizer. Parallel to `dataset.py`, but a completely separate data
source (HF parquet shards, not QDAT) -- `dataset.py` stays QDAT/Class-B-only,
untouched.

`prepare_manifest()` scans the dataset's parquet shards directly, not HF's
`/filter` API (which only indexes the first 5GB of the 207k-row train split
and silently caps training data at ~4 reciters -- see
Learnings/2026-06-21-phoneme-recognizer-wide-reciter-retrain.md), exports
each matching clip to a 16 kHz mono WAV, and writes a manifest CSV.

Reciters span ~2.76 contiguous shards each (full-Quran recitations, ordered
by surah), so Al-Fatihah (surah 1, near the start of a reciter's block) and
Al-Bayyinah (surah 98, near the end) usually land in DIFFERENT shards for the
same reciter -- the window-scan below reads a few shards per newly-found
reciter, not just the one where they were first spotted, to avoid silently
dropping one of the two surahs.
"""
from __future__ import annotations

import argparse
import io
from pathlib import Path

import pandas as pd
import pyarrow.parquet as pq
import requests
import soundfile as sf
import torch
import torch.nn as nn
from huggingface_hub import list_repo_files
from torch.utils.data import Dataset

from . import config as C

REPO = "hetchyy/everyayah-phonemes"
PHONEME_WAV_DIR = C.PROCESSED_DIR / "phoneme_wav"
PHONEME_MANIFEST_CSV = C.PROCESSED_DIR / "phoneme_manifest.csv"

# HF dataset's "verse" column is "{surah}_{ayah}" (underscore); the
# Phonemizer's own ref format is "{surah}:{ayah}" (colon) -- deliberately
# different namespaces, converted at the boundary by verse_ref_for().
_AYAH_COUNTS = {1: 7, 98: 8}  # Al-Fatihah, Al-Bayyinah


def _target_verses() -> set[str]:
    return {f"{s}_{a}" for s, n in _AYAH_COUNTS.items() for a in range(1, n + 1)}


def verse_ref_for(verse: str) -> str:
    """HF dataset's "1_1" -> the Phonemizer's "1:1"."""
    surah, ayah = verse.split("_")
    return f"{surah}:{ayah}"


def _read_columns(shard_path: str, columns: list[str]) -> pd.DataFrame:
    # pyarrow's native hf:// reader supports column-chunk pruning (skips audio
    # bytes when not requested); falls back to a plain HTTP fetch if the
    # environment's pyarrow build lacks hf:// support.
    try:
        t = pq.read_table(f"hf://datasets/{REPO}/{shard_path}", columns=columns)
    except Exception:
        url = f"https://huggingface.co/datasets/{REPO}/resolve/main/{shard_path}"
        t = pq.read_table(io.BytesIO(requests.get(url, timeout=120).content), columns=columns)
    return t.to_pandas()


def _matching_rows(
    shard_path: str, target_verses: set[str], columns: list[str] | None = None,
) -> pd.DataFrame:
    df = _read_columns(shard_path, columns or ["audio", "reciter", "verse", "phonemes"])
    return df[df["verse"].isin(target_verses)]


def _export(df: pd.DataFrame, split: str, rows: list[dict]) -> None:
    for _, row in df.iterrows():
        fname = f"{split}_{row['verse']}_{row['reciter']}.wav".replace("/", "-")
        path = PHONEME_WAV_DIR / fname
        if not path.exists():
            wav, sr = sf.read(io.BytesIO(row["audio"]["bytes"]), dtype="float32")
            assert sr == C.SAMPLE_RATE, f"expected {C.SAMPLE_RATE}Hz, got {sr}Hz for {row['verse']}/{row['reciter']}"
            sf.write(path, wav, sr)
        rows.append({
            "filename": fname, "split": split,
            "verse": row["verse"], "reciter": row["reciter"],
            "phonemes": row["phonemes"],
        })


def prepare_manifest(new_reciter_target: int = 16, window: int = 4) -> Path:
    """Scan HF parquet shards for Al-Fatihah + Al-Bayyinah clips, export WAVs,
    write the manifest CSV. Dev: scan all dev shards fully (small split, ~61
    clips/8 reciters). Train: window-scan to reach `new_reciter_target`
    distinct reciters without downloading all 124 shards."""
    target_verses = _target_verses()
    repo_files = list_repo_files(REPO, repo_type="dataset")
    train_files = sorted(f for f in repo_files if f.startswith("data/train-"))
    dev_files = sorted(f for f in repo_files if f.startswith("data/dev-"))
    print(f"[phoneme-manifest] {len(train_files)} train shards, {len(dev_files)} dev shards")

    PHONEME_WAV_DIR.mkdir(parents=True, exist_ok=True)
    rows: list[dict] = []

    dev_df = pd.concat([_matching_rows(f, target_verses) for f in dev_files], ignore_index=True)
    _export(dev_df, "dev", rows)
    print(f"[phoneme-manifest] dev: {len(dev_df)} clips, {dev_df['reciter'].nunique()} reciters")

    train_chunks, reciters_seen, shard_idx = [], set(), 0
    while len(reciters_seen) < new_reciter_target and shard_idx < len(train_files):
        new_reciters = set(_read_columns(train_files[shard_idx], ["reciter"])["reciter"]) - reciters_seen
        if new_reciters:
            chunk = pd.concat(
                [_matching_rows(f, target_verses) for f in train_files[shard_idx:shard_idx + window]],
                ignore_index=True,
            )
            chunk = chunk[chunk["reciter"].isin(new_reciters)]
            if len(chunk):
                train_chunks.append(chunk)
                reciters_seen |= set(chunk["reciter"].unique())
                print(f"[phoneme-manifest] shard {shard_idx}+{window}: "
                      f"+{len(new_reciters)} reciters ({len(chunk)} clips), total {len(reciters_seen)}")
        shard_idx += window

    train_df = pd.concat(train_chunks, ignore_index=True)
    overlap = set(train_df["reciter"]) & set(dev_df["reciter"])
    assert not overlap, f"train/dev reciter overlap, would leak: {overlap}"
    _export(train_df, "train", rows)
    print(f"[phoneme-manifest] train: {len(train_df)} clips, {train_df['reciter'].nunique()} reciters")

    df = pd.DataFrame(rows)
    PHONEME_MANIFEST_CSV.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(PHONEME_MANIFEST_CSV, index=False)
    print(f"[phoneme-manifest] wrote {PHONEME_MANIFEST_CSV} ({len(df)} rows)")
    return PHONEME_MANIFEST_CSV


class PhonemeClipDataset(Dataset):
    def __init__(self, split: str, manifest_csv: Path | str = PHONEME_MANIFEST_CSV):
        df = pd.read_csv(manifest_csv)
        self.df = df[df.split == split].reset_index(drop=True)
        if self.df.empty:
            raise ValueError(f"No rows for split='{split}' in {manifest_csv}")

    def __len__(self) -> int:
        return len(self.df)

    def __getitem__(self, i: int):
        row = self.df.iloc[i]
        wav, _sr = sf.read(PHONEME_WAV_DIR / row.filename, dtype="float32")
        ids = [C.PHON_TO_ID[p] for p in row.phonemes.split(" ")]
        return torch.from_numpy(wav), torch.tensor(ids, dtype=torch.long)


def collate(batch):
    waveforms, targets = zip(*batch)
    wav_lens = torch.tensor([len(w) for w in waveforms])
    tgt_lens = torch.tensor([len(t) for t in targets])
    wav_padded = nn.utils.rnn.pad_sequence(waveforms, batch_first=True)
    tgt_concat = torch.cat(targets)  # CTCLoss wants targets concatenated, not padded
    return wav_padded, wav_lens, tgt_concat, tgt_lens


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Scan hetchyy/everyayah-phonemes -> phoneme manifest")
    ap.add_argument("--new-reciter-target", type=int, default=16)
    args = ap.parse_args()
    prepare_manifest(args.new_reciter_target)
