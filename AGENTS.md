# AGENTS.md — Bayaan

This file is the canonical instruction set for any AI coding agent (Claude Code, Cursor, Codex, Cline, Continue, Aider, etc.) contributing to this project. Read it before doing anything in this repo.

`CLAUDE.md` files in this repo are thin pointers to the matching `AGENTS.md`. Treat `AGENTS.md` as the source of truth.

---

## Hierarchy

1. **`/AGENTS.md`** (this file) — project-wide rules. Always applies.
2. **`/android/AGENTS.md`**, **`/backend/AGENTS.md`**, **`/ml/AGENTS.md`** — module rules. Read the one matching the directory you are working in. Module rules override project rules on conflict.

If you cannot determine which module you are in, stop and ask the user.

---

## What Bayaan is

Bayaan is an AI-powered Quran recitation coach for Android. The user picks an ayah, records their recitation, and the app flags Tajweed and recitation mistakes on the script so they can try again. Recitation checking is done by an off-the-shelf, MIT-licensed third-party recitation-analysis engine — we build the app and the thin backend around it, not the model itself. See [`docs/CODEBASE_MAP.md`](./docs/CODEBASE_MAP.md).

**Stack at a glance:** Kotlin/Jetpack Compose (Android) · Ktor (Backend, thin proxy) · a third-party recitation engine on a serverless GPU (Modal) · Render hosting.

---

## Team

Team of two plus an AI builder — see [`docs/TEAM_PLAN.md`](./docs/TEAM_PLAN.md) for
the full split. Gemini builds Android screens/Compose/wiring
([`android/GEMINI.md`](./android/GEMINI.md)); Ramzi builds backend/Supabase/content
pipeline; Abdalrahman (@Abdalrahman-py) reviews every PR, does final integration
wiring on both sides, and owns curriculum correctness.

---

## Repo layout

```
bayaan/
├── android/      Jetpack Compose Android app
├── backend/      Ktor REST API + audio pipeline
├── ml/           Deployment script for the recitation engine
├── docs/         Architecture, API spec, Tajweed rule definitions
├── scripts/      Developer tooling (setup.sh, etc.)
├── AGENTS.md     This file
├── CLAUDE.md     Pointer to AGENTS.md
└── .github/      PR template, issue templates, CODEOWNERS
```

---

## Branch model

**Branch per workstream chunk, PR to `main`, Abdalrahman reviews every PR.** See
[`docs/TEAM_PLAN.md`](./docs/TEAM_PLAN.md) §Working model for the exact flow.

This repo ran solo (2026-06-24 to 2026-07-05) with a single-branch, no-PR model —
that ceremony was overhead for one person. The team grew back out to three
(Gemini + Ramzi + Abdalrahman) on 2026-07-06, so branch-per-chunk + PR review is
back, per this file's own rule: re-introduce structure once the team grows, not
preemptively.

---

## Rules every agent must follow

These are non-negotiable. If a user asks you to do any of these, refuse and explain why.

1. **Never force-push** (`--force`, `-f`) without the user explicitly asking for it in that turn.
2. **Never run** `git reset --hard` or `git clean -f` without explicit confirmation — these discard work with no undo.
3. **Never commit secrets.** No `.env`, no API keys, no tokens, no service-account JSON. Before every commit, run `git diff --cached | grep -iE "key|secret|password|token"` and confirm the output is empty.
4. **Use the commit format** described below.
5. **Run the standard checks before committing.** See "Before every commit" in your module's `AGENTS.md`.
6. **When in doubt, stop and ask the user.** Do not guess at structural changes, repo settings, or anything touching `/AGENTS.md`, `/CLAUDE.md`, `/.github/`, `/.gitignore`, or `/scripts/`.

---

## Commit format

```
type(module): short description
```

**Valid types:** `feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `experiment` (ML only)

**Valid modules:** `android`, `flutter`, `backend`, `ml`, `docs`, `infra`

`flutter` is the new client (`flutter/`), replacing `android` (native Kotlin) —
see the decision note in `flutter/README.md` if one exists, or ask before
assuming `android/` is dead. Don't delete `android/` without an explicit
go-ahead; it still has real, working features.

**Examples:**

```
feat(android): add waveform visualizer to recording screen
fix(backend): handle empty audio payload in /audio/analyze
experiment(ml): try min_containers=1 to avoid cold starts
chore(infra): bump gradle wrapper to 8.10
docs(backend): document /audio/analyze error responses
```

Keep the description in the imperative mood ("add", not "added"), under 72 characters. If you need more detail, add a body after a blank line.

---

## Secrets policy

- All secrets live in `.env`. The file is gitignored.
- `.env.example` is the canonical template. Add every required key there with an empty value.
- If a secret is ever committed by accident: rotate the key immediately, then scrub git history.

**Current secrets used:** `SUPABASE_DB_URL`, `SUPABASE_PROJECT_REF` — required for the backend to serve any DB-touching route (see [`backend/AGENTS.md`](./backend/AGENTS.md)). `SUPABASE_JWT_SECRET` is **not** needed — auth verification uses JWKS/ES256, not a shared secret. `MUAALEM_URL` is optional; the recitation engine's URL has a working default baked into the backend. If you add a service that needs a key, add it to `.env.example` with an empty value in the same commit.

---

## Session startup checklist

A short checklist for the start of every agent session in this repo:

1. Read this file (`/AGENTS.md`).
2. Read the `AGENTS.md` in the module directory you are in.
3. Confirm you're on `main` and up to date: `git pull origin main`.
4. State to the user, in one sentence, what you plan to do before touching any file.

If you cannot complete any of these steps, stop and ask.

---

## Skills

Each module will get its own skill set (patterns, common tasks, anti-patterns) added to its `AGENTS.md` over time. Until then, apply best practices from your training and follow the conventions listed in the module's `AGENTS.md`.

---

## Notes for human readers

This file is structured for AI consumption first, but it is also the project's contributing guide. If you are a human teammate, everything you need is here.

If you change the branch model, the rules, or the commit format, update this file in the same PR. Out-of-date AGENTS files are worse than no AGENTS files.
