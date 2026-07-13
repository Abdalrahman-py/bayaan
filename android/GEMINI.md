# GEMINI.md — Android Module

You are Gemini, building the Android screens and wiring for Bayaan's Arabic-track
rollout. Read [`AGENTS.md`](./AGENTS.md) first — it's the canonical rulebook (stack,
conventions, commit format, safe commands) and applies to you exactly as it does to
any other coding agent. This file adds your specific scope: what you build, what you
don't, and how work gets from you into `main`.

---

## Your scope

You build the client side of the two Android workstreams in
[`../docs/TEAM_PLAN.md`](../docs/TEAM_PLAN.md):

- [`../docs/workstreams/ws-android-shell.md`](../docs/workstreams/ws-android-shell.md) — M0: 4-tab nav, Learn tab placeholder, design-system utilities (motion, sound, haptics, score ring, confetti), app icon + splash, `DEMO_MODE` flag.
- [`../docs/workstreams/ws-lesson-player.md`](../docs/workstreams/ws-lesson-player.md) — M2/M3: `LessonScreen` + `LessonViewModel`, all exercise composables, lesson flow (WarmUp/Teach/Drill/Wrap), mic UX, wiring `POST /speech/grade`.

Concretely, that means:

- **Scaffolding** — new screens, navigation routes, ViewModels, Compose file/folder structure for anything those two sheets call for.
- **Compose code** — the composables themselves: exercise types, motion/sound/haptic utilities, the lesson state machine, mic waveform UI.
- **Wiring** — connecting screens to ViewModels, ViewModels to the network layer, and calling documented backend endpoints (`../docs/api-spec.md`, `../docs/PRODUCTION_PLAN.md` §9) once Ramzi ships them.

## Not your scope

- **Backend, Supabase, content pipeline** — Ramzi's workstreams (`ws-content-pipeline.md`, `ws-learn-backend.md`). If a screen needs a field or endpoint that doesn't exist yet, stub it behind the documented contract shape and flag it — don't invent an endpoint or a response shape.
- **Curriculum content** — lesson text, exercise wording, distractors, tajweed correctness. That's authored content reviewed by Abdalrahman; render whatever the frozen `content/` schema gives you.
- **The reuse contract** — `RecitationScreen`, `VerseText`, `RecitationViewModel`, the mushaf pager, and auth are load-bearing and already built. Wrap them; don't fork or rewrite them.
- **Final integration sign-off** — Abdalrahman reviews every PR and does the final wiring pass (confirming the client hits the right endpoint shape end-to-end, confirming curriculum renders correctly) before merge. Ship complete, buildable increments; don't wait for permission to open a PR.

## Rules you inherit from AGENTS.md (repeated because they matter most for you)

- Styling law is [`UI_SPEC.md`](./UI_SPEC.md) — read it before writing any screen. Don't ask about styling; it's answered there.
- Data contracts (`Verse`, `Mistake`, `RecitationUiState`) are in [`UI_BRIEF.md`](./UI_BRIEF.md) §4 — don't rename those fields.
- Hoist state to the ViewModel; composables stay stateless.
- Material 3 only, Compose only, no new dependencies for things Compose already does (springs, canvas particles, etc).

## How your work lands

1. Branch per workstream chunk (per `TEAM_PLAN.md` working model).
2. Open a PR — build + tests must pass (`./gradlew build && ./gradlew test`).
3. Abdalrahman reviews and wires it into the rest of the app before merge.

Acceptance criteria for each chunk live in the matching workstream sheet, quoted from
`PRODUCTION_PLAN.md` §10 — done means green on a real device, not "compiles."
