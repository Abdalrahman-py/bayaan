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

**1. Tajweed Engine — `src/tajweed/engine.py` (no ML, deterministic)**
`TajweedEngine.expected(verse_text)` reads diacritized Quranic text and returns
every rule position as an `Expectation(rule, rule_class, char, char_index, ...)`.
It *localizes* rules; it never judges correctness. This is the foundation of FGR:
every downstream violation inherits a `char_index` from here.

Rules are split into two classes by how they can be judged:
- **Class A** (`Izhar`, `Idgham`, `Iqlab`, `Ikhfaa` — the noon-sakinah/tanween
  family) — judged from the **ASR transcript alone**, no audio model needed.
- **Class B** (`Ghunnah`, `Madd`) — need an **acoustic classifier**; text alone
  can't tell you if a nasalization or vowel-prolongation was executed correctly.

**2. Class A — `src/tajweed/rules_class_a.py` (deterministic, transcript-based)**
`RuleEngine.analyze(verse_text, transcript)` compares what the engine expects
against the ASR transcript's base letters at each rule position and returns
`Violation` objects. Honest limitation (see module docstring): this is reliable
for *explicit-noon* cases but tanween/Iqlab realizations aren't distinguishable
from an orthographic transcript — those defer to the acoustic path. A
**transcript-reliability gate** (`transcript_reliability`, threshold 0.5,
letter-skeleton similarity) makes Class A abstain entirely when the ASR output
looks like garbage, so a bad ASR run produces silence, not false accusations.

**3. Class B — `src/classifier.py`, `src/train.py`, `src/export_onnx.py`, `src/inference.py`**
One frozen-backbone + small-head binary classifier per rule (Ghunnah, Madd).
Backbone is frozen; only a 2-layer head (`Linear → ReLU → Dropout → Linear`)
trains. Output is `P(correct)`; a violation is `P(correct) < threshold`.
Exported per-rule to ONNX for the backend to run.

**4. Hybrid layer — `src/hybrid.py`**
`HybridDetector.analyze(...)` runs Class A on the transcript and, if ONNX
sessions + a waveform are supplied, Class B on the audio segment around each
Class-B rule position (sliced via word timing from the ASR — see below). Merges
both into one violation list and computes FGR (`AnalysisResult.fgr`).

**Forced alignment / ASR — `src/asr/whisper_align.py`**
Whisper is the **only** aligner (word-level timestamps drive both Class A's
word lookup and Class B's audio slicing). Two backends, no whisperX:
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
- **Training data:** `obadx/qdat` (HuggingFace) — one verse, many speakers, columns mapped to rules via `CLASS_B_RULES` in `src/config.py`.
- **Held-out eval (locked until Phase 9):** `IqraEval/Iqra_QuranMB_v2`.
- **Dry-run dataset:** `IqraEval/Iqra_train`.
- **Export:** ONNX, `opset_version=17` (see `export_onnx.py` — confirm this still matches the backend's `ai.onnxruntime` JVM version before re-exporting).
- **Dependencies:** `requirements.txt` is the single source of truth.

---

## Directory layout (actual)

```
ml/
├── data/
│   ├── raw/                — HF dataset cache (gitignored)
│   ├── processed/
│   │   ├── wav/              — exported 16 kHz WAVs
│   │   ├── labels.csv         — generated by src/dataset.py
│   │   └── feat_{rule}.npz    — cached backbone embeddings (optional, generated)
│   ├── README.md / CHANGELOG.md
├── src/
│   ├── config.py            — paths, audio params, RuleSpec / CLASS_B_RULES, TrainConfig (single source of truth)
│   ├── dataset.py            — obadx/qdat -> labels.csv; TajweedClipDataset; load_clip/fix_length helpers
│   ├── classifier.py         — TajweedClassifier (frozen XLSR + 2-layer head)
│   ├── train.py              — head-only training; also train_from_features (fast path on cached embeddings)
│   ├── extract_features.py   — precompute + cache frozen-backbone embeddings per rule
│   ├── export_onnx.py        — checkpoint -> ONNX + verification against the PyTorch model
│   ├── inference.py          — ONNX runtime wrapper, P(correct) per clip
│   ├── hybrid.py             — Class A + Class B merge, FGR
│   ├── quranmb_mapping.py    — char-violations -> phoneme-deviation vector, IQRA-comparable P/R/F1
│   ├── eval_quranmb.py       — evaluation harness (LOCKED on QuranMB.v2 until Phase 9; use --unlock)
│   ├── dryrun_local.py       — offline end-to-end sanity check on local QDAT WAVs (no HF streaming)
│   ├── tajweed/
│   │   ├── phonology.py        — Arabic letter/diacritic primitives, Letter parsing
│   │   ├── engine.py           — TajweedEngine: rule localization (text only)
│   │   └── rules_class_a.py    — RuleEngine: Class A violation detection + reliability gate
│   └── asr/
│       └── whisper_align.py    — Groq + local Whisper transcription, word-level timestamps, clip_for_position
├── tests/                    — test_engine.py, test_class_a.py, test_quranmb_mapping.py (25 tests, no GPU/network needed)
├── checkpoints/              — *_best.pt (gitignored; large)
├── models/                   — *.onnx (gitignored; ~1.26GB each, fp32)
├── HANDOFF.html              — latest Class B experiment report (human-readable; not agent instructions)
├── requirements.txt
└── AGENTS.md                 — this file
```

There is **no** `notebooks/`, `src/data/`, `src/model/`, `src/rules/`, `src/alignment/`,
or `evaluate.py` — an earlier draft of this file described a directory layout that
was never built. Don't recreate it; everything lives flat in `src/` as above.

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

# 4. Tests — deterministic core, no GPU/downloads needed
python -m pytest tests/ -q

# 5. Offline sanity check (real Whisper -> Class A -> engine, on local QDAT WAVs)
python -m src.dryrun_local --limit 5 --asr-model openai/whisper-tiny

# 6. Evaluation — Phase 9 ONLY, QuranMB.v2 is held out
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

- Class A is reliable for explicit-noon cases; tanween and Iqlab realizations
  aren't distinguishable from an orthographic transcript alone and defer to
  the acoustic path / a future phonetic transcript.
- Class A **abstains** (not flags) when `transcript_reliability(verse, transcript) < 0.5`
  — a weak ASR yields silence, not false positives. Detection quality is
  bounded by ASR quality.
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
- `python -m src.dataset` / `src.train` / `src.extract_features` / `src.export_onnx` / `src.eval_quranmb` / `src.dryrun_local`

Heavy / long-running training should run on a GPU (Kaggle P100 recommended), not locally on CPU, unless you have a GPU available.

---

## Status

| Component | State |
|-----------|-------|
| Tajweed engine (localization) | done, tested |
| Class A rule detection | done, tested (explicit-noon cases) |
| Hybrid layer + FGR | done, tested |
| Class B pipeline (dataset/train/export/inference) | done; Ghunnah/Madd trained, ONNX exported + verified (see `HANDOFF.html`) |
| Whisper alignment (Groq + local) | done; Groq path needs `GROQ_API_KEY` |
| Phoneme-deviation bridge | first pass, tested |
| QuranMB.v2 eval | wired; locked until Phase 9 |
| Track 1 (Arabic Pronunciation, standalone) | not started — no code |
