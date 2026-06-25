package com.bayaan.ui.viewmodel

import android.app.Application
import android.media.MediaRecorder
import android.os.Build
import androidx.compose.runtime.mutableStateMapOf
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.bayaan.BuildConfig
import com.bayaan.ui.model.BAYYINAH
import com.bayaan.ui.model.FATIHAH
import com.bayaan.ui.model.Mistake
import com.bayaan.ui.model.RecitationUiState
import com.bayaan.ui.model.Verse
import com.bayaan.ui.model.verseFor
import io.ktor.client.HttpClient
import io.ktor.client.engine.cio.CIO
import io.ktor.client.request.forms.MultiPartFormDataContent
import io.ktor.client.request.forms.formData
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import io.ktor.http.isSuccess
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.File

/**
 * Drives the recitation demo loop: mic recording, uploading to the backend's
 * /audio/analyze, and mapping its response into RecitationUiState. One state
 * per (sura, aya) so revisiting an ayah doesn't lose its result.
 */
class RecitationViewModel(application: Application) : AndroidViewModel(application) {

    val uiStates = mutableStateMapOf<Pair<Int, Int>, RecitationUiState>()

    private var recorder: MediaRecorder? = null
    private var audioFile: File? = null
    private var timerJob: Job? = null

    // Same client + engine the backend uses to call the muaalem engine
    // (backend/.../Routing.kt) — long timeout for the same cold-start reason.
    private val client = HttpClient(CIO) {
        engine { requestTimeout = 60_000 }
    }

    fun stateFor(sura: Int, aya: Int): RecitationUiState =
        uiStates.getOrPut(sura to aya) { RecitationUiState.Ready(verseFor(sura, aya)) }

    fun permissionDenied(sura: Int, aya: Int) {
        uiStates[sura to aya] = RecitationUiState.Error(
            verseFor(sura, aya),
            "Microphone permission is needed to record your recitation.",
        )
    }

    fun record(sura: Int, aya: Int) {
        val key = sura to aya
        val verse = verseFor(sura, aya)
        val context = getApplication<Application>()
        val file = File(context.cacheDir, "recitation_${System.currentTimeMillis()}.m4a")

        val mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        try {
            mediaRecorder.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setOutputFile(file.absolutePath)
                prepare()
                start()
            }
        } catch (e: Exception) {
            uiStates[key] = RecitationUiState.Error(verse, "Couldn't start recording. Try again.")
            return
        }
        recorder = mediaRecorder
        audioFile = file

        timerJob?.cancel()
        timerJob = viewModelScope.launch {
            var elapsed = 0
            while (isActive) {
                uiStates[key] = RecitationUiState.Recording(verse, elapsed)
                delay(1000)
                elapsed++
            }
        }
    }

    fun stop(sura: Int, aya: Int) {
        val key = sura to aya
        val verse = verseFor(sura, aya)
        timerJob?.cancel()
        timerJob = null

        val file = audioFile
        val mediaRecorder = recorder
        recorder = null
        audioFile = null
        if (mediaRecorder == null || file == null) return // wasn't recording

        try {
            mediaRecorder.stop()
        } catch (e: Exception) {
            mediaRecorder.release()
            uiStates[key] = RecitationUiState.Error(verse, "Recording was too short. Try again.")
            return
        }
        mediaRecorder.release()

        uiStates[key] = RecitationUiState.Uploading(verse)
        viewModelScope.launch {
            uiStates[key] = analyze(file, sura, aya, verse)
            file.delete()
        }
    }

    private suspend fun analyze(file: File, sura: Int, aya: Int, verse: Verse): RecitationUiState =
        try {
            val response = client.post("${BuildConfig.BACKEND_URL}/audio/analyze") {
                setBody(
                    MultiPartFormDataContent(
                        formData {
                            append(
                                "audio",
                                file.readBytes(),
                                Headers.build { append(HttpHeaders.ContentDisposition, "filename=\"recitation.m4a\"") },
                            )
                            append("sura", sura.toString())
                            append("aya", aya.toString())
                        },
                    ),
                )
            }
            parseResponse(response, verse)
        } catch (e: Exception) {
            RecitationUiState.Error(verse, "Couldn't reach the coach. Check your connection and try again.")
        }

    private suspend fun parseResponse(response: HttpResponse, verse: Verse): RecitationUiState {
        val text = response.bodyAsText()
        if (!response.status.isSuccess()) {
            val message = runCatching { JSONObject(text).optString("message") }.getOrNull()
            return RecitationUiState.Error(
                verse,
                message?.takeIf { it.isNotBlank() } ?: "The recitation coach couldn't process that. Try again.",
            )
        }
        val json = JSONObject(text)
        val errors = json.getJSONArray("errors")
        val mistakes = (0 until errors.length()).map { i -> errors.getJSONObject(i).toMistake() }
        return RecitationUiState.Result(
            verse = verse,
            mistakes = mistakes,
            allCorrect = json.getBoolean("all_correct"),
        )
    }

    private fun JSONObject.toMistake(): Mistake {
        val pos = getJSONArray("uthmani_pos")
        val rule = optJSONArray("ref_tajweed_rules")
            ?.takeIf { it.length() > 0 }
            ?.getJSONObject(0)
            ?.optJSONObject("name")
        return Mistake(
            charRange = pos.getInt(0) until pos.getInt(1),
            isTajweed = getString("error_type") == "tajweed",
            kind = getString("speech_error_type"),
            ruleNameEn = rule?.optString("en"),
            ruleNameAr = rule?.optString("ar"),
            expectedLen = intOrNull("expected_len"),
            gotLen = intOrNull("predicted_len"),
        )
    }

    private fun JSONObject.intOrNull(key: String): Int? =
        if (has(key) && !isNull(key)) getInt(key) else null

    fun retry(sura: Int, aya: Int) {
        uiStates[sura to aya] = RecitationUiState.Ready(verseFor(sura, aya))
    }

    fun nextAyah(sura: Int, aya: Int, onNavigate: (Int, Int) -> Unit) {
        val (_, verses) = if (sura == 98) BAYYINAH else FATIHAH
        when {
            aya < verses.size -> onNavigate(sura, aya + 1)
            sura == 1 -> onNavigate(98, 1)
            else -> onNavigate(1, 1)
        }
    }

    override fun onCleared() {
        recorder?.release()
        client.close()
    }
}
