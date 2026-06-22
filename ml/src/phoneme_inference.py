"""Raw PyTorch inference for the Class A phoneme recognizer.

No ONNX -- deployment decision: this model serves server-side, not
on-device, so the ONNX-export contract that Class B's classifiers need
doesn't apply here (see /home/jade/.claude/plans/serialized-baking-cat.md).

    rec = load_model("checkpoints/phoneme_recognizer_mvp.pt")
    phonemes = predict_phonemes(rec, waveform)   # -> list[str]
"""
from __future__ import annotations

from pathlib import Path

import torch

from . import config as C
from .phoneme_classifier import PhonemeRecognizer
from .phoneme_train import greedy_ctc_decode


def load_model(checkpoint_path: Path | str, device: str = "cpu") -> PhonemeRecognizer:
    ckpt = torch.load(checkpoint_path, map_location=device, weights_only=True)
    model = PhonemeRecognizer(backbone_name=ckpt["backbone"], vocab_size=ckpt["vocab_size"]).to(device)
    model.head.load_state_dict(ckpt["head_state_dict"])
    model.eval()
    return model


@torch.no_grad()
def predict_phonemes(model: PhonemeRecognizer, waveform, device: str = "cpu") -> list[str]:
    """waveform: 16 kHz mono float32 array-like -> phoneme list (greedy CTC
    decode -- beam search is a production nicety, not MVP-required)."""
    wav = torch.as_tensor(waveform, dtype=torch.float32, device=device)[None, :]
    logits = model(wav)[0]  # (T, vocab_size)
    ids = greedy_ctc_decode(logits)
    return [C.ID_TO_PHON[i] for i in ids]
