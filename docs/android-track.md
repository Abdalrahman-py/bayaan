---
type: resource
project: "Diploma Graduation Project"
entities: [Mahmoud Abu Jadallah]
date: 2026-06-10
tags: [bayaan, android, compose, architecture-review, issa, osama]
summary: "Complete Android track for Bayaan — harsh technology review, crash course explaining every decision, and 15-task implementation guide for Issa and Osama."
---

> ⚠️ **Partly outdated (pre-pivot, June 10).** Superseded in scope by [`quran-muaalem-decision.md`](./quran-muaalem-decision.md) (2026-06-23). The Compose/Ktor-client/MediaRecorder **tech decisions and crash course below are still valid and useful.** But the *scope* (6 screens, word-recognition, Arabic gate, sign-in, progress dashboard, `violations` response shape) is not the demo: the demo is one screen — pick ayah → record → highlight mistakes → retry. Build the tech the way this doc says; build only the demo loop.

# Bayaan Android — Harsh Review, Crash Course & Implementation Guide

Same treatment the backend got on June 10. Technology decisions researched, terms explained from zero, and a task list Issa and Osama can execute without asking questions.

---

## Part 1: Harsh Review — 7 Issues With the Current Android Plan

### Issue #1: KMP Adds Complexity With Zero MVP Benefit (CRITICAL)

The proposal says "Kotlin Multiplatform + Jetpack Compose." KMP is great for sharing business logic across Android and iOS. But Bayaan's MVP is Android-only. There is no iOS target.

What KMP would force on this project:
- `expect`/`actual` declarations for platform-specific code (audio recording, file I/O)
- KMP module structure (`shared/`, `androidApp/`)
- Multiplatform dependency management (some libraries don't support KMP)
- A learning curve for Issa, who's already learning Compose

What KMP would give us: nothing. There's no iOS app.

**Verdict: Pure Android for MVP.** Standard Android project structure. If Bayaan ever expands to iOS, the business logic can be extracted into a shared KMP module later. Don't pay the KMP tax for code that won't be shared.

### Issue #2: Retrofit Is Legacy for New Kotlin Projects (ARCHITECTURE)

The proposal mentions Retrofit as the HTTP client. Retrofit dominated Android for a decade. But it's Java-annotation-based, OkHttp-dependent, and Android-only.

Ktor Client is:
- Kotlin-native (no annotations, pure DSL)
- Coroutine-first (every call is a suspend function)
- The same library as the backend (consistent stack, same mental model)
- Multiplatform-ready (not needed now, but zero-cost future-proofing)

**Verdict: Ktor Client.** The backend uses Ktor Server. The Android app should use Ktor Client. One HTTP mental model across the whole project.

### Issue #3: Hilt Is Overkill for a 6-Screen App (COMPLEXITY)

Hilt is Google's recommended DI framework. It's built on Dagger, uses annotation processing, and requires understanding `@Module`, `@InstallIn`, `@Singleton`, `@ViewModelScoped`, and component hierarchies.

For a graduation project with 6 screens and maybe 15 classes, this is too much. Koin is:
- Pure Kotlin DSL — no annotation processing
- Starts in 3 lines: `val myModule = module { single { MyRepository() } }`
- Same functionality at this scale
- Issa can learn it in 10 minutes

**Verdict: Koin.** Simpler, faster to set up, sufficient for the project's size. If Bayaan grew to 50+ screens, Hilt's compile-time safety would matter. At 6 screens, Koin's simplicity wins.

### Issue #4: The Android Directory Is Empty (REALITY)

`/android` contains a 3-line README. No Kotlin files. No build.gradle. No Compose screens. This is the biggest gap in the entire Bayaan codebase.

**Verdict:** This document replaces the gap. Issa and Osama start from the task list below.

### Issue #5: Issa Is Learning Compose While Building the App (RISK)

Issa has XML background, not Compose. The original plan acknowledges this — "learning on the job." This is fine for simple screens but risky if the architecture is also new.

**Mitigation:** The 6 screens in Bayaan are all simple:
- Home/Onboarding: text + buttons
- Word Recognition: image + text + button
- Surah Selection: list
- Active Recitation: text + button + feedback overlay
- Session Summary: list of results
- Progress Dashboard: cards with numbers

None require complex layouts, animations, or custom drawing. Issa can learn Compose by building these. If a screen proves too hard, Abdalrahman can pair on it.

### Issue #6: Audio Recording on Android Is Surprisingly Fragile (RISK)

MediaRecorder is simple but has sharp edges:
- Permissions: `RECORD_AUDIO` requires runtime permission + foreground service on newer Android
- Output format: defaults to M4A/AAC at variable quality
- State machine: wrong call order crashes the app (can't `start()` before `prepare()`)
- File handling: must manage temp files, clean up after upload

**Mitigation:** The recording screen is Osama's responsibility. The task list includes explicit state machine handling, permission flow, and error states. No shortcuts.

### Issue #7: No Offline Strategy (GAP)

Gaza has unreliable internet. What happens when the user records audio but can't reach the backend?

**Verdict:** Queue-and-retry. Save the recorded file locally, attempt upload, retry on failure. Show "waiting for connection" state. This is task O4 in the list below. Simple, honest, works.

---

## Part 2: Crash Course — Every Android Term Explained

### What is Jetpack Compose?

Traditional Android UIs are built with XML files — separate files that describe the layout, inflated into views at runtime. You write `<Button android:text="Record"/>` in one file and `findViewById(R.id.button)` in another.

Compose is different. You write UI in Kotlin, directly:

```kotlin
Button(onClick = { startRecording() }) {
    Text("Record")
}
```

No XML. No findViewById. The UI is a function of state — when `isRecording` changes to `true`, the button automatically shows "Stop" instead. This is called **declarative UI** — you declare what the UI should look like for a given state, and Compose figures out how to update it.

**Analogy from ML:** Compose is to XML what PyTorch is to manual gradient calculation. XML requires you to update the UI manually (find the button, change its text). Compose recomputes the UI automatically when state changes, like how PyTorch recomputes gradients automatically when you call `.backward()`.

### What is MVVM?

MVVM (Model-View-ViewModel) is the standard Android architecture pattern:

- **Model:** Data + business logic. The repository that calls the backend API.
- **View:** The Compose screen. Just renders what the ViewModel tells it to.
- **ViewModel:** The bridge. Holds UI state as `StateFlow`. Survives screen rotations.

```
User taps button → View calls ViewModel.startRecording()
  → ViewModel updates state: _uiState.value = RecordingState.RECORDING
  → Compose sees state change → recomposes the UI
```

The View never calls the backend directly. The ViewModel never touches UI elements. This separation makes testing easy — you can test the ViewModel without running the app.

### What is a StateFlow?

StateFlow is a Kotlin coroutine type that holds a value and notifies observers when it changes. Think of it as a variable that Compose watches:

```kotlin
// In ViewModel:
private val _uiState = MutableStateFlow(HomeUiState())
val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

// In Compose:
val state by viewModel.uiState.collectAsState()
// UI auto-updates when state changes
```

**Analogy from ML:** StateFlow is like the `val_f1` variable in your training loop. Every epoch, it gets updated. You print it. Compose is like a print statement that runs automatically whenever the value changes.

### What is a ViewModel?

A ViewModel is a class that holds UI-related data and survives configuration changes (like screen rotation). If the user rotates their phone, the Activity is destroyed and recreated — but the ViewModel keeps its state. No lost data, no restarted network calls.

### What is Koin (Dependency Injection)?

Dependency injection means "don't create your dependencies inside your class — get them passed in." Instead of:

```kotlin
class RecitationViewModel {
    private val repository = ApiRepository() // BAD: hardcoded dependency
}
```

You do:

```kotlin
class RecitationViewModel(private val repository: ApiRepository) {
    // repository is passed in from outside
}
```

Koin manages this passing-in for you. You declare what's available once:

```kotlin
val appModule = module {
    single { ApiRepository(get()) }
    viewModel { RecitationViewModel(get()) }
}
```

Then anywhere you need a ViewModel, Koin provides it with all dependencies already wired. No manual wiring.

**Why Koin over Hilt:** Hilt uses compile-time code generation (annotations → generated code). It's more "correct" at scale but requires learning its annotation system. Koin is a simple DSL — you declare modules in Kotlin, it resolves them at runtime. For 6 screens, Koin is sufficient.

### What is Supabase Auth on Android?

The Android Supabase SDK (`supabase-kt`) handles sign-in. Issa adds the `auth-kt` and `compose-auth` dependencies, configures the client with the project URL and anon key, and gets pre-built sign-in UI components.

Flow:
1. User opens app → Supabase checks for existing session
2. No session → show sign-in screen (email/password or Google)
3. User signs in → Supabase returns a JWT
4. Android stores the JWT → attaches it to every backend request
5. Backend verifies the JWT locally (same HS256 secret)

### What is MediaRecorder?

Android's built-in audio recording API. You configure it (source = mic, format = M4A, bitrate = 128kbps), call `prepare()` and `start()`, and it writes to a file. When done, call `stop()` and `release()`. Simple state machine: Initial → Initialized → Prepared → Recording → Released.

**Why not AudioRecord?** AudioRecord gives raw PCM samples (the actual numbers). You'd need to encode them to a compressed format manually. MediaRecorder does encoding for you — one call, compressed output file.

---

## Part 3: Technology Stack — Decisions Already Made

| Concern | What we're using | Why | Rejected |
|---------|-----------------|-----|----------|
| **UI framework** | Jetpack Compose | Modern, Kotlin-native, no XML | XML (legacy) |
| **Platform** | Pure Android (not KMP) | MVP is Android-only, simpler setup | KMP (no iOS target, adds complexity) |
| **Architecture** | MVVM + Single Activity | Standard, well-documented, Compose-native | MVI (overkill for 6 screens) |
| **State management** | StateFlow + collectAsState | Compose-native, coroutine-based | LiveData (legacy) |
| **Navigation** | Compose Navigation (type-safe routes) | Official, type-safe at compile time | Third-party (unnecessary) |
| **HTTP client** | Ktor Client (CIO engine) | Kotlin-native, coroutine-first, same as backend | Retrofit (Java annotations, Android-only) |
| **Auth** | supabase-kt (auth-kt + compose-auth) | Official community SDK, pre-built UI | Firebase Auth (redundant) |
| **Audio recording** | MediaRecorder (M4A, 128kbps) | Simple API, compressed output | AudioRecord (raw PCM, needs manual encoding) |
| **DI** | Koin | Simple DSL, no annotation processing | Hilt (overkill for this scale) |
| **Image loading** | Coil (Compose-native) | Lightweight, Compose integration built-in | Glide (XML-era) |

---

## Part 4: Implementation Guide — Issa's Tasks

Issa owns screens, navigation, auth UI, and feedback rendering. 8 tasks, ordered.

### I1. Project Setup + Dependencies
- Create Android project in `/android` (target SDK 34, min SDK 26)
- Add `build.gradle.kts` dependencies:
  ```kotlin
  // Compose BOM
  implementation(platform("androidx.compose:compose-bom:2025.05.00"))
  implementation("androidx.compose.ui:ui")
  implementation("androidx.compose.material3:material3")
  implementation("androidx.compose.ui:ui-tooling-preview")
  // Navigation
  implementation("androidx.navigation:navigation-compose:2.8.5")
  // ViewModel
  implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
  // Koin
  implementation("io.insert-koin:koin-androidx-compose:4.0.0")
  // Supabase
  implementation(platform("io.github.jan-tennert.supabase:bom:3.2.1"))
  implementation("io.github.jan-tennert.supabase:auth-kt")
  implementation("io.github.jan-tennert.supabase:compose-auth")
  // Ktor Client
  implementation("io.ktor:ktor-client-okhttp:3.4.0")
  implementation("io.ktor:ktor-client-content-negotiation:3.4.0")
  implementation("io.ktor:ktor-serialization-kotlinx-json:3.4.0")
  // Coil
  implementation("io.coil-kt:coil-compose:2.7.0")
  ```
- Set up Material 3 theme (colors, typography)
- Create `BayaanApplication` class with Koin initialization
- **Test:** App launches, shows empty screen, no crashes

### I2. Supabase Auth Setup + Sign-In Screen
- Initialize Supabase client in `BayaanApplication` with project URL + anon key
- Install Auth plugin
- Build sign-in screen using `supabase-kt`'s `compose-auth` composables:
  - Email/password sign-in form
  - Google Sign-In button (if enabled in Supabase dashboard)
- Handle session state: signed out → show sign-in, signed in → show home
- **Test:** Sign in with test account, verify JWT stored, sign out

### I3. Navigation Graph
- Define type-safe routes with `@Serializable` data classes:
  ```kotlin
  @Serializable object Home
  @Serializable object WordRecognition
  @Serializable data class Recitation(val surah: String, val verse: Int)
  @Serializable data class SessionSummary(val sessionId: String)
  @Serializable object Progress
  ```
- Set up `NavHost` with all 6 destinations
- Bottom navigation bar: Home, Progress (2 tabs for MVP)
- **Test:** Navigate between all screens, back button works

### I4. Home / Onboarding Screen
- App name + tagline ("Bayaan — Speak. Listen. Improve.")
- Two mode selection cards:
  - "Word Practice" — Arabic word recognition
  - "Quran Recitation" — Tajweed practice
- User's name from Supabase profile
- **Test:** Both cards navigate to correct screens

### I5. Word Recognition Screen
- Display Arabic word with diacritics (large, centered)
- "Listen" button — plays reference pronunciation (TTS or pre-recorded)
- "Record" button → starts MediaRecorder (Osama's code)
- Loading state while backend processes
- Result display: correct (green check) or incorrect with feedback
- "Next Word" button
- **Test:** Full flow with mock backend response

### I6. Surah Selection Screen
- List of available surahs (MVP: Al-Fatihah only)
- Each surah shows: Arabic name, English name, verse count
- Tap surah → expands to show 7 verses
- Tap verse → navigates to Recitation screen
- **Test:** Verse tap navigates with correct surah + verse params

### I7. Active Recitation Screen
- Arabic verse text displayed (large, readable, with diacritics)
- "Start Reciting" button → activates recording (Osama's code)
- Recording indicator (pulsing mic icon, timer)
- "Stop" button → sends audio to backend
- Loading spinner while processing
- Violation overlay: highlights wrong words, shows rule name + English feedback
- "Try Again" button → re-enters recording
- "Next Verse" / "Finish" button
- Error states: no connection, mic permission denied, backend timeout
- **Test:** Full recitation loop with mock backend

### I8. Session Summary Screen
- Displays results after completing a surah or word session:
  - Verses/words attempted
  - Violations found
  - Per-rule accuracy
- "Practice Again" button
- "View Progress" button
- **Test:** Navigate from recitation screen, data displays correctly

---

## Part 5: Implementation Guide — Osama's Tasks

Osama owns audio recording, HTTP client, file upload, and the recitation loop. 7 tasks, ordered.

### O1. Audio Recorder Setup
- Add `RECORD_AUDIO` permission to `AndroidManifest.xml`
- Implement runtime permission request (Compose `rememberLauncherForActivityResult`)
- Set up MediaRecorder with these exact settings:
  ```kotlin
  MediaRecorder().apply {
      setAudioSource(MediaRecorder.AudioSource.MIC)
      setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
      setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
      setAudioEncodingBitRate(128000)
      setAudioSamplingRate(16000)
      setOutputFile(audioFile.absolutePath)
      prepare()
      start()
  }
  ```
- Handle MediaRecorder state machine correctly (Initial → Initialized → DataSourceConfigured → Prepared → Recording → Released)
- Release MediaRecorder in `onDestroy()` / `DisposableEffect`
- **Test:** Record 3 seconds, verify file created, play it back

### O2. Ktor HTTP Client + API Service
- Create `BayaanApi` class wrapping Ktor `HttpClient`:
  ```kotlin
  class BayaanApi(private val client: HttpClient) {
      suspend fun analyzeAudio(
          audioFile: File,
          surah: String,
          verse: Int,
          jwt: String
      ): AnalyzeResponse {
          return client.post("https://bayaan.up.railway.app/audio/analyze") {
              header("Authorization", "Bearer $jwt")
              setBody(MultiPartFormDataContent(formData {
                  append("audio", audioFile.readBytes(), Headers.build {
                      append(HttpHeaders.ContentDisposition, "filename=\"recording.m4a\"")
                  })
                  append("surah", surah)
                  append("verse", verse.toString())
              }))
          }.body()
      }
  }
  ```
- Register in Koin: `single { BayaanApi(get()) }`
- Add serialization for request/response models matching `docs/api-spec.md`
- **Test:** Mock backend returns known response, verify parsing

### O3. Auth Token Management
- Create `AuthManager` that:
  - Retrieves JWT from Supabase session
  - Attaches JWT to every HTTP request via Ktor plugin
  - Handles token expiry (Supabase SDK auto-refreshes)
- Register in Koin
- **Test:** HTTP request includes Authorization header

### O4. Offline Queue + Retry
- Save recorded audio file to app-internal storage before upload
- Attempt upload immediately
- On network failure: show "Waiting for connection..." state
- Retry with exponential backoff (1s, 2s, 4s, max 3 retries)
- On success: delete local file
- On permanent failure (after retries): show "Upload failed. Recording saved." with manual retry button
- **Test:** Turn off WiFi, record, verify file saved locally, turn on WiFi, verify auto-retry

### O5. Audio Recording UI Components
- Recording button with 3 states: idle (mic icon), recording (pulsing red), processing (spinner)
- Timer display (MM:SS) during recording
- Waveform visualization (simple — animated bar height based on amplitude)
- **Test:** Visual states match recording states

### O6. Recitation Loop Integration
- Wire recording button → MediaRecorder → file → HTTP upload → response
- Pass violation response to Issa's UI components
- Handle all error cases:
  - Mic permission denied → show settings link
  - Recording too short (<1s) → show "Please recite the full verse"
  - Recording too long (>15s) → auto-stop
  - Upload timeout → retry or save locally
- **Test:** Full end-to-end: record → upload → see violations (mock backend)

### O7. End-to-End Integration Testing
- Test with real backend (local or Railway):
  - Record audio, send to backend, verify response
  - Test with intentionally incorrect recitation
  - Test permission denied flow
  - Test network loss mid-upload
  - Measure: recording size, upload time, total round-trip

---

## Part 6: Shared Tasks (Both Issa + Osama)

### S1. ViewModel Implementation (Issa leads)
- One ViewModel per screen:
  - `HomeViewModel` — user profile, mode selection
  - `WordRecognitionViewModel` — word list, current word, results
  - `SurahSelectionViewModel` — surah list from API
  - `RecitationViewModel` — recording state, upload, violations
  - `SessionSummaryViewModel` — session results
  - `ProgressViewModel` — progress stats from API
- Each ViewModel exposes a single `StateFlow<UiState>` sealed class
- UiState sealed classes follow this pattern:
  ```kotlin
  sealed class RecitationUiState {
      data object Idle : RecitationUiState()
      data class Ready(val verse: Verse) : RecitationUiState()
      data object Recording : RecitationUiState()
      data object Uploading : RecitationUiState()
      data class Result(val response: AnalyzeResponse) : RecitationUiState()
      data class Error(val message: String) : RecitationUiState()
  }
  ```
- **Test:** Unit test each ViewModel with mock repository

### S2. Theme + Accessibility (Issa leads)
- Dark/light theme support (follow system setting)
- Arabic text: use `Noto Naskh Arabic` font for verse display
- Minimum touch target 48dp
- Content descriptions on all icons
- **Test:** Toggle dark mode, verify all screens

---

## Part 7: Dependency Chain

```
Issa:  I1 → I2 → I3 → I4 → I5,I6 → I7 → I8
                                         ↓
Osama: O1 → O2 → O3 → O4 → O5 → O6 → O7
                ↓                    ↓
Shared:        S1 ────────────────── S2
```

**Key handoffs:**
- Issa's I3 (navigation) → Issa's I4-I8 (can build screens once routes exist)
- Osama's O2 (HTTP client) → Osama's O6 (recitation loop needs it)
- Osama's O6 (recitation loop) → Issa's I7 (needs recording integration)

**Parallel work:** Issa's I4-I6 (screens without recording) and Osama's O1-O3 (infrastructure) are independent. They integrate at I7/O6.

---

## Part 8: What Got Cut (MVP Scope Discipline)

| Item | Why cut |
|------|---------|
| KMP / shared module | No iOS target. Pure Android for MVP. |
| Retrofit | Legacy. Ktor Client is consistent with backend. |
| Hilt | Overkill for 6 screens. Koin is simpler. |
| XML layouts | Compose-only. Issa is learning it anyway. |
| AudioRecord / raw PCM | MediaRecorder handles encoding. Simpler. |
| Animated tajweed overlays | Stretch goal. Static highlights are sufficient. |
| Voice playback (TTS in app) | Backend returns text feedback. Voice is Phase 2. |
| Offline-first database (Room) | Queue-and-retry to file is simpler. Room is overkill for temp audio. |

---

## Part 9: Reference Files

| File | Issa needs | Osama needs |
|------|-----------|------------|
| `docs/architecture.md` | System overview | Data flow diagram |
| `docs/api-spec.md` | Response shapes for progress endpoints | Request/response shapes for `/audio/analyze` |
| `docs/team-roles.md` | Who owns what | Who owns what |
| `docs/supabase-setup.md` | Supabase URL + anon key (from Ramzi) | JWT handling |
| `android/AGENTS.md` | AI agent rules | AI agent rules |

---

## Related (vault)

- [[Diploma-Graduation-Project]] — parent project hub
- [[bayaan-backend-harsh-review]] — backend review (the model for this)
- [[bayaan-ramzi-implementation-guide]] — Ramzi's guide (same format)
- [[bayaan-documentation-audit]] — full docs audit
