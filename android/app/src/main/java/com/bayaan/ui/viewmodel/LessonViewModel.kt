package com.bayaan.ui.viewmodel

import android.app.Application
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.bayaan.ui.lesson.ContentRepository
import com.bayaan.ui.lesson.LearnApi
import com.bayaan.ui.lesson.LessonAudioPlayer
import com.bayaan.ui.lesson.ProgressStore
import com.bayaan.ui.lesson.model.ExerciseItem
import com.bayaan.ui.lesson.model.ExerciseType
import com.bayaan.ui.lesson.model.Lesson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.ByteArrayOutputStream

/**
 * Drives one lesson: the phase machine Teach → Drill → Wrap, and per-item
 * Prompt → Answer → Feedback → Next (PRODUCTION_PLAN §6, §4.x).
 *
 * Spoken items (ECHO / READ_ALOUD_SYLLABLE) now record real mic audio and
 * call POST /speech/grade (M3). WarmUp is skipped in M2 (no SRS queue until M4
 * reviews are wired). State is hoisted here as mutableStateOf (matching
 * RecitationViewModel); composables stay stateless.
 */
class LessonViewModel(application: Application) : AndroidViewModel(application) {

    class Factory(private val application: Application) : ViewModelProvider.Factory {
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            @Suppress("UNCHECKED_CAST")
            return LessonViewModel(application) as T
        }
    }

    enum class Outcome { CORRECT, FAILED, GRADING, RETRY }

    /** Results held per spoken item — captured from /speech/grade response. */
    data class SpeechResult(
        val verdict: String,
        val score: Double,
        val feedbackKey: String?,
        val issues: List<Map<String, Any>> = emptyList(),
    )

    sealed interface UiState {
        data object Loading : UiState
        data class Missing(val lessonId: String) : UiState
        data class Teach(val lesson: Lesson) : UiState
        data class Drill(
            val lesson: Lesson,
            val index: Int,
            val total: Int,
            val item: ExerciseItem,
            val disabledOptions: Set<String>,
            val outcome: Outcome?,
            val retriesLeft: Int,
            val shakeKey: Int,
            val isPractice: Boolean,
            /** Non-null once a spoken item is graded — shows verdict-specific feedback. */
            val speechResult: SpeechResult? = null,
            /** True while the mic is recording (spoken items only). */
            val isRecording: Boolean = false,
            /** True while the audio is being processed/graded by the server. */
            val isGrading: Boolean = false,
        ) : UiState

        data class Wrap(
            val lesson: Lesson,
            val scorePct: Float,
            val correctCount: Int,
            val total: Int,
            val xpAwarded: Int,
            val totalXp: Int,
            val streak: Int,
            val passed: Boolean,
            val canPractice: Boolean,
            /** True after a successful server sync — marks the wrap as committed. */
            val synced: Boolean = false,
        ) : UiState
    }

    private val progress = ProgressStore(getApplication())
    private val audio = LessonAudioPlayer(getApplication())

    var state by mutableStateOf<UiState>(UiState.Loading)
        private set

    private var audioRecord: AudioRecord? = null
    private var tokenProvider: () -> String? = { null }

    private var recordingJob: Job? = null
    private var recordingTimeoutJob: Job? = null
    private var isRecordingVal = false
    private var isGradingVal = false
    private val pcmBuffer = ByteArrayOutputStream()

    private class Session(
        val lesson: Lesson,
        val items: List<ExerciseItem>,
        val isPractice: Boolean,
    ) {
        var index = 0
        var retriesLeft = MAX_RETRIES
        val disabled = linkedSetOf<String>()
        var outcome: Outcome? = null
        var shakeKey = 0
        val firstTryCorrect = BooleanArray(items.size)
        val wrongItems = mutableListOf<ExerciseItem>()
        val current get() = items[index]
        /** Speech results keyed by item index — populated for spoken items on grade. */
        val speechResults = mutableMapOf<Int, SpeechResult>()
    }

    private var session: Session? = null

    fun load(lessonId: String, tokenProvider: () -> String? = { null }) {
        this.tokenProvider = tokenProvider
        val lesson = ContentRepository.lesson(getApplication(), lessonId)
        state = when {
            lesson == null || lesson.isStub -> UiState.Missing(lessonId)
            lesson.teach != null -> UiState.Teach(lesson)
            else -> { beginDrill(lesson, lesson.items, isPractice = false); state }
        }
    }

    fun startDrill() {
        val lesson = (state as? UiState.Teach)?.lesson ?: return
        beginDrill(lesson, lesson.items, isPractice = false)
    }

    private fun beginDrill(lesson: Lesson, items: List<ExerciseItem>, isPractice: Boolean) {
        session = Session(lesson, items, isPractice)
        emitDrill(playPrompt = true)
    }

    /** Recognition answer (LISTEN_PICK / READ_PICK / DISCRIMINATE / ODD_ONE_OUT). */
    fun answer(option: String) {
        val s = session ?: return
        if (s.outcome != null) return
        val correct = option == s.current.answer
        if (correct) {
            if (s.disabled.isEmpty()) s.firstTryCorrect[s.index] = true
            s.outcome = Outcome.CORRECT
        } else {
            s.disabled += option
            s.shakeKey++
            if (s.current !in s.wrongItems) s.wrongItems += s.current
            if (s.retriesLeft > 0) s.retriesLeft-- else s.outcome = Outcome.FAILED
        }
        emitDrill(playPrompt = false)
    }

    /** Start recording for a spoken (ECHO/READ_ALOUD_SYLLABLE) item. */
    fun startRecording() {
        val s = session ?: return
        if (s.outcome != null) return
        if (!s.current.type.isSpoken) return
        if (isRecordingVal || isGradingVal) return // Prevent concurrent recording/grading

        val minBuf = AudioRecord.getMinBufferSize(SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        if (minBuf <= 0) return

        val ar = AudioRecord(MediaRecorder.AudioSource.MIC, SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, minBuf * 4)
        if (ar.state != AudioRecord.STATE_INITIALIZED) { ar.release(); return }
        
        try {
            ar.startRecording()
        } catch (e: Exception) {
            ar.release()
            return
        }
        
        audioRecord = ar
        pcmBuffer.reset()
        isRecordingVal = true
        isGradingVal = false
        emitDrill(playPrompt = false)

        recordingJob = viewModelScope.launch(Dispatchers.IO) {
            val chunk = ByteArray(minBuf)
            try {
                while (isActive) {
                    val n = ar.read(chunk, 0, chunk.size)
                    if (n > 0) {
                        pcmBuffer.write(chunk, 0, n)
                    } else if (n < 0) {
                        break
                    }
                }
            } catch (e: Exception) {
                // Ignore standard mic-closed errors
            }
        }

        recordingTimeoutJob = viewModelScope.launch {
            delay(4000)
            stopRecording()
        }
    }

    fun stopRecording() {
        if (!isRecordingVal) return
        isRecordingVal = false
        isGradingVal = true

        recordingTimeoutJob?.cancel()
        recordingTimeoutJob = null

        val job = recordingJob
        recordingJob = null

        val ar = audioRecord
        audioRecord = null

        val s = session ?: return
        s.outcome = Outcome.GRADING
        emitDrill(false)

        viewModelScope.launch {
            try {
                ar?.stop()
                job?.cancelAndJoin()
                ar?.release()
            } catch (e: Exception) {
                ar?.release()
            }

            val pcm = pcmBuffer.toByteArray()
            pcmBuffer.reset()

            if (pcm.isEmpty()) {
                isGradingVal = false
                s.outcome = Outcome.FAILED
                emitDrill(false)
                return@launch
            }

            // Grade via /speech/grade
            val wav = buildWav(pcm)
            val api = LearnApi(tokenProvider)
            val refText = s.current.referenceText ?: ""
            val result = api.gradeSpeech(wav, s.current.gradingTier, refText, s.current.itemRef)
            api.close()

            val isTajweed = s.lesson.lessonId.startsWith("tj.")
            val targetIssueTypes = when {
                s.lesson.lessonId.contains("ghunnah") -> listOf("missing_ghunnah")
                s.lesson.lessonId.contains("qalqalah") -> listOf("missing_qalqalah")
                s.lesson.lessonId.contains("madd") -> listOf("length_short", "length_long")
                else -> emptyList()
            }

            val speechResult = if (result != null) {
                var finalVerdict = result.verdict
                if (isTajweed && targetIssueTypes.isNotEmpty()) {
                    val hasTargetViolation = result.phonemeIssues.any {
                        (it["issue_type"] as? String) in targetIssueTypes
                    }
                    finalVerdict = if (hasTargetViolation) "fail" else "pass"
                }
                SpeechResult(
                    verdict = finalVerdict,
                    score = result.score,
                    feedbackKey = result.phonemeIssues.firstOrNull { (it["issue_type"] as? String) in targetIssueTypes }?.get("feedback_key") as? String
                        ?: result.phonemeIssues.firstOrNull()?.get("feedback_key") as? String,
                    issues = result.phonemeIssues
                )
            } else {
                // Network/engine unreachable → fall back to retry
                SpeechResult("retry", 0.0, null, emptyList())
            }

            val correct = speechResult.verdict == "pass"
            if (correct) {
                if (s.disabled.isEmpty()) s.firstTryCorrect[s.index] = true
                s.outcome = Outcome.CORRECT
            } else {
                if (s.current !in s.wrongItems) s.wrongItems += s.current
                s.outcome = if (speechResult.verdict == "retry") Outcome.RETRY else Outcome.FAILED
            }
            s.speechResults[s.index] = speechResult
            isGradingVal = false
            emitDrill(false)
        }
    }

    fun replayPrompt() {
        audio.play(session?.current?.promptAsset)
    }

    fun next() {
        val s = session ?: return
        if (s.outcome == Outcome.GRADING || isGradingVal) return // wait for grade to finish
        if (s.outcome == null) return
        // RETRY means try again — reset outcome so user can re-record
        if (s.outcome == Outcome.RETRY) { s.outcome = null; emitDrill(false); return }
        if (s.index < s.items.lastIndex) {
            s.index++
            s.retriesLeft = MAX_RETRIES
            s.disabled.clear()
            s.outcome = null
            emitDrill(playPrompt = true)
        } else {
            finish(s)
        }
    }

    private fun finish(s: Session) {
        audio.stop()
        val correct = s.firstTryCorrect.count { it }
        val total = s.items.size
        val scorePct = if (total == 0) 0f else correct.toFloat() / total

        if (s.isPractice) {
            state = UiState.Wrap(s.lesson, scorePct, correct, total, 0, progress.xp(), progress.streak(), passed = true, canPractice = false)
            return
        }

        val result = progress.recordAttempt(s.lesson.lessonId, s.lesson.isCheckpoint, scorePct)

        // Fire-and-forget server sync
        viewModelScope.launch(Dispatchers.IO) {
            val api = LearnApi(tokenProvider)
            api.complete(
                s.lesson.lessonId, scorePct.toDouble(), s.lesson.isCheckpoint,
                s.items.mapIndexed { i, item ->
                    val isCorrect = s.firstTryCorrect[i]
                    LearnApi.ItemResult(item.itemRef, isCorrect, isCorrect && (i !in s.speechResults.keys || s.speechResults[i]?.verdict == "pass"))
                },
            )
            api.close()
        }

        state = UiState.Wrap(
            lesson = s.lesson,
            scorePct = scorePct,
            correctCount = correct,
            total = total,
            xpAwarded = result.xpAwarded,
            totalXp = result.totalXp,
            streak = result.streak,
            passed = result.passed,
            canPractice = s.lesson.isCheckpoint && !result.passed,
            synced = true,
        )
    }

    /** Failed-checkpoint remedy: re-drill the missed items (pure client logic, §4.x). */
    fun startPractice() {
        val s = session ?: return
        val practiceItems = s.wrongItems.ifEmpty { s.items }
        beginDrill(s.lesson, practiceItems, isPractice = true)
    }

    private fun emitDrill(playPrompt: Boolean) {
        val s = session ?: return
        val item = s.current
        val speechResult = s.speechResults[s.index]
        state = UiState.Drill(
            lesson = s.lesson,
            index = s.index,
            total = s.items.size,
            item = item,
            disabledOptions = s.disabled.toSet(),
            outcome = s.outcome,
            retriesLeft = s.retriesLeft,
            shakeKey = s.shakeKey,
            isPractice = s.isPractice,
            speechResult = speechResult,
            isRecording = isRecordingVal,
            isGrading = isGradingVal,
        )
        // Auto-play the sound the learner must identify.
        if (playPrompt && (item.type == ExerciseType.LISTEN_PICK || item.type == ExerciseType.DISCRIMINATE)) {
            audio.play(item.promptAsset)
        }
    }

    private fun tokenProvider(): () -> String? = {
        val prefs = getApplication<Application>().getSharedPreferences("supabase_session", 0)
        prefs.getString("access_token", null)
    }

    override fun onCleared() {
        recordingTimeoutJob?.cancel()
        recordingJob?.cancel()
        audioRecord?.release()
        audio.stop()
    }

    companion object {
        private const val MAX_RETRIES = 2
        private const val SAMPLE_RATE = 16_000
    }
}

@PublishedApi
internal fun buildWav(pcm: ByteArray): ByteArray {
    val out = ByteArrayOutputStream(44 + pcm.size)
    out.write("RIFF".toByteArray())
    out.write(le32(36 + pcm.size))
    out.write("WAVE".toByteArray())
    out.write("fmt ".toByteArray())
    out.write(le32(16))
    out.write(le16(1))
    out.write(le16(1))
    out.write(le32(16_000))
    out.write(le32(16_000 * 2))
    out.write(le16(2))
    out.write(le16(16))
    out.write("data".toByteArray())
    out.write(le32(pcm.size))
    out.write(pcm)
    return out.toByteArray()
}

private fun le32(v: Int) = byteArrayOf(v.toByte(), (v shr 8).toByte(), (v shr 16).toByte(), (v shr 24).toByte())
private fun le16(v: Int) = byteArrayOf(v.toByte(), (v shr 8).toByte())
