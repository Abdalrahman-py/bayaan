# Bayaan — Prototype Build Guide (4-person, ~2–4 days)

> **Scope:** ONLY the supervisor-showcase prototype slice — auth + essential app scaffolding + paged mushaf ayah selection + tajweed analysis handoff. This is deliberately **not** the full product (Arabic placement, learning roadmap, memorization streaming, gamification live there: see [`PRODUCT_VISION.md`](./PRODUCT_VISION.md)).
> **Audience:** the 4-person frontend team (member-agnostic — owners are labelled A–D, assign names yourselves). Backend is already built and deployed; this is Android + a little content/asset work.
> **Goal:** a fresh-install user can open the app → see intro → sign up → land home → open the mushaf → tap an ayah → analyze their tajweed with live letter-level mistake highlighting. On a real device, cold.

---

## 0. How this documentation is organized

This file is the **overview + index**. Detailed, leave-nothing-to-guess specs live in dedicated files:

- **Shared UI spec (read before any screen):** [`android/UI_SPEC.md`](../android/UI_SPEC.md) — color, type, spacing, components, RTL, accessibility.
- **Data contract for the recitation screen:** [`android/UI_BRIEF.md`](../android/UI_BRIEF.md) §4.
- **Per-owner implementation guides** (scope · files · interface · step-by-step · expected output):

  | Owner | Guide | Area |
  |---|---|---|
  | A | [`prototype/01-auth-session.md`](./prototype/01-auth-session.md) | Auth & session (critical path) |
  | B | [`prototype/02-app-shell-nav.md`](./prototype/02-app-shell-nav.md) | App shell, navigation, splash/onboarding/home/profile/settings |
  | C | [`prototype/03-mushaf-selection.md`](./prototype/03-mushaf-selection.md) | Mushaf paged ayah selection (the hard part) |
  | D | [`prototype/04-content-assets-qa.md`](./prototype/04-content-assets-qa.md) | Content, assets, integration, polish, QA |

A copy of this map also lives in the Android module at [`android/PROTOTYPE_DOCS.md`](../android/PROTOTYPE_DOCS.md).

---

## 1. What we're building (end-to-end flow)

```
First launch:  Splash ──► Onboarding (3-screen carousel) ──► [Get Started]
                 │                                              │
   (session?)    │ has session                                  ▼
                 ▼                                     Login  ◄─► Signup   (Supabase email/pw)
               Home ◄──────────────────── auth success + /auth/sync ──────┘
                 │
                 ▼
   Home ──► Mushaf (paged Quran images)
                 │  tap/long-press an ayah's box → action menu:
                 ├─ "Memorize"        → DISABLED / "Coming soon" (locked in this build)
                 └─ "Analyze Tajweed" → RecitationScreen(sura,aya)  [EXISTING screen]
                                          record → Muaalem engine → letter-level highlights
   Also reachable from a top-bar/nav: Profile (account + logout), Settings (theme/about).
```

**Reused as-is (do not rebuild):** `RecitationScreen`, `VerseText` (letter highlighting), `RecitationViewModel` + engine pipeline, `BayaanTheme`, the `recitation/{sura}/{aya}` nav route. The tajweed handoff is *mostly already wired* — selecting an ayah just navigates to that existing route. **Note:** `/audio/analyze` currently returns **401** because the app sends no auth token yet — Owner A fixes this (guide 01).

---

## 2. Screen inventory (full per-screen specs are in the owner guides)

| Screen | New? | Owner | One-line spec |
|---|---|---|---|
| **Splash** | New | B | Branded (بَيَان wordmark). Auth-gate decides first destination. → guide 02 |
| **Onboarding** | New | B | 3-screen `HorizontalPager`, shown once ever (`first_launch` flag). → guide 02 |
| **Login** | New | A | Email/password, inline spinner + errors. Calls `AuthViewModel.login()`. → guide 01 |
| **Signup** | New | A | Email/password/confirm; email-confirmation-pending state. → guide 01 |
| **Home** | New | B | Post-auth landing; primary CTA "Open the Qur'an" → Mushaf. → guide 02 |
| **Mushaf** | New (hard) | C | Paged Quran **images** + `ayahinfo` bbox selection → action menu. → guide 03 |
| **RecitationScreen** | EXISTS | — | Reused unchanged. Receives `(sura, aya)`. |
| **Profile** | New | B | Account email + **Log out**. → guide 02 |
| **Settings** | New | B | Minimal: theme note, about/version. → guide 02 |

---

## 3. Navigation & app shell (detail in guide 02)

- Single `NavHost`. Routes: `splash` (start), `onboarding`, `login`, `signup`, `home`, `mushaf`, `recitation/{sura}/{aya}` (exists), `profile`, `settings`.
- Post-auth area reached via a **bottom nav — 3 tabs: Home · Qur'an · Profile** (Settings lives under Profile). Bottom bar shows only on `home`/`mushaf`/`profile`/`settings`; not on splash/onboarding/auth or the recitation screen. See guide 02.
- Auth gate lives at `splash`: it decides the first destination and clears the back stack with `popUpTo`. After logout: `navigate("login") { popUpTo(0) { inclusive = true } }`.
- The existing `BayaanNavGraph` currently hardcodes `startDestination = "picker"` and takes recitation lambdas directly — Owner B restructures it around the auth gate; see guide 02.

---

## 4. The hard part — Mushaf paged selection

Full spec in **[guide 03](./prototype/03-mushaf-selection.md)**. Summary: `HorizontalPager` over bundled Madani page **images** + read ayah bounding boxes from a bundled `ayahinfo` SQLite DB, overlay a `Canvas` for hit-testing (scale box coords from image-pixel space to displayed size — the #1 bug source), highlight the tapped ayah, show an action menu, and hand off `onAyahSelected(sura, aya)` → `navController.navigate("recitation/$sura/$aya")`.

- **Day-1 spike:** render ONE page + select ONE ayah correctly. Decide mushaf vs fallback by EOD Day 1.
- **Fallback (guaranteed demo):** reuse the existing `VersePickerScreen` (surah→ayah list) with the same two-option menu. Keep it ready all week.

---

## 5. Content gotcha (detail in guide 04)

Full spec in **[guide 04](./prototype/04-content-assets-qa.md)**. Summary: `verseFor()` only has hardcoded Uthmani text for **Al-Fatihah (1)** and **Al-Bayyinah (98)**; the mushaf can select any ayah, so `RecitationScreen` would show the wrong text otherwise. Cheapest fix: constrain the demo mushaf to pages whose surahs already have text. Better: use the engine-returned `uthmani` field for highlight text (so char positions line up) and/or generalize `verseFor()`.

---

## 6. Four-person task split (member-agnostic, minimal collisions)

Each owner works in a different area with a clear interface, so you can build in parallel and integrate late. **Full detail per owner is in the linked guide.**

| Owner | Area | Exposes to others | Guide |
|---|---|---|---|
| **A** | Auth & session (critical path) | `AuthUiState`, `currentAccessToken()`, login/signup/signOut; token provider into `RecitationViewModel` | [01](./prototype/01-auth-session.md) |
| **B** | App shell & scaffolding | Nav graph with `mushaf` entry + slot for C's screen; `recitation/{sura}/{aya}` route; `BayaanHeader` | [02](./prototype/02-app-shell-nav.md) |
| **C** | Mushaf paged selection | `MushafScreen(onAyahSelected)`; develops standalone against one bundled page | [03](./prototype/03-mushaf-selection.md) |
| **D** | Content, assets, integration, QA | Bundled page images + `ayahinfo` DB; resolved text gotcha; app icon; QA sign-off | [04](./prototype/04-content-assets-qa.md) |

**Stub contracts so everyone can start Day 1:** others stub Owner A with a fake token provider (`{ "fake-token" }`); Owner B stubs C's screen with a placeholder composable calling `onAyahSelected(1, 1)`; C develops against one bundled page with no auth.

---

## 7. Suggested day-by-day (adjust to team velocity)

- **Day 1:** A → Supabase + auth skeleton compiles. B → nav + splash + onboarding shell. C → **mushaf spike (1 page renders + 1 ayah selects)** — decide mushaf vs fallback by EOD. D → source assets + demo-page text.
- **Day 2:** A → finish Login/Signup + gate + token wiring. B → Home/Profile/Settings. C → full selection + action menu + handoff. D → resolve text gotcha + start polish.
- **Day 3:** Integration — everything through B's nav. Full end-to-end test (fresh launch → onboarding → signup → home → mushaf → select → analyze → highlights). D leads QA.
- **Day 4 (buffer):** app icon, error/cold-start states, edge cases (wrong password, unconfirmed email, no-network), **cold-install demo rehearsal**, keep-warm.

---

## 8. Definition of done (acceptance test — run on a real device, cold)

1. Build passes: `cd android && ./gradlew build`. No secrets staged (`git diff --cached | grep -iE "key|secret|password|token"` empty; `local.properties` untracked).
2. Fresh install → Splash → **Onboarding shows (3 pages)** → Get Started → Signup → "confirm email" state → (confirm) → Login → **Home**.
3. Relaunch → Splash skips onboarding + auth → **Home directly** (session persists).
4. Home → **Mushaf** → tap an ayah → menu shows **Memorize (disabled)** + **Analyze Tajweed**.
5. Analyze Tajweed → **RecitationScreen with the correct ayah text** → record → `Result` (NOT a 401) → **letter-level mistake highlights on the correct letters**.
6. Profile → **Log out** → returns to Login; relaunch does not auto-enter the app.
7. If mushaf fell back to the list: same loop works via `VersePickerScreen`.

Per-owner acceptance checks are at the end of each owner guide.

---

## 9. Dependencies, assets, risks

- **New deps:** Supabase `auth-kt` (+ BOM). Optional: Coil (page-image loading). SharedPreferences (no dep) for `first_launch`. Raw `SQLiteDatabase` for `ayahinfo` (no Room). Keep it lean.
- **Assets:** bundled page-image subset + `ayahinfo` DB in `assets/` — **verify attribution/license** (guide 04).
- **Risks:** (1) mushaf bbox coord-scaling in Compose → spike Day 1, list fallback ready. (2) text gotcha (§5) → constrain pages or engine-`uthmani`. (3) backend cold starts (Render + Modal free tiers) → keep warm before the demo; make spinners honest. (4) email-confirmation ON → keep a pre-confirmed demo account for the live login path; use a fresh email only to show the pending state.
