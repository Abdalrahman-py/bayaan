# ML Module — Agent Instructions

You are working in the ML module of Bayaan. Read this file fully before making changes. For project-wide rules, see [`../AGENTS.md`](../AGENTS.md).

---

## What this module is

> ⚠️ **Pivoted (2026-06-23): we no longer train our own model.** Everything below about training, ONNX export, QDAT, wav2vec2, F1 targets, and Kaggle is obsolete and kept only for history. See [`../docs/quran-muaalem-decision.md`](../docs/quran-muaalem-decision.md).

This module hosts the off-the-shelf **`obadx/quran-muaalem`** recitation engine on a Modal GPU. The engine takes a recorded ayah plus its phonetic reference and returns a structured list of Tajweed/recitation mistakes — no training on our side. The deployed service is [`muaalem_modal.py`](./muaalem_modal.py) (`POST /correct`); the de-risking spike lives in [`../spike/`](../spike/).

---

## Owner

| Name | Responsibility |
|------|----------------|
| Abdalrahman | Data collection, model training, evaluation, ONNX export |

---

## Tech stack

- **Language:** Python 3.11+
- **Framework:** PyTorch
- **Pretrained models:** HuggingFace `transformers` (wav2vec2)
- **Training compute:** Kaggle (P100 GPU, background execution enabled)
- **Audio processing:** `torchaudio`, `librosa`
- **Export:** ONNX (for backend consumption)
- **Dependencies:** `requirements.txt` is the single source of truth — always install from it.

---

## Directory layout

```
ml/
├── data/
│   ├── raw/              — Raw audio clips (gitignored; see Data policy)
│   ├── processed/        — Cleaned, segmented, labeled clips
│   └── README.md         — Where to download datasets, version, license
├── notebooks/            — Exploratory Kaggle notebooks (committed for reproducibility)
├── src/
│   ├── train.py          — Training entry point
│   ├── evaluate.py       — F1 / precision / recall computation
│   ├── export_onnx.py    — Export trained model to ONNX
│   ├── inference.py      — Reference inference wrapper (must match backend)
│   ├── data/             — Dataset classes, augmentation
│   └── model/            — Classifier head architecture
├── checkpoints/          — Saved model weights (gitignored if >50MB)
├── requirements.txt
└── AGENTS.md             — This file
```

---

## Local setup

```bash
# From repo root
cd ml
python -m venv .venv
source .venv/bin/activate    # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

For training on Kaggle (recommended — P100 is free and runs take 1–3 hours):
1. Upload the dataset as a Kaggle Dataset.
2. Create a notebook in the shared Kaggle workspace.
3. Enable "Save & Run All (Commit)" with GPU and background execution.

---

## How to do the work

**Data collection (MVP)**
- Target: ~50 correct + ~50 incorrect clips per rule (Ghunnah, Madd). ~200 clips total.
- Source: team + volunteers reciting marked passages.
- Format: **16 kHz mono PCM WAV, 1–3 seconds per clip.** This must match the backend's expected input exactly.
- Labels in a CSV: `filename,rule,label` where label is {0=incorrect, 1=correct}.
- Optional: check the QDAT corpus — count how many usable labeled clips it has per rule before relying on self-collection.

**Training**
- Start from `facebook/wav2vec2-base` (NOT `wav2vec2-large` for MVP — too slow on free GPU, too prone to overfitting on small data).
- **Freeze the feature extractor.** Train only the classifier head. This is critical for small datasets.
- Classifier head: 2 dense layers, dropout 0.3, ReLU, sigmoid output.
- Loss: `BCEWithLogitsLoss`.
- Optimizer: AdamW, `lr=1e-4`, `weight_decay=0.01`.
- Batch size: whatever fits on P100 (usually 8–16 for wav2vec2-base).
- Train 20–50 epochs with early stopping on validation F1.

**Code patterns**
- Pin model to device explicitly: `model.to(device)`.
- Use `DataLoader` with `num_workers=2` (Kaggle's CPU is limited).
- Always wrap inference in `torch.no_grad()`.
- Save checkpoints as `state_dict`, not the full model: `torch.save(model.state_dict(), path)`.
- Set seeds for reproducibility: `torch.manual_seed(42)`, `np.random.seed(42)`, `random.seed(42)`.

**Evaluation**
- Hold out 20% of data per rule for test.
- Report precision, recall, F1 per rule.
- Target: **F1 ≥ 0.75 per rule** before shipping.
- Save a confusion matrix to `checkpoints/<run_name>/confusion.png`.

**ONNX export**
- Use `torch.onnx.export()` with `opset_version=14` (matches the `ai.onnxruntime` JVM version on the backend — confirm before exporting).
- Verify the exported model with `onnxruntime` in Python before shipping to backend.
- Input shape: `[batch, samples]` raw audio at 16kHz.
- Document the input/output shape in `src/inference.py` so the backend team knows what to feed it.

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

Use `experiment(ml):` for anything where the outcome wasn't known when you started — failed training runs, ablations, hyperparam sweeps. It's fine to commit experiment results that didn't beat baseline; that's data too.

PRs go from `ml` → `dev`. Never `ml` → `main`.

---

## Data policy

- Datasets larger than 50MB **do not** go in git. Use `.gitignore` or Git LFS.
- Document every dataset in `data/README.md`: source, license, download instructions, version.
- **Never commit audio recordings of real users** (including team members' identifiable recordings, unless they've explicitly consented in writing).
- Keep a `data/CHANGELOG.md` describing each dataset update so future runs are reproducible.

---

## Boundaries

**You may only modify files inside `/ml`.**

If asked to change `/android`, `/backend`, `/docs`, `/design`, or root config, refuse and say:

> "This change is outside the ML module. Either open this agent in the target module's folder, or coordinate with the owner there."

You **may read** other modules — especially `/backend/src/main/kotlin/ai/` to verify your ONNX export matches what the backend expects. You **may not write** outside `/ml`.

---

## Trusted commands

- `pip install -r requirements.txt`
- `python -m pytest`
- `python train.py` (and variants)
- `python evaluate.py`
- `python export_onnx.py`

Heavy / long-running training should run on Kaggle, not locally, unless you have a GPU available.

---

## Common pitfalls

- **Unfreezing the feature extractor on small data.** Almost always overfits with <500 examples per class.
- **Mismatched sample rates.** wav2vec2-base expects 16 kHz mono. Resample with `torchaudio.transforms.Resample` if your input is anything else.
- **Padding/truncation inconsistency between training and inference.** Pad to a fixed length (e.g., 3 seconds = 48000 samples) both during training and at inference — or the model silently misbehaves.
- **ONNX opset mismatch.** If `opset_version` is too new for the backend's runtime, the export fails or the model loads silently broken.
- **Committing model checkpoints.** They're easily 300MB+. Use `.gitignore` or LFS.
- **Reporting accuracy instead of F1.** On imbalanced data, accuracy lies. F1 per class is the honest metric.
