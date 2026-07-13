package com.bayaan.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.bayaan.ui.theme.BayaanTheme
import com.bayaan.ui.theme.XpGold
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Animated score ring (PRODUCTION_PLAN §7.1 / §7.8) — the sweep counts up from 0 on
 * first show. Reused at large size on the lesson Wrap screen and small as the
 * daily-goal ring in the Learn header.
 */
@Composable
fun ScoreRing(
    score: Float,
    modifier: Modifier = Modifier,
    ringSize: Dp = 120.dp,
    strokeWidth: Dp = 10.dp,
    label: String? = null,
    showPercent: Boolean = true,
    animate: Boolean = true,
) {
    val target = score.coerceIn(0f, 1f)
    val sweep = remember { Animatable(0f) }
    LaunchedEffect(target, animate) {
        if (animate) sweep.animateTo(target, tween(700, easing = FastOutSlowInEasing))
        else sweep.snapTo(target)
    }

    val track = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.12f)
    Box(contentAlignment = Alignment.Center, modifier = modifier.size(ringSize)) {
        Canvas(Modifier.fillMaxSize()) {
            val sw = strokeWidth.toPx()
            val d = min(size.width, size.height) - sw
            val topLeft = Offset((size.width - d) / 2f, (size.height - d) / 2f)
            val arcSize = Size(d, d)
            drawArc(track, -90f, 360f, false, topLeft, arcSize, style = Stroke(sw, cap = StrokeCap.Round))
            drawArc(XpGold, -90f, 360f * sweep.value, false, topLeft, arcSize, style = Stroke(sw, cap = StrokeCap.Round))
        }
        if (showPercent || label != null) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                if (showPercent) {
                    Text(
                        text = "${(sweep.value * 100).roundToInt()}%",
                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }
                label?.let {
                    Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
                }
            }
        }
    }
}

@Preview
@Composable
private fun ScoreRingPreview() {
    BayaanTheme { ScoreRing(score = 0.86f, label = "Great") }
}
