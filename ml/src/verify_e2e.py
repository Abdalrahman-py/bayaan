"""End-to-end sanity check for the Class A phoneme recognizer on REAL audio.

Loads the trained checkpoint, fetches a few real Al-Fatihah/Al-Bayyinah dev
clips directly from `hetchyy/everyayah-phonemes` (the dev split the
checkpoint's val_PER was already measured against during training -- see
phoneme_train.py), and runs recognizer -> phoneme_diff end-to-end. This is
NOT QuranMB.v2 (locked until Phase 9) and NOT a synthetic fixture (the only
coverage test_phoneme_diff.py has) -- it's the first real-audio run of the
full Class A path, closing the gap flagged in
serialized-baking-cat.md's verification steps 3-4.

    python -m src.verify_e2e --n-clips 3
"""
from __future__ import annotations

import argparse
import io

import soundfile as sf
from huggingface_hub import list_repo_files

from . import config as C
from .phoneme_dataset import REPO, _matching_rows, _target_verses, verse_ref_for
from .phoneme_inference import load_model, predict_phonemes
from .tajweed.phoneme_diff import diff
from .tajweed.phoneme_reference import reference_for

CHECKPOINT = C.ROOT / "checkpoints" / "phoneme_recognizer_mvp.pt"


def run(n_clips: int = 3, checkpoint=CHECKPOINT) -> None:
    model = load_model(checkpoint)
    print(f"[verify] loaded checkpoint {checkpoint}")

    target = _target_verses()
    dev_files = sorted(
        f for f in list_repo_files(REPO, repo_type="dataset") if f.startswith("data/dev-")
    )

    seen = 0
    for shard in dev_files:
        df = _matching_rows(shard, target, columns=["audio", "reciter", "verse", "phonemes", "text"])
        for _, row in df.iterrows():
            wav, sr = sf.read(io.BytesIO(row["audio"]["bytes"]), dtype="float32")
            assert sr == C.SAMPLE_RATE, f"expected {C.SAMPLE_RATE}Hz, got {sr}Hz"

            verse_ref = verse_ref_for(row["verse"])
            reference = reference_for(verse_ref, row["text"])
            observed = predict_phonemes(model, wav)
            violations = diff(reference, observed, verse_id=verse_ref)

            print(f"\n[verify] {verse_ref}  reciter={row['reciter']!r}  dur={len(wav) / sr:.1f}s")
            print(f"  reference: {' '.join(reference.phoneme_sequence)}")
            print(f"  observed : {' '.join(observed)}")
            print(f"  violations ({len(violations)}):")
            for v in violations:
                print(f"    {v.to_dict()}")

            seen += 1
            if seen >= n_clips:
                _check_waveform_none_contract()
                return

    if seen == 0:
        raise RuntimeError("no matching dev clips found across all dev shards")


def _check_waveform_none_contract() -> None:
    """Plan verification step 4: waveform=None must zero out Class A too."""
    from .hybrid import HybridDetector

    model = load_model(CHECKPOINT)
    detector = HybridDetector(recognizer=model)
    result = detector.analyze(verse_text="بِسْمِ اللَّهِ", verse_ref="1:1", waveform=None)
    status = "OK" if result.violations == [] else "FAIL"
    print(f"\n[verify] waveform=None contract: {status} (violations={result.violations})")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--n-clips", type=int, default=3)
    ap.add_argument("--checkpoint", default=str(CHECKPOINT))
    args = ap.parse_args()
    run(n_clips=args.n_clips, checkpoint=args.checkpoint)
