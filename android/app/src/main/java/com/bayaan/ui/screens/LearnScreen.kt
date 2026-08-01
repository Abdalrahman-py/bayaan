package com.bayaan.ui.screens

import android.content.Context
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.bayaan.BuildConfig
import com.bayaan.ui.components.StreakXpHeader
import com.bayaan.ui.lesson.LearnApi
import com.bayaan.ui.theme.AmiriFontFamily
import com.bayaan.ui.theme.BayaanTheme
import com.bayaan.ui.theme.NodeLockedDark
import com.bayaan.ui.theme.NodeLockedLight
import org.json.JSONObject

enum class NodeStatus { DONE, CURRENT, LOCKED }

private data class NodeUi(
    val id: String, val titleEn: String, val titleAr: String,
    val status: NodeStatus, val isCheckpoint: Boolean = false,
)

private data class UnitUi(val titleEn: String, val titleAr: String, val track: String, val nodes: List<NodeUi>)

@Composable
fun LearnScreen(
    onOpenLesson: (String) -> Unit = {},
    tokenProvider: () -> String? = { null },
    streak: Int = 0,
    xp: Int = 0,
    demoMode: Boolean = BuildConfig.DEMO_MODE,
) {
    val context = LocalContext.current
    // Parsed during composition, not in the LaunchedEffect: the unit titles live in a
    // 7.5KB bundled asset, so there is nothing to wait for. Seeding from placeholderPath()
    // and filling in later meant the first frame always showed "Unit 1 · The Letters"
    // before swapping to the real titles — a visible flash on every launch. Reading the
    // asset on the main thread once at startup is the cheaper of the two.
    var units by remember { mutableStateOf(loadCurriculum(context).ifEmpty { placeholderPath() }) }
    var header by remember { mutableStateOf(LearnApi.Header(0, xp, streak, 10, 0)) }

    LaunchedEffect(Unit) {
        if (tokenProvider() == null) return@LaunchedEffect
        val api = LearnApi(tokenProvider)
        val path = api.learnPath()
        api.close()
        if (path != null) {
            header = path.header
            units = mergeUnits(units, path.units)
        }
    }

    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { visible = true }

    val flatNodes = units.flatMap { it.nodes }
    val continueNode = flatNodes.firstOrNull { it.status == NodeStatus.CURRENT }
        ?: flatNodes.firstOrNull { it.status == NodeStatus.DONE }

    Scaffold(containerColor = MaterialTheme.colorScheme.background) { padding ->
        Column(
            modifier = Modifier.padding(padding).fillMaxWidth()
                .verticalScroll(rememberScrollState()).padding(horizontal = 16.dp),
        ) {
            Spacer(Modifier.height(8.dp))
            Text("Learn", style = MaterialTheme.typography.headlineMedium, color = MaterialTheme.colorScheme.onBackground)
            Spacer(Modifier.height(12.dp))
            StreakXpHeader(streak = header.streak, xp = header.xp, goalMinutes = header.dailyGoalMinutes, minutesDone = 0)
            Spacer(Modifier.height(16.dp))

            if (continueNode != null) {
                Button(
                    onClick = { onOpenLesson(continueNode.id) },
                    modifier = Modifier.fillMaxWidth().height(52.dp),
                ) {
                    Icon(Icons.Filled.PlayArrow, contentDescription = null)
                    Spacer(Modifier.width(8.dp))
                    Text("Continue · ${continueNode.titleEn}", style = MaterialTheme.typography.labelLarge)
                }
                Spacer(Modifier.height(24.dp))
            }

            var index = 0
            var lastTrack = "arabic"
            units.forEach { unit ->
                if (unit.track == "tajweed" && lastTrack == "arabic") {
                    Spacer(Modifier.height(24.dp))
                    Text(
                        text = "Tajweed Track",
                        style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
                        color = MaterialTheme.colorScheme.secondary,
                        modifier = Modifier.padding(vertical = 12.dp)
                    )
                    Spacer(Modifier.height(8.dp))
                }
                lastTrack = unit.track
                UnitHeader(unit)
                unit.nodes.forEach { node ->
                    val i = index++
                    AnimatedVisibility(
                        visible = visible,
                        enter = fadeIn(tween(300, delayMillis = i * 55)) +
                            slideInVertically(tween(300, delayMillis = i * 55)) { it / 4 },
                    ) {
                        LessonNode(node = node, demoMode = demoMode, onClick = { onOpenLesson(node.id) })
                    }
                }
                Spacer(Modifier.height(20.dp))
            }
            Spacer(Modifier.height(32.dp))
        }
    }
}

@Composable
private fun UnitHeader(unit: UnitUi) {
    Column(Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
        Text(unit.titleEn, style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.onBackground)
        Text(
            text = unit.titleAr,
            fontFamily = AmiriFontFamily,
            style = MaterialTheme.typography.titleLarge.copy(textDirection = TextDirection.Rtl),
            color = MaterialTheme.colorScheme.primary,
        )
    }
}

@Composable
private fun LessonNode(node: NodeUi, demoMode: Boolean, onClick: () -> Unit) {
    val unlocked = demoMode || node.status != NodeStatus.LOCKED
    val locked = !unlocked
    val badgeColor: Color = when {
        locked -> if (isSystemInDarkTheme()) NodeLockedDark else NodeLockedLight
        else -> MaterialTheme.colorScheme.primary
    }

    val pulse = rememberInfiniteTransition(label = "pulse")
    val scale by pulse.animateFloat(
        initialValue = 1f, targetValue = if (node.status == NodeStatus.CURRENT && unlocked) 1.08f else 1f,
        animationSpec = infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "nodeScale",
    )

    Row(
        Modifier.fillMaxWidth().clickable(enabled = unlocked, onClick = onClick).padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier.scale(if (node.status == NodeStatus.CURRENT) scale else 1f)
                .size(56.dp).clip(CircleShape).background(badgeColor),
            contentAlignment = Alignment.Center,
        ) {
            when {
                locked -> Icon(Icons.Filled.Lock, contentDescription = "Locked", tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                node.status == NodeStatus.DONE -> Icon(Icons.Filled.Check, contentDescription = "Completed", tint = MaterialTheme.colorScheme.onPrimary)
                else -> Icon(Icons.Filled.PlayArrow, contentDescription = "Current", tint = MaterialTheme.colorScheme.onPrimary)
            }
        }
        Spacer(Modifier.width(16.dp))
        Column(Modifier.weight(1f)) {
            Text(
                node.titleEn,
                style = MaterialTheme.typography.bodyLarge.copy(fontWeight = if (node.status == NodeStatus.CURRENT) FontWeight.SemiBold else FontWeight.Normal),
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = if (locked) 0.5f else 1f),
            )
            Text(
                node.titleAr,
                fontFamily = AmiriFontFamily,
                style = MaterialTheme.typography.bodyLarge.copy(textDirection = TextDirection.Rtl),
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = if (locked) 0.4f else 0.7f),
                textAlign = TextAlign.End,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

private fun loadCurriculum(context: Context): List<UnitUi> = run {
    try {
        val raw = context.assets.open("content/curriculum.json").bufferedReader().use { it.readText() }
        val root = JSONObject(raw)
        val unitsArr = root.getJSONArray("units")
        val result: MutableList<UnitUi> = mutableListOf()
        for (i in 0 until unitsArr.length()) {
            val u = unitsArr.getJSONObject(i)
            val larr = u.getJSONArray("lessons")
            val nodes: MutableList<NodeUi> = mutableListOf()
            for (li in 0 until larr.length()) {
                val l = larr.getJSONObject(li)
                nodes.add(NodeUi(l.getString("lesson_id"), l.getString("title_en"), l.getString("title_ar"), NodeStatus.LOCKED, l.optBoolean("is_checkpoint")))
            }
            val track = u.optString("track", "arabic")
            result.add(UnitUi(u.getString("title_en"), u.getString("title_ar"), track, nodes))
        }
        result
    } catch (_: Exception) { emptyList() }
}

private fun mergeUnits(assetUnits: List<UnitUi>, serverUnits: List<LearnApi.UnitNode>): List<UnitUi> {
    if (serverUnits.isEmpty()) return assetUnits
    val serverMap = mutableMapOf<String, LearnApi.LessonNode>()
    serverUnits.forEach { u -> u.lessons.forEach { l -> serverMap[l.lessonId] = l } }

    var prevCompleted = true
    val result: MutableList<UnitUi> = mutableListOf()
    for (u in serverUnits) {
        val nodes: MutableList<NodeUi> = mutableListOf()
        for (l in u.lessons) {
            val svr = serverMap[l.lessonId]
            val status = when {
                svr?.status == "completed" -> NodeStatus.DONE
                svr?.status == "in_progress" -> NodeStatus.CURRENT
                prevCompleted -> NodeStatus.CURRENT
                else -> NodeStatus.LOCKED
            }
            prevCompleted = svr?.status == "completed"
            nodes.add(NodeUi(l.lessonId, l.titleEn, l.titleAr, status, l.isCheckpoint))
        }
        val track = u.track
        result.add(UnitUi(u.titleEn, u.titleAr, track, nodes))
    }
    return result.ifEmpty { assetUnits }
}

private fun placeholderPath(): List<UnitUi> = listOf(
    UnitUi("Unit 1 · The Letters", "الحروف", "arabic", listOf(
        NodeUi("ar.1.1", "Dotted family", "ب ت ث ن ي", NodeStatus.DONE),
        NodeUi("ar.1.2", "Throat letters", "ج ح خ", NodeStatus.CURRENT),
        NodeUi("ar.1.3", "Non-connectors", "د ذ ر ز و", NodeStatus.LOCKED),
    )),
    UnitUi("Unit 2 · Hearing the difference", "التمييز", "arabic", listOf(
        NodeUi("ar.2.1", "ه / ح / خ", "ه ح خ", NodeStatus.LOCKED),
        NodeUi("ar.2.2", "س / ص، ت / ط", "س ص ت ط", NodeStatus.LOCKED),
    )),
)

@Preview
@Composable
private fun LearnScreenPreview() {
    BayaanTheme { LearnScreen() }
}
