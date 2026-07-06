# Workstream: Content pipeline engineering (M1)

**Owner:** Ramzi · **Depends on:** nothing — start immediately (spikes already done) · **Unblocks:** lesson player (M2), voice loop (M3), content authoring
**Spec:** the full PRD at `docs/specs/m1-content-pipeline.md` — read it end to end. Curriculum being encoded: `docs/PRODUCTION_PLAN.md` §4.

## Goal

The `content/` schema + `scripts/build_content.py` toolchain, so bad content
fails a local script run instead of crashing on-device. **You build the
pipeline; you do not author the curriculum content** — lesson items are
generated (LLM-assisted) and reviewed/frozen by Abdalrahman per unit.

## Tasks (P0s from the PRD, engineering subset)

1. `content/` schema: `curriculum.json` manifest + `lessons/{unit}.{n}.json`
   item shape (`type`, `prompt_asset`, `answer`, `distractors[]`,
   `grading_tier`, `reference_text`). JSON Schema checked into `content/`,
   documented in `content/README.md`. **This is contract 1 — Abdalrahman
   signs off before anything builds against it.**
2. `scripts/build_content.py`: validate every lesson vs schema; fail (non-zero,
   file+line pointer) on any dangling `prompt_asset`/audio reference; TTS
   pre-generation hook (no-op/placeholder mode until a voice is chosen);
   `tts_manifest.json`; emit the Android asset pack. Idempotent re-runs.
3. Units 4–8 stub manifests (schema-valid, zero exercises, clearly marked
   "stub" in build output).
4. Ayah rule-tag generator: script calling
   `Phonemizer().phonemize(...).tajweed_mappings()` per curated ayah →
   `content/ayah_rule_tags.json` + documented format (M7 reads this).
   Independent of everything else — good parallel task.
5. Letter-audio recording checklist (`docs/content/letter-audio-checklist.md`):
   all ~250 clips named + spec'd (16-bit 44.1kHz) so a reciter can record
   without follow-up questions.

## Grading constraint baked into the schema (from Spike S1 — decided)

`docs/decisions/grading-tiers.md`: echo reference text must be **madd- or
sukoon-final** (the phonetizer applies waqf rules word-finally — a bare final
short vowel or qalqalah-final target produces false mismatches). Encode this
as a validator rule in `build_content.py`, not a convention people must remember.

## Acceptance (from the PRD)

- `python scripts/build_content.py` exits 0 on Units 1–3 + stubs; breaking one
  asset ref fails with a specific pointer; re-run idempotent; rule-tag output
  documented; checklist complete.

## Don't

- Put curriculum content in the DB — it ships as versioned app assets (§4.y).
- Build remote content updates (§13 deferred).
- Re-run spikes S1/S2 — done, results in `docs/decisions/grading-tiers.md`
  and `spike/s1_results_*.txt`.
