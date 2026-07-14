# Research — how Duolingo grades spoken attempts (and what it means for Bayaan)

Captured 2026-07-10. Context: sanity-checking Bayaan's Path A (Muaalem phoneme grading)
against the market leader, prompted by the *S1 real-beginner retest* debate.

## Two separate Duolingo systems

1. **Duolingo English Test (DET)** — the rigorous, researched scorer.
   Peer-reviewed: Cai et al. 2025, *Language Learning* (Wiley),
   https://onlinelibrary.wiley.com/doi/full/10.1111/lang.70000 ; summary blog
   https://blog.englishtest.duolingo.com/new-research-in-language-learning-a-pronunciation-scoring-model-built-around-intelligibility-not-imitation/
   - Grades on **intelligibility, not native-like imitation** — deliberately engineered
     *away* from comparing to an L1/native accent.
   - **Beat the baselines:** Whisper ASR confidence, GOP (Goodness of Pronunciation),
     and Microsoft's commercial scorer. Spearman 0.82 vs human raters.
   - **Fairness by design:** training balanced across language backgrounds; augmented
     with accented speech to remove disparities between speaker groups.

2. **Consumer-app speaking exercises** — thin public docs. STT picks up speech,
   real-time feedback, editable before submit; known to be forgiving/skippable so
   beginners aren't frustrated.
   https://blog.duolingo.com/sneaky-pronunciation-practice/

## What it means for Bayaan

- **Validates the S1 retest concern.** Grading L2 beginners against a native reference
  produces documented bias / false positives. That is exactly the untested risk in S1
  (native speakers only).
- **Both our paths are their *baselines*.** Path A (Muaalem's phoneme-goodness diff ≈
  GOP) and Path B (Whisper) are what their model *beat*. Naive phoneme/ASR grading is a
  known-weak, known-biased starting point.
- **But our goal differs — don't copy the leniency.** Duolingo grades *intelligibility*
  (can you be understood). Bayaan grades *makhraj precision* — ص vs س changes the
  Qur'anic word and is tajweed-critical. Borrow the **fairness/bias lesson**, not the
  leniency: makhraj-strict, but not native-accent-biased.
- **Bayaan's engine advantages:** Muaalem is **domain-specific** (Qur'anic phoneme +
  sifat + madd heads), not a general scorer; grading is **text-dependent** (we always
  know the target syllable/word) = the reliable regime, easier than open ASR; and the
  payload already carries **per-sifat confidence** — so we are *not* forced into hard
  binary diffing, we can threshold on confidence. The "hard diff" fear is fixable in the
  policy layer with data we already emit.

## Takeaway

The model choice is sound for our goal. The risk *and* the lever both live in the
**grading-policy / calibration layer** (diff → verdict), not the model. The beginner
retest tells us where to set the thresholds.
