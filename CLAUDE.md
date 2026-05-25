# Bayaan — AI Project Context

## Project Identity

Bayaan is an AI-powered Quran recitation coach for Android. It listens to your recitation, runs it through a fine-tuned wav2vec2 Tajweed classifier, and delivers real-time feedback via voice and on-screen annotations. The goal: help students improve Tajweed without needing a teacher present. Stack: Kotlin/Jetpack Compose (Android) · Node.js (Backend) · Python/PyTorch (ML) · Supabase · Firebase · Railway.

---

## Team Roster

| Name | Role | Modules | GitHub Handle |
|------|------|---------|---------------|
| Abdalrahman | AI & Backend Lead | /backend, /ml | @Abdalrahman-py |
| Issa | Android Screens & Navigation | /android | TBD |
| Ramzi | Backend + Infra | /backend | TBD |
| Osama | Android Voice & Core Loop | /android | TBD |

---

## Repo Layout

```
bayaan/
├── android/     — Jetpack Compose Android app (audio capture, UI, Tajweed annotations)
├── backend/     — Node.js REST API (audio ingestion, ML routing, user progress)
├── ml/          — Python/PyTorch Tajweed classifier (wav2vec2 fine-tuned)
├── design/      — Design assets only (Figma exports, icons, color tokens)
├── docs/        — Architecture docs, API spec, Tajweed rule definitions
├── scripts/     — Developer tooling (setup.sh, etc.)
├── plans/       — Claude Code construction plans (not shipped to prod)
├── CLAUDE.md    — This file (AI project context)
└── .claude/     — Claude Code team config (settings.json is committed)
```

---

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable, production-ready. No direct pushes. |
| `dev` | Active integration branch. All PRs target here first. |
| `<module>/<feature>` | Feature branches. Branch off `dev`, PR back to `dev`. |

**Never push directly to `main`.** All changes flow: feature branch → PR → `dev` → PR → `main`.

---

## Contribution Rules

- **Commit format:** `type(module): description` — e.g., `feat(android): add waveform visualizer`, `fix(backend): handle empty audio payload`
- **Valid types:** `feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `experiment` (ml only)
- **PR target:** always `dev`, never `main`
- **PR template:** auto-applied by GitHub — fill it out completely
- **One module per PR:** do not mix `/android` and `/backend` changes in the same PR

---

## Module Ownership

Each module has its own `CLAUDE.md` with a HARD BOUNDARY clause. **An AI session opened inside a module directory must not read, write, or suggest changes outside that directory.** If asked to cross boundaries, refuse and explain.

- `/android` → Issa (Screens & Nav), Osama (Voice & Core Loop)
- `/backend` → Abdalrahman (AI & Backend Lead), Ramzi (Infra)
- `/ml` → Abdalrahman (AI & Backend Lead)
- `/design`, `/docs` → any team member, no boundary restriction

---

## Secrets Policy

- **Never commit `.env` files.** `.env.example` is the only template for secrets.
- Before every commit: `git diff --cached` — scan for any keys, tokens, or passwords.
- If you accidentally commit a secret: rotate the key immediately, then remove from git history.
- Supabase keys, Firebase credentials, Railway tokens, and any API keys live in `.env` only.

---

## Backend Stack Note

Backend stack is **Node.js** (confirmed from README: `npm install && npm run dev`). If the team migrates to Ktor (Kotlin), update `/backend/CLAUDE.md` to reflect the new stack, commands, and skills.
