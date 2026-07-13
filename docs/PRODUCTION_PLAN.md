# Bayaan — Production Plan (AI Tutor: Arabic Track + Tajweed Track)

> **Audience:** this document is an implementation plan written for an AI coding agent
> (Claude Sonnet) to execute milestone-by-milestone, and for Abdalrahman to review and
> steer. It supersedes the *build sequencing* in [`PRODUCT_VISION.md`](./PRODUCT_VISION.md)
> (which remains the long-term feature encyclopedia). Where the two disagree on what to
> build next, this document wins.
>
> **North star:** Bayaan is an AI tutor — think **Pingo AI, but for Quranic Arabic**.
> Two tracks, one funnel:
> 1. **Arabic track** (build now): audio-first lessons that take a learner from zero to
>    reading and pronouncing Quranic Arabic — powered by an LLM tutor + speech loop,
>    modeled on Pingo's tutor mode.
> 2. **Tajweed track**: the existing Muaalem ML pipeline (wav2vec2 multi-level CTC with
>    tajweed-rule and sifat classifier heads) grades real recitation and makes sure the
>    rules are *actually* correct.
>
> The product must **feel like a learning app** — a guided path, one clear next step,
> streaks, mastery, celebration — and it must feel **premium**: motion, sound, haptics,
> beautiful Arabic typography, zero jank.

---

## 0. Table of contents

1. [What exists today](#1-what-exists-today-dont-rebuild)
2. [The Pingo model we're mimicking](#2-the-pingo-model-were-mimicking)
3. [Voice + AI architecture](#3-voice--ai-architecture)
4. [Arabic track — full curriculum design](#4-arabic-track--full-curriculum-design)
5. [Tajweed track — full curriculum design](#5-tajweed-track--full-curriculum-design)
6. [App structure & navigation](#6-app-structure--navigation)
7. [Premium feel spec](#7-premium-feel-spec)
8. [Data model](#8-data-model-supabase)
9. [Backend API additions](#9-backend-api-additions)
10. [Milestones M0–M8 (the Sonnet execution plan)](#10-milestones--execution-plan)
11. [Spikes & risks](#11-spikes--risks)
12. [Production hardening & launch](#12-production-hardening--launch)
13. [Deferred (one-day) list](#13-deferred-one-day-list)

---

## 1. What exists today (don't rebuild)

| Layer | Built | Notes |
|---|---|---|
| Android | Splash → Onboarding → Login/Signup (Supabase auth, session persistence) → Home → Surah index → **QCF-glyph mushaf pager** with word-level ayah selection → RecitationScreen with letter-level mistake highlights (`VerseText`) + sifat cards → Profile/Settings. 3-tab bottom nav. | Material 3, green/sand `BayaanTheme`, Amiri font. `RecitationViewModel` records M4A/AAC, uploads, parses errors. |
| Backend (Ktor on Render) | `/health`, `/surahs`, `/auth/sync`, `/audio/analyze` (proxy → Muaalem + persist), `/progress`, `/progress/sessions[*]`. JWT verified via Supabase JWKS (ES256). Exposed ORM → Supabase Postgres (`users`, `sessions`, `mistakes`). | `EngineResponseParser` currently **drops `sifat_errors`** (known gap, fix in M6). |
| ML (Modal, L4 GPU) | `ml/muaalem_modal.py` — `POST /correct`: WAV + sura/aya → phoneme diff vs `quran_phonetizer` reference → structured `errors` (with `ref_tajweed_rules`, expected/predicted madd lengths) + `sifat_errors` (10 attribute heads with confidence). Scale-to-zero, ~24s cold / ~1.7s warm. | This **is** the tajweed track's grading engine. |
| Docs | `PRODUCT_VISION.md`, `CODEBASE_MAP.md`, `UI_SPEC.md`, `tajweed-rules.md`, `api-spec.md`. | `UI_SPEC.md` stays the styling law; this plan extends it (§7). |

**Reuse contract:** `RecitationScreen`/`VerseText`/`RecitationViewModel`, the mushaf,
auth, and the Muaalem deployment are load-bearing. New work wraps them; it does not fork
them.

---

## 2. The Pingo model we're mimicking

Pingo AI's loop (from public product + reviews):

- **Voice-first turn loop:** user taps mic → speech-to-text → LLM tutor generates the
  next turn → TTS speaks it. Transcript bubbles render both sides.
- **Two modes:** *Tutor mode* (guided, scripted-but-adaptive lesson: teach a phrase →
  learner repeats → check → advance) and *Roleplay mode* (open scenario).
- **In-turn affordances:** translate, hint / suggested answers, slow replay, repeat.
- **Post-session feedback:** transcript with per-phrase corrections (pronunciation,
  grammar, vocabulary, fluency), save words → flashcards, a short "what to practice
  next" plan.
- **Retention:** streaks, levels, adaptive difficulty.
- **Tech shape:** commodity ASR (Whisper-class) + general LLM (GPT-class) + neural TTS,
  glued by product design. Nothing exotic — the moat is the loop and the polish.

**Bayaan's translation of that loop:**

| Pingo | Bayaan Arabic track |
|---|---|
| Tutor mode lesson | Structured audio lesson: tutor voice teaches a letter/sound/word → learner repeats into the mic → graded → tutor reacts |
| ASR grading of speech | **Tiered grading** (§3.3): Muaalem phoneme engine for anything in Quranic script (our unfair advantage — Pingo can't do phoneme-level), Whisper as fallback/spike alternative |
| LLM tutor brain | Claude generates dynamic feedback lines, answers "explain this", writes the post-lesson coaching summary |
| TTS tutor voice | Pre-generated neural TTS for scripted lines (cheap, instant) + live TTS only for dynamic lines; **human-recorded audio for canonical letter sounds** |
| Roleplay mode | Not needed v1 — the "open" mode is the **Tajweed track / Explore** (recite any ayah, get graded) |
| Post-session corrections | Lesson summary screen: score, weak sounds, tutor voice note, items pushed into the review queue |

Key deviation from Pingo, on purpose: Pingo's content is open-ended conversation so it
must run ASR+LLM+TTS live on every turn. Bayaan's Arabic lessons are ~90% *scripted
content with dynamic branching*, so most audio is pre-generated at content-build time
and most turns need **no LLM call at all**. This makes the app faster than Pingo's loop
and an order of magnitude cheaper to run.

---

## 3. Voice + AI architecture

### 3.1 Components

```
Android (lesson player)
  │  m4a/wav mic audio + exercise context          pre-bundled: lesson JSON, letter audio,
  ▼                                                 pre-generated TTS lines (assets/CDN)
Ktor backend (Render, paid tier)
  ├── /speech/grade      → Muaalem (Modal GPU)      phoneme-level grading, Quranic script
  ├── /speech/transcribe → Whisper (Modal, faster-whisper large-v3 or tarteel fine-tune)
  ├── /tutor/turn        → Claude API               dynamic feedback / explain / summary
  ├── /tts/line          → TTS provider (cached)    only for dynamic lines
  └── /learn/*           → Supabase Postgres        curriculum state, progress, SRS
```

### 3.2 Model & provider choices

| Role | Choice | Why / cost notes |
|---|---|---|
| **Pronunciation grading (Quranic script)** | **Muaalem** (already deployed) | Phoneme-level, tajweed-aware, already paid for. Spike S1 (§11) tests single-letter/word grading. |
| **General Arabic ASR** | `faster-whisper` **large-v3** on Modal (same pattern as `muaalem_modal.py`); evaluate `tarteel-ai/whisper-base-ar-quran` for Quranic bias | Self-hosted keeps unit cost ~$0 at low volume with scale-to-zero; no per-minute API fees. Only needed where Muaalem can't grade (spike-dependent). |
| **In-lesson LLM turns** (feedback lines, "explain this", hints) | **`claude-haiku-4-5`** ($1/$5 per MTok) | Latency is the constraint: these fire mid-lesson and must return in <1.5s. Turns are ~300 tokens out. With prompt caching on the tutor system prompt, a turn costs fractions of a cent. |
| **Post-lesson coaching + placement analysis** | **`claude-opus-4-8`** ($5/$25 per MTok) | Runs once per lesson (async, latency-tolerant); quality of the coaching summary is the "wow" moment — don't cheapen it. If cost pressure appears at scale, `claude-sonnet-5` ($3/$15, intro $2/$10) is the step-down — owner's call, not the agent's. |
| **Content authoring (build-time)** | `claude-opus-4-8`, human-reviewed | Lesson scripts, distractor options, tutor line variants are generated into the content repo, reviewed, then frozen as JSON. Never generated at runtime. |
| **Tutor voice TTS** | **ElevenLabs multilingual** (premium voice, good Arabic) — fallback **Azure Neural `ar-*`** if cost/licensing bites | ~95% of lines pre-generated at build time and shipped as assets → TTS spend is one-time per content release, not per user. Live TTS only via `/tts/line` with a Postgres-backed cache keyed on `sha256(text+voice)`. |
| **Canonical letter/harakah sounds** | **Human-recorded** by a qari/teacher (~250 clips: 28 letters isolated + each with fatha/kasra/damma/sukoon-context + madd) | TTS cannot be trusted for isolated makhraj-correct phonemes; this is the pedagogical core and a quality signal users will judge instantly. Record once, 16-bit 44.1kHz, normalize, ship as assets. |

**API-shape notes for the implementer (backend is Kotlin — use the Anthropic Java SDK):**
- Model IDs exactly: `claude-haiku-4-5`, `claude-opus-4-8`. No date suffixes.
- Opus 4.8: use `thinking: adaptive` where reasoning helps (coaching summary); **never**
  send `temperature`/`top_p`/`budget_tokens` (400s).
- Put the frozen tutor system prompt + rubric first with `cache_control: {type: "ephemeral"}`;
  per-exercise context goes after the breakpoint. Verify `cache_read_input_tokens > 0`.
- Use structured outputs (`output_config.format`, json_schema) for feedback objects so
  the client never parses prose.
- Claude has **no audio input** — audio is always transcribed/graded by Whisper/Muaalem
  first; the LLM sees text + structured grading results.

### 3.3 Tiered pronunciation-grading strategy (the crux)

The vision doc assumed "the engine can't grade isolated spoken letters" and fell back to
recognition-only MCQ. We upgrade that assumption with a tiered design + a spike:

- **Tier 0 — Recognition (no mic):** tap-the-letter-you-heard, match sound→letter.
  Always available; used heavily in Units 1–2 and as the low-confidence fallback.
- **Tier 1 — Echo with syllable context:** learner repeats a **CV syllable or short
  word** (e.g. بَ، بُ، بِسْمِ) rather than a bare phoneme. Graded by:
  - **Path A (preferred, Spike S1):** Muaalem with a phonetized reference of that exact
    syllable/word (`quran_phonetizer` on arbitrary Uthmani-script text). If the spike
    passes, we get phoneme+sifat-level grading of *lesson* audio with zero new ML.
  - **Path B (fallback):** Whisper transcription + normalized string match against the
    target + confusion table (e.g. heard س for ص → "make it heavier" feedback).
- **Tier 2 — Read-aloud, real Quran:** words/ayat from the mushaf graded by the full
  existing `/audio/analyze` pipeline. Used from Unit 7 onward and in the entire Tajweed
  track. Already works today.
- **Grading is always server-side**; the client gets a normalized result:
  `{verdict: pass|retry|fail, score: 0..1, phoneme_issues: [...], feedback_key: "..."}`.

### 3.4 Latency budget (premium feel is mostly latency)

| Interaction | Budget | How |
|---|---|---|
| Play any scripted audio | instant | bundled assets |
| Echo exercise → verdict | ≤ 2.5s warm | Modal warm path is ~1.7s; keep `min_containers=1` in production (§12); upload trimmed audio (≤4s clips) |
| Dynamic tutor line (LLM) | ≤ 1.5s | Haiku + prompt cache + `max_tokens≈300`; UI plays a thinking chime + animated avatar so waits read as intentional |
| Post-lesson summary | async | fire request when last exercise completes; summary screen shows score instantly, coaching card streams in |
| Cold start | never user-visible | paid Render + `min_containers=1` on Modal; `/health` warm ping worker |

---

## 4. Arabic track — full curriculum design

**Promise:** zero → can read any ayah of the mushaf aloud, with correct letter sounds,
ready for tajweed refinement. Recognition → discrimination → production → fluency, one
new concept per lesson, everything audio-first.

**Structure:** 8 units → 41 lessons + placement. A lesson = 7–10 minutes. Units unlock
sequentially; lessons within a unit unlock sequentially; completed lessons re-playable
("practice" mode, half XP). `DEMO_MODE` flag bypasses all locks (kept from vision doc).

### 4.0 Unit 0 — Placement (one adaptive session, skippable)

- Item bank drawn from Units 1–7 checkpoint items (recognition + echo).
- Adaptive ladder: start at Unit 3 difficulty; 2 consecutive misses drops a level, 3
  consecutive hits raises. 12–18 items, ~4 minutes.
- Output: `placement_results` row + `profiles.arabic_level` (0–8) → roadmap unlocks up
  to that unit. "I'm new to Arabic" button skips the test and sets level 0.
- Post-test: Opus generates a 3-sentence personal plan ("You know your letters — we'll
  start you at short vowels…"), spoken by the tutor voice. First wow moment.

### Unit 1 — The Letters (6 lessons)

Letters grouped by visual family, sound taught with each shape from the start.

| Lesson | Letters | New concept |
|---|---|---|
| 1.1 | ب ت ث ن ي | dots distinguish letters |
| 1.2 | ج ح خ | throat letters intro |
| 1.3 | د ذ ر ز و | non-connectors exist |
| 1.4 | س ش ص ض | whistling & heavy sounds |
| 1.5 | ط ظ ع غ ف ق | deep-throat & heavy sounds |
| 1.6 | ك ل م هـ ء أ + checkpoint | hamza; unit checkpoint |

Exercise mix: `LISTEN_PICK` (hear sound → tap letter), `READ_PICK` (see letter → tap the
audio that matches), `ECHO` (Tier 1, letter + fatha syllable), `ODD_ONE_OUT`.

### Unit 2 — Hearing the difference (5 lessons)

Minimal-pair discrimination — the #1 failure point for non-Arabs and the foundation of
tajweed later. 2.1 ه/ح/خ · 2.2 س/ص، ت/ط، د/ض · 2.3 ذ/ظ/ز، ث/س · 2.4 ك/ق، أ/ع ·
2.5 mixed gauntlet + checkpoint. Exercise mix: `DISCRIMINATE` (hear one of a pair →
which was it), `ECHO` pairs back-to-back (say سَ then صَ), `LISTEN_PICK` with cruel
distractors. Tutor explains articulation points with the mouth-diagram asset per letter.

### Unit 3 — Short vowels / harakat (6 lessons)

3.1 fatha · 3.2 kasra · 3.3 damma · 3.4 mixed CV drills across all 28 letters ·
3.5 two-syllable chains (بَتَ، سُكِ…) · 3.6 checkpoint: read 10 random syllables aloud
(Tier 1 graded). New exercise: `READ_ALOUD_SYLLABLE`.

### Unit 4 — Letters join up (5 lessons)

4.1 initial/medial/final forms, connector rules · 4.2 reading 2-letter joins ·
4.3 3-letter words (fully vowelled) · 4.4 the six non-connectors in words ·
4.5 checkpoint. New exercise: `CONNECT` (tap the correct joined form), `BUILD_WORD`
(drag glyph pieces in order — satisfying, premium-feeling interaction).

### Unit 5 — Sukoon, shadda, tanween (4 lessons)

5.1 sukoon (closed syllables — first taste of qalqalah letters sounding "tight") ·
5.2 shadda (doubling; نّ مّ get a "hold your nose — you'll master this in Tajweed" teaser) ·
5.3 tanween an/in/un · 5.4 checkpoint reading full vowelled words aloud.

### Unit 6 — Long vowels (4 lessons)

6.1 ا as madd (بَا vs بَ — length discrimination) · 6.2 ي and و as madd + leen ·
6.3 mixed long/short reading drills (this is *the* rhythm skill tajweed madd builds on) ·
6.4 checkpoint. New exercise: `LENGTH_JUDGE` (was that 1 count or 2?).

### Unit 7 — Reading real words (6 lessons)

High-frequency Quranic vocabulary — every word the learner reads here appears in the
mushaf. 7.1 الله، رَبّ، بِسْمِ + lam-of-Allah heaviness preview · 7.2 ال the definite
article, solar/lunar · 7.3 ة، ى، آ · 7.4 hamzat al-wasl, silent alif (وا) ·
7.5 Uthmani-script quirks (superscript alif, small seen — read what you see in the
mushaf) · 7.6 checkpoint: read 12 real Quranic words aloud (Tier 1/Tier 2 graded).

### Unit 8 — First ayat (5 lessons) → graduation

Full read-aloud of short surahs, graded by the **full Muaalem pipeline** (Tier 2) but
with tajweed-rule errors *softened* into encouragement ("length was short — that's a
madd, next track!") — mispronunciation errors are corrected, rule errors are teased.

8.1 Al-Ikhlas · 8.2 Al-Kawthar · 8.3 An-Nas · 8.4 Al-Falaq · 8.5 **Al-Fatihah — the
graduation.** Completion = confetti + certificate card + the Tajweed track unlocks with
a spoken invitation from the tutor.

### 4.x Lesson anatomy (uniform, engine-driven)

```
WarmUp   (2 SRS review items from the queue, skipped if queue empty)
Teach    (tutor voice + animated glyph/mouth diagram; ~45s; replayable)
Drill    (8–12 exercises, mixed types, 2 hearts-free retries per item)
Wrap     (score ring animates, XP counts up, streak flame, tutor voice line,
          weak items pushed to SRS queue, [Continue] → roadmap)
```

- **Mastery:** lesson passes at ≥80% first-attempt accuracy; checkpoints at ≥85%.
  Failing a checkpoint prescribes a targeted practice lesson (auto-assembled from the
  unit's item bank — pure client logic, no LLM).
- **SRS queue:** wrong items become `review_items` (SM-2-lite: intervals 1, 3, 7, 21
  days). WarmUp consumes due items; Progress tab shows the due count.
- **Dynamic tutor moments** (the only in-lesson LLM calls): after 2 consecutive misses
  on the same item (Haiku explains *why* — "your ص sounded like س, round your lips…"
  grounded in the phoneme_issues payload), and the learner-initiated "Explain" button.
  Everything else is scripted audio.

### 4.y Content pipeline (build-time, in-repo)

- `content/` (new top-level dir): `curriculum.json` (units→lessons→exercise manifests),
  `lessons/{unit}.{n}.json` (exercise items: type, prompt asset, answer, distractors,
  grading tier + reference text), `audio/letters/*.ogg` (human-recorded),
  `audio/tts/{hash}.ogg` (pre-generated tutor lines), `tts_manifest.json`.
- `scripts/build_content.py`: validates JSON against a schema, generates missing TTS
  lines via the provider API, verifies every referenced asset exists, emits the Android
  asset pack. CI fails on dangling references.
- Content versioned via `curriculum.json:"version"`; client bundles v1; remote-update
  mechanism is deferred (§13).

---

## 5. Tajweed track — full curriculum design

**Promise:** you can already *read*; now every rule becomes automatic and verified by
the ML engine. Teach-then-test: every lesson teaches ONE rule, then grades it on real
ayat. The curriculum is ordered by what **Muaalem can actually detect**, so every lesson
is verifiable:

| # | Module | Lessons | Engine signal |
|---|---|---|---|
| T1 | Ghunnah & the nasal family (نّ مّ, meem/noon sakinah overview) | 3 | `ghonna` sifat head + phoneme diff |
| T2 | Noon sakinah & tanween: izhar, idgham, ikhfa, iqlab | 4 | phoneme diff (substitution/deletion patterns) — verify per-rule detectability against real sessions (Spike S3) |
| T3 | Qalqalah (ق ط ب ج د) | 2 | `qalqla` head, sukoon + waqf positions |
| T4 | Madd family: tabee'i, muttasil, munfasil, aared, lazim | 5 | `expected_len` vs `predicted_len` — the engine's strongest signal |
| T5 | Tafkheem & tarqeeq (heavy letters, ra rules, lam of Allah) | 3 | `tafkheem_or_taqeeq` head |
| T6 | Sifat mastery (hams/jahr, shidda/rakhawa, safeer, tikraar, tafashie, istitala, itbaq) | 4 | remaining sifat heads |
| T7 | Waqf & flow: stopping, aared at pause, putting it together on Al-Fatihah + juz-amma surahs | 3 | full pipeline |

**Lesson flow:** `RuleIntroScreen` (rule card: name ar/en, what it sounds like with 2
audio examples right/wrong, when it applies) → recite a curated ayah exercising the rule
(existing `RecitationScreen`, unchanged) → result filtered to *this rule first*, other
errors collapsed under "also noticed" → pass = 2 clean readings of ayat containing the
rule → back to roadmap.

**Adaptive selection:** `GET /learn/next-lesson` scores candidate ayat by
tag-overlap with the user's weak rules (`mistake_breakdown` + `sifat_breakdown`),
tie-broken by least-recently-practiced (vision doc Workstream B, unchanged). Ayah→rule
tags produced deterministically at build time by a script calling
`Phonemizer().phonemize(ref).tajweed_mappings()` from `quranic_phonemizer` (vision doc
Workstream C, unchanged) into `content/ayah_rule_tags.json`. Note: this is a separate
package from `quran_transcript.quran_phonetizer`, the function used for grading
elsewhere in this doc (§3.3) and in `ml/muaalem_modal.py` — same-sounding names,
different libraries, don't conflate them.

**Explore stays open:** the mushaf tab lets anyone analyze any ayah anytime — that's the
sandbox; the track is the curriculum. Memorization mode remains deferred (§13).

---

## 6. App structure & navigation

Bottom nav goes from 3 tabs to 4:

| Tab | Route | Content |
|---|---|---|
| **Learn** (default) | `learn` | The roadmap/path: Unit headers, lesson nodes (done ✓ / current pulsing / locked), streak flame + XP in header, "Continue" hero CTA that deep-links to the next lesson. Tajweed modules render as a visually distinct second chapter of the same path. |
| **Qur'an** | `mushaf` (exists) | Surah index → QCF mushaf → analyze any ayah (existing flow, untouched). |
| **Progress** | `progress` | Streak calendar, XP/level, weak-rules & weak-sounds breakdown (uses `/progress` + `sifat_breakdown`), review-queue card ("6 items due — Review now"), session history. |
| **Profile** | `profile` (exists) | Account, settings, daily-goal picker, notifications toggle, about. |

New routes: `learn`, `lesson/{lessonId}` (lesson player), `lesson_summary/{attemptId}`,
`placement`, `rule_intro/{ruleId}`, `progress`. Existing `recitation/{sura}/{aya}` is
reused by the Tajweed track with an optional `?focusRule=` arg.

Lesson player is **one screen** (`LessonScreen` + `LessonViewModel`) driven by the
exercise manifest — a state machine over `ExerciseState` (Prompt → Listening/Recording →
Grading → Feedback → Next), with per-exercise-type composables
(`ui/lesson/exercises/EchoExercise.kt`, `ListenPickExercise.kt`, …). This is the single
biggest new client component.

---

## 7. Premium feel spec

Extends `android/UI_SPEC.md` (which remains law for color/type/spacing). Sonnet: apply
these as you build each milestone — premium is not a final coat of paint.

1. **Motion.** Every state change animates: lesson nodes spring in (staggered), the
   score ring sweeps, XP counts up, correct answers get a 250ms scale-pop, wrong answers
   a gentle 3px shake (never punitive red flashes). Use Compose `animate*AsState` /
   `AnimatedContent`; standard easing `FastOutSlowIn`; nothing over 400ms.
2. **Sound design.** Tiny audio identity: correct chime, incorrect (soft, non-buzzer),
   lesson-complete flourish, streak-extended sparkle, record start/stop ticks. Bundle as
   ogg, ≤50KB each, honoring the system sound toggle + a settings switch.
3. **Haptics.** Light tick on correct, medium on lesson complete, subtle on record
   start/stop (`HapticFeedback` API; respect system settings).
4. **Mic UX.** Pingo-grade recording affordance: idle pulsing mic → recording shows a
   **live amplitude waveform** (`AudioRecord` amplitude → Canvas bars) with a soft glow;
   auto-stop on 1.2s trailing silence (with manual stop fallback).
5. **Arabic typography.** Amiri for all Arabic; teaching glyphs render at ≥96sp with
   generous line height; harakat color-accented (fatha/kasra/damma each get a consistent
   accent tint from the theme, used *everywhere* they're taught).
6. **Tutor presence.** A simple animated avatar (breathing idle, mouth-moves while
   audio plays, thinking shimmer during LLM waits). A static premium illustration +
   subtle animation beats a cheap Lottie rig — keep it minimal and consistent.
7. **Zero dead ends.** Every error state has one retry action, honest copy ("Warming up
   the recitation engine… ~20s" — never a frozen spinner), and offline detection with a
   friendly card. Skeleton loaders, never blank screens.
8. **Streak & celebration.** Streak flame with day count in the Learn header; daily-goal
   ring; confetti (particle Canvas, not a library gif) on unit completion and graduation.
9. **App identity.** Adaptive vector icon (green/sand بيان mark), branded splash
   (SplashScreen API), consistent 16/20/24dp + 2dp elevation from UI_SPEC.
10. **Performance bar.** Cold start < 2s to Learn tab; lesson transitions 60fps; no
    ANRs; audio playback latency <100ms (pre-load next exercise's assets while the
    current one plays).

---

## 8. Data model (Supabase)

Keep `users`, `sessions`, `mistakes`. Add (RLS scoped to `auth.uid()` where the client
reads directly; the Ktor backend uses the service connection as today):

```sql
profiles          (user_id PK→users, arabic_level int default 0, xp int default 0,
                   streak_count int default 0, streak_updated_on date,
                   daily_goal_minutes int default 10, created_at, updated_at)
placement_results (id PK, user_id FK, level int, items jsonb, created_at)
lesson_progress   (user_id, lesson_id text, status text check in
                   ('locked','available','in_progress','completed'),
                   best_score numeric, attempts int, completed_at,
                   PRIMARY KEY (user_id, lesson_id))
lesson_attempts   (id PK, user_id FK, lesson_id text, score numeric,
                   item_results jsonb, coach_summary text, created_at)
review_items      (id PK, user_id FK, item_ref text, ease numeric default 2.5,
                   interval_days int default 1, due_on date, lapses int default 0)
xp_events         (id PK, user_id FK, amount int, reason text, created_at)
sifat_mistakes    (id PK, session_id FK→sessions cascade, phonemes_group text,
                   attribute text, predicted text, expected text,
                   confidence numeric, created_at)          -- vision §5F, now scheduled
tts_cache         (text_hash text PK, voice text, storage_path text, created_at)
```

Curriculum content is **not** in the DB — it ships as versioned app assets (§4.y);
the DB stores only per-user state keyed by stable `lesson_id`/`item_ref` strings
(e.g. `"ar.3.2"`, `"ar.3.2.echo.ba_kasra"`).

---

## 9. Backend API additions

All auth-required unless noted; same error envelope as `docs/api-spec.md`.

| Endpoint | Purpose |
|---|---|
| `POST /speech/grade` | multipart audio + `{tier, reference_text, item_ref}` → routes to Muaalem (Tier 1/2) or Whisper (Path B) → normalized verdict. Full contract (request/response JSON, `phoneme_issues[]` shape, `feedback_key` enum, grading policy): `docs/api-spec.md` §POST /speech/grade. |
| `POST /tutor/turn` | `{kind: "stuck_help"\|"explain", item_context, grading_result}` → Haiku → `{text, tts_url?}` (structured output) |
| `POST /tutor/lesson-summary` | `{lesson_id, item_results[]}` → Opus 4.8 → `{summary_text, focus_points[], encouragement}`; persisted onto `lesson_attempts` |
| `GET /learn/path` | roadmap state: units/lessons + per-user status + streak/xp header data |
| `POST /learn/complete` | lesson attempt result → updates `lesson_progress`, `xp_events`, streak, SRS inserts; returns updated header data |
| `GET /learn/reviews` · `POST /learn/reviews/{id}/result` | SRS queue |
| `POST /learn/placement` | item results → level; triggers Opus plan blurb |
| `GET /learn/next-lesson` | adaptive tajweed ayah selection (vision Workstream B) |
| `POST /tts/line` | text → cached TTS asset URL (checks `tts_cache` first) |

Secrets added to `.env.example` (empty values, same commit as the code that needs them):
`ANTHROPIC_API_KEY`, `TTS_API_KEY`, `WHISPER_URL` (optional, has Modal default).

Architecture note: the vision doc's Edge-Functions migration is **dropped for v1** —
solo developer, and Ktor already exists and handles multipart/long-poll well. Revisit
post-launch only if Render cost or ops pain demands it.

---

## 10. Milestones — execution plan

Rules for the executing agent: work on `main` (repo branch model), one milestone = one
reviewable chunk of commits using the `type(module): …` format, run the module's
pre-commit checks (`./gradlew build && ./gradlew test`, secret grep) before every
commit, and keep `docs/api-spec.md` updated in the same commit as any endpoint change.
Every milestone ends with its acceptance list green on a real device.

### M0 — Foundations & shell (android)
Scope: 4-tab nav (Learn/Qur'an/Progress/Profile), `learn` + `progress` route stubs,
design-system additions (motion utilities, sound player util, haptics util, streak
flame + XP header composables, score ring, confetti canvas), app icon + branded splash,
`DEMO_MODE` build flag.
Accept: app builds; nav works; Learn tab shows a placeholder path with animated nodes;
icon/splash present; dark mode clean.

### M1 — Content pipeline + curriculum v1 (content, scripts, ml)
Scope: `content/` schema + `curriculum.json` for Units 1–3 fully itemized (later units
stubbed with manifests), `scripts/build_content.py` (validate, TTS-generate, pack),
letter-audio recording checklist doc, ayah rule-tag generator script (Workstream C).
Spikes S1+S2 run here (§11) and their result is committed as
`docs/decisions/grading-tiers.md`, fixing Path A vs B.
Accept: `python scripts/build_content.py` passes; Android assets pack contains Units
1–3 with zero dangling references; grading-tier decision documented.

### M2 — Lesson player with recognition exercises (android)
Scope: `LessonScreen` + `LessonViewModel` state machine; exercise composables
`LISTEN_PICK`, `READ_PICK`, `DISCRIMINATE`, `ODD_ONE_OUT`, `CONNECT`, `BUILD_WORD`;
warm-up/teach/drill/wrap flow; local-only progress (DataStore) for now; sounds, haptics,
animations per §7.
Accept: Units 1–2 fully playable offline end-to-end on device; wrap screen animates
score/XP; a failed checkpoint assembles a practice lesson.

### M3 — Voice loop: echo grading (ml, backend, android)
Scope: implement the S1-chosen path — either extend `muaalem_modal.py` with a
`/grade-text` endpoint (arbitrary Uthmani reference) or deploy
`ml/whisper_modal.py`; Ktor `POST /speech/grade` with tier routing; Android `ECHO`,
`READ_ALOUD_SYLLABLE`, `LENGTH_JUDGE` exercises with waveform mic UX + silence
auto-stop; retry/verdict UI.
Accept: Unit 3 playable with real mic grading; wrong-consonant and wrong-vowel test
recordings produce distinct, correct feedback; warm-path verdict ≤2.5s on device.

### M4 — Learn backend: progress, streak, XP, SRS, placement (backend, android)
Scope: Supabase tables (§8) + repositories; `/learn/path`, `/learn/complete`,
`/learn/reviews*`, `/learn/placement`; Android switches from DataStore to server truth
(DataStore becomes offline cache); placement flow UI; streak/XP live in header;
Progress tab v1.
Accept: fresh account → placement → correct unlocks; completing a lesson on device A
shows on device B; streak increments across a real day boundary; reviews appear in
warm-up.

### M5 — LLM tutor integration (backend, android)
Scope: Anthropic Java SDK in Ktor; `/tutor/turn` (Haiku, structured output, prompt
cache) + `/tutor/lesson-summary` (Opus 4.8, async) + `/tts/line` with cache; Android
"Explain" button, stuck-help interjection after 2 misses, streaming-in coaching card on
the summary screen; tutor avatar states (idle/speaking/thinking).
Accept: stuck-help fires with grounded, specific feedback ≤1.5s warm; summary card
references the learner's actual mistakes; `cache_read_input_tokens > 0` verified in
logs; kill-switch env flag degrades gracefully to scripted lines.

### M6 — Content complete: Units 4–8 + graduation (content, android)
Scope: itemize Units 4–8 (M1 pipeline makes this mostly content work); Tier 2 read-aloud
exercise wrapping the existing analyze pipeline with softened rule errors; graduation
sequence (certificate card, confetti, tajweed-track unlock).
Accept: full zero→Al-Fatihah path playable; graduation triggers exactly once; rule
errors in Unit 8 render as teasers, mispronunciations as corrections.

### M7 — Tajweed track (backend, android, content)
Scope: sifat persistence end-to-end (parse `sifat_errors` → `sifat_mistakes` →
`sifat_breakdown` in `/progress` — vision §5F, exact file pointers there);
`RuleIntroScreen` + rule cards for T1–T7 (audio examples right/wrong);
rule-focused result filtering on `RecitationScreen`; `/learn/next-lesson` adaptive
selection using rule tags; tajweed nodes on the Learn path; Progress tab weak-rule
breakdown. Spike S3 (rule-name reconciliation) runs first.
Accept: T1 ghunnah lesson end-to-end: intro → recite → rule-focused result → pass after
2 clean readings; a deliberate short madd shows up in `sifat_breakdown`/`mistake_breakdown`
and biases the next-lesson selection.

### M8 — Production hardening & launch (infra, all modules)
Scope: §12 in full — paid infra, observability, rate limiting, cost caps, Play Store
packaging, store assets, privacy policy, notifications (streak reminder at user-chosen
time via WorkManager).
Accept: §12 checklist green; internal-testing track build installed from Play Store on
a clean device passes the full M0–M7 acceptance run, cold.

---

## 11. Spikes & risks

| # | Spike (timeboxed, result committed to `docs/decisions/`) | Decides |
|---|---|---|
| **S1** | Can `quran_phonetizer` + Muaalem grade arbitrary short Uthmani text (بَ، بِسْمِ)? Test 10 syllables/words, correct + deliberately wrong recordings. | Tier-1 Path A vs B (§3.3). Passing = phoneme-grade the whole Arabic track with existing ML — the plan's biggest lever. |
| **S2** | Whisper large-v3 (+ tarteel fine-tune) accuracy on isolated syllables from a non-native speaker, 30-sample eval. | Path B viability & confusion-table design. |
| **S3** | Record one real session per T-module rule; inspect `mistakes.rule_name_en` vs phonemizer enum names; confirm izhar/ikhfa/idgham/iqlab are distinguishable in the diff. | Tajweed lesson pass/fail logic + naming map (vision Workstream C caveat). |
| **S4** | TTS bake-off: ElevenLabs vs Azure Arabic voices on 20 tutor lines (Arabic + English mix), judged by a native speaker. | Tutor voice provider + license check for bundled audio. |

Top risks: (1) S1 fails → Units 1–6 lean on recognition + Whisper, production grading
starts at Unit 7 — plan still works, wow-factor drops; mitigate by running S1 first.
(2) Letter-audio recording is a human dependency → checklist ready in M1, TTS
placeholder assets allowed until studio clips land, swap is a pure asset change.
(3) Solo-dev scope → milestones are strictly sequential and each is shippable; M2+M3
alone already demo the product thesis. (4) LLM cost surprise → per-user daily call caps
+ kill-switch (M5), pre-generated content keeps the floor near zero.

---

## 12. Production hardening & launch checklist (M8 detail)

- **Infra:** Render paid instance (no sleep); Modal `min_containers=1` for Muaalem
  during launch window (revisit vs. cold-start tolerance after usage data); Supabase
  paid tier + daily backups verified; secrets rotated out of any dev usage.
- **Observability:** structured logs w/ request IDs across Ktor; Sentry (Android +
  backend); per-endpoint latency + LLM/TTS spend dashboards (simple: log-based +
  provider dashboards); Modal alerts on error rate.
- **Abuse & cost control:** rate limits on `/speech/*` and `/tutor/*` (per-user,
  per-day); max audio duration enforced server-side; Anthropic spend alert; TTS cache
  hit-rate check.
- **Android release:** R8/proguard verified; versioned release signing via Play App
  Signing; targetSdk current; `DEMO_MODE=false`; ANR/crash-free ≥99.5% in internal
  testing; accessibility pass (TalkBack on lesson player, contrast, touch targets).
- **Store:** listing copy + screenshots (Learn path, lesson, mushaf, result screen),
  privacy policy (voice recordings: uploaded for grading, not retained beyond
  processing — make this true in code: don't persist raw audio), data-safety form,
  account-deletion path (Play requirement).
- **Legal/content:** QCF font + mushaf data attribution screen; qari recording
  license on file; TTS provider terms allow bundled synthetic audio.

---

## 13. Deferred (one-day) list

Explicitly out of scope for v1 — tracked so they don't creep in:

- Memorization mode (Tarteel-style hidden verses; batch path first, streaming Whisper
  later) — vision Workstream E.
- Open conversation / roleplay with the tutor in Arabic (Pingo's roleplay mode).
- Live word-by-word follow-along highlighting during recitation (streaming ASR).
- Edge Functions migration; remote curriculum updates without app release; iOS/KMP;
  leaderboards & social; subscriptions/paywall (design free-first, instrument
  everything so the premium line can be drawn from data); widgets; wear.

---

*Written 2026-07-04. Model/pricing facts current as of this date (Anthropic: Haiku 4.5
$1/$5, Sonnet 5 $3/$15 intro $2/$10, Opus 4.8 $5/$25 per MTok). Sources on Pingo:
pingo.ai product pages and third-party reviews (languatalk.com, thinkinitalian.com,
voiceaispace.com).*
