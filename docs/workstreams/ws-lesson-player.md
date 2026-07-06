# Workstream: Lesson player (M2, then M3 client)

**Owners:** Issa + Osama · **Depends on:** M0 shell merged, content schema frozen (contract 1) · **Unblocks:** the entire Arabic track UX
**Spec:** `docs/PRODUCTION_PLAN.md` §4.x (lesson anatomy), §6 (LessonScreen), §7 (premium feel), §10 M2/M3. Exercise types: §4 Units 1–3.

## Goal

One screen (`LessonScreen` + `LessonViewModel`) that plays any lesson JSON the
content pipeline emits. This is the single biggest new client component.

## Tasks — M2 (recognition exercises, offline)

1. `LessonViewModel`: state machine over `ExerciseState`
   (Prompt → Listening/Recording → Grading → Feedback → Next), driven by the
   lesson's exercise manifest. No network.
2. Exercise composables, one file each under `ui/lesson/exercises/`:
   `LISTEN_PICK`, `READ_PICK`, `DISCRIMINATE`, `ODD_ONE_OUT`, `CONNECT`,
   `BUILD_WORD` (drag glyph pieces — make this one feel great, §4 Unit 4).
3. Lesson flow: WarmUp (skipped while SRS doesn't exist) → Teach (audio +
   replay) → Drill (8–12 items, 2 free retries) → Wrap (score ring, XP count-up,
   streak flame, [Continue]).
4. Failed checkpoint → auto-assembled practice lesson from the unit's item bank
   (pure client logic, §4.x).
5. Progress persistence: DataStore only (server truth is M4's job).
6. Sounds/haptics/motion on every interaction per §7 — premium is not a final coat.

## Tasks — M3 (voice exercises, client side; Ramzi ships the endpoint)

7. `ECHO`, `READ_ALOUD_SYLLABLE`, `LENGTH_JUDGE` composables.
8. Mic UX per §7.4: pulsing idle mic, live amplitude waveform (AudioRecord →
   Canvas), auto-stop on 1.2s trailing silence + manual stop.
9. Call `POST /speech/grade` (contract 2, shape in §9); render
   `verdict/score/phoneme_issues` as retry/pass feedback. Trim clips ≤4s.

## Acceptance (from §10 — green on a real device)

- M2: Units 1–2 fully playable offline end-to-end; wrap screen animates
  score/XP; failed checkpoint assembles a practice lesson.
- M3: Unit 3 playable with real mic grading; wrong-consonant and wrong-vowel
  test recordings produce distinct, correct feedback; warm verdict ≤2.5s.

## Don't

- Invent content fields — the schema in `content/README.md` is the contract;
  if it's missing something, that's a schema PR + Abdalrahman sign-off, not a
  client-side workaround.
- Build grading logic client-side. Grading is always server-side
  (`docs/decisions/grading-tiers.md` — decided, don't re-litigate).
- Fork `RecitationScreen` — Tier-2 read-aloud wraps it later (M6).
