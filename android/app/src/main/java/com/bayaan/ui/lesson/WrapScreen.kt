package com.bayaan.ui.lesson

import androidx.compose.animation.core.animateIntAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.bayaan.ui.components.Confetti
import com.bayaan.ui.components.ScoreRing
import com.bayaan.ui.theme.BayaanTheme
import com.bayaan.ui.viewmodel.LessonViewModel

/** Lesson wrap: score ring sweeps, XP counts up, streak flame, then Continue (§4.x/§7.8). */
@Composable
fun WrapScreen(
    state: LessonViewModel.UiState.Wrap,
    onContinue: () -> Unit,
    onPractice: () -> Unit,
) {
    var xpTarget by remember { mutableStateOf(state.totalXp - state.xpAwarded) }
    LaunchedEffect(Unit) { xpTarget = state.totalXp }
    val shownXp by animateIntAsState(targetValue = xpTarget, animationSpec = tween(800), label = "xp")

    Box(Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier.fillMaxSize().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                text = if (state.passed) "Lesson complete!" else "Keep practicing",
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.onBackground,
                textAlign = TextAlign.Center,
            )
            Text(
                text = state.lesson.titleEn,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
                modifier = Modifier.padding(top = 4.dp, bottom = 28.dp),
            )
            ScoreRing(score = state.scorePct, ringSize = 148.dp, strokeWidth = 12.dp, label = "${state.correctCount}/${state.total}")
            Text(
                text = "🔥 ${state.streak}     +${state.xpAwarded} XP",
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.onBackground,
                modifier = Modifier.padding(top = 24.dp),
            )
            Text(
                text = "$shownXp XP total",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
                modifier = Modifier.padding(top = 4.dp, bottom = 36.dp),
            )
            Button(onClick = onContinue, modifier = Modifier.fillMaxWidth().height(52.dp)) {
                Text("Continue")
            }
            if (state.canPractice) {
                OutlinedButton(onClick = onPractice, modifier = Modifier.fillMaxWidth().height(52.dp).padding(top = 12.dp)) {
                    Text("Practice the ones you missed")
                }
            }
        }
        // Celebration overlay — draws only during the burst.
        Confetti(running = state.passed, modifier = Modifier.fillMaxSize())
    }
}

@Preview
@Composable
private fun WrapPreview() {
    BayaanTheme {
        WrapScreen(
            state = LessonViewModel.UiState.Wrap(
                lesson = com.bayaan.ui.lesson.model.Lesson("ar.1.1", "ar.1", "Dotted family", "ب ت ث ن ي", false, null, emptyList()),
                scorePct = 0.86f, correctCount = 6, total = 7, xpAwarded = 18, totalXp = 258, streak = 4,
                passed = true, canPractice = false,
            ),
            onContinue = {}, onPractice = {},
        )
    }
}
