package com.bayaan.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.bayaan.ui.theme.BayaanTheme
import com.bayaan.ui.theme.StreakFlame
import com.bayaan.ui.theme.XpGold
import kotlin.random.Random

/**
 * Particle-Canvas confetti (PRODUCTION_PLAN §7 — "not a library gif"). A bottom
 * burst that arcs up and rains down over ~1.8s, fired on unit completion and
 * graduation. Costs nothing when idle: draws only while a burst is in flight.
 */
private class Particle(
    val x0: Float, val y0: Float,
    val vx: Float, val vy: Float,
    val colorIndex: Int,
    val sizeDp: Float,
    val spin: Float,
    val phase: Float,
)

@Composable
fun Confetti(
    running: Boolean,
    modifier: Modifier = Modifier,
    particleCount: Int = 70,
) {
    val palette = listOf(
        MaterialTheme.colorScheme.primary,
        MaterialTheme.colorScheme.secondary,
        XpGold,
        StreakFlame,
    )
    val particles = remember(particleCount) {
        List(particleCount) {
            Particle(
                x0 = 0.5f + Random.nextFloat() * 0.2f - 0.1f,
                y0 = 1.05f,
                vx = Random.nextFloat() * 1.2f - 0.6f,
                vy = -(0.9f + Random.nextFloat() * 0.6f),
                colorIndex = Random.nextInt(4),
                sizeDp = 6f + Random.nextFloat() * 6f,
                spin = Random.nextFloat() * 720f - 360f,
                phase = Random.nextFloat() * 360f,
            )
        }
    }

    val t = remember { Animatable(0f) }
    LaunchedEffect(running) {
        if (running) {
            t.snapTo(0f)
            t.animateTo(1f, tween(1800, easing = LinearEasing))
        }
    }

    val progress = t.value
    if (progress <= 0f || progress >= 1f) return

    Canvas(modifier.fillMaxSize()) {
        val g = 1.8f
        val alpha = if (progress < 0.6f) 1f else (1f - progress) / 0.4f
        particles.forEach { p ->
            val x = (p.x0 + p.vx * progress) * size.width
            val y = (p.y0 + p.vy * progress + 0.5f * g * progress * progress) * size.height
            if (y > size.height * 1.1f) return@forEach
            val s = p.sizeDp.dp.toPx()
            val color: Color = palette[p.colorIndex].copy(alpha = alpha.coerceIn(0f, 1f))
            rotate(degrees = p.phase + p.spin * progress, pivot = Offset(x, y)) {
                drawRect(color, topLeft = Offset(x - s / 2f, y - s / 4f), size = Size(s, s / 2f))
            }
        }
    }
}

@Preview
@Composable
private fun ConfettiPreview() {
    // Preview shows the idle state (no burst); trigger with running=true at runtime.
    BayaanTheme { Confetti(running = false, modifier = Modifier.fillMaxSize()) }
}
