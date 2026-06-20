# bayaan-ml

Implementation of the **Bayaan** hybrid Tajweed mispronunciation detector
(research write-up lives in the sibling `bayaan-research` repo).

- **Class A** — deterministic rule engine: localizes every rule from text and
  judges noon-sakinah / tanween rules (Idgham, Iqlab, Ikhfaa, Izhar) by
  comparing the expected realization to the ASR transcript. No ML.
- **Class B** — acoustic classifiers: frozen `wav2vec2-large-xlsr-53-arabic`
  backbone + small head, one per rule (Ghunnah, Madd), exported to ONNX.
- **Hybrid layer** — merges both into one character-mapped report and computes
  **Feedback Grounding Rate (FGR)**.

## Layout

```
src/
  config.py            # paths, audio params, rule specs, hyperparameters
  dataset.py           # QDAT -> labels.csv + PyTorch Dataset
  classifier.py        # frozen XLSR backbone + 2-layer head
  train.py             # head-only training, pos_weight, early stop on val F1
  export_onnx.py       # checkpoint -> ONNX (+ verification)
  inference.py         # ONNX runtime, P(correct)
  hybrid.py            # Class A + Class B merge, FGR
  eval_quranmb.py      # held-out evaluation (LOCKED until Phase 9)
  tajweed/
    phonology.py       # Arabic letter groups, parsing, indices
    engine.py          # TajweedEngine.expected() -> rule positions (FGR foundation)
    rules_class_a.py   # RuleEngine.analyze() -> violations
  asr/whisper_align.py # Groq Whisper word-level timestamps (the only aligner)
tests/                 # deterministic engine + Class A + FGR tests
```

## Setup

```bash
python -m venv .venv
.venv/Scripts/activate            # Windows ;  source .venv/bin/activate on Linux
pip install -r requirements.txt   # torch etc. — heavy; or train on Kaggle GPU
pip install pytest
```

> **Windows note:** the console is cp1252. For scripts that print Arabic, set
> `PYTHONUTF8=1` (or `set PYTHONIOENCODING=utf-8`).

## Workflow

```bash
# 1. Data (Phase 1) — download QDAT, export 16 kHz WAVs, build labels.csv
python -m src.dataset --hf-id obadx/qdat

# 2. Train Class B (Phase 4) — Kaggle GPU recommended
python -m src.train --rule ghunnah --epochs 50
python -m src.train --rule madd    --epochs 50

# 3. Export to ONNX
python -m src.export_onnx --rule ghunnah --checkpoint checkpoints/ghunnah_best.pt --output models/ghunnah.onnx
python -m src.export_onnx --rule madd    --checkpoint checkpoints/madd_best.pt    --output models/madd.onnx

# 4. Tests (no GPU / no downloads needed for the deterministic core)
python -m pytest tests/ -q

# 5. Evaluation (Phase 9 ONLY — QuranMB.v2 is held out until then)
python -m src.eval_quranmb --unlock
```

## Status

| Component | State |
|-----------|-------|
| Tajweed engine (localization) | ✅ implemented + tested |
| Class A rule detection | ✅ implemented + tested (explicit-noon cases) |
| Hybrid layer + FGR | ✅ implemented + tested |
| Class B pipeline (dataset/train/export/inference) | ✅ written, compiles — needs data + GPU run |
| Whisper alignment | ✅ written — needs `GROQ_API_KEY` |
| Class B classifiers (Ghunnah/Madd) | ✅ trained — QDAT test F1 0.93 / 0.87; ONNX exported + verified |
| Phoneme-deviation bridge (`quranmb_mapping.py`) | ✅ first pass + tested (IQRA-comparable F1) |
| QuranMB.v2 eval | ⚠️ wired — pending Phase 9 (locked) + dataset-id confirmation |

### Known limitations (honest, for the paper)
- Class A transcript detection is reliable for explicit-noon cases; **tanween**
  and **Iqlab** realizations are not distinguishable from an orthographic
  transcript and defer to the acoustic path / a phonetic transcript.
- **Class A abstains on unreliable transcripts.** A letter-skeleton similarity
  gate (`transcript_reliability`, default 0.5) suppresses Class A when the ASR
  output diverges too far from the reference verse (failed/garbage ASR),
  preventing false positives. Detection quality is therefore bounded by ASR
  quality — a weak Whisper yields abstentions, not false alarms.
- **Phoneme bridge is a first pass.** IqraEval phonemizes *literally* (not
  Tajweed-collapsed), so Tajweed-rule violations don't map 1:1 to phoneme
  substitutions. The char→phoneme alignment here is a monotonic-proportional
  heuristic with symbol snapping; the *exact* alignment needs IqraEval's own
  phonemizer. Frame the F1 as "Bayaan targets a pedagogically meaningful subset
  of phoneme errors with full character grounding (high FGR)".
- The classifier F1 above is **QDAT in-distribution**, not QuranMB.v2 — not
  comparable to IQRA baselines until the Phase-9 eval.
- ONNX models are full fp32 XLSR (~1.26 GB each); int8 quantization is needed
  before any "lightweight / on-device" claim.
