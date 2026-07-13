# Workstream: Lesson player (M2, then M3 client)

**Owner:** Gemini (builder) · **Reviewed & wired by:** Abdalrahman · **Depends on:** M0 shell merged, content schema frozen (contract 1) · **Unblocks:** the entire Arabic track UX
**Spec:** `docs/PRODUCTION_PLAN.md` §4.x (lesson anatomy), §6 (LessonScreen), §7 (premium feel), §10 M2/M3. Exercise types: §4 Units 1–3. Agent scope: `android/GEMINI.md`.

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
   `CONNECT`/`BUILD_WORD` are Unit 4 exercise types, but Unit 4 content is
   stub-only until M6 (`ws-content-pipeline.md` task 3) — build and test these
   against fake `@Preview` data only; they don't factor into M2's real-content
   acceptance test below.
2a. `ECHO`/`READ_ALOUD_SYLLABLE` composables, **stubbed**: record → instant
   playback of the learner's own clip → tap to mark complete. No verdict, no
   grading call — `/speech/grade` doesn't exist until M3. Same
   graceful-degradation pattern as WarmUp below (build the UI now, wire the
   missing backend piece later as a pure addition). Unit 1–2 content includes
   these item types (`PRODUCTION_PLAN.md` §4 Units 1–2), so this is required
   for M2, not optional.
3. Lesson flow: WarmUp (skipped while SRS doesn't exist) → Teach (audio +
   replay) → Drill (8–12 items, 2 free retries) → Wrap (score ring, XP count-up,
   streak flame, [Continue]).
4. Failed checkpoint → auto-assembled practice lesson from the unit's item bank
   (pure client logic, §4.x).
5. Progress persistence: DataStore only (server truth is M4's job).
6. Sounds/haptics/motion on every interaction per §7 — premium is not a final coat.

## Tasks — M3 (voice exercises, client side; Ramzi ships the endpoint)

7. `ECHO`, `READ_ALOUD_SYLLABLE`, `LENGTH_JUDGE`: swap the M2 stub's
   "complete on tap" for a real `POST /speech/grade` call — pure addition to
   the existing composables from task 2a, not a rewrite.
8. Mic UX per §7.4: pulsing idle mic, live amplitude waveform (AudioRecord →
   Canvas), auto-stop on 1.2s trailing silence + manual stop.
9. Call `POST /speech/grade` (contract 2, full shape in `docs/api-spec.md`
   §POST /speech/grade); render `verdict`/`score`/`phoneme_issues` as
   retry/pass/fail feedback, using `feedback_key` to look up copy — don't
   invent copy from `issue_type` directly. Trim clips ≤4s.

## Tasks — M4 (client: progress backend wiring)

10. Switch progress persistence from DataStore-only (task 5) to server truth:
    call `GET /learn/path` on Learn tab load, `POST /learn/complete` after
    every lesson Wrap screen. DataStore becomes an offline cache, not the
    source of truth.
11. Placement flow: first-launch placement test UI (recognition-only per
    vision doc Workstream A) → `POST /learn/placement` → render the
    Opus-generated plan blurb (`PRODUCTION_PLAN.md` §7 "post-test").
12. Progress tab v1: `GET /progress` stats + streak/XP header data from
    `GET /learn/path`; review queue surfaces `GET /learn/reviews` in WarmUp.
13. Known limitation to carry into the UI, not solve here: placement item
    bank only covers Units 1–3 until M6, so placement caps at ~level 3 for
    now (matches `ws-learn-backend.md` task 9 — same limitation, both sides).

## Acceptance (from §10 — green on a real device)

- M2: Units 1–2 fully playable offline end-to-end, including ECHO items
  completing without a verdict by design; wrap screen animates score/XP;
  failed checkpoint assembles a practice lesson.
- M3: Unit 3 playable with real mic grading; wrong-consonant and wrong-vowel
  test recordings produce distinct, correct feedback; warm verdict ≤2.5s.
- M4: fresh account → placement → correct unlocks; lesson completed on device
  A shows on device B; streak increments across a real day boundary; reviews
  appear in warm-up (same acceptance list as `ws-learn-backend.md`'s M4 — one
  observable outcome, two sides of the wire).

## Don't

- Invent content fields — the schema in `content/README.md` is the contract;
  if it's missing something, that's a schema PR + Abdalrahman sign-off, not a
  client-side workaround.
- Build grading logic client-side. Grading is always server-side
  (`docs/decisions/grading-tiers.md` — decided, don't re-litigate).
- Fork `RecitationScreen` — Tier-2 read-aloud wraps it later (M6).
- Invent a `feedback_key` → copy mapping ahead of `docs/api-spec.md`'s enum —
  if a mistake type shows up that isn't in the enum there, that's a contract
  update (flag it), not a client-side guess.
