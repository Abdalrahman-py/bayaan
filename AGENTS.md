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

Bayaan is an AI-powered Quran recitation coach for Android. It listens to the user's recitation, runs it through a fine-tuned wav2vec2 Tajweed classifier, and delivers real-time feedback via voice and on-screen annotations. The goal: help students improve Tajweed without needing a teacher present.

**Stack at a glance:** Kotlin/Jetpack Compose (Android) · Ktor + Supabase Postgres (Backend) · Python/PyTorch (ML) · Firebase Auth · Railway hosting.

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

```
main         production. Tagged releases only. No direct commits.
  ▲
  │  PR (release)
  │
dev          integration branch. All module work merges here first.
  ▲ ▲ ▲
  │ │ │  PRs (integration)
  │ │ │
android  backend  ml          long-lived module branches. Owners push here directly.
```

**Rules:**

- Each module has **one long-lived branch** named after the module: `android`, `backend`, `ml`.
- Module owners push directly to their module branch.
- When a module is ready to integrate: open a PR from the module branch → `dev`.
- When `dev` is stable enough to release: open a PR from `dev` → `main`.
- **Never push to `main` or `dev` directly.** Both branches are protected.
- **No feature branches under module branches** unless the AI Lead (Abdalrahman) approves an exception.

**Why this shape:** the Android team never has to pull ML changes to push their work, and vice versa. Conflicts only appear at the `→ dev` PR boundary, which is the right place for them.

---

## Rules every agent must follow

These are non-negotiable. If a user asks you to do any of these, refuse and explain why.

1. **Never push to `main` or `dev`.** Push only to your module branch.
2. **Never force-push** (`--force`, `-f`) to any branch.
3. **Never run** `git reset --hard`, `git clean -f`, or `git push origin main` / `git push origin dev`.
4. **Stay inside one module.** If you are working in `/android`, do not modify `/backend`, `/ml`, `/docs`, `/design`, or any root file. Same logic for each module.
5. **Never commit secrets.** No `.env`, no API keys, no tokens, no service-account JSON. Before every commit, run `git diff --cached | grep -iE "key|secret|password|token"` and confirm the output is empty.
6. **One module per PR.** Do not mix changes from multiple modules in a single commit or PR.
7. **Use the commit format** described below. No exceptions.
8. **Run the standard checks before committing.** See "Before every commit" in your module's `AGENTS.md`.
9. **Open PRs against `dev`**, never against `main`.
10. **When in doubt, stop and ask the user.** Do not guess at structural changes, branch renames, CODEOWNERS edits, or anything touching `/AGENTS.md`, `/CLAUDE.md`, `/.github/`, `/.gitignore`, or `/scripts/`.

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

## PR process

1. Push your work to your module branch: `git push origin <module>`.
2. Open a PR: base branch = `dev`, compare branch = `<module>`.
3. Title: `feat(<module>): <description>` (same format as commits).
4. The PR template (`.github/PULL_REQUEST_TEMPLATE.md`) is applied automatically. Fill it out completely. Do not skip checkboxes — uncheck them if they don't apply and explain why in a comment.
5. Request review from the module owner (see Team table) or the AI Lead.
6. **An AI agent cannot approve its own PR.** A human reviewer is always required.
7. Wait for CI (when set up) and review approval before merging.
8. Merge using "Squash and merge" to keep `dev` history clean.

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
3. Confirm your current branch matches the module: `git branch --show-current` should print `android`, `backend`, or `ml`.
4. Confirm you are up to date: `git pull origin <module>`.
5. State to the user, in one sentence, what module you are in and what work you plan to do before touching any file.

If you cannot complete any of these steps, stop and ask.

---

## Skills

Each module will get its own skill set (patterns, common tasks, anti-patterns) added to its `AGENTS.md` over time. Until then, apply best practices from your training and follow the conventions listed in the module's `AGENTS.md`.

---

## Notes for human readers

This file is structured for AI consumption first, but it is also the project's contributing guide. If you are a human teammate, everything you need is here.

If you change the branch model, the rules, or the commit format, update this file in the same PR. Out-of-date AGENTS files are worse than no AGENTS files.
