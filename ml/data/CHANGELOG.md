# Data Changelog

## [Unreleased]

- `obadx/qdat` wired up as the Class B training source (`src/dataset.py`); exports
  16 kHz WAVs + stratified train/val/test `labels.csv` per rule (Ghunnah, Madd).
- Class B classifiers trained on QDAT and exported to ONNX (Ghunnah F1 0.93, Madd
  F1 0.87 on QDAT's held-out test split — see `HANDOFF.html` for the full report).
  Checkpoints/ONNX are gitignored (large); not necessarily present in every checkout.
- `IqraEval/Iqra_QuranMB_v2` identified as the Phase-9 held-out benchmark — locked
  in `src/eval_quranmb.py` until then.
