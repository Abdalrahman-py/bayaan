"""Export a trained classifier to ONNX.

    python -m src.export_onnx --rule ghunnah \
        --checkpoint checkpoints/ghunnah_best.pt --output models/ghunnah.onnx

Input : float32 [1, 192000] (16 kHz mono, 12 s)
Output: single logit -> sigmoid -> P(correct)  (done in inference.py)
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import torch

from . import config as C
from .classifier import TajweedClassifier


def export(rule: str, checkpoint: Path, output: Path, opset: int = 17) -> Path:
    model = TajweedClassifier()
    ckpt = torch.load(checkpoint, map_location="cpu")
    model.load_state_dict(ckpt["state_dict"])
    model.eval()

    dummy = torch.zeros(1, C.CLIP_SAMPLES, dtype=torch.float32)
    output.parent.mkdir(parents=True, exist_ok=True)
    torch.onnx.export(
        model,
        dummy,
        str(output),
        input_names=["waveform"],
        output_names=["logit"],
        # time axis is dynamic: inference pools over the clip's true length,
        # matching how the head was trained (variable-length QDAT clips).
        dynamic_axes={"waveform": {0: "batch", 1: "samples"}, "logit": {0: "batch"}},
        opset_version=opset,
    )
    _verify(model, output)
    print(f"[export] {rule}: {checkpoint} -> {output}")
    return output


def _verify(torch_model, onnx_path: Path, tol: float = 1e-3) -> None:
    """Confirm ONNX output matches the PyTorch model on a random clip."""
    import onnxruntime as ort

    sess = ort.InferenceSession(str(onnx_path), providers=["CPUExecutionProvider"])
    # check two lengths to confirm the dynamic time axis really works
    for n in (C.CLIP_SAMPLES, 80_000):
        x = np.random.randn(1, n).astype(np.float32)
        with torch.no_grad():
            ref = torch_model(torch.from_numpy(x)).numpy()
        got = sess.run(["logit"], {"waveform": x})[0].reshape(-1)
        diff = float(np.max(np.abs(ref - got)))
        if diff > tol:
            raise RuntimeError(f"ONNX/torch mismatch @n={n}: max|diff|={diff:.5f} > {tol}")
        print(f"[export] verification ok @n={n} (max|diff|={diff:.2e})")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rule", required=True, choices=list(C.CLASS_B_RULES))
    ap.add_argument("--checkpoint", required=True, type=Path)
    ap.add_argument("--output", required=True, type=Path)
    args = ap.parse_args()
    export(args.rule, args.checkpoint, args.output)


if __name__ == "__main__":
    main()
