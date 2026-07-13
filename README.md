# Bayaan

An AI-powered Quran recitation coach for Android. Pick an ayah, record your recitation, and Bayaan flags Tajweed and pronunciation mistakes directly on the Arabic script — no teacher required.

**Status: Learning track MVP** — guided Arabic curriculum with real-time speech grading, XP/streaks, and spaced repetition. Full recitation analysis loop with page-faithful mushaf (604 pages). Ready for graduation submission.

## What's Built

### Android — Kotlin, Jetpack Compose, Material 3
- 4-tab bottom nav (Learn · Qur'an · Progress · Profile)
- **Learn tab:** curriculum roadmap with animated nodes, server-driven progress/locks
- **Lesson player:** 6 exercise types (listen-pick, read-pick, discriminate, odd-one-out, connect, echo with real mic grading)
- **Qur'an tab:** full page-faithful QCF mushaf browser — all 114 surahs, 604 pages, RTL pager
- **Recitation screen:** record → upload → per-character mistake highlighting + sifat analysis
- **Progress tab:** streak/XP header, weak-rules breakdown, session history
- Premium feel: score ring, confetti canvas, haptics, sound effects, animated transitions
- Supabase Auth (email/password) with local token verification

### Backend — Kotlin, Ktor
- JWT verification via Supabase JWKS/ES256 (no per-request network roundtrip)
- `/audio/analyze` — forward audio to Muaalem engine, persist results
- `/speech/grade` — grade arbitrary Uthmani text for echo exercises
- `/learn/path`, `/learn/complete`, `/learn/reviews`, `/learn/placement` — full learning track API
- `/progress`, `/progress/sessions` — paginated history with mistake breakdown
- Exposed ORM + HikariCP → Supabase Postgres (11 tables)
- Deployed on Render (Docker, free tier)

### ML — Muaalem on Modal GPU
- `/correct` — grade full ayat against Quran database
- `/grade-text` — grade arbitrary Uthmani text (syllables, words) — enables Arabic track echo exercises
- 10 sifat classification heads (ghunnah, qalqalah, tafkheem, etc.)
- Scale-to-zero (~$0 idle), ~24s cold start, ~1.7s warm

### Content Pipeline
- 3 authored units (17 lessons) with recognition + echo exercises
- JSON schema-validated at build time by `scripts/build_content.py`
- Bundled as Android assets

## Architecture

```
[Android App] ──JWT + audio──▶ [Ktor Backend (Render)]
     ▲                              │
     │                  forward audio │ verify locally (JWKS)
     │                              ▼
     │               [Muaalem Engine (Modal GPU)]
     │                              │
     +────── JSON: errors ──────────+
                                    │
                    persist session + mistakes
                                    ▼
                        [Supabase Postgres]
```

## Documentation

| Doc | What's in it |
|---|---|
| [Graduation Report](docs/GRADUATION_REPORT.md) | Full project report (abstract, architecture, implementation, testing) |
| [Codebase Map](docs/CODEBASE_MAP.md) | System design, data flow, every moving part |
| [Production Plan](docs/PRODUCTION_PLAN.md) | Milestone-by-milestone build spec (M0–M8) |
| [API Spec](docs/api-spec.md) | Every endpoint, request/response shapes, error codes |
| [Tajweed Rules](docs/tajweed-rules.md) | The rules the engine detects, with examples |
| [Grading Tiers Decision](docs/decisions/grading-tiers.md) | Spike S1 results + Path A vs B decision |
| [Team Plan](docs/TEAM_PLAN.md) | Team split (Abdalrahman + Ramzi + Gemini) |

## Quick Start

### Backend
```bash
cd backend
./gradlew run   # needs SUPABASE_DB_URL and SUPABASE_PROJECT_REF env vars
```

### Android
```bash
cd android
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
```

### ML Engine
```bash
cd ml
modal deploy muaalem_modal.py
```

## Database Setup
Apply the migration in Supabase SQL editor:
```sql
-- backend/sql/0001_mvp_learn_tables.sql
```

## Roadmap

| Milestone | Status |
|---|---|
| M0 — App shell (4-tab nav, design system) | ✅ Done |
| M1 — Content pipeline + curriculum v1 | ✅ Done (Units 1–3) |
| M2 — Lesson player (recognition exercises) | ✅ Done |
| M3 — Voice loop (echo grading) | ✅ Done |
| M4 — Learn backend (progress, XP, SRS, placement) | ✅ Done |
| M5 — LLM tutor integration | ⬜ Planned |
| M6 — Content complete (Units 4–8) | ⬜ Planned |
| M7 — Tajweed guided-lesson track | ⬜ Planned (backend ready) |
| M8 — Production hardening & launch | ⬜ Planned |

## License
Private — graduation project. QCF font license is showcase-only pending KFGQPC permission.
