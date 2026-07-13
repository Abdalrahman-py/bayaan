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

/** ODD_ONE_OUT — tap the letter that doesn't belong (§4 Unit 1). No audio prompt. */
@Composable
fun OddOneOutExercise(
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
        ExerciseInstruction("Tap the one that doesn't belong")
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
private fun OddOneOutPreview() {
    BayaanTheme {
        OddOneOutExercise(
            item = ExerciseItem("x", ExerciseType.ODD_ONE_OUT, 0, answer = "م", options = listOf("ب", "ت", "ث", "م")),
            disabled = emptySet(), outcome = null, onAnswer = {},
        )
    }
}
