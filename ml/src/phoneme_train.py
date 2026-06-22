"""Train the Class A phoneme recognizer (frozen backbone + CTC head).

    python -m src.phoneme_dataset                 # build the manifest once
    python -m src.phoneme_train --epochs 60

Tracks validation PER (phoneme error rate), not F1 -- this is a sequence
recognition task, not binary classification. val_PER was still trending
down at the 60-epoch cutoff in the last run (0.159, see
Learnings/2026-06-21-phoneme-recognizer-wide-reciter-retrain.md) -- more
epochs is a cheap lever if a future run needs a lower PER.
"""
from __future__ import annotations

import argparse

import editdistance
import torch
import torch.nn as nn
from torch.utils.data import DataLoader

from . import config as C
from .phoneme_classifier import PhonemeRecognizer
from .phoneme_dataset import PhonemeClipDataset, collate


def _loader(split: str, batch_size: int) -> DataLoader:
    ds = PhonemeClipDataset(split)
    return DataLoader(ds, batch_size=batch_size, shuffle=(split == "train"), collate_fn=collate)


def greedy_ctc_decode(logits: torch.Tensor) -> list[int]:
    """logits: (T, vocab_size) for one clip -> collapsed phoneme id sequence."""
    ids = logits.argmax(dim=-1).tolist()
    out, prev = [], None
    for i in ids:
        if i != prev and i != C.PHONEME_BLANK_ID:
            out.append(i)
        prev = i
    return out


@torch.no_grad()
def evaluate(model: PhonemeRecognizer, loader: DataLoader, device: str) -> float:
    """Phoneme error rate: total edit distance / total reference length."""
    model.eval()
    total_edits, total_len = 0, 0
    for wav, _wav_lens, tgt, tgt_lens in loader:
        wav = wav.to(device)
        logits = model(wav)
        offset = 0
        for b in range(wav.shape[0]):
            pred = greedy_ctc_decode(logits[b])
            ref = tgt[offset:offset + tgt_lens[b]].tolist()
            offset += tgt_lens[b]
            total_edits += editdistance.eval(pred, ref)
            total_len += len(ref)
    return total_edits / max(total_len, 1)


def train(
    epochs: int = 60, lr: float = 1e-3, batch_size: int = 8,
    patience: int = 10, device: str = "cuda", seed: int = 42,
):
    torch.manual_seed(seed)

    dev = device if (device == "cpu" or torch.cuda.is_available()) else "cpu"
    if dev != device:
        print(f"[phoneme-train] CUDA unavailable -> falling back to {dev}")

    train_ld = _loader("train", batch_size)
    val_ld = _loader("dev", batch_size)
    print(f"[phoneme-train] train batches: {len(train_ld)}, dev batches: {len(val_ld)}")

    model = PhonemeRecognizer().to(dev)
    n_trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f"[phoneme-train] trainable params (head only): {n_trainable:,}")

    criterion = nn.CTCLoss(blank=C.PHONEME_BLANK_ID, zero_infinity=True)
    optimizer = torch.optim.AdamW(model.head.parameters(), lr=lr)

    best_per, best_state, no_improve = float("inf"), None, 0
    ckpt = C.CHECKPOINT_DIR / "phoneme_recognizer_mvp.pt"

    for epoch in range(1, epochs + 1):
        model.train()
        total_loss = 0.0
        for wav, _wav_lens, tgt, tgt_lens in train_ld:
            wav, tgt = wav.to(dev), tgt.to(dev)
            logits = model(wav)
            log_probs = logits.log_softmax(dim=-1).transpose(0, 1)
            # backbone may subsample time steps internally; assume uniform stride across the batch
            input_lens = torch.full((wav.shape[0],), logits.shape[1], dtype=torch.long)
            loss = criterion(log_probs, tgt, input_lens, tgt_lens)
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
            total_loss += loss.item()

        val_per = evaluate(model, val_ld, dev)
        print(f"[phoneme-train] epoch {epoch:3d} | train_loss {total_loss / len(train_ld):.3f} | val_PER {val_per:.3f}")

        if val_per < best_per:
            best_per = val_per
            best_state = {k: v.cpu().clone() for k, v in model.state_dict().items()}
            no_improve = 0
        else:
            no_improve += 1
            if no_improve >= patience:
                print(f"[phoneme-train] early stop at epoch {epoch} (best val_PER {best_per:.3f})")
                break

    model.load_state_dict(best_state)
    torch.save({
        "head_state_dict": model.head.state_dict(),
        "phon_to_id": C.PHON_TO_ID,
        "vocab_size": C.PHONEME_VOCAB_SIZE,
        "blank_id": C.PHONEME_BLANK_ID,
        "backbone": C.BACKBONE,
        "best_val_per": best_per,
    }, ckpt)
    print(f"[phoneme-train] best val_PER = {best_per:.3f} -> {ckpt}")
    return ckpt


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--epochs", type=int, default=60)
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--batch-size", type=int, default=8)
    ap.add_argument("--patience", type=int, default=10)
    ap.add_argument("--device", default="cuda")
    args = ap.parse_args()
    train(epochs=args.epochs, lr=args.lr, batch_size=args.batch_size,
          patience=args.patience, device=args.device)


if __name__ == "__main__":
    main()
