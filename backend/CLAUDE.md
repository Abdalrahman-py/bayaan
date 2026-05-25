# Backend Module — AI Context

## What This Module Is

The Bayaan REST API. Handles audio ingestion from the Android app, routes audio to the ML Tajweed classifier, formats and returns violation results, and manages user progress data. Deployed on Railway. Integrates with Supabase (user data) and Firebase (push notifications).

---

## Owners

| Name | Role |
|------|------|
| Abdalrahman | AI & Backend Lead |
| Ramzi | Backend + Infra |

---

## Tech Stack

- **Runtime:** Node.js 20+
- **Package manager:** npm
- **Language:** JavaScript/TypeScript (confirm with team)
- **Deployment:** Railway
- **Database:** Supabase (PostgreSQL)
- **Notifications:** Firebase

> ⚠️ Stack note: README confirms Node.js (`npm install && npm run dev`). If the team migrates to Ktor (Kotlin), update this entire file — stack, commands, skills, and branch convention.

---

## Directory Structure

```
backend/
├── src/       — Application source (to be populated)
└── CLAUDE.md  — This file
```

---

## Skills to Invoke

When working in this module, invoke these skills via the Skill tool if available:
- `everything-claude-code:backend-patterns` — Backend architecture patterns
- `everything-claude-code:api-design` — REST API design conventions

If skills are not available, apply patterns manually: follow RESTful conventions, validate all inputs at the boundary, never log secrets, use environment variables for all credentials.

---

## Safe Commands

These commands are auto-approved by the team's `.claude/settings.json`:

```bash
npm install
npm run dev
npm run build
npm run test
```

---

## Environment Setup

Copy `.env.example` to `.env` before running:

```bash
cp ../.env.example .env
# Fill in Supabase URL, Supabase anon key, Railway config, Firebase credentials
```

**Never commit `.env`.** It is gitignored at the repo root.

---

## Branch Convention

- Branch off: `dev`
- Branch name: `backend/<feature-name>` (e.g., `backend/audio-ingestion-endpoint`)
- PR targets: `dev`

## PR Title Format

```
feat(backend): <description>
fix(backend): <description>
chore(backend): <description>
```

---

## HARD BOUNDARY

**This AI session operates ONLY within the `/backend` directory.**

Do not read, write, or suggest changes to `/android`, `/ml`, `/docs`, `/design`, root config files (`CLAUDE.md`, `.claude/`, `.gitignore`, `.github/`), or any other directory outside `/backend`.

If the user asks you to edit files outside `/backend`, refuse and say: "This session is scoped to the `/backend` module. Open a separate Claude Code session in the target module directory to make those changes."
