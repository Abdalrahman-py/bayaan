package com.bayaan.ui.lesson

import android.content.Context
import java.time.LocalDate
import java.time.ZoneOffset

/**
 * Local-only lesson progress (PRODUCTION_PLAN §10 M2: "local-only progress for now").
 *
 * ponytail: SharedPreferences, not DataStore — the app already uses SharedPreferences
 * (`bayaan_prefs`) and no Flow/StateFlow anywhere (android/AGENTS.md), so this matches
 * the codebase and adds no dependency. Ceiling: M4 makes the server the source of
 * truth and this becomes an offline cache — swap the impl behind these methods then.
 *
 * XP/streak math mirrors the backend (0.80 lesson / 0.85 checkpoint pass, UTC streak
 * day) so the local numbers won't jump when M4's server values take over.
 */
class ProgressStore(context: Context) {
    private val prefs = context.getSharedPreferences("bayaan_learn", Context.MODE_PRIVATE)

    fun isCompleted(lessonId: String): Boolean = prefs.getString("lesson.$lessonId.status", null) == "completed"
    fun bestScore(lessonId: String): Float = prefs.getFloat("lesson.$lessonId.best", 0f)
    fun xp(): Int = prefs.getInt("xp", 0)
    fun streak(): Int = prefs.getInt("streak", 0)

    data class AttemptResult(
        val passed: Boolean,
        val firstCompletion: Boolean,
        val xpAwarded: Int,
        val totalXp: Int,
        val streak: Int,
    )

    fun recordAttempt(lessonId: String, isCheckpoint: Boolean, score: Float): AttemptResult {
        val threshold = if (isCheckpoint) 0.85f else 0.80f
        val passed = score >= threshold
        val alreadyCompleted = isCompleted(lessonId)
        val firstCompletion = passed && !alreadyCompleted

        val newBest = maxOf(bestScore(lessonId), score)
        val newStatus = if (passed || alreadyCompleted) "completed" else "in_progress"

        // ponytail: local XP curve — base + score bonus. M4's server formula is authoritative;
        // kept small so the count-up animation reads well without inflating the eventual sync.
        val xpAwarded = (if (isCheckpoint) 20 else 10) + Math.round(score * 10)
        val totalXp = xp() + xpAwarded
        val streak = if (firstCompletion) bumpStreak() else streak()

        prefs.edit()
            .putString("lesson.$lessonId.status", newStatus)
            .putFloat("lesson.$lessonId.best", newBest)
            .putInt("xp", totalXp)
            .apply()

        return AttemptResult(passed, firstCompletion, xpAwarded, totalXp, streak)
    }

    private fun bumpStreak(): Int {
        val today = LocalDate.now(ZoneOffset.UTC)
        val last = prefs.getString("streak_date", null)?.let { runCatching { LocalDate.parse(it) }.getOrNull() }
        val newCount = when (last) {
            today -> streak()
            today.minusDays(1) -> streak() + 1
            else -> 1
        }
        prefs.edit().putInt("streak", newCount).putString("streak_date", today.toString()).apply()
        return newCount
    }
}
