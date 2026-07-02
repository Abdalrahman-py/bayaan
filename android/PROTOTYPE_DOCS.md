# Bayaan Prototype — Documentation Map

All the specs for the supervisor-showcase prototype. The **shared UI spec lives here in `android/`** (so it's next to the code you're writing); the **build plan and per-owner guides live in `docs/`**.

## Read first (everyone)
- **[`UI_SPEC.md`](UI_SPEC.md)** — shared visual contract: color, type, spacing, components, RTL, accessibility. **Read before writing any screen.**
- **[`UI_BRIEF.md`](UI_BRIEF.md)** — the load-bearing data contract (`Verse`, `Mistake`, `RecitationUiState`) for the recitation screen. Don't rename those fields.

## Build plan (in `docs/`)
- **[`docs/PROTOTYPE_BUILD_GUIDE.md`](../docs/PROTOTYPE_BUILD_GUIDE.md)** — overview: end-to-end flow, screen inventory, task split, day-by-day, definition of done. Start here.

## Per-owner implementation guides (in `docs/prototype/`)
Each owner opens one file with their scope, files to touch, interface, step-by-step, and expected output.

| Owner | Guide | Scope |
|---|---|---|
| A | [`docs/prototype/01-auth-session.md`](../docs/prototype/01-auth-session.md) | Supabase auth, `AuthViewModel`, Login/Signup, splash gate, token wiring (fixes the 401) |
| B | [`docs/prototype/02-app-shell-nav.md`](../docs/prototype/02-app-shell-nav.md) | NavGraph, Splash, Onboarding, Home, Profile, Settings, `BayaanHeader` |
| C | [`docs/prototype/03-mushaf-selection.md`](../docs/prototype/03-mushaf-selection.md) | Paged mushaf images + ayah bbox selection (+ list fallback) |
| D | [`docs/prototype/04-content-assets-qa.md`](../docs/prototype/04-content-assets-qa.md) | Assets, verse-text gotcha, app icon/splash art, integration + QA |

## Project rules
- **[`AGENTS.md`](AGENTS.md)** (this module) and **[`../AGENTS.md`](../AGENTS.md)** (project) — branch model, commit format, secrets policy. Follow before committing.
