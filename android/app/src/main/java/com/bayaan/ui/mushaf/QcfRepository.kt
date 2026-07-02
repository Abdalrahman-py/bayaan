package com.bayaan.ui.mushaf

import android.content.Context
import org.json.JSONObject

class QcfRepository(private val context: Context) {
    private var cachedChapters: List<QcfChapter>? = null
    private val cachedPages = mutableMapOf<Int, QcfPage>()

    fun chapters(): List<QcfChapter> {
        cachedChapters?.let { return it }
        val jsonStr = context.assets.open("qcf4/index.json").bufferedReader().use { it.readText() }
        val rootObj = JSONObject(jsonStr)
        val chaptersArray = rootObj.getJSONArray("chapters")
        val list = mutableListOf<QcfChapter>()
        for (i in 0 until chaptersArray.length()) {
            val chObj = chaptersArray.getJSONObject(i)
            val pagesArr = chObj.getJSONArray("pages")
            list.add(
                QcfChapter(
                    id = chObj.getInt("id"),
                    nameEn = chObj.getString("name"),
                    nameAr = chObj.getString("name_arabic"),
                    versesCount = chObj.getInt("verses_count"),
                    startPage = pagesArr.getInt(0),
                    endPage = pagesArr.getInt(1)
                )
            )
        }
        cachedChapters = list
        return list
    }

    fun page(n: Int): QcfPage {
        cachedPages[n]?.let { return it }
        val fileName = String.format("qcf4/pages/%03d.json", n)
        val jsonStr = context.assets.open(fileName).bufferedReader().use { it.readText() }
        val rootObj = JSONObject(jsonStr)
        
        val pageNum = rootObj.getInt("page")
        val pageFont = rootObj.getString("font")
        val linesArray = rootObj.getJSONArray("lines")
        val linesList = mutableListOf<QcfLine>()
        
        for (i in 0 until linesArray.length()) {
            val lineObj = linesArray.getJSONObject(i)
            val lineNum = lineObj.getInt("line")
            val wordsArray = lineObj.getJSONArray("words")
            val wordsList = mutableListOf<QcfWord>()
            
            for (j in 0 until wordsArray.length()) {
                val wObj = wordsArray.getJSONObject(j)
                val code = wObj.getInt("code")
                val font = wObj.getString("font")
                val type = wObj.getString("type")
                val verseKey = if (wObj.has("verse_key") && !wObj.isNull("verse_key")) {
                    wObj.getString("verse_key")
                } else {
                    null
                }
                wordsList.add(
                    QcfWord(
                        code = code,
                        fontName = font,
                        type = type,
                        verseKey = verseKey
                    )
                )
            }
            linesList.add(QcfLine(lineNum, wordsList))
        }
        
        val qcfPage = QcfPage(pageNum, pageFont, linesList)
        cachedPages[n] = qcfPage
        return qcfPage
    }
}
