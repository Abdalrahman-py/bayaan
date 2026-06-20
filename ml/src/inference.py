"""ONNX inference runtime for Class B classifiers — used by the hybrid layer.

    inf = TajweedInference({"ghunnah": "models/ghunnah.onnx",
                            "madd":    "models/madd.onnx"})
    p = inf.predict("ghunnah", "clip.wav")   # -> P(correct) in [0, 1]
"""
from __future__ import annotations

from pathlib import Path

import numpy as np

from . import config as C
from .dataset import load_clip


def _sigmoid(x: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-x))


class TajweedInference:
    def __init__(self, model_paths: dict[str, str | Path]):
        import onnxruntime as ort

        self.sessions = {}
        for rule, path in model_paths.items():
            if not Path(path).exists():
                raise FileNotFoundError(f"ONNX model for '{rule}' not found: {path}")
            self.sessions[rule] = ort.InferenceSession(
                str(path), providers=["CPUExecutionProvider"]
            )

    def predict(self, rule: str, wav_path: str | Path) -> float:
        """P(correct) for one clip and one rule (pooled over true length,
        matching training)."""
        wav = load_clip(wav_path, pad=False).numpy().astype(np.float32)[None, :]
        return self.predict_array(rule, wav)

    def predict_array(self, rule: str, waveform: np.ndarray) -> float:
        if rule not in self.sessions:
            raise KeyError(f"No ONNX model loaded for rule '{rule}'")
        if waveform.ndim == 1:
            waveform = waveform[None, :]
        waveform = waveform.astype(np.float32)
        logit = self.sessions[rule].run(["logit"], {"waveform": waveform})[0]
        return float(_sigmoid(np.asarray(logit)).reshape(-1)[0])

    def is_violation(self, rule: str, wav_path: str | Path,
                     threshold: float | None = None) -> tuple[bool, float]:
        thr = threshold if threshold is not None else C.CLASS_B_RULES[rule].default_threshold
        p = self.predict(rule, wav_path)
        return (p < thr), p


def default_inference() -> "TajweedInference":
    """Load whatever ONNX models are present in models/."""
    paths = {
        rule: C.MODELS_DIR / f"{rule}.onnx"
        for rule in C.CLASS_B_RULES
        if (C.MODELS_DIR / f"{rule}.onnx").exists()
    }
    return TajweedInference(paths)
