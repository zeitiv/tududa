package com.tududi.tududi.bridge

import com.tududi.core.FakeTududi
import com.tududi.core.TududiCore
import com.tududi.core.provisionedVault
import com.tududi.tududi.widget.WidgetOverlays
import io.flutter.plugin.common.MethodCall
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withTimeout
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class WidgetBridgeTest {
    private val fake = FakeTududi()
    private val vault = provisionedVault(fake)
    private val core = TududiCore.create(vault)
    private val overlays = WidgetOverlays()
    private var renders = 0
    private val bridge = WidgetBridge(
        core = { core },
        overlays = overlays,
        renderWidgets = { renders++ },
        scope = CoroutineScope(Dispatchers.Unconfined),
        postToMain = { it.run() },
    )

    @After
    fun tearDown() = fake.server.shutdown()

    private suspend fun call(method: String, args: Map<String, Any?>? = null) = bridge.dispatch(MethodCall(method, args))

    @Test
    fun `pendingChanges lists confirmed changes after a sequence and ack deletes them`() = runTest {
        core.changeLog.append("a", 2)
        core.changeLog.append("b", 0)
        core.changeLog.append("c", 2)

        val all = call("pendingChanges", mapOf("sinceSeq" to 0)) as List<*>
        assertEquals(listOf(1L, 2L, 3L), all.map { (it as Map<*, *>)["seq"] })
        val first = all.first() as Map<*, *>
        assertEquals("a", first["uid"])
        assertEquals(2, first["status"])
        assertTrue(first["atMillis"] is Long)

        assertEquals(listOf("c"), (call("pendingChanges", mapOf("sinceSeq" to 2L)) as List<*>).map { (it as Map<*, *>)["uid"] })

        assertNull(call("ack", mapOf("seq" to 2)))
        assertEquals(listOf(3L), (call("pendingChanges", mapOf("sinceSeq" to 0)) as List<*>).map { (it as Map<*, *>)["seq"] })
        // Sequence numbers survive ack.
        assertEquals(4L, core.changeLog.append("d", 2).seq)
    }

    @Test
    fun `overlay is kept for the widget and redraws it`() = runTest {
        assertNull(call("overlay", mapOf("uid" to "a1", "status" to 2)))
        assertEquals(2, overlays.state.value.getValue("a1").status)
        assertEquals(1, renders)
    }

    @Test
    fun `overlay validates its arguments`() = runTest {
        try {
            call("overlay", mapOf("uid" to "a1"))
            fail("expected INVALID_ARGUMENT")
        } catch (e: BridgeException) {
            assertEquals("INVALID_ARGUMENT", e.code)
        }
    }

    @Test
    fun `refresh redraws immediately and refetches the board in the background`() = runBlocking {
        assertNull(call("refresh"))
        assertEquals(1, renders)
        withTimeout(5_000) {
            while (fake.requests.none { it.path?.startsWith("/api/tasks") == true }) delay(20)
        }
    }

    @Test
    fun `event stream emits the current sequence and every new one`() = runTest {
        val sink = RecordingSink()
        bridge.events.onListen(null, sink)
        assertEquals(listOf<Any?>(0L), sink.events)

        core.changeLog.append("a", 2)
        core.changeLog.append("b", 2)
        assertEquals(listOf<Any?>(0L, 1L, 2L), sink.events)

        bridge.events.onCancel(null)
        core.changeLog.append("c", 2)
        assertEquals(3, sink.events.size)
    }

    @Test
    fun `unknown method is not implemented`() = runTest {
        assertTrue(call("nope") === NotImplemented)
    }
}
