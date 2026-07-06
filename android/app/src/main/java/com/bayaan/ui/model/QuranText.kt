package com.bayaan.ui.model

import android.content.Context
import com.bayaan.ui.mushaf.QcfRepository
import org.json.JSONObject

/**
 * Full-Quran Uthmani text (all 6236 ayat) + surah names, loaded once from
 * bundled assets. Text is dumped from the same `quranic_phonemizer` DB the
 * recitation engine derives its uthmani from, so it matches the app's original
 * hardcoded Fatihah/Bayyinah glyphs (differences are combining-mark order only,
 * which renders identically). Char-level highlight positions still align because
 * RecitationViewModel swaps in the engine-returned uthmani after a recording.
 */
object QuranText {
    private var texts: Map<String, String> = emptyMap()
    private var namesEn: Map<Int, String> = emptyMap()
    private var namesAr: Map<Int, String> = emptyMap()
    private var verseCounts: Map<Int, Int> = emptyMap()

    /** Loads assets on first call; cheap no-op afterwards. Call from an AndroidViewModel. */
    fun ensureLoaded(context: Context) {
        if (texts.isNotEmpty()) return
        val json = context.assets.open("quran/uthmani.json").bufferedReader().use { it.readText() }
        val obj = JSONObject(json)
        val map = HashMap<String, String>(obj.length())
        val keys = obj.keys()
        while (keys.hasNext()) {
            val k = keys.next()
            map[k] = obj.getString(k)
        }
        texts = map
        // Reuse the QCF surah index for names — no second source to keep in sync.
        val chapters = QcfRepository(context).chapters()
        namesEn = chapters.associate { it.id to it.nameEn }
        namesAr = chapters.associate { it.id to it.nameAr }
        verseCounts = chapters.associate { it.id to it.versesCount }
    }

    /** Number of ayat in [sura], or 0 if assets aren't loaded / sura invalid. */
    fun verseCount(sura: Int): Int = verseCounts[sura] ?: 0

    /** The full Verse for (sura, aya), or null if assets aren't loaded / ref invalid. */
    fun verse(sura: Int, aya: Int): Verse? {
        val text = texts["$sura:$aya"] ?: return null
        return Verse(sura, aya, namesEn[sura] ?: "", namesAr[sura] ?: "", text)
    }
}
