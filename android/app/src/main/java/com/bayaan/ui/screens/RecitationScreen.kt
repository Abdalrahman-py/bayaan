package com.bayaan.ui.screens

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bayaan.ui.components.VerseText
import com.bayaan.ui.model.Mistake
import com.bayaan.ui.model.RecitationUiState
import com.bayaan.ui.model.previewMistakes
import com.bayaan.ui.model.previewVerse
import com.bayaan.ui.theme.BayaanTheme
import com.bayaan.ui.theme.AmiriFontFamily
import com.bayaan.ui.theme.PlainErrorBackgroundDark
import com.bayaan.ui.theme.PlainErrorBackgroundLight
import com.bayaan.ui.theme.PlainErrorHighlight
import com.bayaan.ui.theme.TerracottaBackgroundDark
import com.bayaan.ui.theme.TerracottaBackgroundLight
import com.bayaan.ui.theme.TerracottaHighlight

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecitationScreen(
    state: RecitationUiState,
    onRecord: () -> Unit,
    onStop: () -> Unit,
    onTryAgain: () -> Unit,
    onNextAyah: () -> Unit,
    onRetry: () -> Unit,
    onPickAyah: () -> Unit,
    modifier: Modifier = Modifier
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = state.verse.surahNameEn,
                            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold)
                        )
                        Text(
                            text = "Verse ${state.verse.aya}",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f)
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onPickAyah) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back to verses"
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                    titleContentColor = MaterialTheme.colorScheme.onBackground
                )
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 20.dp)
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            Spacer(modifier = Modifier.height(8.dp))

            // Verse Card
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(24.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surface
                ),
                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    val highlights = if (state is RecitationUiState.Result) {
                        state.mistakes.map { it.charRange }
                    } else {
                        emptyList()
                    }

                    VerseText(
                        uthmani = state.verse.uthmani,
                        highlights = highlights
                    )
                }
            }

            // Dynamic State Control Section
            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.Center
            ) {
                when (state) {
                    is RecitationUiState.Ready -> ReadyControls(onRecord = onRecord)
                    is RecitationUiState.Recording -> RecordingControls(
                        elapsedSec = state.elapsedSec,
                        onStop = onStop
                    )
                    is RecitationUiState.Uploading -> UploadingControls()
                    is RecitationUiState.Result -> ResultControls(
                        verse = state.verse,
                        mistakes = state.mistakes,
                        allCorrect = state.allCorrect,
                        onTryAgain = onTryAgain,
                        onNextAyah = onNextAyah
                    )
                    is RecitationUiState.Error -> ErrorControls(
                        message = state.message,
                        onRetry = onRetry
                    )
                }
            }

            Spacer(modifier = Modifier.height(32.dp))
        }
    }
}

@Composable
private fun ReadyControls(onRecord: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
        modifier = Modifier.padding(vertical = 16.dp)
    ) {
        // Microphone Record Button
        Box(
            modifier = Modifier
                .size(96.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.primary)
                .clickable { onRecord() },
            contentAlignment = Alignment.Center
        ) {
            // Simulated micro-animation on hover/tap could go here, basic layout is a clean Mic Icon
            Icon(
                painter = painterResource(id = android.R.drawable.ic_btn_speak_now), // Default Android Mic Resource
                contentDescription = "Record Recitation",
                tint = MaterialTheme.colorScheme.onPrimary,
                modifier = Modifier.size(40.dp)
            )
        }
        Text(
            text = "Tap to Record",
            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
            color = MaterialTheme.colorScheme.primary
        )
        Text(
            text = "Recite clearly at a moderate pace",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.5f)
        )
    }
}

@Composable
private fun RecordingControls(elapsedSec: Int, onStop: () -> Unit) {
    // Pulse animation for recording indicators
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1.0f,
        targetValue = 1.2f,
        animationSpec = infiniteRepeatable(
            animation = tween(1000, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "scale"
    )

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
        modifier = Modifier.padding(vertical = 16.dp)
    ) {
        // Digital Timer
        val minutes = elapsedSec / 60
        val seconds = elapsedSec % 60
        val timerString = String.format("%02d:%02d", minutes, seconds)

        Text(
            text = timerString,
            style = MaterialTheme.typography.displayLarge.copy(fontWeight = FontWeight.Black),
            color = TerracottaHighlight
        )

        // Pulsing Stop Button
        Box(
            modifier = Modifier
                .size(96.dp)
                .scale(pulseScale)
                .clip(CircleShape)
                .background(TerracottaHighlight.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) {
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .clip(CircleShape)
                    .background(TerracottaHighlight)
                    .clickable { onStop() },
                contentAlignment = Alignment.Center
            ) {
                // Square icon for Stop
                Box(
                    modifier = Modifier
                        .size(24.dp)
                        .background(Color.White, RoundedCornerShape(4.dp))
                )
            }
        }

        Text(
            text = "Recording...",
            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
            color = TerracottaHighlight
        )
    }
}

@Composable
private fun UploadingControls() {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
        modifier = Modifier.padding(vertical = 24.dp)
    ) {
        CircularProgressIndicator(
            color = MaterialTheme.colorScheme.primary,
            strokeWidth = 4.dp,
            modifier = Modifier.size(56.dp)
        )
        Text(
            text = "Analyzing recitation...",
            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
            color = MaterialTheme.colorScheme.onBackground
        )
        Text(
            text = "Running AI Tajweed analysis",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.5f)
        )
    }
}

@Composable
private fun ResultControls(
    verse: com.bayaan.ui.model.Verse,
    mistakes: List<Mistake>,
    allCorrect: Boolean,
    onTryAgain: () -> Unit,
    onNextAyah: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        // Verdict Card
        VerdictHeader(allCorrect = allCorrect, mistakeCount = mistakes.size)

        // Mistakes list if they exist
        if (!allCorrect && mistakes.isNotEmpty()) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = "Pronunciation Feedback",
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    color = MaterialTheme.colorScheme.onBackground
                )
                
                mistakes.forEach { mistake ->
                    MistakeCard(mistake = mistake, verseText = verse.uthmani)
                }
            }
        }

        // Action Buttons Row
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            OutlinedButton(
                onClick = onTryAgain,
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier
                    .weight(1f)
                    .height(52.dp),
                border = ButtonDefaults.outlinedButtonBorder.copy(
                    width = 2.dp
                ),
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = MaterialTheme.colorScheme.primary
                )
            ) {
                Icon(imageVector = Icons.Default.Refresh, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text(text = "Try Again", fontWeight = FontWeight.Bold)
            }

            Button(
                onClick = onNextAyah,
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier
                    .weight(1f)
                    .height(52.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primary
                )
            ) {
                Icon(imageVector = Icons.Default.PlayArrow, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text(text = "Next Ayah", fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun VerdictHeader(allCorrect: Boolean, mistakeCount: Int) {
    val cardColor = if (allCorrect) {
        MaterialTheme.colorScheme.primary.copy(alpha = 0.08f)
    } else {
        TerracottaHighlight.copy(alpha = 0.08f)
    }

    val contentColor = if (allCorrect) {
        MaterialTheme.colorScheme.primary
    } else {
        TerracottaHighlight
    }

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = cardColor),
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = if (allCorrect) Icons.Default.CheckCircle else Icons.Default.Warning,
                contentDescription = null,
                tint = contentColor,
                modifier = Modifier.size(32.dp)
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column {
                Text(
                    text = if (allCorrect) "Perfect Recitation!" else "Tajweed Focus Needed",
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    color = contentColor
                )
                Text(
                    text = if (allCorrect) "All rules applied correctly." else "Detected $mistakeCount items to refine.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.7f)
                )
            }
        }
    }
}

@Composable
private fun MistakeCard(mistake: Mistake, verseText: String) {
    val isDark = androidx.compose.foundation.isSystemInDarkTheme()
    
    val (cardBg, brandColor, errorTitle) = if (mistake.isTajweed) {
        Triple(
            if (isDark) TerracottaBackgroundDark else TerracottaBackgroundLight,
            TerracottaHighlight,
            "Tajweed Rule Error"
        )
    } else {
        Triple(
            if (isDark) PlainErrorBackgroundDark else PlainErrorBackgroundLight,
            PlainErrorHighlight,
            "Pronunciation Error"
        )
    }

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = cardBg),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Rule name or title
                Text(
                    text = mistake.ruleNameEn ?: errorTitle,
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    color = brandColor
                )

                // Arabic rule name if available
                if (mistake.ruleNameAr != null) {
                    Text(
                        text = mistake.ruleNameAr,
                        fontFamily = AmiriFontFamily,
                        fontSize = 18.sp,
                        color = brandColor
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Text excerpt
            val snippet = try {
                val start = mistake.charRange.first
                val end = mistake.charRange.last + 1
                verseText.substring(start, end)
            } catch (e: Exception) {
                "Text segment"
            }

            Text(
                text = "Recited text: \"$snippet\"",
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.8f)
            )

            // Length comparisons
            if (mistake.expectedLen != null && mistake.gotLen != null) {
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "Timing: Expected ${mistake.expectedLen} counts, but recited for ${mistake.gotLen}.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                )
            }

            // Explanation depending on kind
            Spacer(modifier = Modifier.height(4.dp))
            val explanation = when (mistake.kind) {
                "replace" -> "The diacritic or pronunciation was substituted with another sound."
                "delete" -> "A required sound or letter was skipped entirely."
                "insert" -> "An extra sound or letter was incorrectly inserted."
                else -> "Check pronunciation alignment."
            }
            Text(
                text = explanation,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
            )
        }
    }
}

@Composable
private fun ErrorControls(message: String, onRetry: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 24.dp)
    ) {
        Icon(
            imageVector = Icons.Default.Info,
            contentDescription = null,
            tint = TerracottaHighlight,
            modifier = Modifier.size(48.dp)
        )
        Text(
            text = "Recitation Analysis Failed",
            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
            color = MaterialTheme.colorScheme.onBackground
        )
        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(8.dp))
        Button(
            onClick = onRetry,
            shape = RoundedCornerShape(12.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = MaterialTheme.colorScheme.primary
            ),
            modifier = Modifier.height(48.dp)
        ) {
            Icon(imageVector = Icons.Default.Refresh, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text(text = "Retry", fontWeight = FontWeight.Bold)
        }
    }
}

// Previews for all states
@Preview(showBackground = true, name = "State Ready")
@Composable
fun RecitationScreenReadyPreview() {
    BayaanTheme {
        RecitationScreen(
            state = RecitationUiState.Ready(previewVerse),
            onRecord = {}, onStop = {}, onTryAgain = {}, onNextAyah = {}, onRetry = {}, onPickAyah = {}
        )
    }
}

@Preview(showBackground = true, name = "State Recording")
@Composable
fun RecitationScreenRecordingPreview() {
    BayaanTheme {
        RecitationScreen(
            state = RecitationUiState.Recording(previewVerse, elapsedSec = 4),
            onRecord = {}, onStop = {}, onTryAgain = {}, onNextAyah = {}, onRetry = {}, onPickAyah = {}
        )
    }
}

@Preview(showBackground = true, name = "State Uploading")
@Composable
fun RecitationScreenUploadingPreview() {
    BayaanTheme {
        RecitationScreen(
            state = RecitationUiState.Uploading(previewVerse),
            onRecord = {}, onStop = {}, onTryAgain = {}, onNextAyah = {}, onRetry = {}, onPickAyah = {}
        )
    }
}

@Preview(showBackground = true, name = "State Result - Mistakes")
@Composable
fun RecitationScreenResultPreview() {
    BayaanTheme {
        RecitationScreen(
            state = RecitationUiState.Result(previewVerse, previewMistakes, allCorrect = false),
            onRecord = {}, onStop = {}, onTryAgain = {}, onNextAyah = {}, onRetry = {}, onPickAyah = {}
        )
    }
}

@Preview(showBackground = true, name = "State Result - Perfect")
@Composable
fun RecitationScreenResultPerfectPreview() {
    BayaanTheme {
        RecitationScreen(
            state = RecitationUiState.Result(previewVerse, emptyList(), allCorrect = true),
            onRecord = {}, onStop = {}, onTryAgain = {}, onNextAyah = {}, onRetry = {}, onPickAyah = {}
        )
    }
}

@Preview(showBackground = true, name = "State Error")
@Composable
fun RecitationScreenErrorPreview() {
    BayaanTheme {
        RecitationScreen(
            state = RecitationUiState.Error(previewVerse, "Could not reach the coach. Please check your connection."),
            onRecord = {}, onStop = {}, onTryAgain = {}, onNextAyah = {}, onRetry = {}, onPickAyah = {}
        )
    }
}
