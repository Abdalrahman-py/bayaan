package com.bayaan.ui.motion

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.graphics.graphicsLayer

/**
 * Shared motion vocabulary (PRODUCTION_PLAN §7.1): every state change animates,
 * standard easing is [FastOutSlowInEasing], nothing runs longer than 400ms.
 * Correct answers scale-pop, wrong answers shake gently — never a punitive flash.
 */
object BayaanMotion {
    const val FAST_MS = 120
    const val MED_MS = 250
    const val MAX_MS = 400

    fun <T> quick() = tween<T>(durationMillis = FAST_MS, easing = FastOutSlowInEasing)
    fun <T> standard() = tween<T>(durationMillis = MED_MS, easing = FastOutSlowInEasing)

    /** Springy entrance for staggered lesson nodes. */
    fun <T> entrance() = spring<T>(
        dampingRatio = Spring.DampingRatioMediumBouncy,
        stiffness = Spring.StiffnessLow,
    )
}

/** 250ms scale-pop when [trigger] changes — the "correct answer" reward. Inert on first composition. */
fun Modifier.correctPop(trigger: Any?): Modifier = composed {
    val scale = remember { Animatable(1f) }
    val first = remember { arrayOf(true) }
    LaunchedEffect(trigger) {
        if (first[0]) { first[0] = false; return@LaunchedEffect }
        scale.animateTo(1.12f, tween(BayaanMotion.FAST_MS, easing = FastOutSlowInEasing))
        scale.animateTo(1f, BayaanMotion.entrance())
    }
    graphicsLayer { scaleX = scale.value; scaleY = scale.value }
}

/** Gentle ±3px horizontal shake when [trigger] changes — the "wrong answer" nudge. Inert on first composition. */
fun Modifier.gentleShake(trigger: Any?): Modifier = composed {
    val offset = remember { Animatable(0f) }
    val first = remember { arrayOf(true) }
    LaunchedEffect(trigger) {
        if (first[0]) { first[0] = false; return@LaunchedEffect }
        val path = floatArrayOf(-3f, 3f, -2f, 2f, -1f, 0f)
        for (dx in path) offset.animateTo(dx, tween(45, easing = FastOutSlowInEasing))
    }
    graphicsLayer { translationX = offset.value * density }
}
