package com.bayaan.ui.feedback

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.hapticfeedback.HapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback

/**
 * Haptic vocabulary for the app (PRODUCTION_PLAN §7.3): a light tick on correct,
 * a firmer bump on lesson complete, a subtle tick on record start/stop.
 *
 * ponytail: routed through Compose's [LocalHapticFeedback] so it needs no `VIBRATE`
 * permission and no new dependency. Ceiling: the platform only exposes two feedback
 * constants, so [Tick] and [Confirm] are the whole palette. Upgrade path — add the
 * `VIBRATE` permission + a `Vibrator`/`VibrationEffect` controller for distinct
 * waveforms (streak-extend sparkle, etc.) if the two-step palette ever feels flat.
 */
enum class Haptic { Tick, Confirm }

class Haptics(private val feedback: HapticFeedback, var enabled: Boolean = true) {
    fun play(kind: Haptic) {
        if (!enabled) return
        val type = when (kind) {
            Haptic.Tick -> HapticFeedbackType.TextHandleMove
            Haptic.Confirm -> HapticFeedbackType.LongPress
        }
        feedback.performHapticFeedback(type)
    }
}

@Composable
fun rememberHaptics(enabled: Boolean = true): Haptics {
    val feedback = LocalHapticFeedback.current
    return remember(feedback) { Haptics(feedback, enabled) }.also { it.enabled = enabled }
}
