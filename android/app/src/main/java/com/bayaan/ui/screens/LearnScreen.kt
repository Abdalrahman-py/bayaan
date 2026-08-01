package com.bayaan.ui.screens

import android.content.Context
import android.util.Log
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
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
import com.bayaan.ui.lesson.ProgressStore
import com.bayaan.ui.theme.AmiriFontFamily
import com.bayaan.ui.theme.BayaanTheme
import com.bayaan.ui.theme.NodeLockedDark
import com.bayaan.ui.theme.NodeLockedLight
import org.json.JSONObject

enum class NodeStatus { DONE, CURRENT, LOCKED }

/**
 * The one unlock rule, shared by the offline seed and the server merge so the two can't
 * disagree and make the path re-shuffle when the network lands.
 *
 * [status] is the server's word for the lesson (`"completed"` / `"in_progress"`), or null
 * when it hasn't answered yet. [prevCompleted] is whether the preceding lesson is done —
 * true for the very first lesson, so a fresh install opens unlocked instead of on a wall
 * of locks.
 */
internal fun nodeStatus(status: String?, prevCompleted: Boolean): NodeStatus = when {
    status == "completed" -> NodeStatus.DONE
    status == "in_progress" -> NodeStatus.CURRENT
    prevCompleted -> NodeStatus.CURRENT
    else -> NodeStatus.LOCKED
}

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
    // Bumped by Retry. Keys the asset parse and the fetch so both re-run.
    var reloadKey by remember { mutableIntStateOf(0) }

    // Parsed during composition, not in the LaunchedEffect: the unit titles live in a
    // 7.5KB bundled asset, so there is nothing to wait for. Filling them in later meant
    // the first frame showed stand-in titles before swapping to the real ones — a visible
    // flash on every launch. Reading the asset on the main thread once is the cheaper of
    // the two. Empty means the asset genuinely failed to parse; that renders as an error
    // with a Retry, never as invented lessons.
    //
    // Statuses come from ProgressStore for the same reason: marking every node LOCKED and
    // waiting for the network meant the Continue button was absent on frame 1 and appeared
    // ~200ms later, shoving the whole path down 76dp. Seeded locally the button is there
    // immediately and the server response only ever corrects its label.
    val store = remember { ProgressStore(context) }
    var units by remember(reloadKey) { mutableStateOf(loadCurriculum(context, store)) }
    var header by remember(reloadKey) {
        mutableStateOf(LearnApi.Header(0, maxOf(xp, store.xp()), maxOf(streak, store.streak()), 10, 0))
    }
    // The path on screen is the local seed, not the server's word for it.
    var syncFailed by remember(reloadKey) { mutableStateOf(false) }

    LaunchedEffect(reloadKey) {
        if (tokenProvider() == null) return@LaunchedEffect
        val api = LearnApi(tokenProvider)
        val path = try { api.learnPath() } finally { api.close() }
        if (path != null) {
            header = path.header
            units = mergeUnits(units, path.units)
        } else {
            syncFailed = true
        }
    }

    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { visible = true }

    val flatNodes = units.flatMap { it.nodes }
    val continueNode = flatNodes.firstOrNull { it.status == NodeStatus.CURRENT }
        ?: flatNodes.firstOrNull { it.status == NodeStatus.DONE }

    Scaffold(containerColor = MaterialTheme.colorScheme.background) { padding ->
        // LazyColumn, not Column+verticalScroll: the curriculum is 44 lessons across 11
        // units, and a scrolling Column composes and measures every one of them on the
        // first frame. Lazily only the visible handful is built.
        LazyColumn(
            modifier = Modifier.padding(padding).fillMaxWidth(),
            contentPadding = PaddingValues(horizontal = 16.dp),
        ) {
            item {
                Spacer(Modifier.height(8.dp))
                Text("Learn", style = MaterialTheme.typography.headlineMedium, color = MaterialTheme.colorScheme.onBackground)
                Spacer(Modifier.height(12.dp))
                StreakXpHeader(streak = header.streak, xp = header.xp, goalMinutes = header.dailyGoalMinutes, minutesDone = 0)
                Spacer(Modifier.height(16.dp))
            }

            if (units.isEmpty()) {
                item { CurriculumUnavailable(onRetry = { reloadKey++ }) }
            } else if (syncFailed) {
                item { SyncFailedNotice(onRetry = { reloadKey++ }) }
            }

            if (continueNode != null) {
                item {
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
            }

            var lastTrack = "arabic"
            units.forEach { unit ->
                val showTrackDivider = unit.track == "tajweed" && lastTrack == "arabic"
                lastTrack = unit.track
                item(key = "unit.${unit.titleEn}") {
                    if (showTrackDivider) {
                        Spacer(Modifier.height(24.dp))
                        Text(
                            text = "Tajweed Track",
                            style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
                            color = MaterialTheme.colorScheme.secondary,
                            modifier = Modifier.padding(vertical = 12.dp)
                        )
                        Spacer(Modifier.height(8.dp))
                    }
                    UnitHeader(unit)
                }
                itemsIndexed(unit.nodes, key = { _, node -> node.id }) { i, node ->
                    // ponytail: stagger index is per-unit, not global. Off-screen units are
                    // composed after `visible` is already true, so AnimatedVisibility skips
                    // their enter animation entirely and the index never shows. Ceiling: if
                    // this ever becomes a single flat unit, the cascade restarts mid-scroll.
                    val delay = minOf(i, 6) * 45
                    AnimatedVisibility(
                        visible = visible,
                        enter = fadeIn(tween(300, delayMillis = delay)) +
                            slideInVertically(tween(300, delayMillis = delay)) { it / 4 },
                    ) {
                        LessonNode(node = node, demoMode = demoMode, onClick = { onOpenLesson(node.id) })
                    }
                }
                item(key = "gap.${unit.titleEn}") { Spacer(Modifier.height(20.dp)) }
            }
            item { Spacer(Modifier.height(32.dp)) }
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

    // Only the one CURRENT node gets a transition. Building it unconditionally meant 44
    // infinite animations invalidating every frame, 43 of them animating 1f to 1f.
    val scale = if (node.status == NodeStatus.CURRENT && unlocked) pulseScale() else 1f

    Row(
        Modifier.fillMaxWidth().clickable(enabled = unlocked, onClick = onClick).padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier.scale(scale)
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

/**
 * Shown when `content/curriculum.json` could not be read. Deliberately says the lessons
 * could not be loaded rather than inventing a path — an earlier version fell back to two
 * hardcoded units with hardcoded DONE/CURRENT statuses, which told the user they had
 * completed lessons they had never opened.
 */
@Composable
private fun CurriculumUnavailable(onRetry: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(vertical = 48.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            "Couldn't load your lessons",
            style = MaterialTheme.typography.titleLarge,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            "The lesson list is bundled with the app, so this usually means the install is damaged. Reinstalling should fix it.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.7f),
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(24.dp))
        OutlinedButton(
            onClick = onRetry,
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.height(52.dp),
            border = ButtonDefaults.outlinedButtonBorder.copy(width = 2.dp),
            colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.primary),
        ) {
            Icon(Icons.Default.Refresh, contentDescription = null)
            Spacer(Modifier.width(8.dp))
            Text("Try again", style = MaterialTheme.typography.labelLarge)
        }
    }
}

/**
 * The lessons rendered from the local seed but the server never answered, so the statuses
 * on screen are the last known ones. Says so instead of passing stale progress off as live.
 */
@Composable
private fun SyncFailedNotice(onRetry: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            "Showing your saved progress — couldn't reach the server.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(1f),
        )
        Spacer(Modifier.width(8.dp))
        TextButton(onClick = onRetry) {
            Text("Retry", style = MaterialTheme.typography.labelLarge)
        }
    }
}

@Composable
private fun pulseScale(): Float {
    val pulse = rememberInfiniteTransition(label = "pulse")
    val scale by pulse.animateFloat(
        initialValue = 1f, targetValue = 1.08f,
        animationSpec = infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "nodeScale",
    )
    return scale
}

private fun loadCurriculum(context: Context, store: ProgressStore): List<UnitUi> = run {
    try {
        val raw = context.assets.open("content/curriculum.json").bufferedReader().use { it.readText() }
        val root = JSONObject(raw)
        val unitsArr = root.getJSONArray("units")
        val result: MutableList<UnitUi> = mutableListOf()
        // Same unlock rule as mergeUnits: the lesson after the last completed one is CURRENT.
        // Starts true so a fresh install opens on node 0 unlocked rather than a wall of locks.
        var prevCompleted = true
        for (i in 0 until unitsArr.length()) {
            val u = unitsArr.getJSONObject(i)
            val larr = u.getJSONArray("lessons")
            val nodes: MutableList<NodeUi> = mutableListOf()
            for (li in 0 until larr.length()) {
                val l = larr.getJSONObject(li)
                val id = l.getString("lesson_id")
                val completed = store.isCompleted(id)
                val status = nodeStatus(if (completed) "completed" else null, prevCompleted)
                prevCompleted = completed
                nodes.add(NodeUi(id, l.getString("title_en"), l.getString("title_ar"), status, l.optBoolean("is_checkpoint")))
            }
            val track = u.optString("track", "arabic")
            result.add(UnitUi(u.getString("title_en"), u.getString("title_ar"), track, nodes))
        }
        result
    } catch (e: Exception) {
        // Empty, never a stand-in path: the caller renders CurriculumUnavailable. Logged
        // because a damaged asset used to fail completely silently.
        Log.e("LearnScreen", "curriculum.json unreadable", e)
        emptyList()
    }
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
            val status = nodeStatus(svr?.status, prevCompleted)
            prevCompleted = svr?.status == "completed"
            nodes.add(NodeUi(l.lessonId, l.titleEn, l.titleAr, status, l.isCheckpoint))
        }
        val track = u.track
        result.add(UnitUi(u.titleEn, u.titleAr, track, nodes))
    }
    return result.ifEmpty { assetUnits }
}

@Preview
@Composable
private fun LearnScreenPreview() {
    BayaanTheme { LearnScreen() }
}
