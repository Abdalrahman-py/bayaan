# Workstream: Android app shell (M0)

**Owner:** Issa · **Depends on:** nothing — start immediately · **Unblocks:** lesson player (M2)
**Spec:** `docs/PRODUCTION_PLAN.md` §6 (navigation), §7 (premium feel), §10 M0. Styling law: `android/UI_SPEC.md`.

## Goal

Turn the 3-tab prototype into the 4-tab learning-app shell the whole Arabic
track lives in. No lesson logic — structure, motion, and design-system
utilities only.

## Tasks

1. Bottom nav 3 → 4 tabs: **Learn** (new, default) · Qur'an (existing mushaf,
   untouched) · **Progress** (new stub) · Profile (existing). Routes `learn`,
   `progress` added to `NavGraph.kt`; drill-in routes keep hiding the bar.
2. Learn tab placeholder path: unit headers + lesson nodes (done ✓ / current
   pulsing / locked states), streak flame + XP in header, "Continue" hero CTA.
   Static fake data — real state arrives in M4.
3. Design-system additions (each its own small util, `ui/designsystem/`):
   - motion utilities (spring-in for nodes, 250ms correct-pop, 3px wrong-shake,
     `FastOutSlowIn`, nothing over 400ms — §7.1)
   - sound player util (ogg one-shots, respects system + settings toggle — §7.2)
   - haptics util (§7.3)
   - score ring composable, confetti canvas (particle, no library — §7.8)
4. App icon (adaptive, green/sand بيان mark) + branded splash (SplashScreen API).
5. `DEMO_MODE` build flag (BuildConfig boolean) — gates nothing yet, exists so
   later lock checks have one switch.

## Acceptance (from §10 M0 — green on a real device)

- App builds; nav works; Learn tab shows placeholder path with animated nodes;
  icon/splash present; dark mode clean.

## Don't

- Touch `RecitationScreen`, mushaf code, or auth — reuse contract in §1.
- Add dependencies for things Compose already does (confetti, springs).
- Ask Abdalrahman about styling — `UI_SPEC.md` answers it.
