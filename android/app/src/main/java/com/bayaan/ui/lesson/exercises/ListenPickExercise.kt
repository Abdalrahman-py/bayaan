package com.bayaan.ui.lesson.exercises

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.bayaan.ui.lesson.model.ExerciseItem
import com.bayaan.ui.lesson.model.ExerciseType
import com.bayaan.ui.theme.BayaanTheme
import com.bayaan.ui.viewmodel.LessonViewModel.Outcome

/** LISTEN_PICK — hear a sound, tap the letter (PRODUCTION_PLAN §4 Unit 1). */
@Composable
fun ListenPickExercise(
    item: ExerciseItem,
    disabled: Set<String>,
    outcome: Outcome?,
    onAnswer: (String) -> Unit,
    onReplay: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        ExerciseInstruction("Which letter did you hear?")
        AudioPromptButton(onReplay)
        OptionsFlow {
            item.options.forEach { opt ->
                OptionButton(
                    label = opt,
                    visual = optionVisual(opt, item.answer, disabled, outcome),
                    arabic = true,
                    onClick = { onAnswer(opt) },
                )
            }
        }
    }
}

@Preview
@Composable
private fun ListenPickPreview() {
    BayaanTheme {
        ListenPickExercise(
            item = ExerciseItem("x", ExerciseType.LISTEN_PICK, 0, promptAsset = "a.ogg", answer = "ب", options = listOf("ب", "ت", "ث", "ن")),
            disabled = emptySet(), outcome = null, onAnswer = {}, onReplay = {},
        )
    }
}
