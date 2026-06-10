# Issa & Osama — Bayaan Android Implementation Guide

Everything you need to build the Bayaan Android app. Read this once, then start from I1/O1 and work down. If a question isn't answered here, ask Abdalrahman.

---

## 1. What We're Building

Bayaan is an AI-powered Arabic and Quran voice tutor. Users speak, the app listens, AI checks correctness.

**The Android app's job:** Let users sign in, practice Arabic words, recite Quran verses, record audio, send it to the backend, and see Tajweed feedback.

**MVP scope:**
- Arabic Word Recognition (30-50 words)
- 2 Tajweed rules (Ghunnah, Madd)
- Surah Al-Fatihah only (7 verses)
- 6 screens, English interface, Android only

**Team:**
- **Issa** — Screens, navigation, auth UI, feedback rendering (I1-I8)
- **Osama** — Audio recording, HTTP client, file upload, recitation loop (O1-O7)
- **Abdalrahman** — Backend API + ML models

**Repo:** `github.com/Abdalrahman-py/bayaan`
**Branch:** `dev` (PR to `main`)
**Your modules:** `shared/` (pure Kotlin) + `androidApp/` (Compose UI)

---

## 2. Technology Stack (Decisions Already Made)

These are decided. Use exactly these.

| Concern | What we're using | Why |
|---------|-----------------|-----|
| UI framework | Jetpack Compose | Modern, Kotlin-native, no XML |
| Platform | KMP — `shared/` + `androidApp/` | iOS-ready, clean separation |
| Architecture | MVVM + Single Activity | Standard, testable, Compose-native |
| State | StateFlow + sealed classes | Reactive, one state at a time |
| Navigation | Compose Navigation (type-safe) | Official, compile-time safe |
| HTTP client | Ktor Client (OkHttp engine) | Same library as backend, multiplatform |
| Auth | supabase-kt (auth-kt + compose-auth) | Official community SDK, pre-built UI |
| Audio | MediaRecorder (M4A, 128kbps) | Simple, compressed output |
| DI | Koin | Simple DSL, no annotation processing |
| Images | Coil | Lightweight, Compose-native |

**What we are NOT using:**
- XML layouts (Compose only)
- Retrofit (legacy, Ktor Client replaces it)
- Hilt (Koin is simpler for this scale)
- AudioRecord (MediaRecorder handles encoding)
- Firebase Auth (Supabase Auth replaces it)

---

## 3. Architecture at a Glance

```
bayaan/
  shared/                          ← Pure Kotlin, no Android deps
    models/                         ← AnalyzeResponse, Verse, Surah...
    api/                            ← BayaanApi (Ktor Client)
    repository/                     ← ApiRepository
  androidApp/                       ← Android UI
    ui/screens/                     ← Compose screens (Issa)
    ui/components/                  ← Recording UI (Osama)
    audio/                          ← MediaRecorder (Osama)
    auth/                           ← Supabase session (Issa)
    di/                             ← Koin modules

Phone (Android App)
    │  HTTP + JWT
    ↓
Ktor Backend (Ramzi + Abdalrahman)
    │
    ├──→ Supabase PostgreSQL
    └──→ Python ML Server
```

---

## 4. Issa's Tasks (I1 → I8)

Issa owns screens, navigation, auth, and feedback rendering. 8 tasks. Build in order.

### I1. Project Setup + Dependencies

**What:** Create the KMP project skeleton.

- `shared/` module — pure Kotlin. Add Ktor Client, kotlinx.serialization.
- `androidApp/` module — Compose UI. Add Compose BOM, Navigation, Koin, Supabase, Coil.
- Set up Material 3 theme (colors, typography).
- Create `BayaanApplication` class with `startKoin { modules(appModule) }`.
- Target SDK 34, min SDK 26.

**Dependencies — shared/build.gradle.kts:**
```kotlin
kotlin {
    androidTarget()
    // iosArm64(), iosSimulatorArm64() — uncomment post-MVP
}
commonMain.dependencies {
    implementation("io.ktor:ktor-client-core:3.4.0")
    implementation("io.ktor:ktor-client-content-negotiation:3.4.0")
    implementation("io.ktor:ktor-serialization-kotlinx-json:3.4.0")
}
```

**Dependencies — androidApp/build.gradle.kts:**
```kotlin
// Compose BOM
implementation(platform("androidx.compose:compose-bom:2025.05.00"))
implementation("androidx.compose.ui:ui")
implementation("androidx.compose.material3:material3")
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
// Ktor Client (Android engine)
implementation("io.ktor:ktor-client-okhttp:3.4.0")
// Coil
implementation("io.coil-kt:coil-compose:2.7.0")
```

**Test:** App launches, shows empty screen, no crashes.

---

### I2. Supabase Auth + Sign-In Screen

**What:** User authentication with pre-built UI.

- Initialize Supabase client in `BayaanApplication` with project URL + anon key (get from Ramzi).
- Install `Auth` plugin.
- Use `compose-auth` composables for sign-in screen (email/password form).
- Handle session state: signed out → show sign-in, signed in → show home.
- Google Sign-In button (if enabled in Supabase dashboard — ask Abdalrahman).

```kotlin
val supabase = createSupabaseClient(
    supabaseUrl = BuildConfig.SUPABASE_URL,
    supabaseKey = BuildConfig.SUPABASE_ANON_KEY
) { install(Auth) }
```

**Test:** Sign in with test account. Verify JWT stored. Sign out works.

---

### I3. Navigation Graph

**What:** Type-safe navigation between all 6 screens.

Define routes as `@Serializable` data classes:

```kotlin
@Serializable object Home
@Serializable object WordRecognition
@Serializable data class Recitation(val surah: String, val verse: Int)
@Serializable data class SessionSummary(val sessionId: String)
@Serializable object Progress
```

Set up `NavHost` with a `Scaffold` + bottom navigation bar (Home, Progress).

**Test:** Navigate between all screens. Back button works. Route params survive rotation.

---

### I4. Home Screen

**What:** Landing screen with two mode cards.

- App name + tagline: "Bayaan — Speak. Listen. Improve."
- Two cards: "Word Practice" (→ WordRecognition) and "Quran Recitation" (→ SurahSelection)
- User greeting from Supabase profile

**Test:** Both cards navigate correctly.

---

### I5. Word Recognition Screen

**What:** User sees/hears an Arabic word, speaks it, gets feedback.

- Large Arabic word with diacritics, centered
- "Listen" button — reference pronunciation (pre-recorded or TTS)
- "Record" button → starts MediaRecorder (Osama's code handles this)
- States: idle → recording → uploading → result (correct/incorrect + feedback) → next word
- "Next Word" button

**Test:** Full flow with mock backend response. States transition correctly.

---

### I6. Surah Selection Screen

**What:** List of available surahs. Tap to see verses.

- MVP: only Al-Fatihah, but structure for multiple
- Each surah card: Arabic name, English name, verse count
- Tap → expands to show 7 verse rows
- Tap verse → navigates to Recitation(surah, verse)

**Test:** Verse tap passes correct params to Recitation screen.

---

### I7. Active Recitation Screen

**What:** The core screen — verse display, recording, results.

- Arabic verse text (large, with diacritics, `Noto Naskh Arabic` font)
- "Start Reciting" button
- Recording indicator: pulsing mic icon, timer MM:SS
- "Stop" button → uploads audio → loading spinner → results
- Violation overlay: highlights wrong words, shows rule name + English feedback
- "Try Again" → re-enter recording state
- "Next Verse" / "Finish" → navigate to summary
- Error states: no connection, mic denied, backend timeout

**UiState sealed class:**
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

**Test:** Full recitation loop with mock backend. All error states reachable.

---

### I8. Session Summary + Progress Screen

**Session Summary** — after completing a session:
- Verses/words attempted, violations found, per-rule accuracy
- "Practice Again" and "View Progress" buttons

**Progress Screen** — overall stats:
- Total sessions, total verses practiced
- Per-rule accuracy cards (Ghunnah, Madd)
- Accuracy trend (simple list, no charts needed)

**Test:** Navigate from recitation with mock data. Progress screen loads from backend.

---

## 5. Osama's Tasks (O1 → O7)

Osama owns audio, HTTP, file upload, and the recitation loop. 7 tasks. Build in order.

### O1. Audio Recorder Setup

**What:** Record audio using MediaRecorder.

- Add `RECORD_AUDIO` to `AndroidManifest.xml`
- Runtime permission request with `rememberLauncherForActivityResult`
- MediaRecorder config:

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

- **Handle the state machine correctly:** Initial → Initialized → DataSourceConfigured → Prepared → Recording → Released. Wrong call order crashes.
- Release in `DisposableEffect` (Compose cleanup).
- Save to `context.cacheDir` (temp file, deleted after upload).

**Test:** Record 3 seconds. Verify M4A file created. Play it back.

---

### O2. Ktor HTTP Client + API Service

**What:** HTTP client in `shared/` that calls the backend.

```kotlin
// shared/src/commonMain/kotlin/api/BayaanApi.kt
class BayaanApi(private val client: HttpClient) {
    suspend fun analyzeAudio(
        audioFile: ByteArray,
        surah: String,
        verse: Int,
        jwt: String
    ): AnalyzeResponse {
        return client.post("${BuildConfig.BASE_URL}/audio/analyze") {
            header("Authorization", "Bearer $jwt")
            setBody(MultiPartFormDataContent(formData {
                append("audio", audioFile, Headers.build {
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
- Add serialization models matching `docs/api-spec.md`
- `BASE_URL`: `http://10.0.2.2:8080` (emulator → localhost), configurable for prod

**Test:** Mock backend returns known response. Verify parsing.

---

### O3. Auth Token Management

**What:** Attach JWT to every HTTP request.

- Create `AuthManager` that reads JWT from Supabase session
- Add Ktor plugin that injects `Authorization: Bearer ***` header
- Supabase SDK auto-refreshes expired tokens

```kotlin
// Ktor plugin in shared/
val HttpClientConfig<*>.authPlugin: Unit
    get() {
        install("Auth") {
            // Intercept requests, add JWT from session
        }
    }
```

**Test:** HTTP request includes Authorization header.

---

### O4. Offline Queue + Retry

**What:** Handle Gaza's unreliable internet.

- Save recorded audio to `cacheDir` before upload
- Attempt upload immediately
- On network failure: show "Waiting for connection..."
- Retry with backoff: 1s, 2s, 4s (max 3 retries)
- On success: delete local file
- On permanent failure: show "Upload failed. Recording saved." with manual retry button

**Test:** Turn off WiFi, record, verify file saved. Turn on WiFi, verify auto-retry.

---

### O5. Recording UI Components

**What:** Reusable UI for recording state.

- `RecordButton` composable with 3 states: idle (mic icon), recording (pulsing red), processing (spinner)
- `RecordingTimer` composable: MM:SS display
- Simple waveform: animated bar height (optional, static bars are fine for MVP)

```kotlin
@Composable
fun RecordButton(state: RecordState, onClick: () -> Unit) {
    when (state) {
        RecordState.Idle -> IconButton(onClick) { Icon(Icons.Default.Mic, "Record") }
        RecordState.Recording -> IconButton(onClick) { 
            Icon(Icons.Default.Stop, "Stop", tint = Color.Red) 
        }
        RecordState.Processing -> CircularProgressIndicator()
    }
}
```

Issa uses these in I5 and I7.

**Test:** Visual states match recording states.

---

### O6. Recitation Loop Integration

**What:** Wire everything together — the full record → upload → result flow.

- MediaRecorder → file → read bytes → BayaanApi.analyzeAudio() → parse response
- Pass response to Issa's UI layer via ViewModel's StateFlow
- Handle all errors:
  - Mic permission denied → show settings link
  - Recording too short (<1s) → "Please recite the full verse"
  - Recording too long (>15s) → auto-stop
  - Upload timeout → retry or save locally per O4
  - Backend 401 → session expired → redirect to sign-in
  - Backend 422 → "Audio could not be processed"
  - Backend 503 → "Service unavailable, try again"

**Test:** Full end-to-end with real or mock backend. Every error path tested.

---

### O7. Integration Testing

**What:** Verify everything works together.

- Test with real backend (local Ktor or Railway):
  - Record audio, send, verify response
  - Intentionally incorrect recitation → verify violations detected
- Test offline: airplane mode, record, reconnect, verify retry
- Measure: recording file size, upload time, total round-trip
- Target: <2s processing time, 3-7s total wall-clock

**Test:** Run on a real device. Record actual Arabic recitation. See real results.

---

## 6. Shared Tasks (Issa + Osama)

### S1. ViewModels (Issa leads, Osama contributes RecitationViewModel)

One ViewModel per screen. Each exposes a single `StateFlow<UiState>`.

| ViewModel | Screen | Key state |
|-----------|--------|-----------|
| `HomeViewModel` | Home | User name, loading |
| `WordRecognitionViewModel` | Word Recognition | Current word, recording, result |
| `SurahSelectionViewModel` | Surah Selection | Surah list from API |
| `RecitationViewModel` | Recitation | Recording, uploading, violations (Osama leads) |
| `SessionSummaryViewModel` | Session Summary | Session results |
| `ProgressViewModel` | Progress | Stats from GET /progress |

Every UiState uses the sealed class pattern. Unit test each ViewModel with a mock repository.

### S2. Theme + Accessibility

- Dark/light theme (follow system)
- Arabic text: `Noto Naskh Arabic` font for verse display
- Minimum touch target: 48dp
- Content descriptions on all icons

---

## 7. Dependency Chain

```
Issa:  I1 → I2 → I3 → I4 → I5,I6 → I7 → I8
                                         ↓
Osama: O1 → O2 → O3 → O4 → O5 → O6 → O7
                ↓                    ↓
Shared:        S1 ────────────────── S2
```

**Key handoffs:**
- I3 (navigation) → I4-I8 (screens depend on routes)
- O2 (HTTP client) → O6 (recitation loop needs it)
- O5 (recording UI) → I5, I7 (Issa uses Osama's components)
- O6 (recitation loop) → I7 (integration point)

**Parallel work:**
- Issa's I4-I6 (screens without recording) and Osama's O1-O3 (infrastructure) are independent
- They meet at I7/O6 — the recitation screen

---

## 8. Testing Expectations

Every task has a test bullet. Minimum for each screen:

- **ViewModel unit tests:** Mock repository, verify state transitions
- **UI tests (optional for MVP):** `ComposeTestRule` for critical flows
- **Manual QA:** Run on real device, record actual Arabic, verify results

**Test data:** Use a mock `BayaanApi` that returns hardcoded `AnalyzeResponse` objects. No backend needed.

---

## 9. Error Handling

Every screen handles these states:

| State | UI |
|-------|-----|
| Loading | Spinner or shimmer |
| Empty | "No data yet" message |
| Error | Message + retry button |
| Success | Normal content |

Network errors specifically:
- No connection → "Waiting for connection..." + auto-retry
- Timeout → "Taking longer than expected..." + cancel option
- Auth expired → redirect to sign-in

---

## 10. What NOT to Build

These are either Abdalrahman's responsibility or out of scope:

- **The backend API** — handled by Ramzi + Abdalrahman
- **The ML model** — Abdalrahman's domain
- **Audio format conversion** — backend handles M4A → WAV
- **Voice playback (TTS)** — Phase 2 stretch goal. Text feedback only for MVP.
- **Offline database (Room)** — temp files + retry is sufficient
- **Multi-language support** — English interface only for MVP
- **Gamification / animations** — out of scope
- **Apple/Google Play submission** — graduation demo, not store release

---

## 11. Reference Files

| File | What it covers | Who needs it |
|------|---------------|-------------|
| `docs/architecture.md` | System diagram, data flows | Everyone |
| `docs/api-spec.md` | All endpoint contracts | Osama |
| `docs/supabase-setup.md` | Supabase URL + anon key | Issa |
| `docs/team-roles.md` | Who owns what | Everyone |
| `android/AGENTS.md` | AI agent rules | Everyone |
| `README.md` | Getting started, branch strategy | Everyone |
