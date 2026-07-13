package com.bayaan.ui.theme

import androidx.compose.ui.graphics.Color

// Primary Palette - Calm & Reverent Greens/Sands
val GreenPrimaryLight = Color(0xFF2C5E43)
val GreenSecondaryLight = Color(0xFF8D9965)
val SandBackgroundLight = Color(0xFFFCFBF7)
val CreamSurfaceLight = Color(0xFFF6F4EB)
val TextDark = Color(0xFF1E2922)

val GreenPrimaryDark = Color(0xFF639D7E)
val GreenSecondaryDark = Color(0xFFA5B284)
val SandBackgroundDark = Color(0xFF111814)
val CreamSurfaceDark = Color(0xFF1A231E)
val TextLight = Color(0xFFE3EAE6)

// Tajweed Highlight Colors - Muted Terracotta/Amber instead of alarmist red
val TerracottaHighlight = Color(0xFFD95A3B)
val TerracottaBackgroundLight = Color(0xFFFEEFEA)
val TerracottaBackgroundDark = Color(0xFF3B1E19)

val PlainErrorHighlight = Color(0xFFC084FC) // Muted purple for plain misreads
val PlainErrorBackgroundLight = Color(0xFFF3E8FF)
val PlainErrorBackgroundDark = Color(0xFF2E1C3F)

val SifatHighlight = Color(0xFF2B7AB3)        // Calm blue for letter-characteristic errors
val SifatBackgroundLight = Color(0xFFE8F2FA)
val SifatBackgroundDark = Color(0xFF0E1E2D)

// Gamification accents (M0, PRODUCTION_PLAN §7). Named constants, theme-agnostic —
// same warmth reads in light and dark, like the mistake-highlight family above.
val StreakFlame = Color(0xFFE8863C)           // streak flame
val XpGold = Color(0xFFD9A441)                // XP / score ring
val NodeLockedLight = Color(0xFFD8D3C4)       // locked lesson node (light)
val NodeLockedDark = Color(0xFF39413A)        // locked lesson node (dark)

// Harakat teaching tints (§7.5) — one consistent accent per short vowel, used
// everywhere a harakah is taught so learners bind color→sound.
val FathaAccent = Color(0xFFCB6D51)
val KasraAccent = Color(0xFF4E86A8)
val DammaAccent = Color(0xFF7C9A54)
