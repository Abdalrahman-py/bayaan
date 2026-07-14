# S1 beginner retest — checklist + run

Resolves wayfinder ticket *S1 real-beginner retest*
(`.scratch/mvp-tracks/issues/03-s1-beginner-retest.md`).

**Why:** S1 decided Path A (Muaalem grades arbitrary Uthmani text), but both S1
speakers turned out **native** (`docs/decisions/grading-tiers.md`, commit 6319484).
Path A's whole value is grading a *learner's* imperfect speech — native-only data
doesn't prove that. This retest is an **M3 prerequisite**: it's the single unproven
load-bearing assumption before the echo-grading milestone builds on Path A.

Reuses the existing S1 harness unchanged — new manifest, same runner, same pinned
image. No code.

---

## 1. Get the right speaker (the whole point)

**One genuine non-native Arabic beginner** — someone who *cannot* already recite
well. If they read Arabic fluently, they're the wrong speaker and the retest is
worthless. Accented, hesitant, imperfect = exactly right.

## 2. Record 14 clips

- Phone mic is fine. **Spoken plainly, like a learner — not recited.**
- Quiet room. **Trim leading/trailing silence** on each clip — the native run's
  false positives came from breath-noise at clip edges, not the model. Tight clips.
- ~1–3s each. Save into `spike/s1_recordings/` with the **exact filenames** below.
- Convert to 16 kHz mono WAV if needed:
  `ffmpeg -i in.m4a -ar 16000 -ac 1 spike/s1_recordings/<name>.wav`

**Correct rows = the beginner's honest best attempt** (aiming to say it right, accent
and all). **Wrong rows = deliberately say the named wrong sound.**

| Filename | Target | Say | Kind |
|---|---|---|---|
| `baa_correct_b.wav` | بَا | honest "baa" (long) | correct |
| `bii_correct_b.wav` | بِي | honest "bii" | correct |
| `buu_correct_b.wav` | بُو | honest "buu" | correct |
| `saad_correct_b.wav` | صَا | honest heavy "Saa" | correct |
| `taa_correct_b.wav` | طَا | honest heavy "Taa" | correct |
| `haa_correct_b.wav` | حَا | honest "7aa" (ح) | correct |
| `qul_correct_b.wav` | قُلْ | honest "qul" | correct |
| `bismi_correct_b.wav` | بِسْمِ | honest "bismi" | correct |
| `saad_as_siin_b.wav` | صَا | say "saa" (س) instead | wrong — consonant |
| `taa_as_light_b.wav` | طَا | say light "taa" (ت) | wrong — consonant |
| `haa_as_soft_b.wav` | حَا | say soft "haa" (هـ) | wrong — consonant |
| `qul_as_kul_b.wav` | قُلْ | say "kul" (ك) | wrong — consonant |
| `bismi_as_basmi_b.wav` | بِسْمِ | say "basmi" (fatha) | wrong — vowel |
| `baa_short_b.wav` | بَا | say short "ba" | wrong — length |

(Optional extra: bare waqf probe `بَ` — skipped here; it's a known reference-convention
confound, not a beginner-accuracy question.)

## 3. Run (Modal — cloud GPU, nothing heavy runs on your laptop)

One-time: `pip install modal && modal token new`

```bash
modal run spike/s1_grade_text_spike.py --manifest spike/s1_beginner_manifest.csv | tee spike/s1_results_beginner.txt
```

Cost is cents inside Modal's free credits (scale-to-zero).

## 4. Score against the fixed criteria

Same bar as S1, plus the beginner-specific reading:

- **≥80% of `correct` clips come back clean** (verdict `pass`/`retry` — **not** hard
  `fail`). This is the real test: an honest learner attempt must **not** be punished
  as a mistake. Over-flagging correct beginner audio = Path A is unsafe for M3.
- **≥80% of `wrong` clips flagged**, with the error localized to the right letter.
- **Zero crashes** (watch for the `multilevel_greedy_decode` negative-dimension
  RuntimeError noted in `grading-tiers.md` — if it appears, it's the wrap-in-retry
  case, not a pass).

## 5. Record the verdict

1. Keep `spike/s1_results_beginner.txt` (raw output).
2. Append a short result block + verdict to `docs/decisions/grading-tiers.md`:
   **Path A safe as-is for M3**, or **needs the mitigations widened** (say which).
3. Then resolve ticket *S1 real-beginner retest* — which unblocks
   *Whisper fallback scope* (07): retest holds → Whisper drops from MVP; retest
   exposes gaps → Whisper fallback re-enters as an M3 build item.
