package com.bayaan.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.shape.RoundedCornerShape
import com.bayaan.ui.feedback.Haptic
import com.bayaan.ui.feedback.Sfx
import com.bayaan.ui.feedback.rememberHaptics
import com.bayaan.ui.feedback.rememberSoundEffects
import com.bayaan.ui.lesson.WrapScreen
import com.bayaan.ui.lesson.exercises.DiscriminateExercise
import com.bayaan.ui.lesson.exercises.ListenPickExercise
import com.bayaan.ui.lesson.exercises.OddOneOutExercise
import com.bayaan.ui.lesson.exercises.ReadPickExercise
import com.bayaan.ui.lesson.exercises.SpokenExercise
import com.bayaan.ui.lesson.model.ExerciseType
import com.bayaan.ui.lesson.model.Lesson
import com.bayaan.ui.motion.gentleShake
import com.bayaan.ui.theme.AmiriFontFamily
import androidx.compose.material3.ButtonDefaults
import androidx.compose.runtime.remember
import com.bayaan.ui.lesson.LessonAudioPlayer
import com.bayaan.ui.theme.TerracottaHighlight
import com.bayaan.ui.viewmodel.LessonViewModel
import com.bayaan.ui.viewmodel.LessonViewModel.Outcome
import com.bayaan.ui.viewmodel.LessonViewModel.UiState

/**
 * The lesson player — one screen driven by [LessonViewModel]'s phase machine
 * (PRODUCTION_PLAN §6). Stateless: all state in, all actions out as lambdas.
 */
@Composable
fun LessonScreen(
    state: UiState,
    onStartDrill: () -> Unit,
    onAnswer: (String) -> Unit,
    onCompleteSpoken: () -> Unit,
    onStartRecording: () -> Unit = {},
    onStopRecording: () -> Unit = {},
    onReplay: () -> Unit,
    onNext: () -> Unit,
    onStartPractice: () -> Unit,
    onExit: () -> Unit,
) {
    when (state) {
        UiState.Loading -> Centered { CircularProgressIndicator(color = MaterialTheme.colorScheme.primary) }
        is UiState.Missing -> MissingContent(onExit)
        is UiState.Teach -> TeachContent(state.lesson, onStartDrill, onExit)
        is UiState.Drill -> DrillContent(state, onAnswer, onCompleteSpoken, onStartRecording, onStopRecording, onReplay, onNext, onExit)
        is UiState.Wrap -> WrapScreen(state, onContinue = onExit, onPractice = onStartPractice)
    }
}

@Composable
private fun Centered(content: @Composable () -> Unit) {
    Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) { content() }
}

@Composable
private fun LessonTopBar(progress: Float?, onExit: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = onExit) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Exit lesson")
        }
        if (progress != null) {
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier.weight(1f).padding(horizontal = 12.dp),
                color = MaterialTheme.colorScheme.primary,
            )
        } else {
            Spacer(Modifier.weight(1f))
        }
    }
}

@Composable
private fun MissingContent(onExit: () -> Unit) {
    Column(Modifier.fillMaxSize()) {
        LessonTopBar(progress = null, onExit = onExit)
        Column(Modifier.fillMaxSize().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Text("This lesson isn't ready yet", style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.onBackground)
            Spacer(Modifier.height(8.dp))
            Text("It's coming in a future update. Try another lesson on your path.",
                style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f), textAlign = TextAlign.Center)
            Spacer(Modifier.height(24.dp))
            Button(onClick = onExit) { Text("Back to path") }
        }
    }
}

@Composable
private fun TeachContent(lesson: Lesson, onStart: () -> Unit, onExit: () -> Unit) {
    val isTajweed = lesson.teach?.ruleNameEn != null
    Column(Modifier.fillMaxSize()) {
        LessonTopBar(progress = null, onExit = onExit)
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(8.dp))
            Text(lesson.titleEn, style = MaterialTheme.typography.headlineMedium, color = MaterialTheme.colorScheme.onBackground)
            Spacer(Modifier.height(20.dp))
            
            if (isTajweed) {
                val teach = lesson.teach
                Text(
                    text = "${teach.ruleNameEn} (${teach.ruleNameAr})",
                    style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                    color = MaterialTheme.colorScheme.primary
                )
                Spacer(Modifier.height(16.dp))
                Text(
                    text = teach.glyphs.joinToString("  "),
                    fontFamily = AmiriFontFamily, fontSize = 64.sp,
                    color = MaterialTheme.colorScheme.primary,
                    style = MaterialTheme.typography.displayLarge.copy(textDirection = TextDirection.Rtl),
                    textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(16.dp))
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    elevation = CardDefaults.cardElevation(2.dp),
                ) {
                    Column(Modifier.padding(20.dp)) {
                        Text(teach.narrationEn, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurface)
                        
                        val context = androidx.compose.ui.platform.LocalContext.current
                        val player = remember { LessonAudioPlayer(context) }
                        
                        Spacer(Modifier.height(16.dp))
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                            if (!teach.audioCorrect.isNullOrBlank()) {
                                Button(
                                    onClick = { player.play(teach.audioCorrect) },
                                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
                                ) {
                                    Text("🔊 Correct")
                                }
                            }
                            if (!teach.audioIncorrect.isNullOrBlank()) {
                                Button(
                                    onClick = { player.play(teach.audioIncorrect) },
                                    colors = ButtonDefaults.buttonColors(containerColor = TerracottaHighlight)
                                ) {
                                    Text("🔊 Incorrect")
                                }
                            }
                        }
                    }
                }
            } else {
                lesson.teach?.let { teach ->
                    Text(
                        text = teach.glyphs.joinToString("  "),
                        fontFamily = AmiriFontFamily, fontSize = 64.sp,
                        color = MaterialTheme.colorScheme.primary,
                        style = MaterialTheme.typography.displayLarge.copy(textDirection = TextDirection.Rtl),
                        textAlign = TextAlign.Center,
                    )
                    Spacer(Modifier.height(24.dp))
                    Card(
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                        elevation = CardDefaults.cardElevation(2.dp),
                    ) {
                        Text(teach.narrationEn, style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurface, modifier = Modifier.padding(20.dp))
                    }
                    teach.focusEn?.let {
                        Spacer(Modifier.height(12.dp))
                        Text(it, style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                            color = MaterialTheme.colorScheme.primary, textAlign = TextAlign.Center)
                    }
                }
            }
            Spacer(Modifier.height(32.dp))
            Button(onClick = onStart, modifier = Modifier.fillMaxWidth().height(52.dp)) { Text("Start") }
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun DrillContent(
    drill: UiState.Drill,
    onAnswer: (String) -> Unit,
    onCompleteSpoken: () -> Unit,
    onStartRecording: () -> Unit = {},
    onStopRecording: () -> Unit = {},
    onReplay: () -> Unit,
    onNext: () -> Unit,
    onExit: () -> Unit,
) {
    val haptics = rememberHaptics()
    val sfx = rememberSoundEffects()

    // Wrong-answer feedback: shake key bumps on every wrong pick.
    LaunchedEffect(drill.shakeKey) {
        if (drill.shakeKey > 0) { sfx.play(Sfx.Incorrect); haptics.play(Haptic.Tick) }
    }
    // Item outcome feedback: fires once per item when it resolves.
    LaunchedEffect(drill.item.itemRef, drill.outcome) {
        when (drill.outcome) {
            Outcome.CORRECT -> { sfx.play(Sfx.Correct); haptics.play(Haptic.Confirm) }
            Outcome.FAILED -> sfx.play(Sfx.Incorrect)
            null -> {}
            else -> {}
        }
    }

    Column(Modifier.fillMaxSize()) {
        LessonTopBar(progress = (drill.index + 1f) / drill.total, onExit = onExit)
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).gentleShake(drill.shakeKey),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(24.dp))
            when (drill.item.type) {
                ExerciseType.LISTEN_PICK -> ListenPickExercise(drill.item, drill.disabledOptions, drill.outcome, onAnswer, onReplay)
                ExerciseType.DISCRIMINATE -> DiscriminateExercise(drill.item, drill.disabledOptions, drill.outcome, onAnswer, onReplay)
                ExerciseType.ODD_ONE_OUT -> OddOneOutExercise(drill.item, drill.disabledOptions, drill.outcome, onAnswer)
                ExerciseType.READ_PICK -> ReadPickExercise(drill.item, drill.disabledOptions, drill.outcome, onAnswer)
                ExerciseType.ECHO, ExerciseType.READ_ALOUD_SYLLABLE ->
                    SpokenExercise(
                        item = drill.item,
                        outcome = drill.outcome,
                        isRecording = drill.isRecording,
                        isGrading = drill.isGrading,
                        speechResult = drill.speechResult,
                        onComplete = onCompleteSpoken,
                        onStartRecording = onStartRecording,
                        onStopRecording = onStopRecording,
                        onReplay = onReplay,
                    )
            }
            Spacer(Modifier.height(32.dp))
            if (drill.outcome != null) {
                Button(onClick = onNext, modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp).height(52.dp)) {
                    Text(if (drill.index == drill.total - 1) "See results" else "Continue")
                }
            }
            Spacer(Modifier.height(24.dp))
        }
    }
}
