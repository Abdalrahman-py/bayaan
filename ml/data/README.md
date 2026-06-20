# Data

## Datasets

| Dataset | Source | Used for | License | Notes |
|---------|--------|----------|---------|-------|
| `obadx/qdat` | HuggingFace | Class B training (Ghunnah, Madd) | see HF card | One verse (Al-Baqarah 2:32), many speakers. Downloaded by `python -m src.dataset --hf-id obadx/qdat`. |
| `IqraEval/Iqra_train` | HuggingFace | Dry runs / ASR sanity checks | see HF card | Open to use any time. |
| `IqraEval/Iqra_QuranMB_v2` | HuggingFace | Held-out evaluation (Phase 9 only) | see HF card | **Locked** — see `src/eval_quranmb.py`. Do not open before Phase 9; it's the comparison set against IQRA 2026 baselines. |

## Format

All clips must be **16 kHz mono PCM WAV**. This matches the backbone's expected input exactly.
QDAT clips are 1–17s (variable length; the backbone pools over true length, see `src/config.py`).

`data/processed/labels.csv` schema: `filename,rule,label,split`
- `rule`: one of `ghunnah`, `madd` (see `CLASS_B_RULES` in `src/config.py`)
- `label`: `0` = incorrect, `1` = correct
- `split`: `train` | `val` | `test` (stratified per rule)

Written automatically by `src.dataset.prepare_labels()` — don't hand-edit.

## Directory structure

```
data/
├── raw/                 — HF dataset cache (gitignored)
├── processed/
│   ├── wav/              — Exported 16 kHz mono WAVs
│   ├── labels.csv         — Master label file (generated)
│   └── feat_{rule}.npz    — Cached frozen-backbone embeddings (generated, optional)
└── README.md / CHANGELOG.md
```

## Notes

- Never commit recordings of real users without explicit written consent.
- Trained checkpoints (`checkpoints/*.pt`) and exported ONNX models (`models/*.onnx`, ~1.26GB each) are gitignored — too large for git. See `HANDOFF.html` for the latest training run's results if the artifacts aren't present locally.
- See `CHANGELOG.md` for dataset version history.
