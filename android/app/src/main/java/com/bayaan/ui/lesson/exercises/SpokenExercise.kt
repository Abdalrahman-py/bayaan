package com.bayaan.ui.lesson.exercises

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material3.ButtonDefaults
import com.bayaan.ui.theme.TerracottaHighlight
import com.bayaan.ui.lesson.model.ExerciseItem
import com.bayaan.ui.lesson.model.ExerciseType
import com.bayaan.ui.theme.AmiriFontFamily
import com.bayaan.ui.theme.BayaanTheme
import com.bayaan.ui.viewmodel.LessonViewModel.Outcome
import com.bayaan.ui.viewmodel.LessonViewModel.SpeechResult

/**
 * ECHO / READ_ALOUD_SYLLABLE — the learner reads a syllable aloud.
 *
 * M3: replaced the M2 stub with real mic recording + /speech/grade verdict UI.
 * The VM handles AudioRecord + API call; this composable just drives the UI states.
 */
@Composable
fun SpokenExercise(
    item: ExerciseItem,
    outcome: Outcome?,
    isRecording: Boolean = false,
    isGrading: Boolean = false,
    speechResult: SpeechResult? = null,
    onComplete: () -> Unit = {},
    onStartRecording: () -> Unit = {},
    onStopRecording: () -> Unit = {},
    onReplay: () -> Unit = {},
) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        ExerciseInstruction(
            if (item.type == ExerciseType.ECHO) "Say it out loud"
            else "Read it aloud"
        )
        Text(
            text = item.referenceText.orEmpty(),
            fontFamily = AmiriFontFamily,
            fontSize = 88.sp,
            color = MaterialTheme.colorScheme.primary,
            style = MaterialTheme.typography.displayLarge.copy(textDirection = TextDirection.Rtl),
        )
        if (item.promptAsset != null) {
            TextButton(onClick = onReplay) { Text("▶ Hear it") }
        }

        when {
            outcome != null && outcome != Outcome.GRADING -> {
                // Verdict shown
                if (outcome == Outcome.CORRECT) {
                    val hasOtherIssues = speechResult?.issues?.isNotEmpty() ?: false
                    if (hasOtherIssues && item.itemRef.startsWith("tj.")) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("✅ Rule Passed!", style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.primary)
                            Spacer(Modifier.height(4.dp))
                            Text("Also noticed: check other letters for perfect pronunciation.", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    } else {
                        Text("✅ Perfect", style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.primary)
                    }
                } else if (outcome == Outcome.RETRY) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("🔄 Try again", style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.error)
                        speechResult?.feedbackKey?.let { key ->
                            Spacer(Modifier.height(4.dp))
                            Text(feedbackCopy(key), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                } else {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("💪 Keep practicing", style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.error)
                        speechResult?.feedbackKey?.let { key ->
                            Spacer(Modifier.height(4.dp))
                            Text(feedbackCopy(key), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
            }
            isGrading -> {
                CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
                Text("Listening…", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            isRecording -> {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Recording...", style = MaterialTheme.typography.titleMedium, color = TerracottaHighlight)
                    Button(
                        onClick = onStopRecording,
                        colors = ButtonDefaults.buttonColors(containerColor = TerracottaHighlight),
                        modifier = Modifier.fillMaxWidth().height(52.dp)
                    ) {
                        Text("⏹  Stop Recording")
                    }
                }
            }
            outcome == null -> {
                Button(
                    onClick = onStartRecording,
                    modifier = Modifier.fillMaxWidth().height(52.dp),
                ) { Text("🎤  Record") }
            }
        }

        if (outcome == null && !isGrading && !isRecording) {
            Text(
                text = "Tap record, say it, and tap stop when done.",
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Normal),
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
            )
        }
    }
}

private fun feedbackCopy(key: String): String = when (key) {
    "swap_sad_seen" -> "Try making the heavy ص sound instead of س."
    "swap_taa_ta" -> "That's a light ت — try the heavy ط with a deeper tongue."
    "swap_haa_ha" -> "That sounds like ه — ح comes from the middle throat."
    "swap_qaf_kaf" -> "Try ق from the back of the throat, not ك."
    "swap_consonant_other" -> "A consonant didn't come through clearly — try again slower."
    "vowel_mismatch" -> "The vowel sounds a bit off. Hear it once more, then match it."
    "length_short" -> "Hold the sound a little longer."
    "length_long" -> "Keep it shorter — don't stretch it out."
    "light_lam" -> "Try making the ل lighter — less emphasis."
    "missing_ghunnah" -> "Add the nasal hum (ghunnah)."
    "missing_qalqalah" -> "Add the bounce (qalqalah) at the end."
    else -> "Try again — match the sound you heard."
}

@Preview
@Composable
private fun SpokenPreview() {
    BayaanTheme {
        SpokenExercise(
            item = ExerciseItem("x", ExerciseType.ECHO, 1, referenceText = "بَا"),
            outcome = null,
        )
    }
}
