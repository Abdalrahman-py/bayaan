# Owner A — Auth & Session

> **Critical path.** Nothing else demos end-to-end until this lands: `/audio/analyze` currently returns **401** because the app sends no token. You own Supabase auth, the two auth screens, the splash auth-gate decision, and wiring the token into the existing `RecitationViewModel`.
>
> **Read first:** [`android/UI_SPEC.md`](../../android/UI_SPEC.md) (visual rules) and this whole file. **Prereqs:** none — you can start Day 1; others stub you with a fake token provider.

---

## Backend contract (already deployed — do not change)

Verified from the backend source:

- Auth is **Supabase JWT (HS256)**, verified locally by the backend. These routes sit behind `authenticate("auth-jwt")` and **require `Authorization: Bearer <supabase access token>`**:
  - `POST /auth/sync` → upserts the user row. Returns `{"user_id":"<uuid>","created":true|false}`.
  - `POST /audio/analyze` → the recitation analysis (the existing screen calls this).
  - `GET /progress*` → not used in this build.
- Base URL is already set: `BuildConfig.BACKEND_URL = "https://bayaan-backend.onrender.com"` ([`app/build.gradle.kts`](../../android/app/build.gradle.kts)).
- **No token → 401.** That's the bug this work fixes.

The "access token" you send is the Supabase session's access token from `auth-kt` — not the anon key.

---

## Files you create / touch

| File | Action |
|---|---|
| `app/build.gradle.kts` | add Supabase `auth-kt` (+ BOM); read `SUPABASE_URL`/`SUPABASE_ANON_KEY` from `local.properties` into `BuildConfig` |
| `gradle/libs.versions.toml` | version-catalog entries for the Supabase BOM + `auth-kt` (+ `ktor-client-cio` already present) |
| `local.properties` | **gitignored** — add the two Supabase values (never commit) |
| `ui/viewmodel/AuthViewModel.kt` | **new** — owns `SupabaseClient`, exposes `AuthUiState` + actions |
| `ui/screens/LoginScreen.kt` | **new** — stateless, state in / lambdas out |
| `ui/screens/SignupScreen.kt` | **new** — stateless |
| `ui/viewmodel/RecitationViewModel.kt` | **touch** — inject a token provider; add `Authorization: Bearer` to the `/audio/analyze` call |
| `MainActivity.kt` | **touch** — create `AuthViewModel`; pass token provider into `RecitationViewModel` (coordinate with B on the gate) |

---

## Gradle setup (step-by-step)

1. Add to `local.properties` (already gitignored — confirm with `git check-ignore local.properties`):
   ```properties
   SUPABASE_URL=https://<project-ref>.supabase.co
   SUPABASE_ANON_KEY=<anon public key>
   ```
2. In `app/build.gradle.kts` `defaultConfig`, read them into `BuildConfig` (mirrors how `BACKEND_URL` is already done):
   ```kotlin
   val props = Properties().apply {
       rootProject.file("local.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
   }
   buildConfigField("String", "SUPABASE_URL", "\"${props.getProperty("SUPABASE_URL", "")}\"")
   buildConfigField("String", "SUPABASE_ANON_KEY", "\"${props.getProperty("SUPABASE_ANON_KEY", "")}\"")
   ```
3. Add the Supabase BOM + `auth-kt` (+ the Ktor engine `auth-kt` needs — CIO is already a dep). Keep it in the version catalog.

**Expected output:** project builds; `BuildConfig.SUPABASE_URL` is non-empty at runtime.

---

## `AuthViewModel` (the contract others depend on)

Owns a single `SupabaseClient` (install the `Auth` plugin). Expose exactly:

```kotlin
sealed interface AuthUiState {
    data object Checking : AuthUiState                          // splash: deciding
    data class LoggedOut(
        val error: String? = null,
        val pendingConfirmation: Boolean = false,               // signup done, must confirm email
        val submitting: Boolean = false,                        // a request is in flight
    ) : AuthUiState
    data object LoggedIn : AuthUiState
}

class AuthViewModel(app: Application) : AndroidViewModel(app) {
    val state: <observable of AuthUiState>                      // Compose state or StateFlow — match repo style (mutableStateOf is fine)
    fun checkSession()                                          // splash calls this: sets Checking → LoggedIn/LoggedOut
    fun login(email: String, password: String)                 // sets submitting; on success calls /auth/sync then LoggedIn
    fun signup(email: String, password: String)                // on success → LoggedOut(pendingConfirmation = true)
    fun signOut()                                              // → LoggedOut()
    fun currentAccessToken(): String?                          // the Bearer token for backend calls; null if logged out
}
```

Rules:
- **Call `POST /auth/sync` after a successful login, before emitting `LoggedIn`.** Send `Authorization: Bearer <accessToken>`. A non-2xx sync should surface as `LoggedOut(error=…)`, not a silent `LoggedIn`.
- Email-confirmation is **ON**: `signup()` succeeding does **not** enter the app — it sets `pendingConfirmation = true` so the UI can say "check your inbox, then log in".
- `currentAccessToken()` reads the current session token from `auth-kt` (refresh handled by the SDK). Return `null` when logged out.
- Use `viewModelScope` for all calls; no `runBlocking` (`android/AGENTS.md`).

**Others stub this** with `val currentAccessToken: () -> String? = { "fake" }` until you land — so B and C aren't blocked.

---

## LoginScreen (stateless)

```kotlin
@Composable
fun LoginScreen(
    state: AuthUiState.LoggedOut,
    onLogin: (email: String, password: String) -> Unit,
    onGoToSignup: () -> Unit,
    modifier: Modifier = Modifier,
)
```

Layout (per [`UI_SPEC.md`](../../android/UI_SPEC.md)): `BayaanHeader` at top → two `OutlinedTextField`s (email = `KeyboardType.Email`, password = `PasswordVisualTransformation`) → full-width `Button` "Log in" → "No account? Sign up" text link.
- While `state.submitting`: button **disabled** + inline `CircularProgressIndicator`; fields disabled.
- `state.error != null`: show it under the button in `bodyMedium`, `TerracottaHighlight`.
- Email/password text is **local `remember` state** inside the screen (that's UI state, allowed); everything else is a lambda.

**Previews:** default, `submitting = true`, `error = "Invalid login credentials"`.

---

## SignupScreen (stateless)

```kotlin
@Composable
fun SignupScreen(
    state: AuthUiState.LoggedOut,
    onSignup: (email: String, password: String) -> Unit,
    onGoToLogin: () -> Unit,
    modifier: Modifier = Modifier,
)
```

Same shape + a confirm-password field (validate match locally before calling `onSignup`; mismatch is a local inline error, no network).
- `state.pendingConfirmation == true`: replace the form with a "**Check your inbox to confirm, then log in**" state + a "Back to log in" link. Do **not** auto-enter the app.

**Previews:** default, `submitting = true`, `pendingConfirmation = true`, `error = "User already registered"`.

---

## Wiring the token into `RecitationViewModel` (fixes the 401)

Today [`RecitationViewModel.analyze()`](../../android/app/src/main/java/com/bayaan/ui/viewmodel/RecitationViewModel.kt) posts to `/audio/analyze` with **no** auth header. Change:

1. Give `RecitationViewModel` a token provider. Since it's an `AndroidViewModel` created via `ViewModelProvider`, add a `ViewModelProvider.Factory` that injects `tokenProvider: () -> String?` (or set a `lateinit var` from `MainActivity` before first use — factory is cleaner).
2. In the `client.post(...)` block, add:
   ```kotlin
   header(HttpHeaders.Authorization, "Bearer ${tokenProvider() ?: ""}")
   ```
3. If the token is null/blank, short-circuit to `RecitationUiState.Error(verse, "Please log in again.")` rather than firing a guaranteed 401.

The existing `parseResponse` already maps a non-success status to `RecitationUiState.Error` with the backend's `message`, so a 401 won't crash — but with a real token it should now return `Result`.

**In `MainActivity`:** create `AuthViewModel`, then build `RecitationViewModel` with `tokenProvider = { authViewModel.currentAccessToken() }`. Coordinate the splash gate with Owner B (B owns the nav; you own the decision logic `checkSession()` feeds it).

---

## Expected output / acceptance (Owner A)

- [ ] `./gradlew build` passes; `git diff --cached | grep -iE "key|secret|password|token"` is empty; `local.properties` untracked.
- [ ] Login with a **pre-confirmed demo account** → app calls `/auth/sync` (200) → `LoggedIn`.
- [ ] Signup with a fresh email → `pendingConfirmation` state shown; app does **not** enter Home.
- [ ] Wrong password → `LoggedOut(error=…)` shown inline; button re-enabled.
- [ ] After login, **Analyze Tajweed returns a `Result`, not a 401** (verify on a real recording).
- [ ] `signOut()` → `LoggedOut`; relaunch does not auto-enter (session cleared).
- [ ] Login/Signup have `@Preview`s for every state and follow `UI_SPEC.md`.

**Keep a pre-confirmed demo account** for the live login path in the showcase; use a throwaway email only to demo the pending-confirmation state.
