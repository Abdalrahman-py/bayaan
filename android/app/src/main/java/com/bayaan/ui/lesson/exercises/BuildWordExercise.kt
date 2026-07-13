package com.bayaan.ui.lesson.exercises

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.bayaan.ui.theme.AmiriFontFamily
import com.bayaan.ui.theme.BayaanTheme

/**
 * BUILD_WORD — assemble a word from glyph pieces in order (§4 Unit 4).
 *
 * Unit 4 is stub-only until M6, so this is @Preview-only. ponytail: tap-to-append,
 * not drag — proves the interaction; the "make it feel great" drag-and-drop polish
 * (§4 Unit 4) is an M6 upgrade when this exercise carries real content.
 */
@Composable
fun BuildWordExercise(
    target: List<String> = listOf("بَ", "تَ"),
) {
    val remaining = remember { mutableStateListOf(*target.shuffled().toTypedArray()) }
    val built = remember { mutableStateListOf<String>() }
    val done = built.size == target.size && built.toList() == target

    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        ExerciseInstruction("Build the word, left to right")
        Row(
            modifier = Modifier.fillMaxWidth().heightIn(min = 72.dp)
                .border(2.dp, MaterialTheme.colorScheme.onSurface.copy(alpha = 0.15f), RoundedCornerShape(12.dp))
                .padding(12.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = built.joinToString(""),
                fontFamily = AmiriFontFamily,
                style = MaterialTheme.typography.displayLarge.copy(textDirection = TextDirection.Rtl),
                color = if (done) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
            )
        }
        OptionsFlow {
            remaining.forEach { piece ->
                OptionButton(
                    label = piece, visual = OptionVisual.IDLE, arabic = true,
                    onClick = { built.add(piece); remaining.remove(piece) },
                )
            }
        }
        if (done) Text("Nicely built", color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.titleLarge)
    }
}

@Preview
@Composable
private fun BuildWordPreview() {
    BayaanTheme { BuildWordExercise() }
}
