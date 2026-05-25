# Android Module — AI Context

## What This Module Is

The Bayaan Android app. Records the user's Quran recitation via microphone, streams audio to the backend, and renders real-time Tajweed annotations on-screen with voice feedback. Built with Jetpack Compose for a modern, reactive UI. Targets Android 8.0 (API 26)+.

---

## Owners

| Name | Role |
|------|------|
| Issa | Screens & Navigation |
| Osama | Voice Recording & Core Recitation Loop |

---

## Tech Stack

- **Language:** Kotlin
- **UI:** Jetpack Compose (Material 3)
- **Architecture:** KMP (Kotlin Multiplatform) — Android-first; `shared/` contains platform-agnostic logic
- **Async:** Kotlin Coroutines + Flow
- **Networking:** Retrofit or Ktor client (confirm with team)
- **Build:** Gradle (Kotlin DSL)
- **Min SDK:** 26 (Android 8.0)

---

## Directory Structure

```
android/
├── app/       — Android app module (MainActivity, Compose screens, DI setup)
├── shared/    — KMP shared code (business logic, models, use cases)
└── CLAUDE.md  — This file
```

---

## Skills to Invoke

When working in this module, invoke these skills via the Skill tool if available:
- `android-cli` — Android CLI patterns and adb commands
- `kotlin-patterns` — Idiomatic Kotlin
- `compose-ui` — Jetpack Compose UI patterns
- `android-coroutines` — Coroutines and Flow patterns

If a skill is not available, apply the patterns manually: prefer `StateFlow` over `LiveData`, use `LaunchedEffect` for one-shot side effects, hoist state to `ViewModel`.

---

## Safe Commands

These commands are auto-approved by the team's `.claude/settings.json`:

```bash
./gradlew build
./gradlew test
./gradlew assembleDebug
adb logcat
```

---

## Branch Convention

- Branch off: `dev`
- Branch name: `android/<feature-name>` (e.g., `android/waveform-visualizer`)
- PR targets: `dev`

## PR Title Format

```
feat(android): <description>
fix(android): <description>
chore(android): <description>
```

---

## HARD BOUNDARY

**This AI session operates ONLY within the `/android` directory.**

Do not read, write, or suggest changes to `/backend`, `/ml`, `/docs`, `/design`, root config files (`CLAUDE.md`, `.claude/`, `.gitignore`, `.github/`), or any other directory outside `/android`.

If the user asks you to edit files outside `/android`, refuse and say: "This session is scoped to the `/android` module. Open a separate Claude Code session in the target module directory to make those changes."
