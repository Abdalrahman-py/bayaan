package com.bayaan.ui.feedback

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext

/**
 * Tiny audio identity for the app (PRODUCTION_PLAN §7.2): correct chime, soft
 * incorrect, lesson-complete flourish, streak sparkle, record ticks.
 *
 * Each effect maps to a `res/raw/<name>.ogg` resolved by name at runtime, so this
 * util compiles and runs with **zero** audio files present — a missing clip is a
 * silent no-op, never a crash or an unresolved `R.raw.*` reference.
 *
 * ponytail: the real ≤50KB ogg assets land in M2 (§7.2) as a pure asset drop-in —
 * no code change here when they arrive, just add the files named below.
 */
enum class Sfx(val resName: String) {
    Correct("sfx_correct"),
    Incorrect("sfx_incorrect"),
    LessonComplete("sfx_lesson_complete"),
    StreakExtended("sfx_streak_extended"),
    RecordTick("sfx_record_tick"),
}

class SoundEffects(context: Context, var enabled: Boolean = true) {
    private val appContext = context.applicationContext
    private val pool = SoundPool.Builder()
        .setMaxStreams(4)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        .build()

    // resName -> soundId. Absent raw resource resolves to id 0 → skipped.
    private val ids: Map<Sfx, Int> = Sfx.entries.associateWith { sfx ->
        val resId = appContext.resources.getIdentifier(sfx.resName, "raw", appContext.packageName)
        if (resId != 0) pool.load(appContext, resId, 1) else 0
    }

    fun play(sfx: Sfx) {
        if (!enabled) return
        val id = ids[sfx] ?: 0
        if (id != 0) pool.play(id, 1f, 1f, 1, 0, 1f)
    }

    fun release() = pool.release()
}

@Composable
fun rememberSoundEffects(enabled: Boolean = true): SoundEffects {
    val context = LocalContext.current
    val effects = remember { SoundEffects(context, enabled) }
    effects.enabled = enabled
    DisposableEffect(effects) { onDispose { effects.release() } }
    return effects
}
