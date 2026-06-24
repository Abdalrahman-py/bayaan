package com.bayaan.ui.components

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.bayaan.ui.theme.BayaanTheme
import com.bayaan.ui.theme.QuranTextStyle
import com.bayaan.ui.theme.TerracottaBackgroundDark
import com.bayaan.ui.theme.TerracottaBackgroundLight
import com.bayaan.ui.theme.TerracottaHighlight
import com.bayaan.ui.model.previewVerse

@Composable
fun VerseText(
    uthmani: String,
    highlights: List<IntRange> = emptyList(),  // char ranges to mark as mistakes
    modifier: Modifier = Modifier,
) {
    val isDark = isSystemInDarkTheme()
    val highlightBg = if (isDark) TerracottaBackgroundDark else TerracottaBackgroundLight

    val annotatedString = buildAnnotatedString {
        append(uthmani)
        for (range in highlights) {
            val start = range.first
            val end = range.last + 1 // IntRange is closed (inclusive), addStyle end is exclusive
            if (start in 0..uthmani.length && end in 0..uthmani.length) {
                addStyle(
                    style = SpanStyle(
                        color = TerracottaHighlight,
                        background = highlightBg,
                        textDecoration = TextDecoration.Underline
                    ),
                    start = start,
                    end = end
                )
            }
        }
    }

    Text(
        text = annotatedString,
        style = QuranTextStyle,
        textAlign = TextAlign.Center,
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 16.dp, horizontal = 24.dp)
    )
}

@Preview(showBackground = true)
@Composable
fun VerseTextPreview() {
    BayaanTheme {
        VerseText(
            uthmani = previewVerse.uthmani,
            highlights = listOf(0..7, 10..13)
        )
    }
}
