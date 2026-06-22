# ML Module — Agent Instructions

You are working in the ML module of Bayaan. Read this file fully before making changes. For project-wide rules, see [`../AGENTS.md`](../AGENTS.md).

This file describes what is **actually implemented** in `src/`, not the original
design sketch. If you find this file and the code disagree again, trust the code,
fix this file in the same PR, and check `README.md` (kept in sync with `src/`).

---

## What this module is

The Bayaan **hybrid Tajweed mispronunciation detector**. Given a Quran verse's
text and a recording of someone reciting it, it answers: *which Tajweed rules
were violated, where, and why* — with every violation grounded to an exact
Arabic character (this character-grounding is the project's novel contribution,
measured as **Feedback Grounding Rate / FGR**).

**Current scope: Quran Recitation (Tajweed) only.** A second, standalone "Arabic
Pronunciation" track (assessing isolated letters/words with no Tajweed rules,
gating access to the Quran track per the product spec) is planned but **has no
code yet** — don't assume any of it exists when reading `src/`.

---

## Architecture: three layers

**BREAKING CHANGE (2026-06-21):** Class A used to judge a Whisper word-level
transcript against a hand-built rule engine. It's now a phoneme-sequence diff
against `quranic_phonemizer`'s reference, driven by audio, not text. **Class A
now requires `waveform`** — a `waveform=None` call to `HybridDetector.analyze()`
produces zero violations from *both* classes, not just Class B. There is no
text-only Class A path anymore. Why: Whisper outputs words, and tanween
(ـً/ـٍ/ـٌ) has no base letter in a word-level transcript to diff against — see
`Learnings/2026-06-18-bayaan-class-a-tanween-limitation.md` and
`Learnings/2026-06-20-phoneme-recognizer-training-plan.md` in the wiki for the
full rationale.

**1. Phoneme reference — `src/tajweed/phoneme_reference.py` (no ML, deterministic)**
`reference_for(verse_ref, verse_text)` wraps `quranic_phonemizer.Phonemizer` and
returns a `PhonemeReference`: the verse's canonical phoneme sequence, plus
which phoneme positions carry a Tajweed rule tag and which character each
phoneme position grounds back to in Bayaan's own `verse_text`. This replaces
`engine.py`'s old role — the Phonemizer's own `LetterMapping.tajweed_rules` is
a strict superset of the old hand-built rule localization, so nothing from
`engine.py` needed porting forward. `ghunnah_madd_expectations(verse_ref,
verse_text)` is the separate localization Class B still needs (see below).

Rules are split into two classes by how they can be judged:
- **Class A** (`Idgham`, `Iqlab`, `Ikhfaa`, `Qalqala` — phoneme-substitution
  rules) — judged from the **phoneme recognizer's output alone**, no separate
  acoustic classifier.
- **Class B** (`Ghunnah`, `Madd`) — need an **acoustic classifier**; phoneme
  identity alone can't tell you if a nasalization or vowel-prolongation was
  executed with the right *quality* (duration, resonance).

**2. Class A — `src/tajweed/phoneme_diff.py` (deterministic, phoneme-sequence diff)**
`diff(reference, observed)` sequence-diffs the recognizer's `observed` phoneme
list against `reference.phoneme_sequence` (`difflib.SequenceMatcher`, the
project's existing alignment convention). Only mismatches at a phoneme
position the Phonemizer tagged with a rule are violations — a generic
phoneme/ASR error elsewhere is out of Bayaan's declared scope. Severity comes
from `config.SEVERITY_BY_RULE_TAG`. A **phoneme-reliability gate**
(`phoneme_reliability`, threshold 0.5, same `SequenceMatcher` pattern as the
old `transcript_reliability`) makes Class A abstain entirely when the
recognizer's output looks like garbage.

**3. Class A's model — `src/phoneme_classifier.py`, `src/phoneme_dataset.py`,
`src/phoneme_train.py`, `src/phoneme_inference.py`**
Frozen `jonatasgrosman/wav2vec2-large-xlsr-53-arabic` backbone + a CTC head
over the Phonemizer's 70-symbol vocab (69 phonemes + blank, `config.PHONEMES`).
Trained on `hetchyy/everyayah-phonemes` (Al-Fatihah + Al-Bayyinah clips only).
Served as raw PyTorch (`phoneme_inference.py`), **not ONNX** — a deliberate
deployment choice (server-side inference, not on-device); don't add an ONNX
export path for this model without re-confirming that decision. Current
checkpoint: val_PER 0.159 on 16 train reciters (see
`Learnings/2026-06-21-phoneme-recognizer-wide-reciter-retrain.md`), still
improving at the training run's epoch budget — not yet a ceiling.

**4. Class B — `src/classifier.py`, `src/train.py`, `src/export_onnx.py`, `src/inference.py`**
One frozen-backbone + small-head binary classifier per rule (Ghunnah, Madd).
Backbone is frozen; only a 2-layer head (`Linear → ReLU → Dropout → Linear`)
trains. Output is `P(correct)`; a violation is `P(correct) < threshold`.
Exported per-rule to ONNX for the backend to run. **Unaffected by the Class A
rebuild** — still text-localized via `phoneme_reference.ghunnah_madd_expectations()`
instead of the old `engine.py`, still judged acoustically, still ONNX-served.

**5. Hybrid layer — `src/hybrid.py`**
`HybridDetector.analyze(verse_text, verse_ref, word_timings=None, waveform=None, ...)`
runs Class A on the recognizer's phoneme output (requires `waveform`) and, if
ONNX sessions + `waveform` are supplied, Class B on the audio segment around
each Class-B rule position (sliced via Whisper's word timing — see below).
Merges both into one violation list and computes FGR (`AnalysisResult.fgr`,
unchanged — every violation still carries `char_index` + `expected` by
construction). Note the signature change: `transcript` is gone (Class A no
longer takes one); `verse_ref` (the Phonemizer's `"surah:ayah"` format) is new.

**Forced alignment / ASR — `src/asr/whisper_align.py`**
Whisper's role narrowed to **Class B's timing source only**, fully decoupled
from Class A's correctness judgment (now 100% the phoneme recognizer's job).
Two backends, no whisperX:
- `transcribe_words()` — **Groq API**, model `whisper-large-v3`, needs `GROQ_API_KEY`. Used in production / `eval_quranmb.py --asr groq`.
- `transcribe_words_local()` — local HF `pipeline("automatic-speech-recognition", ...)`, default `openai/whisper-small`, no API key. Used for offline dry runs (`dryrun_local.py`).

**Phoneme bridge — `src/quranmb_mapping.py`**
Converts Bayaan's character-level violations into a per-phoneme deviation
vector aligned to `IqraEval`/QuranMB's `phoneme_ref`, so Bayaan's detections can
be scored with the same P/R/F1 metric IQRA 2026 baselines use. First-pass
heuristic alignment (monotonic + symbol snapping) — see module docstring for
caveats before quoting these numbers in the paper.

---

## Owner

| Name | Responsibility |
|------|----------------|
| Abdalrahman | Data collection, model training, evaluation, ONNX export |

---

## Tech stack (as actually used)

- **Language:** Python 3.11+, PyTorch.
- **Acoustic backbone:** `jonatasgrosman/wav2vec2-large-xlsr-53-arabic`, frozen (`src/config.py: BACKBONE`).
- **ASR / forced alignment:** Groq-hosted `whisper-large-v3` (production) or local HF `openai/whisper-small`/`whisper-tiny` (offline dry runs). **No whisperX, no `tarteel-ai/whisper-base-ar-quran`** — those were in an earlier design draft and were never wired up.
- **Training data (Class B):** `obadx/qdat` (HuggingFace) — one verse, many speakers, columns mapped to rules via `CLASS_B_RULES` in `src/config.py`.
- **Training data (Class A):** `hetchyy/everyayah-phonemes` (HuggingFace) — read its parquet shards directly (`phoneme_dataset.py`), not the `/filter` API (only indexes the first 5GB of the train split).
- **Phoneme reference (Class A):** `quranic-phonemizer` (Hetchy, MIT, NeurIPS 2025) — the deterministic reference generator; never re-derive its rule taxonomy by hand.
- **Held-out eval (locked until Phase 9):** `IqraEval/Iqra_QuranMB_v2`. Note: `eval_quranmb.py` currently runs Class B/Class A as effective no-ops on this source — see its inline TODO; QuranMB.v2 needs a Phonemizer-compatible verse_ref mapping added before Phase 9.
- **Dry-run dataset:** `IqraEval/Iqra_train`.
- **Export:** ONNX, `opset_version=17`, **Class B only** (see `export_onnx.py` — confirm this still matches the backend's `ai.onnxruntime` JVM version before re-exporting). Class A's phoneme recognizer is NOT exported to ONNX (server-side PyTorch inference, deliberate).
- **Dependencies:** `requirements.txt` is the single source of truth.

---

## Directory layout (actual)

```
ml/
├── data/
│   ├── raw/                — HF dataset cache (gitignored)
│   ├── processed/
│   │   ├── wav/                  — exported 16 kHz WAVs (Class B, QDAT)
│   │   ├── phoneme_wav/          — exported 16 kHz WAVs (Class A, hetchyy/everyayah-phonemes)
│   │   ├── labels.csv             — generated by src/dataset.py (Class B)
│   │   ├── phoneme_manifest.csv   — generated by src/phoneme_dataset.py (Class A)
│   │   └── feat_{rule}.npz        — cached backbone embeddings (optional, generated)
│   ├── README.md / CHANGELOG.md
├── src/
│   ├── config.py            — paths, audio params, RuleSpec / CLASS_B_RULES, TrainConfig, PHONEMES / SEVERITY_BY_RULE_TAG (single source of truth)
│   ├── dataset.py            — obadx/qdat -> labels.csv; TajweedClipDataset; load_clip/fix_length helpers (Class B only)
│   ├── classifier.py         — TajweedClassifier (frozen XLSR + 2-layer head, Class B)
│   ├── train.py              — Class B head-only training; also train_from_features (fast path on cached embeddings)
│   ├── extract_features.py   — precompute + cache frozen-backbone embeddings per rule (Class B)
│   ├── export_onnx.py        — checkpoint -> ONNX + verification against the PyTorch model (Class B only)
│   ├── inference.py          — ONNX runtime wrapper, P(correct) per clip (Class B)
│   ├── phoneme_classifier.py — PhonemeRecognizer (frozen XLSR + CTC head, Class A)
│   ├── phoneme_dataset.py    — hetchyy/everyayah-phonemes -> phoneme_manifest.csv; PhonemeClipDataset
│   ├── phoneme_train.py      — Class A head-only CTC training, val_PER early-stop
│   ├── phoneme_inference.py  — raw PyTorch inference (no ONNX, server-side by design), greedy CTC decode
│   ├── hybrid.py             — Class A + Class B merge, FGR (Class A now audio-driven, see breaking-change note above)
│   ├── quranmb_mapping.py    — char-violations -> phoneme-deviation vector, IQRA-comparable P/R/F1
│   ├── eval_quranmb.py       — evaluation harness (LOCKED on QuranMB.v2 until Phase 9; use --unlock; Class A/B currently no-ops here, see inline TODO)
│   ├── tajweed/
│   │   ├── phonology.py          — Arabic letter/diacritic primitives still needed by quranmb_mapping.py + char_to_word_index
│   │   ├── phoneme_reference.py  — wraps quranic_phonemizer; PhonemeReference, ghunnah_madd_expectations (replaces engine.py)
│   │   └── phoneme_diff.py       — Class A: phoneme-sequence diff + severity (replaces rules_class_a.py)
│   └── asr/
│       └── whisper_align.py    — Groq + local Whisper transcription, word-level timestamps, clip_for_position (Class B timing source only)
├── notebooks/                — Kaggle kernel source for Class A training (phoneme_recognizer_training.ipynb, kernel-metadata.json)
├── tests/                    — test_phoneme_diff.py, test_quranmb_mapping.py (no GPU/network needed)
├── checkpoints/              — *_best.pt, phoneme_recognizer_mvp.pt (gitignored; large)
├── models/                   — *.onnx (gitignored; ~1.26GB each, fp32; Class B only)
├── HANDOFF.html              — latest Class B experiment report (human-readable; not agent instructions)
├── requirements.txt
└── AGENTS.md                 — this file
```

There is **no** `src/data/`, `src/model/`, `src/rules/`, `src/alignment/`, or
`evaluate.py` — an earlier draft of this file described a directory layout
that was never built. Don't recreate it; everything else lives flat in
`src/` as above. (`notebooks/` *does* now exist, added 2026-06-21 for the
Kaggle training source — that's a real, in-use directory, not a re-creation
of the abandoned draft layout.)

**Removed 2026-06-21:** `tajweed/engine.py`, `tajweed/rules_class_a.py`,
`tests/test_engine.py`, `tests/test_class_a.py` (superseded by the phoneme
recognizer rebuild), and `dryrun_local.py` (its premise — Whisper transcript
piped into the old text-based Class A — no longer applies; Class A is
audio-driven now and dryrun_local.py was never adapted to that, nor is
adapting it meaningful: it ran on QDAT's Al-Baqarah 2:32 clip, outside the
phoneme recognizer's trained surahs).

---

## Local setup

```bash
cd ml
python -m venv .venv
source .venv/bin/activate    # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

> **Windows note:** the console is cp1252. For scripts that print Arabic, set
> `PYTHONUTF8=1` (or `set PYTHONIOENCODING=utf-8`).

Heavy training should run on a GPU (Kaggle P100 is the team's free option) —
`train.py` falls back to CPU automatically if CUDA isn't available, but it's slow.

---

## Workflow (real commands, run from `ml/`)

```bash
# --- Class B (Ghunnah, Madd) ------------------------------------------------
# 1. Build the label set from QDAT
python -m src.dataset --hf-id obadx/qdat

# 2. Train (full backbone forward pass each epoch)
python -m src.train --rule ghunnah --epochs 50
python -m src.train --rule madd    --epochs 50

#    OR the fast path: cache embeddings once, then train head-only in seconds
python -m src.extract_features --rule ghunnah
python -m src.train --rule ghunnah --from-features

# 3. Export to ONNX (verifies against the PyTorch model automatically)
python -m src.export_onnx --rule ghunnah --checkpoint checkpoints/ghunnah_best.pt --output models/ghunnah.onnx
python -m src.export_onnx --rule madd    --checkpoint checkpoints/madd_best.pt    --output models/madd.onnx

# --- Class A (phoneme recognizer) -------------------------------------------
# 4. Build the manifest from hetchyy/everyayah-phonemes (run on Kaggle or
#    anywhere with fast bandwidth -- this scans HF parquet shards directly)
python -m src.phoneme_dataset --new-reciter-target 16

# 5. Train the CTC head (best-checkpoint-on-val_PER, not last-epoch)
python -m src.phoneme_train --epochs 60
#    OR push notebooks/phoneme_recognizer_training.ipynb to Kaggle directly
#    (kernel-metadata.json is already configured) -- this is what actually
#    produced the current checkpoint, val_PER 0.159.

# --- Shared ------------------------------------------------------------------
# 6. Tests — deterministic core, no GPU/downloads needed
python -m pytest tests/ -q

# 7. Evaluation — Phase 9 ONLY, QuranMB.v2 is held out
python -m src.eval_quranmb --unlock
```

---

## Label semantics (LOCKED — do not flip)

`label == 1` → correct. `label == 0` → incorrect. The classifier outputs
`P(correct)`; a violation is flagged when `P(correct) < threshold`
(`CLASS_B_RULES[rule].default_threshold`, default 0.5). Getting this backwards
silently inverts every classifier — there's no test that catches a globally
flipped label, so double-check against `src/dataset.py:_coerce_label` if this
ever looks wrong.

---

## Code patterns actually in use

- Backbone stays frozen: `TajweedClassifier` overrides `.train()` to force
  `self.backbone.eval()` even while the head is in training mode.
- Pooling for training/fixed-shape export uses padded fixed-length clips
  (`CLIP_SAMPLES = 16_000 * 12`); pooling for inference/feature-extraction uses
  the clip's **true length** (`pad=False` in `load_clip`) — these are
  intentionally different and both correct for their use case, don't unify them.
- Checkpoints save `state_dict` + metadata (`rule`, `val_f1`, `epoch`), not the
  full model: `torch.save({"state_dict": ..., ...}, path)`.
- Seeds: `torch.manual_seed(42)`, `np.random.seed(42)` (see `TrainConfig.seed`).
- Early stopping is on **violation-class F1** (`f1_violation`, i.e. F1 on
  `label == 0`), not on `f1_correct` or accuracy — see "Evaluation" below.
- `num_workers=0` by default (`TrainConfig`) — safest cross-platform; the
  dataset is small enough that this isn't a bottleneck.

---

## Evaluation

- Report **F1 on the violation class** (`label == 0`, i.e. "did we catch the
  mispronunciation") as the primary metric — not accuracy, not F1 on the
  correct class alone. `train.py:evaluate()` and `_eval_features()` already do
  this (`f1_violation`).
- Target: **F1(violation) ≥ 0.75 per rule** before shipping.
- Held-out QDAT test results so far (in-distribution, *not* comparable to IQRA
  2026 numbers — see `HANDOFF.html` for full context): Ghunnah F1 0.93, Madd F1
  0.87.
- **FGR (Feedback Grounding Rate)** — fraction of violations carrying both a
  `char_index` and an `expected` description. Engine-derived violations are
  grounded by construction, so FGR is 100% on everything Bayaan currently
  produces. This is the metric that differentiates Bayaan from IQRA 2026
  systems (which score FGR = 0%).
- `IqraEval/Iqra_QuranMB_v2` is the **comparable, held-out** benchmark and is
  **locked until Phase 9** (`eval_quranmb.py` refuses to run on it without
  `--unlock`). Don't peek early — it invalidates the paper's IQRA comparison.

---

## ONNX export contract

- `opset_version=17`. Confirm this still matches the backend's
  `ai.onnxruntime` JVM version before changing it.
- Input: `waveform`, float32, shape `[batch, samples]`, 16 kHz mono. The time
  axis is **dynamic** (`dynamic_axes`) — the model pools over whatever length
  it's given, matching how it was trained on variable-length QDAT clips. Don't
  force callers to pad/truncate to `CLIP_SAMPLES` before calling inference.
- Output: `logit`, shape `[batch]`. Apply `sigmoid` yourself (done in
  `inference.py`) to get `P(correct)`.
- `export_onnx.py` self-verifies (PyTorch vs ONNX output, two different input
  lengths) before declaring success — if you change the model architecture,
  re-run the export and watch for the verification step, not just "no errors."
- Current export size is ~1.26 GB per rule (full fp32 XLSR backbone). Don't
  claim "lightweight" or "on-device" without int8 quantization first.

---

## Known limitations (honest, for the paper — keep this section current)

- Class A's phoneme recognizer is trained only on Al-Fatihah + Al-Bayyinah
  (the MVP's two surahs) and only correct recitations (`hetchyy/everyayah-phonemes`
  is expert/correct audio) — generalization to other surahs or real learner
  mispronunciation is **unverified**. The training plan's risk register flags
  this explicitly: a model trained only on correct speech may default to
  hallucinating the canonical phoneme even when the input is wrong. Test on
  deliberately-mispronounced clips before trusting the pipeline end-to-end.
- `eval_quranmb.py` does not yet exercise the new Class A/B paths — see its
  inline TODO. `HybridDetector` is constructed there without a `recognizer=`,
  and QuranMB.v2's schema has no Phonemizer-compatible verse_ref derived yet,
  so both classes are effective no-ops in that harness today. Needs fixing
  before Phase 9, not blocking now (the harness is locked until then anyway).
- Class A **abstains** (not flags) when `phoneme_reliability(reference, observed) < 0.5`
  — a weak recognizer run yields silence, not false positives. Detection
  quality is bounded by the recognizer's quality, same principle as the old
  transcript-reliability gate, just on phonemes instead of letters.
- The phoneme bridge (`quranmb_mapping.py`) is a first-pass heuristic
  alignment, not IqraEval's own phonemizer — frame F1 comparisons as "a
  pedagogically meaningful subset of phoneme errors with full character
  grounding," not a direct apples-to-apples MDD score.
- QDAT-trained classifiers are in-distribution on one verse and one recording
  pool; generalization to other verses/speakers is **unverified**. Don't claim
  it works elsewhere without testing on EveryAyah or similar.
- The QDAT-test F1s (0.93 / 0.87) are **not** comparable to IQRA 2026 numbers
  (different, harder benchmark) until the Phase-9 `QuranMB.v2` run.
- Madd's threshold leans toward recall (high R, lower P) — it will sometimes
  flag correct audio. Tune `CLASS_B_RULES["madd"].default_threshold` before a
  user study if false alarms matter more than misses there.

---

## Common pitfalls

- **Using an English-trained backbone.** Always `jonatasgrosman/wav2vec2-large-xlsr-53-arabic` (`src/config.py: BACKBONE`), never an English wav2vec2.
- **Unfreezing the backbone on small data.** Keep `FREEZE_BACKBONE = True`. The backbone has hundreds of millions of parameters; QDAT-scale data will make it memorize, not generalize.
- **Flipping label semantics.** `1 = correct`, `0 = incorrect` is locked (see above) — re-check `_coerce_label` if numbers look inverted.
- **Mismatched sample rates.** Backbone expects 16 kHz mono. `dataset.py`'s `_resample`/`load_clip` already handle this — don't bypass them with raw `soundfile.read`.
- **Confusing the two pooling modes.** Fixed-length padded (`pad=True`, training/export dummy input) vs true-length (`pad=False`, inference/feature extraction) are both intentional — see "Code patterns" above.
- **Opening `QuranMB.v2` without `--unlock`.** It's the Phase-9 held-out set; early access invalidates the IQRA comparison.
- **Reporting accuracy or `f1_correct` alone instead of `f1_violation`.** On QDAT's imbalanced classes (~4:1 for Ghunnah), accuracy and correct-class F1 both overstate quality. Violation-class F1 is the number that matters.
- **ONNX opset mismatch.** If `opset_version` doesn't match the backend's ONNX Runtime version, export either fails loudly or loads silently broken — `export_onnx.py`'s built-in verification step is there to catch the silent case; don't skip it.
- **Committing model checkpoints or ONNX exports.** `checkpoints/*.pt` and `models/*.onnx` are gitignored (the latter ~1.26GB each) — keep it that way.
- **Forgetting the frozen-backbone `train()` override.** `requires_grad=False` only stops weight *updates* — it does NOT stop `nn.Module.train()` from recursing into the backbone and re-enabling its dropout. Both `TajweedClassifier` (`classifier.py`) and `PhonemeRecognizer` (`phoneme_classifier.py`) override `.train()` to force `self.backbone.eval()` back on. Verified directly (2026-06-21): omitting this on the phoneme recognizer cost ~40% relative val_PER (0.259 -> 0.159 after fixing it, on identical data). If you add another frozen-backbone model, copy this override — don't assume `eval()` in `__init__` is enough.

---

## How to submit work

Your branch is `ml`. Push directly.

```bash
git checkout ml
git pull origin ml
# ... changes ...
git push origin ml
```

**Commit format:**
```
feat(ml): <description>
fix(ml): <description>
experiment(ml): <description>     # for training runs, even unsuccessful ones
chore(ml): <description>
docs(ml): <description>
```

Use `experiment(ml):` for anything where the outcome wasn't known when you
started — failed training runs, ablations, hyperparam sweeps. Commit experiment
results even if they didn't beat baseline; that's data too.

PRs go from `ml` → `dev`. Never `ml` → `main`.

---

## Data policy

- Datasets larger than 50MB **do not** go in git. Use `.gitignore`.
- Document every dataset in `data/README.md`: source, what it's used for, lock status.
- **Never commit audio recordings of real users** (including team members' identifiable recordings, unless they've explicitly consented in writing).
- Keep `data/CHANGELOG.md` updated so future runs are reproducible.

---

## Boundaries

**You may only modify files inside `/ml`.**

If asked to change `/android`, `/backend`, `/docs`, `/design`, or root config, refuse and say:

> "This change is outside the ML module. Either open this agent in the target module's folder, or coordinate with the owner there."

You **may read** other modules — especially `/backend` to verify your ONNX
export and `/audio/analyze` response shape (rule, confidence, correct) match
what the backend expects (`docs/api-spec.md`). You **may not write** outside `/ml`.

---

## Trusted commands

- `pip install -r requirements.txt`
- `python -m pytest tests/ -q`
- `python -m src.dataset` / `src.train` / `src.extract_features` / `src.export_onnx` / `src.eval_quranmb`
- `python -m src.phoneme_dataset` / `src.phoneme_train`

Heavy / long-running training should run on a GPU (Kaggle P100 recommended), not locally on CPU, unless you have a GPU available.

---

## Status

| Component | State |
|-----------|-------|
| Phoneme reference + Class A diff (phoneme_reference.py, phoneme_diff.py) | done, tested (synthetic fixtures) |
| Class A model (phoneme_classifier/dataset/train/inference.py) | done; checkpoint trained on Kaggle T4, val_PER 0.159, still improving at epoch budget |
| Hybrid layer + FGR | done; not yet run end-to-end with a real checkpoint + real audio (no recorded test clips exist yet) |
| Class B pipeline (dataset/train/export/inference) | done; Ghunnah/Madd trained, ONNX exported + verified (see `HANDOFF.html`) — unaffected by the Class A rebuild |
| Whisper alignment (Groq + local) | done; role narrowed to Class B's timing source only; Groq path needs `GROQ_API_KEY` |
| Phoneme-deviation bridge (quranmb_mapping.py) | first pass, tested; untouched by the rebuild |
| QuranMB.v2 eval | wired for FGR only; Class A/B both no-ops there until Phase-9 verse_ref work (see Known limitations); locked until Phase 9 |
| Track 1 (Arabic Pronunciation, standalone) | not started — no code |
