# PRD — M1: Content Pipeline + Curriculum v1

> Status: draft. Written 2026-07-05. Scopes `docs/PRODUCTION_PLAN.md` milestone M1.
> Supersedes nothing — extends the curriculum design in `PRODUCTION_PLAN.md` §4 and
> the content-pipeline sketch in §4.y into a buildable spec. Precedes M2 (lesson
> player) and M3 (echo grading), which consume this milestone's output.

---

## Problem statement

The Arabic track — Bayaan's headline feature, the "zero to reading Quranic Arabic"
funnel — currently exists only as a curriculum design on paper (`PRODUCTION_PLAN.md`
§4: 8 units, 41 lessons). There is no `content/` directory, no schema, no build
tooling, and no decision yet on which grading tier Units 1–3's spoken exercises
will target. Every downstream milestone (M2's lesson player, M3's echo grading)
needs real, validated lesson content to build against — right now there is nothing
to point a `LessonViewModel` at. Mushaf bundling (the last open item on the
showcase side) is done; this is the next unblocking piece before any lesson-player
UI work can start.

## Goals

- Ship a versioned `content/` schema (`curriculum.json` + per-lesson JSON) that M2
  and M3 can build against without further schema changes.
- Fully itemize Units 1–3 (17 lessons, ~120–150 exercise items) — real content, not
  stubs — covering the letters, minimal-pair discrimination, and harakat curriculum
  described in `PRODUCTION_PLAN.md` §4.
- Resolve the single biggest open risk in the whole production plan: whether
  Muaalem can grade arbitrary short Arabic text (Spike S1), with a fallback
  decision (Spike S2) if not. Commit the answer to `docs/decisions/grading-tiers.md`
  so M3 has an unambiguous target.
- Produce a `scripts/build_content.py` that validates every lesson file, catches
  dangling asset references, and packs the result into an Android asset bundle —
  so bad content fails a local script run, not a runtime crash on-device.
- Stand up the deterministic ayah rule-tag pipeline (Workstream C) early, since
  Units 7–8 and the entire Tajweed track (M7) depend on it and it has zero
  dependency on the Arabic-track content itself.

## Non-goals

- **Lesson player UI** — building `LessonScreen`/`LessonViewModel` to actually play
  this content is M2, not this milestone. M1 ships content and a validator, not a
  runtime.
- **Echo/voice grading implementation** — wiring `POST /speech/grade` or a
  Whisper deployment is M3. M1 only decides *which* path via Spikes S1/S2; it does
  not build the grading endpoint.
- **Units 4–8 content** — stubbed with placeholder manifests (so the build script
  has something to validate against) but not itemized. Full content is M6, after
  the pipeline has proven itself on Units 1–3.
- **TTS voice selection (Spike S4)** — the ElevenLabs-vs-Azure bake-off is a
  separate spike not required to unblock M1; Units 1–3 can ship with placeholder
  or partial TTS and swap voices later without a schema change.
- **Remote content updates** — explicitly deferred in `PRODUCTION_PLAN.md` §13.
  Content ships bundled with the app; `curriculum.json`'s `version` field exists
  for future-proofing only, not to support an update mechanism now.

## User stories

**Learner** (consumes the content, via M2/M3 later):
- As a learner starting from zero, I want each lesson to teach exactly one new
  concept so that I never feel lost or overwhelmed mid-lesson.
- As a learner, I want wrong answers to show me *why* it was wrong (which letter,
  which sound) so that I actually learn from the mistake, not just fail silently.
- As a learner repeating a lesson in practice mode, I want the same lesson content
  to still make sense out of its original unlock order.

**Content author / maintainer** (Abdalrahman, wearing the content-pipeline hat):
- As the content author, I want a schema I can validate locally so that a typo in
  a lesson file fails on my machine, not after I've bundled a broken APK.
- As the content author, I want the build script to catch a missing audio asset
  reference before I ship, so a lesson never renders a silent gap in production.
- As the content author, I want the grading-tier decision (Spike S1/S2) written
  down once, so I don't re-litigate "can the engine grade a single syllable?"
  every time I sit down to write M3.
- As the content author, I want Units 4–8 to exist as empty-but-valid manifests
  so the build script's dangling-reference check has something to run against
  before those units are written.

## Requirements

### Must-have (P0)

**1. `content/` directory schema**
- `content/curriculum.json` — top-level manifest: `version`, ordered list of units,
  each unit with `id`, title (ar/en), and an ordered list of lesson IDs.
- `content/lessons/{unit}.{n}.json` — one file per lesson: ordered exercise items,
  each with `type` (`LISTEN_PICK`, `READ_PICK`, `ECHO`, `ODD_ONE_OUT`,
  `DISCRIMINATE`, `READ_ALOUD_SYLLABLE`, per `PRODUCTION_PLAN.md` §4 Units 1–3),
  `prompt_asset`, `answer`, `distractors[]` (where applicable), `grading_tier`
  (0/1/2 per §3.3), and `reference_text` for graded items.
- Acceptance:
  - [ ] `curriculum.json` validates against a JSON Schema checked into `content/`.
  - [ ] Every lesson file referenced in `curriculum.json` exists and validates.
  - [ ] Schema documented in `content/README.md` (new).

**2. Units 1–3 fully itemized**
- Unit 1 (6 lessons, letter families 1.1–1.6 + checkpoint), Unit 2 (5 lessons,
  minimal-pair discrimination 2.1–2.5 + checkpoint), Unit 3 (6 lessons, harakat
  drills 3.1–3.6 + checkpoint) — content exactly as scoped in
  `PRODUCTION_PLAN.md` §4.
- Acceptance:
  - Given a completed Unit 1–3 content set,
  - When `build_content.py` runs,
  - Then all 17 lesson files parse, every exercise item has a non-empty prompt
    and answer, and checkpoint lessons (1.6, 2.5, 3.6) are flagged distinctly
    from regular lessons in the schema.

**3. `scripts/build_content.py`**
- Validates every lesson file against the schema.
- Walks every `prompt_asset` / audio reference and confirms the file exists in
  `content/audio/` before packing — fails the build (non-zero exit) on any
  dangling reference.
- Generates any missing pre-generated TTS lines via the chosen provider (or a
  placeholder/no-op mode if Spike S4 hasn't landed a voice choice yet) and
  records them in `tts_manifest.json`.
- Emits the Android asset pack consumed by M2.
- Acceptance:
  - [ ] Running `python scripts/build_content.py` against Units 1–3 exits 0.
  - [ ] Deliberately breaking one asset reference makes the script fail with a
    specific file+line pointer, not a silent skip.
  - [ ] Re-running against unchanged content is idempotent (no duplicate TTS
    generation, no changed output hash).

**4. Spikes S1 + S2, decision committed**
- S1: test whether `quranic_phonemizer` + Muaalem can grade 10 arbitrary short
  Uthmani syllables/words (correct + deliberately-wrong recordings each).
- S2 (only if S1 fails or is ambiguous): 30-sample Whisper large-v3 /
  `tarteel-ai/whisper-base-ar-quran` accuracy eval on isolated syllables.
- Acceptance:
  - [ ] `docs/decisions/grading-tiers.md` exists, states Path A (Muaalem) or
    Path B (Whisper) for Tier 1 echo exercises, with the raw spike results
    (accuracy numbers, sample recordings referenced) backing the call.
  - [ ] M3 can start from this doc without re-running the spike.

**5. Ayah rule-tag generator (Workstream C)**
- Script calling `Phonemizer().phonemize(...).tajweed_mappings()` per curated
  ayah, extracting real `TajweedRule` enum values (madd sub-types, ghunnah
  family, `QALQALA_*`, `TAFKHEEM`, etc.) plus a static lookup for sifat
  attributes not modeled as rules (`safeer`, `tikraar`, `tafashie`, `istitala`,
  `itbaq`).
- Output: `content/ayah_rule_tags.json`.
- Acceptance:
  - [ ] Script runs standalone against at least the ayat needed for Unit 7's
    "real Quranic words" lessons (front-loaded so M6/M7 don't block on it).
  - [ ] Output format documented so M7's adaptive-selection logic has a stable
    contract to read from.

**6. Units 4–8 stub manifests**
- Empty-but-schema-valid lesson-list entries in `curriculum.json` for Units 4–8,
  each pointing at placeholder lesson files (title + "not yet authored" marker,
  zero exercises).
- Acceptance: `build_content.py` treats a stub unit as valid (not an error), and
  clearly distinguishes "authored" vs "stub" units in its output summary.

**7. Letter-audio recording checklist**
- A `docs/content/letter-audio-checklist.md` listing all ~250 required clips
  (28 letters isolated + each with fatha/kasra/damma/sukoon-context + madd),
  recording spec (16-bit 44.1kHz), and file-naming convention matching what
  `build_content.py` expects in `content/audio/letters/`.
- Acceptance: checklist is complete enough that a qari/teacher (or Abdalrahman
  himself) could record from it without needing to ask a follow-up question
  about which clips are needed.

### Nice-to-have (P1)

- TTS pre-generation actually run for Units 1–3's scripted teach-segment lines
  (not just the manifest scaffolding) — can ship with placeholder audio and
  backfill once Spike S4 picks a voice.
- A pre-commit or CI hook that runs `build_content.py` automatically so a broken
  content commit never lands, even solo.
- A `content/CHANGELOG.md` or per-unit changelog so content revisions are
  traceable independent of git history.

### Future considerations (P2)

- Remote content updates without an app release (explicitly deferred, tracked
  in `PRODUCTION_PLAN.md` §13 — don't build toward this now, but don't design
  `curriculum.json`'s `version` field in a way that forecloses it later).
- LLM-assisted distractor generation at build time (today: Opus-authored,
  human-reviewed, frozen as JSON — per §3.2 content-authoring row). Automating
  this further is a possible pipeline improvement, not required for M1.
- Multi-locale content (e.g. non-English UI strings for teach segments) — not
  needed while this is a single-developer, single-audience build.

## Success metrics

This milestone ships before there are any live learners, so metrics are
pipeline-health and content-completeness, not engagement:

**Leading (checked at M1 completion):**
- `build_content.py` exit code 0 against the full Units 1–3 + stubbed 4–8 set.
- Zero dangling asset references in the packed output.
- 100% of Units 1–3 lessons have every field the schema requires (no
  placeholder text shipped as if it were real content).
- Grading-tier decision document exists and is dated before M3 work starts.

**Lagging (checked once M2/M3 ship and Units 1–3 are actually playable):**
- Checkpoint pass rate (1.6, 2.5, 3.6) at ≥80% first-attempt accuracy — the
  threshold `PRODUCTION_PLAN.md` §4.x sets for lesson mastery. If real checkpoint
  data comes in far outside that band, it's a signal the M1 content itself needs
  a revision pass, not just the exercises/grading built on top of it.
- Zero "dead" lessons (a lesson that crashes or renders empty in M2 due to a
  content-pipeline gap M1's validator should have caught).

## Open questions

- **Who records the ~250 letter-audio clips, and by when?** TTS can't be
  trusted for isolated makhraj-correct phonemes (per `PRODUCTION_PLAN.md` §3.2),
  so this is a hard human dependency. *(Owner: Abdalrahman — needs a qari/teacher
  lined up or a personal recording plan.)*
- **Is Spike S4 (TTS voice bake-off) worth running before or after M1?** Running
  it first means Units 1–3 ship with final tutor-voice audio; running it after
  means shipping placeholder/no audio and re-generating later. *(Owner:
  Abdalrahman — a scope/sequencing call, not a technical blocker.)*
- **How much of Units 1–3's distractor authoring is manual vs Opus-assisted?**
  Affects how much of "fully itemized" is hand-written vs generated-then-reviewed.
  *(Owner: Abdalrahman — content-authoring workflow choice.)*
- **Does M1 need M0 (app shell) finished first?** They're independent in principle
  — content pipeline doesn't touch the Android nav shell — but M2 (which consumes
  M1's output) needs the `learn` route from M0 to exist. Worth confirming M0 is
  either done or being deliberately deferred before M2 starts. *(Owner:
  Abdalrahman — sequencing decision, non-blocking for M1 itself.)*

## Timeline considerations

No hard external deadline given. Sequencing dependencies:
- Spikes S1/S2 should run **first**, before Units 1–3 content is finalized —
  the grading-tier decision affects how `ECHO`/`READ_ALOUD_SYLLABLE` items are
  authored (what `reference_text` and `grading_tier` values are valid).
- The ayah rule-tag generator has no dependency on the rest of M1 and can be
  built in parallel with Unit content authoring if useful to de-risk early.
- M1 is a hard prerequisite for M2 (lesson player needs real content to render)
  and M3 (echo grading needs the tier decision + reference text format).
- Per the roadmap's "solo developer, fully sequential" constraint, treat this as
  one continuous block of work rather than a date — but if a target is wanted,
  anchor it to "before starting M2," since M2 cannot meaningfully start without it.
