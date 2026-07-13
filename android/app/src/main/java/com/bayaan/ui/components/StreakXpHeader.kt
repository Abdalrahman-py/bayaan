package com.bayaan.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.bayaan.ui.theme.BayaanTheme
import com.bayaan.ui.theme.StreakFlame
import com.bayaan.ui.theme.XpGold

/**
 * Streak flame + XP, with an optional daily-goal ring (PRODUCTION_PLAN §7.8). Sits
 * atop the Learn tab and, later, the Progress tab.
 *
 * ponytail: the flame is an emoji glyph — zero assets, renders on every device.
 * Ceiling: a custom animated flame vector is the polish upgrade (§7.8), a drop-in
 * swap of this one Text.
 */
@Composable
fun StreakXpHeader(
    streak: Int,
    xp: Int,
    modifier: Modifier = Modifier,
    goalMinutes: Int? = null,
    minutesDone: Int = 0,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            StatPill(text = "🔥 $streak", tint = StreakFlame)
            Spacer(Modifier.width(10.dp))
            StatPill(text = "$xp XP", tint = XpGold)
        }
        if (goalMinutes != null && goalMinutes > 0) {
            ScoreRing(
                score = minutesDone.toFloat() / goalMinutes,
                ringSize = 46.dp,
                strokeWidth = 5.dp,
                showPercent = false,
                modifier = Modifier.size(46.dp),
            )
        }
    }
}

@Composable
private fun StatPill(text: String, tint: androidx.compose.ui.graphics.Color) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.SemiBold),
        color = MaterialTheme.colorScheme.onSurface,
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(tint.copy(alpha = 0.14f))
            .padding(horizontal = 12.dp, vertical = 6.dp),
    )
}

@Preview
@Composable
private fun StreakXpHeaderPreview() {
    BayaanTheme {
        StreakXpHeader(streak = 7, xp = 1240, goalMinutes = 10, minutesDone = 6, modifier = Modifier.padding(16.dp))
    }
}
