package com.tududi.core.sync

import com.tududi.core.vault.InMemoryVault
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ChangeLogTest {
    private val vault = InMemoryVault()
    private var now = 100L
    private fun log() = ChangeLog(vault) { now++ }

    @Test
    fun `append assigns monotonic seq and since filters`() = runTest {
        val log = log()
        assertEquals(1L, log.append("a", 2).seq)
        assertEquals(2L, log.append("b", 0).seq)
        assertEquals(3L, log.append("a", 0).seq)

        assertEquals(listOf(2L, 3L), log.since(1).map { it.seq })
        assertEquals(WidgetChange(1, "a", 2, 100), log.since(0).first())
        assertEquals(3L, log.latestSeq())
        assertTrue(log.since(3).isEmpty())
    }

    @Test
    fun `ack removes entries up to seq but keeps counting`() = runTest {
        val log = log()
        repeat(3) { log.append("t$it", 2) }

        log.ack(2)
        assertEquals(listOf(3L), log.since(0).map { it.seq })

        log.ack(99)
        assertTrue(log.since(0).isEmpty())
        assertEquals(3L, log.latestSeq())
        assertEquals(4L, log.append("x", 2).seq)
    }

    @Test
    fun `seq stays monotonic across reinstantiation`() = runTest {
        log().append("a", 2)
        log().ack(1)
        val second = log().append("b", 2)
        assertEquals(2L, second.seq)
        assertEquals(listOf("b"), log().since(0).map { it.uid })
    }

    @Test
    fun `latest seq flow emits the current value`() = runTest {
        val log = log()
        log.append("a", 2)
        assertEquals(1L, log.latestSeqFlow.first())
    }

    @Test
    fun `log is capped`() = runTest {
        val log = log()
        repeat(ChangeLog.MAX_ENTRIES + 5) { log.append("t", 2) }
        assertEquals(ChangeLog.MAX_ENTRIES, log.since(0).size)
        assertEquals(ChangeLog.MAX_ENTRIES + 5L, log.latestSeq())
    }
}
