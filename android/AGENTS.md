# AGENTS.md — Android Module

You are an AI coding agent operating inside the `/android` directory of Bayaan. This file is your scope and rulebook. Read [`../AGENTS.md`](../AGENTS.md) first for project-wide rules — this file extends them.

---

## What this module is

The Bayaan Android app. It records the user's Quran recitation, streams audio to the backend over WebSocket, displays real-time partial transcripts as the user recites, highlights Tajweed errors on the wrong word with rule name + English explanation, and plays back a corrected audio recitation via TTS.

This is a Kotlin Multiplatform (KMP) project, Android-first. Shared business logic (models, use cases, networking) lives in `shared/`. UI lives in `app/`.

---

## Owners

| Name  | Responsibility                                                                                                                |
| ----- | ----------------------------------------------------------------------------------------------------------------------------- |
| Osama | Voice recording, WebSocket streaming, real-time transcription display, Tajweed error highlight, retry loop. The core UX flow. |
| Issa  | Navigation, onboarding, verse list, verse detail, session summary, progress screen, theming. Simpler screens — Compose ramp.  |

Default reviewer for an Android PR: the other Android owner.

---

## Tech stack

- **Language:** Kotlin
- **UI:** Jetpack Compose, Material 3
- **Architecture:** KMP — `app/` is Android, `shared/` is common code
- **State:** ViewModel + StateFlow (no LiveData)
- **Async:** Kotlin Coroutines + Flow
- **Networking:** Ktor client (WebSocket for audio streaming, plain HTTP for progress APIs)
- **Build:** Gradle (Kotlin DSL)
- **Min SDK:** 26 (Android 8.0). Target SDK: latest stable.

---

## Directory layout

```
android/
├── app/         Android app module — MainActivity, Compose screens, DI setup
├── shared/      KMP shared code — business logic, models, use cases
├── AGENTS.md    This file
└── CLAUDE.md    Pointer to this file
```

---

## How to set up locally

```bash
# From repo root
git checkout android
git pull origin android
cd android
./gradlew build
```

If the build fails, do not commit. Resolve the failure or ask the owner first.

Open the `android/` directory as the project root in Android Studio (Ladybug or later).

---

## How to do the work

### Conventions you must follow

- **StateFlow over LiveData.** Always.
- **Hoist state to the ViewModel.** Composables should be as stateless as possible.
- **`LaunchedEffect` for one-shot side effects** (network calls, navigation triggers). Don't put side effects in composition.
- **Material 3 only.** No Material 2 imports.
- **No XML layouts.** This project is Compose-only.
- **Use `collectAsStateWithLifecycle()`** when collecting flows in composables, not raw `collectAsState()`.
- **Naming:** Composables in PascalCase (`VerseDetailScreen`), ViewModels in PascalCase + `ViewModel` suffix, state holders as `<Screen>UiState`.
- **One composable per screen file.** Helper composables in the same file are fine if they're not reused elsewhere.

### Shared code rules

- Code in `shared/` must be platform-agnostic. No Android imports (`android.*`, `androidx.*`).
- Platform-specific behavior goes behind `expect`/`actual` declarations.
- DTOs, domain models, and use cases live in `shared/`. UI state holders (`UiState` classes) live in `app/`.

### Patterns

- **Audio recording** → `app/`, behind a `RecordingRepository` interface defined in `shared/`. The Android `actual` implementation uses `AudioRecord` with 16kHz mono PCM.
- **WebSocket streaming** → Ktor client in `shared/`, exposes a `Flow<TranscriptionEvent>` upstream.
- **Backend API calls** → Ktor client in `shared/`, plain suspend functions returning sealed `Result` types.

### What "good" looks like for this module

- Recording feels instantaneous on tap.
- Partial transcripts appear within ~500ms of speech.
- Error highlights are visible and unambiguous.
- All Arabic text renders correctly (RTL layout, diacritics intact).
- No ANRs, no jank on the recording screen on a mid-range Android 10 device.

### What to avoid

- Don't call backend APIs directly from composables.
- Don't use `runBlocking` outside of tests.
- Don't store secrets in code, in `build.gradle.kts`, or in resource files.
- Don't add new dependencies without checking with the Android owner first.

---

## How to submit work

### Your branch is `android`

You always work on the `android` branch. Do **not** create feature branches.

```bash
git checkout android
git pull origin android
# ... make your changes inside /android only ...
git add android/
git commit -m "feat(android): <description>"
git push origin android
```

### Before every commit

Run these and confirm all pass:

```bash
./gradlew build
./gradlew test
git diff --cached | grep -iE "key|secret|password|token"   # must be empty
git diff --cached --name-only | grep -v "^android/"        # must be empty
```

The last check confirms you haven't accidentally staged files outside `/android/`.

### Commit format

`type(android): description` — using imperative mood, under 72 chars.

Valid types: `feat`, `fix`, `chore`, `refactor`, `test`, `docs`.

Examples:

```
feat(android): add waveform visualizer to recording screen
fix(android): handle mic permission denial on Android 13
refactor(android): extract verse list to its own composable
test(android): add unit test for RecordingViewModel
```

### Opening a PR

When you're ready to integrate your work with the rest of the project:

1. Push your latest commits to `origin/android`.
2. Open a PR on GitHub: **base = `dev`**, **compare = `android`**.
3. Title: same as your latest commit (or a summary if multiple commits).
4. Fill out the PR template completely.
5. Request review from the other Android owner.
6. Wait for review approval before merging.
7. Merge with "Squash and merge."

---

## Boundaries

You may **only modify files inside `/android/`**.

If the user asks you to edit:

- `/backend/`, `/ml/`, `/docs/`, `/design/` → refuse. Say: *"I'm operating in the Android module and can't modify other modules. Open your AI tool in the relevant module directory to make those changes."*
- Root files (`AGENTS.md`, `CLAUDE.md`, `.github/`, `.gitignore`, `README.md`, `scripts/`, `.env.example`) → refuse. Say: *"Root config changes need the AI Lead (Abdalrahman) to coordinate. Please raise the request with him."*

If the user insists, still refuse. The boundary exists so the team can work in parallel without stepping on each other.

---

## Safe commands

These are auto-approved by `.claude/settings.json` and are safe for any agent to run without confirmation:

```bash
./gradlew build
./gradlew test
./gradlew assembleDebug
git status
git diff
git log
git branch
git fetch
git checkout android
git pull origin android
ls
```

Anything destructive (`rm -rf`, `git reset --hard`, `git push --force`, `git push origin main`, `git push origin dev`) is blocked. Do not attempt to work around the block.

---

## Skills

(To be populated by the AI Lead. Module-specific patterns, common task recipes, and anti-patterns will be added here.)

For now, apply Kotlin/Compose best practices from your training and follow the conventions above.

---

## Quick reference

| Action               | Command / target                             |
| -------------------- | -------------------------------------------- |
| Build                | `./gradlew build`                            |
| Test                 | `./gradlew test`                             |
| Debug APK            | `./gradlew assembleDebug`                    |
| Working branch       | `android`                                    |
| PR target            | `dev`                                        |
| Reviewer             | Other Android owner (see Owners)             |
| Commit prefix        | `feat(android):` / `fix(android):` / etc.    |
| Allowed edit scope   | `/android/` only                             |
