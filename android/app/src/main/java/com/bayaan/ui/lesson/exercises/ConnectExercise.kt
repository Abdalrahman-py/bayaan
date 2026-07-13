package com.bayaan.ui.lesson.exercises

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bayaan.ui.theme.AmiriFontFamily
import com.bayaan.ui.theme.BayaanTheme
import com.bayaan.ui.viewmodel.LessonViewModel.Outcome

/**
 * CONNECT — tap the correct joined form of a letter (§4 Unit 4).
 *
 * Unit 4 content is stub-only until M6, so this is @Preview-only self-contained state
 * (ws-lesson-player task 2). Wire it to the drill machine when Unit 4 is authored.
 */
@Composable
fun ConnectExercise(
    base: String = "ب",
    options: List<String> = listOf("بـ", "ـبـ", "ـب"),
    answer: String = "بـ",
) {
    var picked by remember { mutableStateOf<String?>(null) }
    val outcome = if (picked == null) null else Outcome.CORRECT.takeIf { picked == answer } ?: Outcome.FAILED

    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        ExerciseInstruction("Tap the initial (start) form")
        Text(base, fontFamily = AmiriFontFamily, fontSize = 96.sp, color = MaterialTheme.colorScheme.primary,
            style = MaterialTheme.typography.displayLarge.copy(textDirection = TextDirection.Rtl))
        OptionsFlow {
            options.forEach { opt ->
                OptionButton(
                    label = opt,
                    visual = optionVisual(opt, answer, if (picked != null && picked != answer) setOf(picked!!) else emptySet(), outcome),
                    arabic = true,
                    onClick = { picked = opt },
                )
            }
        }
    }
}

@Preview
@Composable
private fun ConnectPreview() {
    BayaanTheme { ConnectExercise() }
}
