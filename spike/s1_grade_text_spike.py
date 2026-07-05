"""
Spike S1: can quran_phonetizer + Muaalem grade ARBITRARY short Uthmani text?

Decides Tier-1 Path A vs Path B in docs/PRODUCTION_PLAN.md §3.3 — whether the
Arabic track's echo exercises (Units 1-6) get phoneme-level grading from the
existing engine with zero new ML. Result goes to docs/decisions/grading-tiers.md.

What is already known (tested locally on quran-transcript 0.5.2, no GPU needed):
  - quran_phonetizer(text, moshaf) accepts arbitrary Uthmani strings — it is NOT
    limited to Aya() lookups.
  - It applies WAQF rules to word-final position: a final short vowel is dropped
    ('صَ' -> 'ص') and qalqalah letters get the qalqalah phoneme ('بَ' -> 'بڇ').
    So isolated CV syllables with a short vowel are un-gradeable as written —
    the manifest teaches qaida-style long forms (بَا بِي بُو) instead, plus one
    deliberate raw 'بَ' row to measure the waqf behavior on real audio.

What this spike measures (needs GPU + real recordings):
  1. Does the model produce sane phonemes for SHORT (~1s) SPOKEN clips? It was
     trained on skilled reciters, segmented by pause rules (waqf chunks) — short
     chunks are in-domain, plain speaking style is not.
  2. Do correct recordings come back clean, and deliberately-wrong recordings
     (wrong consonant / wrong vowel / wrong length) get flagged at the right
     phoneme?

PASS CRITERIA (decided before running, per plan):
  - >=80% of `correct` rows return zero errors.
  - >=80% of `wrong` rows return >=1 error, and eyeballing shows the error is
    AT the planted mistake (not random noise).
  - No crashes on ~1s clips.
  Include at least one genuinely NON-NATIVE speaker's recordings — the model
  passing on a native's faked mistakes proves little.

Run:
  1. Record clips per spike/s1_manifest.csv into spike/s1_recordings/
     (phone mic, spoken plainly like a learner, 16kHz mono WAV:
      ffmpeg -i in.m4a -ar 16000 -ac 1 out.wav)
  2. modal run spike/s1_grade_text_spike.py --manifest spike/s1_manifest.csv
     Single clip:  modal run spike/s1_grade_text_spike.py --audio x.wav --text 'بَا'

ponytail: throwaway spike — no sifat output, no backend wiring. If S1 passes,
the real work is a /grade-text endpoint in ml/muaalem_modal.py (M3).
"""

import csv
import io
import time
from pathlib import Path

import modal

# Same pinned image as the production service (ml/muaalem_modal.py) — the spike
# must test the exact versions the product would use.
image = (
    modal.Image.debian_slim(python_version="3.11")
    .apt_install("ffmpeg", "libsndfile1")
    .pip_install(
        "quran-muaalem==0.1.0",
        "quran-transcript==0.5.2",
        "librosa==0.11.0",
        "soundfile==0.14.0",
        "numba>=0.61.2",
    )
)

app = modal.App("bayaan-s1-grade-text", image=image)

model_cache = modal.Volume.from_name("hf-cache", create_if_missing=True)
CACHE_DIR = "/cache"


@app.cls(gpu="L4", volumes={CACHE_DIR: model_cache}, timeout=600, scaledown_window=300)
class GradeTextSpike:
    @modal.enter()
    def load(self):
        import os

        os.environ["HF_HOME"] = CACHE_DIR
        from quran_muaalem import Muaalem

        t0 = time.perf_counter()
        self.model = Muaalem(device="cuda")
        print(f"[load] muaalem ready in {time.perf_counter() - t0:.1f}s")

    @modal.method()
    def grade(self, wav_bytes: bytes, text: str) -> dict:
        """Arbitrary Uthmani text as the reference — the whole point of S1."""
        import dataclasses
        import json

        import librosa
        import soundfile as sf
        from quran_transcript import explain_error, quran_phonetizer
        from quran_transcript.phonetics.moshaf_attributes import MoshafAttributes

        wave, sr = sf.read(io.BytesIO(wav_bytes), dtype="float32")
        if wave.ndim > 1:
            wave = wave.mean(axis=1)
        if sr != 16000:
            wave = librosa.resample(wave, orig_sr=sr, target_sr=16000)

        moshaf = MoshafAttributes(
            rewaya="hafs",
            madd_monfasel_len=2,
            madd_mottasel_len=4,
            madd_mottasel_waqf=4,
            madd_aared_len=4,
        )
        ref = quran_phonetizer(text, moshaf, remove_spaces=True)

        t0 = time.perf_counter()
        outs = self.model([wave], [ref], sampling_rate=16000)
        infer_secs = time.perf_counter() - t0

        predicted = outs[0].phonemes.text
        errors = explain_error(text, ref.phonemes, predicted, ref.mappings)
        errors_json = json.loads(
            json.dumps(
                [dataclasses.asdict(e) for e in errors],
                default=lambda o: sorted(o) if isinstance(o, set) else str(o),
            )
        )
        return {
            "text": text,
            "reference_phonemes": ref.phonemes,
            "predicted_phonemes": predicted,
            "errors": errors_json,
            "error_count": len(errors_json),
            "audio_secs": round(len(wave) / 16000, 2),
            "infer_secs": round(infer_secs, 3),
        }


def _grade_one(spike, path: str, text: str) -> dict:
    wav = Path(path).read_bytes()
    return spike.grade.remote(wav, text)


@app.local_entrypoint()
def main(manifest: str = "", audio: str = "", text: str = ""):
    spike = GradeTextSpike()

    if audio:
        r = _grade_one(spike, audio, text)
        print(f"\ntext:      {r['text']}")
        print(f"reference: {r['reference_phonemes']}")
        print(f"predicted: {r['predicted_phonemes']}")
        print(f"errors ({r['error_count']}): {r['errors']}")
        print(f"audio {r['audio_secs']}s, inference {r['infer_secs']}s")
        return

    rows = [r for r in csv.DictReader(open(manifest)) if not r["audio"].startswith("#")]
    base = Path(manifest).parent
    results = []
    for row in rows:
        path = base / row["audio"]
        if not path.exists():
            print(f"SKIP (not recorded yet): {row['audio']}")
            continue
        try:
            r = _grade_one(spike, str(path), row["text"])
        except Exception as e:
            print(f"CRASH {row['audio']}: {type(e).__name__}: {e}")
            results.append({**row, "crash": True, "error_count": -1})
            continue
        flagged = r["error_count"] > 0
        ok = (row["expect"] == "wrong") == flagged
        results.append({**row, "crash": False, "error_count": r["error_count"], "ok": ok})
        mark = "✓" if ok else "✗"
        print(f"\n{mark} {row['audio']}  [{row['expect']}]  {row['note']}")
        print(f"  text:      {r['text']}")
        print(f"  reference: {r['reference_phonemes']}")
        print(f"  predicted: {r['predicted_phonemes']}")
        if flagged:
            print(f"  errors ({r['error_count']}): {r['errors']}")

    graded = [r for r in results if not r["crash"]]
    correct = [r for r in graded if r["expect"] == "correct"]
    wrong = [r for r in graded if r["expect"] == "wrong"]
    c_pass = sum(r["ok"] for r in correct)
    w_pass = sum(r["ok"] for r in wrong)
    crashes = sum(r["crash"] for r in results)
    print("\n=========== S1 SUMMARY ===========")
    print(f"correct clips graded clean:   {c_pass}/{len(correct)}  (need >=80%)")
    print(f"wrong clips flagged:          {w_pass}/{len(wrong)}  (need >=80%)")
    print(f"crashes:                      {crashes}  (need 0)")
    both = correct and wrong and c_pass / len(correct) >= 0.8 and w_pass / len(wrong) >= 0.8
    print(f"\nS1 verdict: {'PASS — Path A (Muaalem)' if both and not crashes else 'FAIL/INCONCLUSIVE — see rows above'}")
    print("Eyeball wrong-clip errors: flagged AT the planted mistake, or random noise?")
    print("Commit result + this output to docs/decisions/grading-tiers.md")
