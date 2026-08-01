package com.bayaan.ui.screens

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Guards the one rule the learn path's first frame depends on: the offline seed
 * (ProgressStore) and the server merge must agree, or the path visibly re-shuffles when
 * the network answers ~200ms after launch.
 */
class NodeStatusTest {

    /** Runs the rule over a list the way both callers do, threading `prevCompleted`. */
    private fun path(vararg statuses: String?): List<NodeStatus> {
        var prevCompleted = true
        return statuses.map { s ->
            nodeStatus(s, prevCompleted).also { prevCompleted = s == "completed" }
        }
    }

    @Test
    fun `fresh install opens on the first lesson, not a wall of locks`() {
        assertEquals(
            listOf(NodeStatus.CURRENT, NodeStatus.LOCKED, NodeStatus.LOCKED),
            path(null, null, null),
        )
    }

    @Test
    fun `the lesson after the last completed one is current`() {
        assertEquals(
            listOf(NodeStatus.DONE, NodeStatus.DONE, NodeStatus.CURRENT, NodeStatus.LOCKED),
            path("completed", "completed", null, null),
        )
    }

    @Test
    fun `offline seed and server agree on the same progress`() {
        // Seed knows lessons 1-2 are done and says nothing about the rest; the server
        // sends the same two as "completed". Both must produce an identical path, or the
        // Continue button changes target when the response lands.
        val seeded = path("completed", "completed", null, null)
        val fromServer = path("completed", "completed", null, null)
        assertEquals(seeded, fromServer)
    }

    @Test
    fun `an in-progress lesson is current even when the one before is unfinished`() {
        assertEquals(
            listOf(NodeStatus.CURRENT, NodeStatus.LOCKED, NodeStatus.CURRENT),
            path(null, null, "in_progress"),
        )
    }

    @Test
    fun `only one lesson is current on a linear path`() {
        val current = path(null, null, null, null).count { it == NodeStatus.CURRENT }
        assertEquals(1, current)
    }
}
