"""Evaluation harness on QuranMB.v2 (IQRA 2026 held-out benchmark).

    python -m src.eval_quranmb --unlock

⚠️  QuranMB.v2 is LOCKED until Phase 9. Running this earlier (for debugging or
threshold tuning) invalidates the paper's comparison to IQRA 2026 baselines.
The --unlock flag is a deliberate speed bump, not a real lock.

Computes:
  - Feedback Grounding Rate (FGR)  — directly comparable (IQRA systems = 0%)
  - per-rule violation counts
  - F1 vs ground truth  — REQUIRES mapping our character-level violations onto
    QuranMB.v2's phoneme-deviation annotations (see map_to_deviations TODO).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from . import config as C
from .hybrid import HybridDetector, corpus_fgr
from .inference import default_inference
from .quranmb_mapping import ground_truth_deviations, map_to_deviations, mdd_counts, prf


QURANMB_ID = "IqraEval/Iqra_QuranMB_v2"


def run(
    source: str = QURANMB_ID,
    split: str = "test",
    limit: int | None = None,
    use_class_b: bool = True,
    asr: str = "none",                 # none | local | groq
    asr_model: str = "openai/whisper-small",
    only_deviations: bool = False,
    device: str | None = None,
) -> dict:
    from datasets import Audio, load_dataset

    print(f"[eval] streaming {source} [{split}] | asr={asr}")
    ds = load_dataset(source, split=split, streaming=True)
    feats = ds.features
    print(f"[eval] features: {list(feats.keys())}")

    inference = None
    if use_class_b:
        try:
            inference = default_inference()
            print(f"[eval] Class B models: {list(inference.sessions)}")
        except Exception as e:  # noqa: BLE001
            print(f"[eval] no Class B models ({e}); running Class A only")

    detector = HybridDetector(inference=inference)

    # --- column discovery (IqraEval schema) -------------------------------- #
    text_col = _first_present(ds, ["tashkeel_sentence", "sentence", "text", "verse"])
    ref_col = _first_present(ds, ["phoneme_ref"])
    aug_col = _first_present(ds, ["phoneme_aug"])
    audio_col = next(
        (k for k, v in ds.features.items() if v.__class__.__name__ == "Audio"), None
    )
    print(f"[eval] text={text_col!r} ref={ref_col!r} aug={aug_col!r} audio={audio_col!r}")
    if not (ref_col and aug_col):
        print("[eval] no phoneme_ref/phoneme_aug -> FGR only, no comparable F1")

    from .dataset import _decode_audio
    from .asr.whisper_align import transcribe_words_local

    if audio_col:
        ds = ds.cast_column(audio_col, Audio(decode=False))  # decode bytes ourselves

    need_audio = bool(audio_col) and (asr == "local" or (use_class_b and inference))
    results = []
    tp = fp = fn = 0
    accepted = 0
    for i, ex in enumerate(ds):
        verse_text = str(ex.get(text_col, "")) if text_col else ""
        if not verse_text:
            continue
        ref, aug = ex.get(ref_col), ex.get(aug_col)
        if only_deviations and not (ref and aug and ref != aug):
            continue  # dry-run: keep only utterances that actually contain errors

        waveform = _decode_audio(ex[audio_col]) if need_audio else None

        if asr == "local":
            t = transcribe_words_local(waveform, model=asr_model, device=device)
            transcript, word_timings = t["text"], t["words"]
        elif asr == "groq":
            from .asr.whisper_align import transcribe_words
            t = transcribe_words(ex[audio_col]["path"])
            transcript, word_timings = t["text"], t["words"]
        else:
            transcript, word_timings = verse_text, None  # placeholder

        res = detector.analyze(
            verse_text, transcript, word_timings=word_timings,
            waveform=waveform, verse_id=str(i),
        )
        results.append(res)

        if ref and aug:  # IQRA-comparable scoring via the phoneme-deviation bridge
            gt = ground_truth_deviations(ref, aug)
            pred = map_to_deviations(verse_text, res.violations, ref)
            dtp, dfp, dfn = mdd_counts(pred, gt)
            tp, fp, fn = tp + dtp, fp + dfp, fn + dfn

        accepted += 1
        if accepted % 5 == 0:
            print(f"[eval] {accepted} utterances processed", flush=True)
        if limit is not None and accepted >= limit:
            break

    fgr = corpus_fgr(results)
    by_rule: dict[str, int] = {}
    for r in results:
        for v in r.violations:
            by_rule[v["rule"]] = by_rule.get(v["rule"], 0) + 1

    f1_block = prf(tp, fp, fn) if (ref_col and aug_col) else None
    summary = {
        "n_utterances": len(results),
        "total_violations": sum(len(r.violations) for r in results),
        "fgr": fgr,
        "violations_by_rule": by_rule,
        "mdd": f1_block,   # phoneme-deviation P/R/F1 vs IqraEval ground truth
    }
    out_path = C.ROOT / "eval_quranmb_results.json"
    out_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    print(f"[eval] FGR = {fgr:.1%}  (IQRA 2026 baselines: 0%)")
    if f1_block:
        print(f"[eval] MDD F1 = {f1_block['f1']:.4f} "
              f"(P={f1_block['precision']:.3f} R={f1_block['recall']:.3f}) "
              f"vs IQRA 2026 top F1 = 0.7201")
    print(f"[eval] wrote {out_path}")
    return summary


def _first_present(ds, candidates: list[str]) -> str | None:
    return next((c for c in candidates if c in ds.features), None)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", default=QURANMB_ID,
                    help="HF dataset id (use IqraEval/Iqra_train for a dry run)")
    ap.add_argument("--split", default="test")
    ap.add_argument("--limit", type=int, default=None)
    ap.add_argument("--no-class-b", action="store_true")
    ap.add_argument("--asr", choices=["none", "local", "groq"], default="none")
    ap.add_argument("--asr-model", default="openai/whisper-small")
    ap.add_argument("--only-deviations", action="store_true",
                    help="dry run: keep only utterances where phoneme_aug != phoneme_ref")
    ap.add_argument("--device", default=None)
    ap.add_argument("--unlock", action="store_true",
                    help="confirm you are at Phase 9 and may open QuranMB.v2")
    args = ap.parse_args()

    # The lock applies ONLY to the held-out QuranMB.v2; other sources are open.
    if "quranmb" in args.source.lower() and not args.unlock:
        print(__doc__)
        print("Refusing to open QuranMB.v2 without --unlock (held out until Phase 9).")
        sys.exit(2)

    run(source=args.source, split=args.split, limit=args.limit,
        use_class_b=not args.no_class_b, asr=args.asr, asr_model=args.asr_model,
        only_deviations=args.only_deviations, device=args.device)


if __name__ == "__main__":
    main()
