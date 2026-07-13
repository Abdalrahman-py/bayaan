# Workstream: Speech grading + learn backend (M3 server, M4)

**Owner:** Ramzi · **Reviewed & wired by:** Abdalrahman (Supabase schema + route review, client-server integration) · **Depends on:** M3 part — content pipeline schema; M4 part — M2 player merged · **Unblocks:** voice exercises (M3), placement/streak/XP/SRS (M4)
**Spec:** `docs/PRODUCTION_PLAN.md` §3.3 (tiers), §8 (data model), §9 (endpoints), §10 M3/M4. Module rules: `backend/AGENTS.md` (note: auth is JWKS/ES256).

## Goal

Two chunks, in order: (A) the `/speech/grade` endpoint that powers echo
exercises; (B) the learn backend (progress, streak, XP, SRS, placement).

## Tasks — A: `/speech/grade` (M3 server side)

1. Extend `ml/muaalem_modal.py` with a `/grade-text` endpoint: arbitrary
   Uthmani `reference_text` instead of sura/aya (Path A — the working
   reference implementation is `spike/s1_grade_text_spike.py`, including the
   sifat extraction).
2. Ktor `POST /speech/grade`: multipart audio + `{tier, reference_text,
   item_ref}` → Modal → normalize to contract 2:
   `{verdict: pass|retry|fail, score, phoneme_issues[], feedback_key}`.
3. Grading policy (all from `docs/decisions/grading-tiers.md` — decided):
   - drop `insert`-type errors at clip start/end (breath artifacts);
   - single minor error → `retry`, not `fail`;
   - the upstream decode crash (`multilevel_greedy_decode` RuntimeError,
     1/43 clips in S1) → catch → `retry` verdict, never a 500;
   - max audio duration enforced server-side.
4. **Hard prerequisite before M3 ships:** `docs/decisions/grading-tiers.md`'s open
   items flag that Spike S1 only used two native-Arabic speakers — rerun a
   10-clip subset with a genuine non-native beginner and confirm the tolerance
   policy above (step 3) still holds before this endpoint goes live. This is
   called out there as "a hard M3 prerequisite, not a nice-to-have" — don't skip
   it because grading-tiers.md is otherwise "decided, don't re-litigate."
5. Update `docs/api-spec.md` in the same commit (repo rule) — full request/response
   contract, including the `phoneme_issues[]` shape and `feedback_key` enum, is
   already written there (`POST /speech/grade` section); implement against it,
   don't re-derive the shape.

## Tasks — B: learn backend (M4)

6. Supabase tables per §8: `profiles`, `placement_results`, `lesson_progress`,
   `lesson_attempts`, `review_items`, `xp_events` (+ repositories, same
   Exposed patterns as `SessionRepository`).
7. Endpoints per §9: `GET /learn/path`, `POST /learn/complete` (updates
   progress, XP, streak, SRS inserts), `GET /learn/reviews` +
   `POST /learn/reviews/{id}/result`, `POST /learn/placement`.
8. Streak day-boundary: decide + document the timezone rule (store user offset
   or UTC — pick one, write it in api-spec).
9. Known limitation to document, not solve: placement item bank only covers
   Units 1–3 until M6 lands content for 4–8, so placement caps at ~level 3
   for now (`PRODUCTION_PLAN.md` §4.0 vs milestone order).

## Acceptance (from §10)

- M3: wrong-consonant and wrong-vowel recordings produce distinct, correct
  feedback; warm verdict ≤2.5s end-to-end on device; beginner-retest (task 4)
  run and tolerance policy confirmed before ship.
- M4: fresh account → placement → correct unlocks; lesson completed on device A
  shows on device B; streak increments across a real day boundary; reviews
  appear in warm-up.

## Don't

- Re-litigate Path A vs Whisper (`docs/decisions/grading-tiers.md`).
- Add the LLM tutor endpoints (`/tutor/*`, `/tts/line`) — that's M5, later.
- Persist raw learner audio (privacy commitment, §12).
