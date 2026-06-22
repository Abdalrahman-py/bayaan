"""Frozen-backbone wav2vec2 + CTC head — outputs the Quranic Phonemizer's
native 69-symbol phoneme inventory per frame. Same backbone/freezing
convention as `classifier.py`'s TajweedClassifier; the head is a CTC linear
layer over the full vocab instead of a pooled binary classifier, since this
is sequence recognition (Class A), not pooled binary judgment (Class B).
"""
from __future__ import annotations

import torch
import torch.nn as nn
from transformers import Wav2Vec2Model

from . import config as C


class PhonemeRecognizer(nn.Module):
    def __init__(
        self,
        backbone_name: str = C.BACKBONE,
        freeze_backbone: bool = C.FREEZE_BACKBONE,
        vocab_size: int = C.PHONEME_VOCAB_SIZE,
    ):
        super().__init__()
        self.backbone = Wav2Vec2Model.from_pretrained(backbone_name)
        if freeze_backbone:
            self.backbone.eval()
            for p in self.backbone.parameters():
                p.requires_grad = False
        self.freeze_backbone = freeze_backbone
        self.head = nn.Linear(self.backbone.config.hidden_size, vocab_size)

    def train(self, mode: bool = True):
        """Keep the frozen backbone in eval mode even during head training --
        same fix as TajweedClassifier.train() (classifier.py). Verified
        2026-06-21 that omitting this silently reactivates the backbone's
        dropout each epoch, costing ~40% relative val_PER on this exact
        backbone (see Learnings/2026-06-21-phoneme-recognizer-wide-reciter-retrain.md)."""
        super().train(mode)
        if self.freeze_backbone:
            self.backbone.eval()
        return self

    def forward(self, waveform: torch.Tensor) -> torch.Tensor:
        """waveform: (B, samples) -> logits (B, T, vocab_size). Raw logits,
        not log-probabilities -- nn.CTCLoss expects log_softmax applied at
        loss time, and greedy decode just needs argmax (monotonic either way)."""
        ctx = torch.no_grad() if self.freeze_backbone else torch.enable_grad()
        with ctx:
            hidden = self.backbone(waveform).last_hidden_state  # (B, T, H)
        return self.head(hidden)
