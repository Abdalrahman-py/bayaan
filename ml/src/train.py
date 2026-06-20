"""Train a Class B binary classifier (head-only) for one rule.

    python -m src.train --rule ghunnah --epochs 50
    python -m src.train --rule madd    --epochs 50

Target: val F1 >= 0.75 per rule. Saves checkpoints/{rule}_best.pt.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import torch
from sklearn.metrics import f1_score, precision_recall_fscore_support
from torch.utils.data import DataLoader

from . import config as C
from .classifier import TajweedClassifier
from .dataset import TajweedClipDataset


def _loader(rule: str, split: str, cfg: C.TrainConfig, labels_csv: Path) -> DataLoader:
    ds = TajweedClipDataset(rule, split, labels_csv)
    return DataLoader(
        ds,
        batch_size=cfg.batch_size,
        shuffle=(split == "train"),
        num_workers=cfg.num_workers,
        drop_last=(split == "train"),
    )


@torch.no_grad()
def evaluate(model, loader, device, threshold: float = 0.5):
    model.eval()
    ys, ps = [], []
    for wav, y in loader:
        prob = torch.sigmoid(model(wav.to(device))).cpu().numpy()
        ps.append(prob)
        ys.append(y.numpy())
    y = np.concatenate(ys)
    p = np.concatenate(ps)
    # F1 on the *violation* class (label==0 -> incorrect) is what matters for
    # mispronunciation detection; we report both for transparency.
    pred_correct = (p >= threshold).astype(int)
    f1_correct = f1_score(y, pred_correct, zero_division=0)
    f1_violation = f1_score(1 - y, 1 - pred_correct, zero_division=0)
    prec, rec, _, _ = precision_recall_fscore_support(
        y, pred_correct, average="binary", zero_division=0
    )
    return {
        "f1_correct": f1_correct,
        "f1_violation": f1_violation,
        "precision": prec,
        "recall": rec,
    }


def train(cfg: C.TrainConfig, labels_csv: Path) -> Path:
    torch.manual_seed(cfg.seed)
    np.random.seed(cfg.seed)
    device = cfg.device if (cfg.device == "cpu" or torch.cuda.is_available()) else "cpu"
    if device != cfg.device:
        print(f"[train] CUDA unavailable -> falling back to {device}")

    train_ld = _loader(cfg.rule, "train", cfg, labels_csv)
    val_ld = _loader(cfg.rule, "val", cfg, labels_csv)

    model = TajweedClassifier().to(device)
    params = [p for p in model.parameters() if p.requires_grad]
    print(f"[train] trainable params: {sum(p.numel() for p in params):,}")

    pos_weight = train_ld.dataset.pos_weight().to(device) if cfg.use_pos_weight else None
    criterion = torch.nn.BCEWithLogitsLoss(pos_weight=pos_weight)
    optim = torch.optim.AdamW(params, lr=cfg.lr, weight_decay=cfg.weight_decay)

    best_f1, best_epoch, since_improve = -1.0, -1, 0
    ckpt = C.CHECKPOINT_DIR / f"{cfg.rule}_best.pt"

    for epoch in range(1, cfg.epochs + 1):
        model.train()
        running = 0.0
        for wav, y in train_ld:
            wav, y = wav.to(device), y.to(device)
            optim.zero_grad()
            loss = criterion(model(wav), y)
            loss.backward()
            optim.step()
            running += loss.item() * len(y)
        train_loss = running / len(train_ld.dataset)

        m = evaluate(model, val_ld, device)
        val_f1 = m["f1_violation"]   # early-stop on violation-detection F1
        print(
            f"[{cfg.rule}] epoch {epoch:3d} | loss {train_loss:.4f} | "
            f"val F1(viol) {val_f1:.4f} | F1(corr) {m['f1_correct']:.4f} | "
            f"P {m['precision']:.3f} R {m['recall']:.3f}"
        )

        if val_f1 > best_f1:
            best_f1, best_epoch, since_improve = val_f1, epoch, 0
            torch.save(
                {"state_dict": model.state_dict(), "rule": cfg.rule,
                 "val_f1": val_f1, "epoch": epoch, "config": C.BACKBONE},
                ckpt,
            )
        else:
            since_improve += 1
            if since_improve >= cfg.early_stop_patience:
                print(f"[train] early stop at epoch {epoch} (best @ {best_epoch})")
                break

    print(f"[train] best val F1(viol) = {best_f1:.4f} @ epoch {best_epoch} -> {ckpt}")
    return ckpt


def _eval_features(model, X, y, device, threshold: float = 0.5):
    model.eval()
    with torch.no_grad():
        p = torch.sigmoid(model.forward_features(X.to(device))).cpu().numpy()
    pred = (p >= threshold).astype(int)
    return {
        "f1_violation": f1_score(1 - y, 1 - pred, zero_division=0),
        "f1_correct": f1_score(y, pred, zero_division=0),
        "precision": precision_recall_fscore_support(
            y, pred, average="binary", zero_division=0)[0],
        "recall": precision_recall_fscore_support(
            y, pred, average="binary", zero_division=0)[1],
    }


def train_from_features(cfg: C.TrainConfig, feat_path: Path) -> Path:
    """Fast head-only training on cached backbone embeddings."""
    torch.manual_seed(cfg.seed)
    device = cfg.device if (cfg.device == "cpu" or torch.cuda.is_available()) else "cpu"
    if device != cfg.device:
        print(f"[train] CUDA unavailable -> {device}")

    data = np.load(feat_path, allow_pickle=True)
    X, y, split = data["X"], data["label"], data["split"].astype(str)
    sel = lambda s: (torch.tensor(X[split == s], dtype=torch.float32),
                     y[split == s].astype(int))
    Xtr, ytr = sel("train")
    Xva, yva = sel("val")
    print(f"[train] {cfg.rule}: train={len(ytr)} val={len(yva)} (cached features)")

    model = TajweedClassifier().to(device)  # backbone idle; we train the head only
    params = [p for p in model.head.parameters()]
    if cfg.use_pos_weight:
        pos, neg = int((ytr == 1).sum()), int((ytr == 0).sum())
        pw = torch.tensor([neg / max(pos, 1)], dtype=torch.float32, device=device)
    else:
        pw = None
    criterion = torch.nn.BCEWithLogitsLoss(pos_weight=pw)
    optim = torch.optim.AdamW(params, lr=cfg.lr, weight_decay=cfg.weight_decay)

    Xtr_d = Xtr.to(device)
    ytr_d = torch.tensor(ytr, dtype=torch.float32, device=device)
    n = len(ytr)
    best_f1, best_epoch, since = -1.0, -1, 0
    ckpt = C.CHECKPOINT_DIR / f"{cfg.rule}_best.pt"

    for epoch in range(1, cfg.epochs + 1):
        model.train()
        perm = torch.randperm(n, device=device)
        total = 0.0
        for i in range(0, n, cfg.batch_size):
            idx = perm[i:i + cfg.batch_size]
            optim.zero_grad()
            loss = criterion(model.forward_features(Xtr_d[idx]), ytr_d[idx])
            loss.backward()
            optim.step()
            total += loss.item() * len(idx)
        m = _eval_features(model, Xva, yva, device)
        if epoch % 5 == 0 or epoch == 1:
            print(f"[{cfg.rule}] ep {epoch:3d} | loss {total/n:.4f} | "
                  f"val F1(viol) {m['f1_violation']:.4f} F1(corr) {m['f1_correct']:.4f} "
                  f"P {m['precision']:.3f} R {m['recall']:.3f}")
        if m["f1_violation"] > best_f1:
            best_f1, best_epoch, since = m["f1_violation"], epoch, 0
            torch.save({"state_dict": model.state_dict(), "rule": cfg.rule,
                        "val_f1": best_f1, "epoch": epoch}, ckpt)
        else:
            since += 1
            if since >= cfg.early_stop_patience:
                break

    # final test-set report from the best checkpoint
    model.load_state_dict(torch.load(ckpt, map_location=device)["state_dict"])
    Xte, yte = sel("test")
    tm = _eval_features(model, Xte, yte, device)
    print(f"[{cfg.rule}] BEST val F1(viol)={best_f1:.4f} @ep{best_epoch} | "
          f"TEST F1(viol)={tm['f1_violation']:.4f} F1(corr)={tm['f1_correct']:.4f} "
          f"P={tm['precision']:.3f} R={tm['recall']:.3f} -> {ckpt}")
    return ckpt


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rule", required=True, choices=list(C.CLASS_B_RULES))
    ap.add_argument("--data-dir", default=str(C.PROCESSED_DIR),
                    help="directory containing labels.csv")
    ap.add_argument("--epochs", type=int, default=50)
    ap.add_argument("--batch-size", type=int, default=8)
    ap.add_argument("--lr", type=float, default=3e-4)
    ap.add_argument("--device", default="cuda")
    ap.add_argument("--from-features", action="store_true",
                    help="train head on cached embeddings (run extract_features first)")
    args = ap.parse_args()

    cfg = C.TrainConfig(
        rule=args.rule, epochs=args.epochs, batch_size=args.batch_size,
        lr=args.lr, device=args.device,
    )
    if args.from_features:
        from .extract_features import feat_path
        fp = feat_path(args.rule)
        if not fp.exists():
            raise SystemExit(f"{fp} missing — run: python -m src.extract_features --rule {args.rule}")
        train_from_features(cfg, fp)
    else:
        train(cfg, Path(args.data_dir) / "labels.csv")


if __name__ == "__main__":
    main()
