package com.bayaan.ui.lesson.exercises

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bayaan.ui.lesson.model.ExerciseItem
import com.bayaan.ui.lesson.model.ExerciseType
import com.bayaan.ui.theme.AmiriFontFamily
import com.bayaan.ui.theme.BayaanTheme
import com.bayaan.ui.viewmodel.LessonViewModel.Outcome

/**
 * READ_PICK — see a letter, tap the matching sound (§4 Unit 1).
 *
 * ponytail: options are labelled "Sound 1/2/…" and selecting one answers directly.
 * When the letter clips land, wire tap → play-then-select; a no-op today since the
 * audio is still pending (letter-audio-checklist.md).
 */
@Composable
fun ReadPickExercise(
    item: ExerciseItem,
    disabled: Set<String>,
    outcome: Outcome?,
    onAnswer: (String) -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        ExerciseInstruction("Tap the sound that matches")
        Text(
            text = item.promptTextAr.orEmpty(),
            fontFamily = AmiriFontFamily,
            fontSize = 96.sp,
            color = MaterialTheme.colorScheme.primary,
            style = MaterialTheme.typography.displayLarge.copy(textDirection = TextDirection.Rtl),
        )
        OptionsFlow {
            item.options.forEachIndexed { i, opt ->
                OptionButton(
                    label = "Sound ${i + 1}",
                    visual = optionVisual(opt, item.answer, disabled, outcome),
                    arabic = false,
                    onClick = { onAnswer(opt) },
                )
            }
        }
    }
}

@Preview
@Composable
private fun ReadPickPreview() {
    BayaanTheme {
        ReadPickExercise(
            item = ExerciseItem("x", ExerciseType.READ_PICK, 0, promptTextAr = "ن",
                answer = "letters/nun_fatha.ogg",
                options = listOf("letters/nun_fatha.ogg", "letters/ba_fatha.ogg", "letters/ta_fatha.ogg")),
            disabled = emptySet(), outcome = null, onAnswer = {},
        )
    }
}
