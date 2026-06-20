"""Offline dry run: real Whisper transcript -> Class A -> engine -> FGR, on
local QDAT WAVs (no HF dataset streaming, which is unreliable on flaky nets).

QDAT clips are correct recitations of one verse (Al-Baqarah 2:32), so this is
an end-to-end runtime check of the ASR->detection chain AND a false-positive
test (correct audio should yield few/no violations). MDD scoring against
phoneme annotations is covered by tests/test_quranmb_mapping.py.

    python -m src.dryrun_local --limit 5 --asr-model openai/whisper-tiny
"""
from __future__ import annotations

import argparse
import glob

from .asr.whisper_align import transcribe_words_local
from .dataset import WAV_DIR, load_clip
from .hybrid import HybridDetector

# The single verse every QDAT clip recites (vowelized).
QDAT_VERSE = "قَالُوا لَا عِلْمَ لَنَا إِلَّا مَا عَلَّمْتَنَا إِنَّكَ أَنْتَ الْعَلِيمُ الْحَكِيمُ"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=5)
    ap.add_argument("--asr-model", default="openai/whisper-tiny")
    ap.add_argument("--device", default="cuda")
    args = ap.parse_args()

    wavs = sorted(glob.glob(str(WAV_DIR / "*.wav")))[: args.limit]
    if not wavs:
        raise SystemExit(f"No WAVs in {WAV_DIR} — run src.dataset first.")

    detector = HybridDetector(inference=None)  # Class A only
    print(f"verse: {QDAT_VERSE}")
    print(f"engine localizations: "
          f"{[(e.rule, e.char) for e in detector.engine.expected(QDAT_VERSE)]}")
    print("-" * 70, flush=True)

    total_v = total_fp = 0
    fgrs = []
    for path in wavs:
        wav = load_clip(path, pad=False).numpy()
        t = transcribe_words_local(wav, model=args.asr_model, device=args.device)
        res = detector.analyze(QDAT_VERSE, t["text"], word_timings=t["words"],
                               verse_id="2:32")
        total_v += len(res.violations)
        total_fp += len(res.violations)   # all QDAT clips are correct -> any flag is FP
        fgrs.append(res.fgr)
        print(f"[{path.split(chr(92))[-1]}]")
        print(f"  transcript : {t['text'][:90]}")
        print(f"  violations : {[(v['rule'], v['char'], v['detected'][:30]) for v in res.violations]}")
        print(f"  FGR        : {res.fgr:.2f}", flush=True)

    n = len(wavs)
    print("-" * 70)
    print(f"clips={n}  total_violations={total_v}  "
          f"false_positives(on correct audio)={total_fp}  "
          f"mean_FGR={sum(fgrs)/n:.3f}")
    print(f"FP rate = {total_fp/n:.2f} violations/clip on correct recitations "
          f"(lower is better; roadmap target ~0)")


if __name__ == "__main__":
    main()
