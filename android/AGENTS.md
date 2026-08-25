# AGENTS.md — Android Module

> **STATUS: DISCONTINUED (2026-08-25).** The Android (Kotlin/Jetpack Compose) client is discontinued.
> The Flutter client (`/flutter`) is the current app — do not build new features here.
> This module is kept as reference (it still holds features the port may not have carried,
> e.g. the QCF mushaf renderer — see `docs/CODEBASE_MAP.md`) and for the historical record.
> Only critical fixes allowed, and only with explicit go-ahead.

You are an AI coding agent operating inside the `/android` directory of Bayaan. This file is your scope and rulebook. Read [`../AGENTS.md`](../AGENTS.md) first for project-wide rules — this file extends them.

---

## What this module is

The Bayaan Android app: pick an ayah, record your recitation, upload it, and see mistakes highlighted on the Arabic script. Sign-in/sign-up (Supabase Auth) is implemented — see `AuthViewModel`. See [`UI_BRIEF.md`](./UI_BRIEF.md) for the original UI spec and [`../docs/CODEBASE_MAP.md`](../docs/CODEBASE_MAP.md) for the full system picture.

**Plain Android, single Gradle module (`app/`).** Not Kotlin Multiplatform — there is no `shared/` module. An earlier draft of this file planned for KMP and WebSocket audio streaming; neither was built.

---

## Owner

Team: Gemini builds screens/Compose code for the Arabic-track workstreams (scope in
[`GEMINI.md`](./GEMINI.md)); Abdalrahman (@Abdalrahman-py) reviews every change and does
final wiring. See [`../docs/TEAM_PLAN.md`](../docs/TEAM_PLAN.md) for the full team split.

---

## Tech stack

- **Language:** Kotlin
- **UI:** Jetpack Compose, Material 3
- **State:** `ViewModel` (`AndroidViewModel`) + Compose state (`mutableStateMapOf`), no Flow/StateFlow currently
- **Async:** Kotlin Coroutines (`viewModelScope`)
- **Networking:** Ktor client (`io.ktor:ktor-client-cio`), plain HTTP — no WebSocket, no Retrofit
- **Navigation:** Navigation Compose
- **Audio:** `android.media.MediaRecorder`, M4A/AAC output
- **Build:** Gradle (Kotlin DSL)
- **Min SDK:** 26 (Android 8.0). Target/compile SDK: 34.

---

## Directory layout

```
android/
├── app/src/main/java/com/bayaan/
│   ├── MainActivity.kt
│   ├── ui/screens/        Splash, Onboarding, Login/Signup, Home, Profile, Settings,
│   │                      SurahIndex, MushafPager, Recitation
│   ├── ui/viewmodel/      AuthViewModel, RecitationViewModel
│   ├── ui/navigation/     NavGraph (auth gate + 3-tab bottom nav)
│   ├── ui/mushaf/         QcfRepository (QCF glyph-font page loader)
│   ├── ui/components/     VerseText (highlightable Uthmani text), BayaanHeader
│   ├── ui/model/          Verse, Mistake, RecitationUiState, QuranText (full Uthmani text)
│   └── ui/theme/          Compose theme, colors, type
├── AGENTS.md              This file
├── GEMINI.md              Scope/rulebook for Gemini as the screens/wiring builder
├── UI_SPEC.md             Styling law — read before writing any screen
├── UI_BRIEF.md            Original UI build spec — data contract is still load-bearing
└── CLAUDE.md              Pointer to this file
```

---

## How to set up locally

```bash
cd android
./gradlew build
```

Open `android/` as the project root in Android Studio (Ladybug or later).

The backend URL the app talks to is set via `BuildConfig.BACKEND_URL` — check `app/build.gradle.kts` for the current value.

---

## How to do the work

### Conventions

- **Hoist state to the ViewModel.** Composables stay stateless — see `RecitationScreen` for the pattern (state in, lambdas out).
- **Material 3 only.** No Material 2 imports.
- **No XML layouts.** Compose-only.
- **Naming:** Composables in PascalCase, ViewModels in PascalCase + `ViewModel` suffix, sealed UI state as `<Screen>UiState`.
- **`RecitationUiState`'s shape is the contract** between the ViewModel and the screen — don't rename or restructure it without updating both. See `UI_BRIEF.md` §4 for the original spec.

### What "good" looks like

- Recording feels instantaneous on tap.
- Arabic text renders correctly (RTL, diacritics intact, Uthmani font).
- The upload/analyze wait is clearly communicated (the recitation engine has a cold-start delay — don't make it look frozen).
- No ANRs, no jank on the recording screen.

### What to avoid

- Don't call the backend directly from a composable — go through the ViewModel.
- Don't use `runBlocking` outside of tests.
- Don't add new dependencies without a real need — Compose already covers springs, canvas particle effects, etc.

---

## How to submit work

```bash
git add android/
git commit -m "feat(android): <description>"
```

### Before every commit

```bash
./gradlew build
./gradlew test
git diff --cached | grep -iE "key|secret|password|token"   # must be empty
```

### Commit format

`type(android): description` — imperative, under 72 chars.

Valid types: `feat`, `fix`, `chore`, `refactor`, `test`, `docs`.

```
feat(android): add waveform visualizer to recording screen
fix(android): handle mic permission denial on Android 13
refactor(android): extract verse list to its own composable
test(android): add unit test for RecitationViewModel
```

---

## Boundaries

You may modify files inside `/android/`. For changes to `/backend/`, `/ml/`, `/docs/`, or root config, say so and let Abdalrahman decide whether to switch context.

---

## Safe commands

```bash
./gradlew build
./gradlew test
./gradlew assembleDebug
git status
git diff
git log
```

Avoid `rm -rf`, `git reset --hard`, `git push --force` without explicit confirmation.

---

## Quick reference

| Action | Command |
|---|---|
| Build | `./gradlew build` |
| Test | `./gradlew test` |
| Debug APK | `./gradlew assembleDebug` |
| Commit prefix | `feat(android):` / `fix(android):` / etc. |
