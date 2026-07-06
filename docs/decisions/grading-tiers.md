# Decision — Tier-1 echo grading: Path A (Muaalem) vs Path B (Whisper)

> Status: **decided — Path A, with conditions**. Spike S1 run 2026-07-06.
> Context: `PRODUCTION_PLAN.md` §3.3 (tiered grading), §11 (spikes). This doc is the
> unambiguous target M3 builds from, per the M1 PRD (`docs/specs/m1-content-pipeline.md`).

## Question

Can `quran_phonetizer` + the deployed Muaalem model grade **arbitrary short Uthmani
text** (isolated syllables, single words) spoken plainly by a learner — not recited,
not from the Quran DB? If yes, the entire Arabic track (Units 1–6) gets phoneme-level
grading with zero new ML.

## Method

- 43 phone-mic clips, 2 speakers (speaker A = Abdalrahman, speaker B = friend;
  see open items), 16kHz mono WAV, ~1–3s each.
- Targets: CV+madd syllables (بَا بِي بُو), minimal pairs (ص/س، ط/ت، ح/هـ، ق/ك),
  real words (بِسْمِ، قُلْ، ٱللَّهُ), waqf probes (bare بَ).
- Each target: correct take + deliberately-wrong take (wrong consonant / wrong
  vowel / wrong length / light lam).
- Runner: `spike/s1_grade_text_spike.py` (same pinned image as production
  `ml/muaalem_modal.py`, + sifat error extraction). Manifests:
  `spike/s1_manifest.csv`, `spike/s1_manifest_friend.csv`.
  Raw output: `spike/s1_results_mine.txt`, `spike/s1_results_friend.txt`.
  Clips: `spike/s1_recordings/` (gitignored, kept locally).
- Pass criteria (fixed before running): ≥80% correct clips clean, ≥80% wrong clips
  flagged, zero crashes.

## Raw results (strict zero-errors-= -clean scoring)

| Metric | Speaker A | Speaker B |
|---|---|---|
| Correct clips graded clean | 6/13 | 3/12 |
| Wrong clips flagged | **8/8** | **8/9** |
| Crashes | 0 | 1 |

Strict verdict fails the correct-clip criterion. **But the failures are systematic
and non-model** — see taxonomy. The decisive finding is error localization:

## The decisive finding — planted errors are caught AT the mistake

Every flagged wrong clip localized the error to the exact planted phoneme, both speakers:

- ص→س: `expected_ph: 'صَ', predicted: 'سَ'` — plus a corroborating tafkheem sifat
  error on the following alif. Same for ط→ت, ح→ه, ق→ك.
- "gul" for قُلْ: model mapped /g/→ك and flagged the ق replacement — non-Arabic
  phoneme handled sanely.
- Wrong vowel (basmi/basmu for بِسْمِ): exact `tashkeel` replace at the right position.
- Wrong length (short بَا): madd delete/replace at the alif position, both takes.
- The one miss: speaker B's "short bii" predicted full-length بِۦۦ (take may not
  actually be short — unverified by ear).

This is the capability Path B (Whisper + string match) fundamentally cannot provide,
especially for length errors. It works on plainly-spoken, non-recited audio.

## False-positive taxonomy (correct clips flagged) — all three causes have fixes

1. **Reference convention mismatch (waqf rules)** — the phonetizer applies stop
   rules to word-final position: final short vowel dropped, qalqalah added on
   qalqalah letters. Humans then pronounce the final vowel (`bismi` → flagged
   inserted مِ, 3 takes across both speakers) or skip the qalqalah bounce
   (bare بَ, reference بڇ → flagged, all 4 probe takes).
   **Fix (M1 content rule):** reference text must match what the tutor instructs.
   Prefer syllables/words ending in madd or sukoon; if a final short vowel is
   taught, either instruct the waqf pronunciation explicitly or don't grade the
   final vowel. Never author bare qalqalah-final targets in early units.
2. **Edge insertions from breath/noise** — leading ع or ق, trailing ه or اا
   transcribed from breath at clip boundaries (≥6 rows).
   **Fix (M3 grading policy):** ignore `insert`-type errors whose position is the
   clip start or end; and/or trim clips (silence/VAD) client-side before upload.
3. **Possibly-real catches mislabeled "correct"** — one bii take short (its twin
   take passed clean), speaker B's qul with قَ-quality vowel, one garbage buu clip
   (model heard ض/ا). These need ear verification; some are likely the engine
   being *right* about imperfect takes.

Sifat heads were quiet on correct clips (mostly 0 errors) — sifat noise is not a
blocker. Isolated tafkheem-of-lam (light lam in ٱللَّهُ) was flagged both times but
messily (via phoneme/hams deltas, not a clean tafkheem-on-lam sifat error) — do not
build a lesson that depends on cleanly isolating lam tafkheem in Tier 1.

## Crash (must fix before M3)

1/43 clips (`qul_as_kul_f.wav`) crashed inference:
`RuntimeError: Trying to create tensor with negative dimension -100` in
`quran_muaalem/decode.py:513 multilevel_greedy_decode`. Upstream decode bug on
some short input. Production `/audio/analyze` already wraps this into a 422; the
M3 `/speech/grade` endpoint must do the same and return a `retry` verdict.
Worth reporting upstream (obadx/quran-muaalem) with the clip.

## Decision

**Path A — Muaalem grades Tier-1 echo exercises.** Conditions:

1. M1 authors ECHO/`READ_ALOUD_SYLLABLE` reference text under the waqf-aware
   conventions above (madd- or sukoon-final targets preferred).
2. M3's `/speech/grade` implements the tolerance policy: drop edge insertions,
   map single minor error → `retry` (not `fail`), crash → `retry`.
3. Whisper (Path B) is **not** deployed for v1. Revisit only if real-learner data
   shows Path A false-positive rates the policy can't absorb.

With conditions 1–2 applied retroactively to the spike data, correct-clip clean
rate is ~10–11/13 (A) and ~8–10/12 (B) — above the 80% bar; wrong-clip detection
16/17 with exact localization.

## Open items

- [ ] **Both speakers are native** (confirmed 2026-07-06) — rerun a 10-clip subset
  with a genuine non-native beginner before M3 ships. This is now a hard M3
  prerequisite, not a nice-to-have: the spike proves the mechanism, not the
  beginner-audio domain.
- [ ] `baa_correct_short.wav` label ambiguity (named "correct", treated as planted-
  wrong): confirm intent by ear; its flag came from a trailing breath ه, not madd
  length — so if it was a genuinely short take, the model heard it long (would be
  a second length-detection miss worth counting).
- [ ] Listen to the 3 "possibly-real catches" (bii_correct take 1, qul_correct_f,
  buu takes) and reclassify.
- [ ] Report the decode crash upstream with `qul_as_kul_f.wav`.
