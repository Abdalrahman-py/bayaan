# Owner B — App Shell, Navigation & Scaffolding

> You own the app's skeleton: the nav graph (with the auth gate), the branded Splash, the 3-screen Onboarding, and Home/Profile/Settings. You also extract the shared `BayaanHeader`. Your nav graph is where everyone integrates — publish the route contract early.
>
> **Read first:** [`android/UI_SPEC.md`](../../android/UI_SPEC.md). **Prereqs:** none to start (stub A with a fake token provider and C with a placeholder screen). Coordinate the auth gate with Owner A and the `mushaf` route with Owner C.

---

## Current state you're changing

[`BayaanNavGraph`](../../android/app/src/main/java/com/bayaan/ui/navigation/NavGraph.kt) today:
- Hardcodes `startDestination = "picker"`.
- Only has `picker` + `recitation/{sura}/{aya}`.
- Takes recitation lambdas as parameters, wired in [`MainActivity`](../../android/app/src/main/java/com/bayaan/MainActivity.kt).

You restructure it around an **auth gate at `splash`** and add the new routes, **without breaking** the existing `recitation/{sura}/{aya}` composable block (leave its body as-is; Owner A adjusts the token, not you).

---

## Files you create / touch

| File | Action |
|---|---|
| `ui/navigation/NavGraph.kt` | **touch** — add routes + gate; keep the recitation block |
| `ui/components/BayaanHeader.kt` | **new** — extract from `VersePickerScreen`'s private `HeaderSection` |
| `ui/screens/SplashScreen.kt` | **new** |
| `ui/screens/OnboardingScreen.kt` | **new** |
| `ui/screens/HomeScreen.kt` | **new** |
| `ui/screens/ProfileScreen.kt` | **new** |
| `ui/screens/SettingsScreen.kt` | **new** |
| `ui/navigation/AppShell.kt` (or in NavGraph) | **new** — bottom nav / top-bar shell for the post-auth area |
| `MainActivity.kt` | **touch** — host the graph; coordinate `AuthViewModel` with A |

---

## Routes (the contract everyone builds against — publish this Day 1)

Single `NavHost`. `startDestination = "splash"`.

| Route | Screen | Owner | Notes |
|---|---|---|---|
| `splash` | Splash | B | auth-gate decides next; no back entry |
| `onboarding` | Onboarding | B | first launch only |
| `login` | Login | A | |
| `signup` | Signup | A | |
| `home` | Home | B | post-auth |
| `mushaf` | Mushaf | C | `MushafScreen(onAyahSelected = { s, a -> nav.navigate("recitation/$s/$a") })` |
| `recitation/{sura}/{aya}` | Recitation | — | **exists — don't change the composable body** |
| `profile` | Profile | B | |
| `settings` | Settings | B | |

**Gate rules:**
- `splash` → on `AuthViewModel.checkSession()` result: `LoggedIn` → `home`; first-launch-ever → `onboarding`; else → `login`. Clear back stack: `navigate(dest) { popUpTo("splash") { inclusive = true } }`.
- After `LoggedIn` from login/signup → `navigate("home") { popUpTo(0) { inclusive = true } }`.
- Logout (from Profile) → `navigate("login") { popUpTo(0) { inclusive = true } }`.

Wrap C's screen with a placeholder until it lands:
```kotlin
composable("mushaf") { /* TODO C */ PlaceholderMushaf(onAyahSelected = { s, a -> navController.navigate("recitation/$s/$a") }) }
```

---

## `BayaanHeader` (extract, don't rewrite)

Lift `HeaderSection` out of [`VersePickerScreen.kt`](../../android/app/src/main/java/com/bayaan/ui/screens/VersePickerScreen.kt) into `ui/components/BayaanHeader.kt` as a public composable, then have `VersePickerScreen` call it (no visual change). Make the tagline a parameter with the current default:

```kotlin
@Composable
fun BayaanHeader(
    modifier: Modifier = Modifier,
    tagline: String = "Your AI Tajweed Recitation Coach",
)
```
Keep the exact styling that's already there (بَيَان Amiri 48sp `primary`, "Bayaan" `displayLarge` ExtraBold, tagline `bodyLarge` @70% alpha). Onboarding/Login/Signup/Home all reuse it.

---

## Screens (each stateless; state in / lambdas out)

### Splash
```kotlin
@Composable fun SplashScreen(modifier: Modifier = Modifier)   // pure visual: BayaanHeader centered on background
```
No interaction. The **gate logic lives in the nav layer** observing `AuthViewModel.state` (`Checking` → show splash; on resolve → navigate). Optionally show a small `CircularProgressIndicator` under the wordmark while `Checking`. **Preview:** the splash.

### Onboarding
```kotlin
@Composable
fun OnboardingScreen(
    onFinish: () -> Unit,          // Get Started → login
    onSkip: () -> Unit,            // → login
    modifier: Modifier = Modifier,
)
```
- `HorizontalPager` (3 pages): what Bayaan does · tajweed feedback · track progress. Each page = icon/illustration + title (`headlineMedium`) + body (`bodyLarge`).
- Page-dots indicator; **Skip** (top-right) + **Next**; last page shows **Get Started** (→ `onFinish`) and a "Log in" text link (→ also login).
- **Shown once ever:** gate on a `first_launch` boolean in `SharedPreferences` (no new dep). The nav/gate flips it to false after onboarding is dismissed; on subsequent launches splash skips onboarding. Keep the read/write in the nav or a tiny helper, not inside the stateless composable.

**Previews:** each of the 3 pages (or a pager preview).

### Home
```kotlin
@Composable
fun HomeScreen(
    onOpenMushaf: () -> Unit,
    onOpenProfile: () -> Unit,
    onOpenSettings: () -> Unit,
    modifier: Modifier = Modifier,
)
```
`BayaanHeader` + primary CTA **"Open the Qur'an"** (full-width `Button`, `primary`) → `onOpenMushaf`. Leave a simple placeholder card ("Your roadmap — coming soon") for the future. Profile/Settings via top-bar icons or bottom nav. **Preview:** Home.

### Profile
```kotlin
@Composable
fun ProfileScreen(
    email: String,
    onLogout: () -> Unit,
    modifier: Modifier = Modifier,
)
```
Show the account `email` (Owner A supplies it from the session) + a **Log out** `Button`. Minimal. **Preview:** with a sample email.

### Settings
```kotlin
@Composable fun SettingsScreen(versionName: String, modifier: Modifier = Modifier)
```
Tiny: a note that theme follows system dark mode (already automatic), About/version (`BuildConfig.VERSION_NAME`), placeholders for later. **Preview:** Settings.

---

## App shell (post-auth navigation)

**Bottom nav — 3 tabs: Home · Qur'an · Profile.** This is the decided pattern; don't add a top-bar nav variant.
- Tab → route: Home → `home`, Qur'an → `mushaf`, Profile → `profile`.
- **Settings** is reached from Profile (a row/icon), not its own tab.
- Use Material 3 `NavigationBar` + `NavigationBarItem`; icons need `contentDescription`; keep it to these 3 tabs.
- The bottom bar shows **only** on the post-auth routes (`home`/`mushaf`/`profile`/`settings`). Splash/onboarding/login/signup and the `recitation/{sura}/{aya}` screen have **no** bottom nav.

---

## Expected output / acceptance (Owner B)

- [ ] `./gradlew build` passes; all new screens have `@Preview`s and follow `UI_SPEC.md`.
- [ ] Fresh install → Splash → **Onboarding (3 pages)** → Get Started → Login. Relaunch → Splash → Login/Home directly (onboarding never shows again).
- [ ] With Owner A landed: `LoggedIn` routes to **Home**; logout returns to Login with back stack cleared (back button doesn't re-enter the app).
- [ ] Home CTA → `mushaf` route (placeholder or C's screen); mushaf → `recitation/{sura}/{aya}` still works.
- [ ] `BayaanHeader` extracted; `VersePickerScreen` looks unchanged.
- [ ] Post-auth nav pattern is consistent; auth screens have no bottom nav.
