package com.bayaan.ui.viewmodel

import android.app.Application
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import androidx.compose.runtime.mutableStateMapOf
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.bayaan.BuildConfig
import com.bayaan.ui.model.BAYYINAH
import com.bayaan.ui.model.FATIHAH
import com.bayaan.ui.model.Mistake
import com.bayaan.ui.model.RecitationUiState
import com.bayaan.ui.model.SifatError
import com.bayaan.ui.model.Verse
import com.bayaan.ui.model.verseFor
import io.ktor.client.HttpClient
import io.ktor.client.engine.cio.CIO
import io.ktor.client.request.forms.MultiPartFormDataContent
import io.ktor.client.request.forms.formData
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.request.header
import io.ktor.client.statement.bodyAsText
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import io.ktor.http.isSuccess
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.ByteArrayOutputStream

/**
 * Drives the recitation demo loop: mic recording, uploading to the backend's
 * /audio/analyze, and mapping its response into RecitationUiState. One state
 * per (sura, aya) so revisiting an ayah doesn't lose its result.
 */
class RecitationViewModel(
    application: Application,
    private val tokenProvider: () -> String?
) : AndroidViewModel(application) {

    class Factory(
        private val application: Application,
        private val tokenProvider: () -> String?
    ) : ViewModelProvider.Factory {
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            if (modelClass.isAssignableFrom(RecitationViewModel::class.java)) {
                @Suppress("UNCHECKED_CAST")
                return RecitationViewModel(application, tokenProvider) as T
            }
            throw IllegalArgumentException("Unknown ViewModel class")
        }
    }

    val uiStates = mutableStateMapOf<Pair<Int, Int>, RecitationUiState>()

    init {
        // Load the full-Quran Uthmani text once so verseFor() resolves any ayah.
        com.bayaan.ui.model.QuranText.ensureLoaded(application)
    }

    private var audioRecord: AudioRecord? = null
    private var recordingJob: Job? = null
    private var timerJob: Job? = null
    private val pcmBuffer = ByteArrayOutputStream()

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

        val minBuf = AudioRecord.getMinBufferSize(SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        if (minBuf <= 0) {
            uiStates[key] = RecitationUiState.Error(verse, "Couldn't start recording. Try again.")
            return
        }

        val ar = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            minBuf * 4,
        )
        if (ar.state != AudioRecord.STATE_INITIALIZED) {
            ar.release()
            uiStates[key] = RecitationUiState.Error(verse, "Couldn't start recording. Try again.")
            return
        }

        try {
            ar.startRecording()
        } catch (e: Exception) {
            ar.release()
            uiStates[key] = RecitationUiState.Error(verse, "Couldn't start recording. Try again.")
            return
        }

        audioRecord = ar
        pcmBuffer.reset()

        recordingJob = viewModelScope.launch(Dispatchers.IO) {
            val chunk = ByteArray(minBuf)
            while (isActive) {
                val n = ar.read(chunk, 0, chunk.size)
                if (n > 0) pcmBuffer.write(chunk, 0, n)
            }
        }

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

        val job = recordingJob
        recordingJob = null
        val ar = audioRecord ?: return
        audioRecord = null

        viewModelScope.launch {
            job?.cancelAndJoin()
            ar.stop()
            ar.release()
            val pcm = pcmBuffer.toByteArray()
            pcmBuffer.reset()
            if (pcm.isEmpty()) {
                uiStates[key] = RecitationUiState.Error(verse, "Recording was too short. Try again.")
                return@launch
            }
            uiStates[key] = RecitationUiState.Uploading(verse)
            uiStates[key] = analyze(buildWav(pcm), sura, aya, verse)
        }
    }

    private suspend fun analyze(wav: ByteArray, sura: Int, aya: Int, verse: Verse): RecitationUiState {
        val token = tokenProvider()
        if (token.isNullOrBlank()) {
            return RecitationUiState.Error(verse, "Please log in again.")
        }
        return try {
            val response = client.post("${BuildConfig.BACKEND_URL}/audio/analyze") {
                header(HttpHeaders.Authorization, "Bearer $token")
                setBody(
                    MultiPartFormDataContent(
                        formData {
                            append(
                                "audio",
                                wav,
                                Headers.build { append(HttpHeaders.ContentDisposition, "filename=\"recitation.wav\"") },
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
        val sifatArr = json.optJSONArray("sifat_errors")
        val sifatErrors = if (sifatArr != null) {
            (0 until sifatArr.length()).map { i -> sifatArr.getJSONObject(i).toSifatError() }
        } else emptyList()
        
        val engineUthmani = json.optString("uthmani")
        val resolvedVerse = if (!engineUthmani.isNullOrBlank()) {
            verse.copy(uthmani = engineUthmani)
        } else {
            verse
        }

        return RecitationUiState.Result(
            verse = resolvedVerse,
            mistakes = mistakes,
            sifatErrors = sifatErrors,
            allCorrect = json.getBoolean("all_correct") && sifatErrors.isEmpty(),
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

    private fun JSONObject.toSifatError() = SifatError(
        phonemesGroup = getString("phonemes_group"),
        attribute     = getString("attribute"),
        predicted     = getString("predicted"),
        expected      = getString("expected"),
        confidence    = if (has("confidence") && !isNull("confidence")) getDouble("confidence").toFloat() else null,
    )

    private fun JSONObject.intOrNull(key: String): Int? =
        if (has(key) && !isNull(key)) getInt(key) else null

    fun retry(sura: Int, aya: Int) {
        uiStates[sura to aya] = RecitationUiState.Ready(verseFor(sura, aya))
    }

    fun nextAyah(sura: Int, aya: Int, onNavigate: (Int, Int) -> Unit) {
        // Real per-surah verse counts from the loaded Quran; fall back to the
        // hardcoded demo counts only if assets aren't loaded (e.g. previews).
        val count = com.bayaan.ui.model.QuranText.verseCount(sura).takeIf { it > 0 }
            ?: (if (sura == 98) BAYYINAH else FATIHAH).second.size
        when {
            aya < count -> onNavigate(sura, aya + 1)
            sura < 114 -> onNavigate(sura + 1, 1)
            else -> onNavigate(1, 1)
        }
    }

    override fun onCleared() {
        audioRecord?.release()
        client.close()
    }

    private fun buildWav(pcm: ByteArray): ByteArray {
        val out = ByteArrayOutputStream(44 + pcm.size)
        out.write("RIFF".toByteArray())
        out.write(le32(36 + pcm.size))
        out.write("WAVE".toByteArray())
        out.write("fmt ".toByteArray())
        out.write(le32(16))
        out.write(le16(1))               // PCM
        out.write(le16(1))               // mono
        out.write(le32(SAMPLE_RATE))
        out.write(le32(SAMPLE_RATE * 2)) // byteRate = sampleRate * blockAlign
        out.write(le16(2))               // blockAlign = channels * bitsPerSample/8
        out.write(le16(16))              // bitsPerSample
        out.write("data".toByteArray())
        out.write(le32(pcm.size))
        out.write(pcm)
        return out.toByteArray()
    }

    private fun le32(v: Int) = byteArrayOf(v.toByte(), (v shr 8).toByte(), (v shr 16).toByte(), (v shr 24).toByte())
    private fun le16(v: Int) = byteArrayOf(v.toByte(), (v shr 8).toByte())

    companion object {
        private const val SAMPLE_RATE = 16_000
    }
}
