"""Bridge: Bayaan character-level violations  <->  IqraEval phoneme-deviation
scoring, so we can report an F1 comparable to the IQRA 2026 baselines.

IqraEval/QuranMB annotation format (confirmed from Iqra_train):
    phoneme_ref : canonical phoneme sequence  ("m i n n U T f a ...")
    phoneme_aug : actual/spoken phoneme sequence
    a *deviation* exists at every position where aug != ref.

Systems in IQRA predict a full phoneme sequence; the metric is per-phoneme
mispronunciation-detection P/R/F1. Bayaan instead emits per-rule violations at
*character* positions. This module converts those into a per-phoneme predicted-
deviation vector aligned to phoneme_ref, then scores it against the ground truth.

⚠️  FIRST PASS — known approximations (documented for the paper):
  1. The exact char->phoneme alignment requires IqraEval's own phonemizer. Here
     we use a monotonic proportional alignment with a "snap" to the matching
     phoneme symbol for rule-relevant letters (ن م ب and the madd vowels).
  2. The phonemization is literal (not Tajweed-collapsed), so some Tajweed-rule
     violations have no 1:1 phoneme-substitution counterpart. Bayaan therefore
     targets a *pedagogically meaningful subset* of phoneme errors with full
     character grounding (high FGR), trading blanket phoneme recall for
     localized, actionable feedback. Frame the F1 comparison accordingly.
"""
from __future__ import annotations

from difflib import SequenceMatcher

import numpy as np

from .tajweed import phonology as P

# Rule-relevant Arabic letter -> candidate IqraEval phoneme symbols (for snapping)
LETTER_TO_PHONEMES: dict[str, set[str]] = {
    P.NOON: {"n", "nn"},
    P.MEEM: {"m", "mm"},
    P.BAA: {"b", "bb"},
    "ا": {"aa", "A", "a"},
    "و": {"uu", "w"},
    "ي": {"ii", "y"},
    P.DAGGER_ALIF: {"aa"},
}


# --------------------------------------------------------------------------- #
# Ground truth
# --------------------------------------------------------------------------- #
def ground_truth_deviations(phoneme_ref: str, phoneme_aug: str) -> np.ndarray:
    """Binary deviation vector over phoneme_ref positions (1 = mispronounced)."""
    ref, aug = phoneme_ref.split(), phoneme_aug.split()
    dev = np.zeros(len(ref), dtype=int)
    if len(ref) == len(aug):
        for i, (r, a) in enumerate(zip(ref, aug)):
            if r != a:
                dev[i] = 1
        return dev
    # unequal length -> align; mark ref positions touched by a non-equal op
    for tag, i1, i2, _j1, _j2 in SequenceMatcher(a=ref, b=aug, autojunk=False).get_opcodes():
        if tag == "equal":
            continue
        if i1 == i2:                       # insertion: flag the adjacent ref slot
            if i1 < len(dev):
                dev[i1] = 1
        else:
            dev[i1:i2] = 1                 # replace / delete
    return dev


# --------------------------------------------------------------------------- #
# Char -> phoneme alignment
# --------------------------------------------------------------------------- #
def align_letters_to_phonemes(letters: list[P.Letter], phonemes: list[str]) -> list[int]:
    """For each base letter (reading order) return an aligned phoneme index.

    Monotonic proportional baseline, refined by snapping rule-relevant letters
    to a nearby matching phoneme symbol within a small window.
    """
    L, n = len(letters), len(phonemes)
    out: list[int] = []
    for k, lt in enumerate(letters):
        approx = min(n - 1, int(round((k + 0.5) / max(L, 1) * n))) if n else 0
        idx = approx
        targets = LETTER_TO_PHONEMES.get(lt.char)
        if targets and n:
            for w in range(4):             # search +/- window for a symbol match
                for cand in (approx - w, approx + w):
                    if 0 <= cand < n and phonemes[cand] in targets:
                        idx = cand
                        break
                else:
                    continue
                break
        out.append(idx)
    return out


def map_to_deviations(verse_text: str, violations: list[dict], phoneme_ref: str) -> np.ndarray:
    """Bayaan violations -> predicted per-phoneme deviation vector over ref.

    `verse_text` must be the same text whose char_index the violations carry
    (the engine's input), and `phoneme_ref` its canonical phonemization.
    """
    phonemes = phoneme_ref.split()
    letters = P.parse_letters(verse_text)
    align = align_letters_to_phonemes(letters, phonemes)
    pred = np.zeros(len(phonemes), dtype=int)
    for v in violations:
        ci = v.get("char_index")
        if ci is None:
            continue
        ordn = sum(1 for c in verse_text[:ci] if P.is_arabic_letter(c))  # letter ordinal
        if 0 <= ordn < len(align):
            p = align[ordn]
            pred[p] = 1
            if p + 1 < len(phonemes) and phonemes[p + 1] == phonemes[p]:  # geminate
                pred[p + 1] = 1
    return pred


# --------------------------------------------------------------------------- #
# Scoring
# --------------------------------------------------------------------------- #
def mdd_counts(pred_dev: np.ndarray, gt_dev: np.ndarray) -> tuple[int, int, int]:
    pred, gt = np.asarray(pred_dev), np.asarray(gt_dev)
    tp = int(((pred == 1) & (gt == 1)).sum())
    fp = int(((pred == 1) & (gt == 0)).sum())
    fn = int(((pred == 0) & (gt == 1)).sum())
    return tp, fp, fn


def prf(tp: int, fp: int, fn: int) -> dict:
    prec = tp / (tp + fp) if (tp + fp) else 0.0
    rec = tp / (tp + fn) if (tp + fn) else 0.0
    f1 = 2 * prec * rec / (prec + rec) if (prec + rec) else 0.0
    return {"tp": tp, "fp": fp, "fn": fn, "precision": prec, "recall": rec, "f1": f1}


def mdd_prf(pred_dev: np.ndarray, gt_dev: np.ndarray) -> dict:
    return prf(*mdd_counts(pred_dev, gt_dev))
