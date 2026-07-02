package com.bayaan.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.spring
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bayaan.ui.model.BAYYINAH
import com.bayaan.ui.model.FATIHAH
import com.bayaan.ui.theme.BayaanTheme
import com.bayaan.ui.theme.AmiriFontFamily
import com.bayaan.ui.components.BayaanHeader
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.TextButton

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VersePickerScreen(
    onPickAyah: (sura: Int, aya: Int) -> Unit,
    modifier: Modifier = Modifier
) {
    var expandedSurah by remember { mutableStateOf<Int?>(1) } // Default Al-Fatihah expanded
    var selectedAyah by remember { mutableStateOf<Pair<Int, Int>?>(null) }
    var showMenu by remember { mutableStateOf(false) }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = MaterialTheme.colorScheme.background
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                Spacer(modifier = Modifier.height(24.dp))
                BayaanHeader()
                Spacer(modifier = Modifier.height(16.dp))
            }

            // Al-Fatihah Card (Sura 1)
            item {
                SurahCard(
                    suraNumber = 1,
                    surahNameEn = "Al-Fatihah",
                    surahNameAr = FATIHAH.first,
                    verses = FATIHAH.second,
                    isExpanded = expandedSurah == 1,
                    onExpandToggle = { expandedSurah = if (expandedSurah == 1) null else 1 },
                    onPickAyah = { sura, aya ->
                        selectedAyah = sura to aya
                        showMenu = true
                    }
                )
            }

            // Al-Bayyinah Card (Sura 98)
            item {
                SurahCard(
                    suraNumber = 98,
                    surahNameEn = "Al-Bayyinah",
                    surahNameAr = BAYYINAH.first,
                    verses = BAYYINAH.second,
                    isExpanded = expandedSurah == 98,
                    onExpandToggle = { expandedSurah = if (expandedSurah == 98) null else 98 },
                    onPickAyah = { sura, aya ->
                        selectedAyah = sura to aya
                        showMenu = true
                    }
                )
            }

            item {
                Spacer(modifier = Modifier.height(32.dp))
            }
        }

        if (showMenu && selectedAyah != null) {
            val (sura, aya) = selectedAyah!!
            ModalBottomSheet(
                onDismissRequest = { showMenu = false },
                containerColor = MaterialTheme.colorScheme.surface,
                shape = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(24.dp)
                ) {
                    Text(
                        text = "Surah $sura, Ayah $aya",
                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Spacer(modifier = Modifier.height(16.dp))

                    TextButton(
                        onClick = {
                            showMenu = false
                            onPickAyah(sura, aya)
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = "Analyze Tajweed",
                            style = MaterialTheme.typography.bodyLarge.copy(
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                        )
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    TextButton(
                        onClick = {},
                        enabled = false,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = "Memorize (Coming Soon)",
                            style = MaterialTheme.typography.bodyLarge.copy(
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f)
                            )
                        )
                    }

                    Spacer(modifier = Modifier.height(24.dp))
                }
            }
        }
    }
}


@Composable
private fun SurahCard(
    suraNumber: Int,
    surahNameEn: String,
    surahNameAr: String,
    verses: List<String>,
    isExpanded: Boolean,
    onExpandToggle: () -> Unit,
    onPickAyah: (sura: Int, aya: Int) -> Unit
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        modifier = Modifier
            .fillMaxWidth()
            .animateContentSize(animationSpec = spring())
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            // Surah Header Row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onExpandToggle() }
                    .padding(20.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    // Sura Number Badge
                    Card(
                        shape = RoundedCornerShape(8.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.1f)
                        ),
                        modifier = Modifier.padding(end = 16.dp)
                    ) {
                        Text(
                            text = if (suraNumber == 98) "98" else "01",
                            style = MaterialTheme.typography.titleLarge.copy(
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            ),
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                        )
                    }

                    Column {
                        Text(
                            text = surahNameEn,
                            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = "${verses.size} Verses",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                        )
                    }
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = surahNameAr,
                        fontFamily = AmiriFontFamily,
                        fontSize = 24.sp,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.padding(end = 12.dp)
                    )
                    Icon(
                        imageVector = if (isExpanded) Icons.Default.KeyboardArrowUp else Icons.Default.KeyboardArrowDown,
                        contentDescription = if (isExpanded) "Collapse" else "Expand",
                        tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                    )
                }
            }

            // Expanded Ayah list
            AnimatedVisibility(visible = isExpanded) {
                Column(modifier = Modifier.fillMaxWidth()) {
                    HorizontalDivider(color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f))
                    
                    verses.forEachIndexed { index, uthmani ->
                        val ayaNumber = index + 1
                        AyahRow(
                            ayaNumber = ayaNumber,
                            uthmani = uthmani,
                            onClick = { onPickAyah(suraNumber, ayaNumber) }
                        )
                        
                        if (index < verses.size - 1) {
                            HorizontalDivider(
                                modifier = Modifier.padding(horizontal = 16.dp),
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.05f)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AyahRow(
    ayaNumber: Int,
    uthmani: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(horizontal = 16.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Ayah Index Badge
        Text(
            text = ayaNumber.toString(),
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            modifier = Modifier.width(28.dp)
        )
        
        Spacer(modifier = Modifier.width(8.dp))

        // Ayah Preview Arabic Text (RTL)
        Text(
            text = uthmani,
            fontFamily = AmiriFontFamily,
            fontSize = 20.sp,
            color = MaterialTheme.colorScheme.onSurface,
            textAlign = TextAlign.End,
            style = MaterialTheme.typography.bodyLarge.copy(
                textDirection = TextDirection.Rtl
            ),
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Preview(showBackground = true)
@Composable
fun VersePickerScreenPreview() {
    BayaanTheme {
        VersePickerScreen(onPickAyah = { _, _ -> })
    }
}
