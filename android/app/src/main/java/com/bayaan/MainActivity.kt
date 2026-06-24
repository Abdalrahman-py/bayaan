package com.bayaan

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.lifecycleScope
import com.bayaan.ui.model.BAYYINAH
import com.bayaan.ui.model.FATIHAH
import com.bayaan.ui.model.Mistake
import com.bayaan.ui.model.RecitationUiState
import com.bayaan.ui.model.Verse
import com.bayaan.ui.navigation.BayaanNavGraph
import com.bayaan.ui.theme.BayaanTheme
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    // Store UI states for each (sura, aya) pair in memory for the prototype simulation
    private val uiStates = mutableStateMapOf<Pair<Int, Int>, RecitationUiState>()
    
    // Active recording timer jobs
    private var timerJobs = mutableMapOf<Pair<Int, Int>, Job>()
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState);
        
        setContent {
            BayaanTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = androidx.compose.material3.MaterialTheme.colorScheme.background
                ) {
                    BayaanNavGraph(
                        currentScreenState = { sura, aya ->
                            getOrCreateUiState(sura, aya)
                        },
                        onRecord = { sura, aya -> startRecording(sura, aya) },
                        onStop = { sura, aya -> stopRecording(sura, aya) },
                        onTryAgain = { sura, aya -> resetToReady(sura, aya) },
                        onNextAyah = { sura, aya, onNavigate -> navigateToNext(sura, aya, onNavigate) },
                        onRetry = { sura, aya -> resetToReady(sura, aya) }
                    )
                }
            }
        }
    }

    private fun getOrCreateUiState(sura: Int, aya: Int): RecitationUiState {
        val key = Pair(sura, aya)
        if (!uiStates.containsKey(key)) {
            val verse = getVerseData(sura, aya)
            uiStates[key] = RecitationUiState.Ready(verse)
        }
        return uiStates[key]!!
    }

    private fun getVerseData(sura: Int, aya: Int): Verse {
        val (surahNameAr, versesList) = if (sura == 98) BAYYINAH else FATIHAH
        val surahNameEn = if (sura == 98) "Al-Bayyinah" else "Al-Fatihah"
        val uthmaniText = try {
            versesList[aya - 1]
        } catch (e: Exception) {
            "بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ"
        }
        return Verse(sura, aya, surahNameEn, surahNameAr, uthmaniText)
    }

    private fun startRecording(sura: Int, aya: Int) {
        val key = Pair(sura, aya)
        val verse = getVerseData(sura, aya)
        
        // Start incrementing timer
        timerJobs[key]?.cancel()
        val job = lifecycleScope.launch {
            var elapsed = 0
            while (true) {
                uiStates[key] = RecitationUiState.Recording(verse, elapsed)
                delay(1000)
                elapsed++
            }
        }
        timerJobs[key] = job
    }

    private fun stopRecording(sura: Int, aya: Int) {
        val key = Pair(sura, aya)
        val verse = getVerseData(sura, aya)
        
        // Cancel timer
        timerJobs[key]?.cancel()
        timerJobs.remove(key)
        
        // Move to uploading
        uiStates[key] = RecitationUiState.Uploading(verse)
        
        // Simulate network analysis delay
        lifecycleScope.launch {
            delay(2000)
            
            // For Al-Fatihah Ayah 1 (Bismillah) or Al-Bayyinah Ayah 3, make it 100% correct
            val isPerfect = (sura == 1 && aya == 1) || (sura == 98 && aya == 3)
            
            if (isPerfect) {
                uiStates[key] = RecitationUiState.Result(
                    verse = verse,
                    mistakes = emptyList(),
                    allCorrect = true
                )
            } else {
                // Generate simulated mistakes based on the verse
                val mistakes = generateSimulatedMistakes(sura, aya)
                uiStates[key] = RecitationUiState.Result(
                    verse = verse,
                    mistakes = mistakes,
                    allCorrect = false
                )
            }
        }
    }

    private fun resetToReady(sura: Int, aya: Int) {
        val key = Pair(sura, aya)
        uiStates[key] = RecitationUiState.Ready(getVerseData(sura, aya))
    }

    private fun navigateToNext(sura: Int, aya: Int, onNavigate: (Int, Int) -> Unit) {
        val (_, currentVerses) = if (sura == 98) BAYYINAH else FATIHAH
        
        if (aya < currentVerses.size) {
            // Next ayah in same Surah
            onNavigate(sura, aya + 1)
        } else if (sura == 1) {
            // End of Fatihah -> Move to Bayyinah Ayah 1
            onNavigate(98, 1)
        } else {
            // End of Bayyinah -> Loop back to Fatihah Ayah 1
            onNavigate(1, 1)
        }
    }

    private fun generateSimulatedMistakes(sura: Int, aya: Int): List<Mistake> {
        // Return structured mistakes for demo
        return when (sura) {
            1 -> {
                when (aya) {
                    2 -> listOf(
                        Mistake(
                            charRange = 10..13, // "لِلَّهِ"
                            isTajweed = true,
                            kind = "replace",
                            ruleNameEn = "Madd Aarid",
                            ruleNameAr = "المد العارض للسكون",
                            expectedLen = 4,
                            gotLen = 2
                        ),
                        Mistake(
                            charRange = 0..7, // "ٱلْحَمْدُ"
                            isTajweed = false,
                            kind = "delete",
                            ruleNameEn = null,
                            ruleNameAr = null,
                            expectedLen = null,
                            gotLen = null
                        )
                    )
                    3 -> listOf(
                        Mistake(
                            charRange = 14..19, // "ٱلرَّحِيمِ"
                            isTajweed = true,
                            kind = "replace",
                            ruleNameEn = "Madd Aarid",
                            ruleNameAr = "المد العارض للسكون",
                            expectedLen = 4,
                            gotLen = 1
                        )
                    )
                    else -> listOf(
                        Mistake(
                            charRange = 0..4,
                            isTajweed = false,
                            kind = "replace",
                            ruleNameEn = null,
                            ruleNameAr = null,
                            expectedLen = null,
                            gotLen = null
                        )
                    )
                }
            }
            98 -> {
                when (aya) {
                    1 -> listOf(
                        Mistake(
                            charRange = 54..60, // "مُنفَكِّينَ" (Ikhfa rule)
                            isTajweed = true,
                            kind = "replace",
                            ruleNameEn = "Ikhfa",
                            ruleNameAr = "الإخفاء الحقيقي",
                            expectedLen = 2,
                            gotLen = 0
                        )
                    )
                    2 -> listOf(
                        Mistake(
                            charRange = 8..14, // "مِّنَ ٱللَّهِ" (Idgham rule)
                            isTajweed = true,
                            kind = "replace",
                            ruleNameEn = "Idgham Bighunnah",
                            ruleNameAr = "الإدغام بغنة",
                            expectedLen = 2,
                            gotLen = 0
                        )
                    )
                    else -> listOf(
                        Mistake(
                            charRange = 5..10,
                            isTajweed = false,
                            kind = "replace",
                            ruleNameEn = null,
                            ruleNameAr = null,
                            expectedLen = null,
                            gotLen = null
                        )
                    )
                }
            }
            else -> emptyList()
        }
    }
}
