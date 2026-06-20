"""Binary acoustic classifier: frozen wav2vec2-XLSR backbone + 2-layer head.

One small classifier per Class B rule. The backbone is frozen (large model +
small data), so only the head trains. Output is a single logit; sigmoid gives
P(correct).
"""
from __future__ import annotations

import torch
import torch.nn as nn
from transformers import Wav2Vec2Model

from . import config as C


class TajweedClassifier(nn.Module):
    def __init__(
        self,
        backbone_name: str = C.BACKBONE,
        freeze_backbone: bool = C.FREEZE_BACKBONE,
        head_hidden: int = C.HEAD_HIDDEN,
    ):
        super().__init__()
        self.backbone = Wav2Vec2Model.from_pretrained(backbone_name)
        hidden = self.backbone.config.hidden_size  # 1024 for xlsr-large

        if freeze_backbone:
            self.backbone.eval()
            for p in self.backbone.parameters():
                p.requires_grad = False

        self.freeze_backbone = freeze_backbone
        self.head = nn.Sequential(
            nn.Linear(hidden, head_hidden),
            nn.ReLU(),
            nn.Dropout(0.1),
            nn.Linear(head_hidden, 1),
        )

    def train(self, mode: bool = True):
        """Keep the frozen backbone in eval mode even during head training."""
        super().train(mode)
        if self.freeze_backbone:
            self.backbone.eval()
        return self

    def pool(self, waveform: torch.Tensor) -> torch.Tensor:
        """waveform: (B, samples) -> pooled backbone embedding (B, H).

        This is the exact input to the head, so caching pool() outputs and
        training the head on them is identical to end-to-end training (the
        backbone is frozen) — but far faster and fits a small GPU."""
        ctx = torch.no_grad() if self.freeze_backbone else torch.enable_grad()
        with ctx:
            hidden = self.backbone(waveform).last_hidden_state  # (B, T, H)
        return hidden.mean(dim=1)                               # mean-pool over time

    def forward_features(self, emb: torch.Tensor) -> torch.Tensor:
        """Pooled embedding (B, H) -> logits (B,)."""
        return self.head(emb).squeeze(-1)

    def forward(self, waveform: torch.Tensor) -> torch.Tensor:
        """waveform: (B, samples) float32 @ 16 kHz -> logits (B,)."""
        return self.forward_features(self.pool(waveform))

    @torch.no_grad()
    def predict_proba(self, waveform: torch.Tensor) -> torch.Tensor:
        """P(correct) per clip."""
        self.eval()
        return torch.sigmoid(self.forward(waveform))
