package com.bayaan.ui.lesson

import android.content.Context
import android.media.MediaPlayer
import android.util.Log

/**
 * Plays a lesson's bundled prompt clips (`assets/content/audio/...`) via MediaPlayer.
 *
 * The ~250 letter clips are a pending human-recording dependency
 * (docs/content/letter-audio-checklist.md), so a missing asset is a **silent no-op**,
 * never a crash — an M2 lesson is fully playable offline before any audio lands.
 */
class LessonAudioPlayer(private val context: Context) {
    private val TAG = "LessonAudioPlayer"
    private var player: MediaPlayer? = null

    /** Play `letters/ba_fatha.ogg` from the content pack. Returns true if a clip actually played. */
    fun play(assetPath: String?): Boolean {
        if (assetPath.isNullOrBlank()) return false
        stop()
        return try {
            val afd = context.assets.openFd("content/audio/$assetPath")
            player = MediaPlayer().apply {
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                setOnCompletionListener { it.release(); if (player === it) player = null }
                prepare()
                start()
            }
            true
        } catch (e: Exception) {
            Log.d(TAG, "clip not bundled yet: $assetPath")
            false
        }
    }

    fun stop() {
        player?.runCatching { release() }
        player = null
    }
}
