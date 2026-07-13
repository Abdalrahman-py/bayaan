package com.bayaan.ui.lesson.exercises

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.unit.dp
import com.bayaan.ui.theme.AmiriFontFamily
import com.bayaan.ui.theme.TerracottaHighlight
import com.bayaan.ui.viewmodel.LessonViewModel.Outcome

/** How a single option should render given the current drill state. */
enum class OptionVisual { IDLE, CORRECT, WRONG, REVEAL, LOCKED }

fun optionVisual(option: String, answer: String?, disabled: Set<String>, outcome: Outcome?): OptionVisual = when {
    outcome == Outcome.CORRECT && option == answer -> OptionVisual.CORRECT
    outcome == Outcome.FAILED && option == answer -> OptionVisual.REVEAL
    option in disabled -> OptionVisual.WRONG
    outcome != null -> OptionVisual.LOCKED
    else -> OptionVisual.IDLE
}

/**
 * One tappable answer. Arabic glyph options render in Amiri; Latin in the body style.
 * Feedback colors reuse the reserved terracotta (wrong) — the one sanctioned non-error
 * use is result feedback (UI_SPEC §1). Correct/reveal use the primary accent.
 */
@Composable
fun OptionButton(
    label: String,
    visual: OptionVisual,
    arabic: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val scheme = MaterialTheme.colorScheme
    val container = when (visual) {
        OptionVisual.CORRECT -> scheme.primary.copy(alpha = 0.16f)
        OptionVisual.WRONG -> TerracottaHighlight.copy(alpha = 0.14f)
        OptionVisual.REVEAL -> scheme.primary.copy(alpha = 0.10f)
        OptionVisual.LOCKED -> scheme.surface.copy(alpha = 0.5f)
        OptionVisual.IDLE -> scheme.surface
    }
    val border = when (visual) {
        OptionVisual.CORRECT, OptionVisual.REVEAL -> scheme.primary
        OptionVisual.WRONG -> TerracottaHighlight
        else -> scheme.onSurface.copy(alpha = 0.15f)
    }
    Surface(
        onClick = onClick,
        enabled = visual == OptionVisual.IDLE,
        shape = RoundedCornerShape(12.dp),
        color = container,
        border = BorderStroke(2.dp, border),
        modifier = modifier.heightIn(min = 56.dp),
    ) {
        Box(contentAlignment = Alignment.Center, modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp)) {
            if (arabic) {
                Text(
                    text = label,
                    fontFamily = AmiriFontFamily,
                    style = MaterialTheme.typography.headlineMedium.copy(textDirection = TextDirection.Rtl),
                    color = MaterialTheme.colorScheme.onSurface,
                    textAlign = TextAlign.Center,
                )
            } else {
                Text(
                    text = label,
                    style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Medium),
                    color = MaterialTheme.colorScheme.onSurface,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

/** Wrap-flow of options — glyph options tile, longer Latin options stack full-width. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun OptionsFlow(content: @Composable () -> Unit) {
    FlowRow(
        modifier = Modifier.fillMaxWidth().wrapContentHeight(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) { content() }
}

internal val ExerciseContentPadding = PaddingValues(horizontal = 20.dp)

/** Large circular replay button for the sound an exercise is testing. */
@Composable
fun AudioPromptButton(onReplay: () -> Unit, modifier: Modifier = Modifier) {
    FilledIconButton(onClick = onReplay, modifier = modifier.size(88.dp)) {
        Icon(Icons.Filled.PlayArrow, contentDescription = "Play the sound", modifier = Modifier.size(40.dp))
    }
}

/** Exercise instruction line. */
@Composable
fun ExerciseInstruction(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleLarge,
        color = MaterialTheme.colorScheme.onBackground,
        modifier = Modifier.fillMaxWidth(),
        textAlign = TextAlign.Center,
    )
}
