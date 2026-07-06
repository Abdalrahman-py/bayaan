# Bayaan — Roadmap

> Last updated: 2026-07-05. Format: Now / Next / Later. Source docs: `README.md`,
> `docs/PRODUCT_VISION.md` (long-term encyclopedia), `docs/PRODUCTION_PLAN.md`
> (current execution plan — wins on sequencing disputes), `docs/NEXT_STEPS.md`,
> `docs/CODEBASE_MAP.md` (matches the code as of today).
>
> This file is a communication tool, not a task tracker — it shows what's shipped,
> what's committed, and what's directional. For the milestone-by-milestone build
> spec, see `docs/PRODUCTION_PLAN.md` §10.

---

## Status overview

**Shipped:** a working prototype with one full loop end to end — sign in, pick an
ayah, record it, get tajweed/pronunciation mistakes highlighted on the Arabic
script, try again. Three services (Android/Kotlin, Ktor backend, Muaalem ML
engine on Modal) plus a subset-bundled page-faithful mushaf renderer.

**In flight:** nothing yet — the product is at the pivot point between "single
working loop" and the full AI-tutor product. `docs/PRODUCTION_PLAN.md` defines
milestones M0–M8; none have started.

**Not started:** everything below M0.

---

## Now (current focus)

Small, unblocking work — land this before picking up M0.

| Item | What / why |
|---|---|
| Commit pending polish | Scrollable auth/home screens + friendly auth-error messages are done but uncommitted in the working tree. Land it so it isn't lost. |
| Decide mushaf bundling strategy | Only a subset of the 604-page mushaf ships today (fonts are ~2MB each; all 47 ≈ 100MB). Three options on the table: bundle everything (simplest, fine for a sideloaded showcase), download-on-demand (real work, needed for Play Store), or bundle a curated subset permanently. Blocks "wider Quran coverage." |
| Cold end-to-end device verification | Run the full signup → login → mushaf → record → highlight loop on a real device with both Render and Modal cold. Gate before calling the current build "done." |
| **M0 — Foundations & shell** | 4-tab nav (Learn / Qur'an / Progress / Profile), `learn` + `progress` route stubs, design-system additions (motion, sound, haptics utilities; streak/XP header; score ring; confetti canvas), app icon + branded splash, `DEMO_MODE` build flag. |

---

## Next (1–3 months)

The Arabic-track foundation — the headline feature and the thing that turns this
from a demo into a learning app.

| Item | What / why | Depends on |
|---|---|---|
| **Spike S1** — arbitrary-text phoneme grading | Test whether the existing Muaalem model can grade short Arabic syllables/words (not just full ayat). This is the single biggest lever in the plan: if it passes, the entire Arabic track gets phoneme-level grading with zero new ML. Run first — it decides M1's design. | — |
| **Spike S2** — Whisper fallback accuracy | 30-sample eval of Whisper large-v3 (+ Tarteel fine-tune) on isolated syllables, in case S1 fails. | — |
| **M1 — Content pipeline + curriculum v1** | `content/curriculum.json` schema, Units 1–3 fully itemized, `scripts/build_content.py` (validate, TTS-generate, pack), letter-audio recording checklist, ayah rule-tag generator. Grading-tier decision from S1/S2 gets committed to `docs/decisions/grading-tiers.md`. | S1, S2 |
| **M2 — Lesson player (recognition exercises)** | `LessonScreen` + `LessonViewModel` state machine; exercise types `LISTEN_PICK`, `READ_PICK`, `DISCRIMINATE`, `ODD_ONE_OUT`, `CONNECT`, `BUILD_WORD`; warm-up/teach/drill/wrap flow; local-only progress via DataStore. | M1 |
| **M3 — Voice loop: echo grading** | The chosen S1 path wired up (either a Muaalem `/grade-text` endpoint or a Whisper deployment); `/speech/grade` with tier routing; `ECHO`, `READ_ALOUD_SYLLABLE`, `LENGTH_JUDGE` exercises with waveform mic UX. | M1, M2 |
| **M4 — Progress backend: streak, XP, SRS, placement** | New Supabase tables (`profiles`, `placement_results`, `lesson_progress`, `review_items`, `xp_events`); `/learn/path`, `/learn/complete`, `/learn/reviews*`, `/learn/placement`; app switches from local DataStore to server truth; Progress tab v1. | M2, M3 |

---

## Later (3–6+ months)

Directional — scope and timing will flex as Next lands.

| Item | What / why |
|---|---|
| **M5 — LLM tutor integration** | Claude Haiku for in-lesson dynamic feedback (stuck-help, "explain"), Claude Opus for post-lesson coaching summaries, TTS with caching. Needs per-user daily call caps + a kill-switch designed in from the start (cost risk). |
| **M6 — Content complete: Units 4–8 + graduation** | Mostly content authoring by this point (pipeline already built in M1). Tier-2 read-aloud exercises wrap the existing analyze pipeline; graduation sequence unlocks the Tajweed track. |
| **M7 — Tajweed guided-lesson track** | Closes the known `sifat_errors` persistence gap (engine returns them, backend currently drops them). `RuleIntroScreen` + rule cards for 7 tajweed modules, rule-focused result filtering, adaptive next-lesson selection by weak rules. |
| **M8 — Production hardening & launch** | Paid Render/Modal/Supabase tiers, observability (Sentry, latency dashboards), rate limiting, Play Store packaging, privacy policy, account deletion, QCF font licensing resolved with KFGQPC. |

### Explicitly deferred (tracked so they don't creep in)

- Memorization mode (Tarteel-style hidden verses — batch path first if picked up later, streaming ASR after that)
- Open-ended roleplay/conversation mode with the tutor
- Live word-by-word follow-along highlighting during recitation (streaming ASR)
- Migration to Supabase Edge Functions
- Remote curriculum updates without an app release
- iOS / Kotlin Multiplatform
- Leaderboards & social features
- Subscriptions / paywall
- Widgets, Wear OS

---

## Risks and dependencies

**Spike S1 is the critical path.** Whether the Arabic track (Units 1–6) gets real
phoneme-level grading or falls back to recognition-only + Whisper hinges entirely
on this spike. It should run before M1's content design is locked in, not
discovered partway through.

**Mushaf bundling decision is open and blocking.** "Wider Quran coverage" (listed
in the README's own roadmap) can't proceed until bundle-vs-download is decided —
this has been open since before this roadmap was written.

**Solo developer, fully sequential.** No parallel tracks are possible; each
milestone's timeline is a soft estimate, not a commitment. Milestones are ordered
so each one is independently shippable (M2 + M3 alone already demo the product
thesis).

**Two stacked cold starts today** (Render free tier ~30–60s + Modal ~24s) are
acceptable for a prototype/demo but must be resolved with paid infra before M8.

**QCF mushaf font license is showcase-only.** MIT covers the page-layout data but
not the fonts themselves (KFGQPC owns those) — this is a hard blocker for any
public launch until permission is secured. Don't remove `assets/qcf4/ATTRIBUTION.md`.

**LLM cost exposure (M5).** Needs per-user daily caps and a kill-switch designed
in before dynamic tutor calls ship, not retrofitted after a cost surprise.

**Stale docs.** `backend/AGENTS.md` still describes the old HS256 JWT verification;
the code moved to JWKS/ES256 several commits ago. Low-risk but worth fixing next
time that file is touched, so an AI agent working from it isn't misled.

---

## Changes since last update

First recorded version of this roadmap — no prior version to diff against.
