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

Bayaan is an AI-powered Quran recitation coach for Android. The user picks an ayah, records their recitation, and the app flags Tajweed and recitation mistakes on the script so they can try again. Recitation checking is done by the off-the-shelf **`obadx/quran-muaalem`** engine (MIT-licensed) — we build the app around it, not the model. See [`docs/quran-muaalem-decision.md`](./docs/quran-muaalem-decision.md).

**Stack at a glance:** Kotlin/Jetpack Compose (Android) · Ktor (Backend, thin proxy) · quran-muaalem on a Modal GPU (recitation engine) · Supabase (Auth + Postgres) · Railway hosting.

---

## Team

| Name        | Role                              | Modules       | GitHub Handle   |
| ----------- | --------------------------------- | ------------- | --------------- |
| Abdalrahman | AI & Backend Lead                 | /backend, /ml | @Abdalrahman-py |
| Issa        | Android — Screens & Navigation    | /android      | TBD             |
| Ramzi       | Backend + Infra                   | /backend      | TBD             |
| Osama       | Android — Voice & Core Recitation | /android      | TBD             |

When you need to assign a code reviewer, the matching owner from this table is the default.

---

## Repo layout

```
bayaan/
├── android/      Jetpack Compose Android app
├── backend/      Ktor REST API + audio pipeline
├── ml/           PyTorch Tajweed classifier (wav2vec2)
├── design/       Figma exports, icons, color tokens
├── docs/         Architecture, API spec, Tajweed rule definitions
├── scripts/      Developer tooling (setup.sh, etc.)
├── plans/        AI construction plans (not shipped)
├── AGENTS.md     This file
├── CLAUDE.md     Pointer to AGENTS.md
└── .github/      PR template, issue templates, CODEOWNERS
```

---

## Branch model

**One branch: `main`.** No `dev`, no per-module branches, no branch protection, no PR requirement. Commit and push directly to `main`.

This repo started with a multi-branch / PR-per-module model for a multi-person team. As of 2026-06-24, Abdalrahman is working solo, so that ceremony was pure overhead — it's gone. If the team grows back out, re-introduce structure then, not preemptively.

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

**Valid modules:** `android`, `backend`, `ml`, `docs`, `infra`

**Examples:**

```
feat(android): add waveform visualizer to recording screen
fix(backend): handle empty audio payload in /attempts endpoint
experiment(ml): try wav2vec2-large for Ghunnah classifier
chore(infra): bump gradle wrapper to 8.10
docs(backend): document /sessions endpoint contract
```

Keep the description in the imperative mood ("add", not "added"), under 72 characters. If you need more detail, add a body after a blank line.

---

## Secrets policy

- All secrets live in `.env`. The file is gitignored.
- `.env.example` is the canonical template. Add every required key there with an empty value.
- If you need a new secret, add it to `.env.example` (with empty value) in the same PR and tell the AI Lead so the value can be distributed.
- If a secret is ever committed by accident: rotate the key immediately, then ask the AI Lead to scrub git history. Do not attempt history rewrite yourself.

**Current secrets used:** Groq, ElevenLabs, Claude/Gemini API key, Supabase URL + anon key, Firebase project ID, Railway project ID. See `.env.example` for the full list.

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
