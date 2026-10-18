package com.tududi.tududi

import com.tududi.core.FakeTududi
import com.tududi.core.TududiCore
import com.tududi.core.data.ConnectionStatus
import com.tududi.core.vault.InMemoryVault
import com.tududi.core.vault.VaultData
import com.tududi.tududi.bridge.SessionBridge
import com.tududi.tududi.bridge.WidgetBridge
import com.tududi.tududi.widget.WidgetOverlays
import io.flutter.plugin.common.MethodCall
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The whole native path with fakes only: Flutter bridges -> core -> a fake Tududi server. No
 * Android framework, no real Keystore.
 */
class WidgetSyncIntegrationTest {
    private val fake = FakeTududi()
    private val vault = InMemoryVault()
    private val core = TududiCore.create(vault)
    private val overlays = WidgetOverlays()
    private val unconfined = CoroutineScope(Dispatchers.Unconfined)
    private val session = SessionBridge(
        core = { core },
        // What TududaApplication.onSessionChanged does, minus the Glance redraw.
        onSessionChanged = {
            overlays.clear()
            core.repository.reset()
            core.repository.refresh()
        },
        scope = unconfined,
        postToMain = { it.run() },
        background = unconfined,
    )
    private val widget = WidgetBridge(
        core = { core },
        overlays = overlays,
        renderWidgets = {},
        scope = unconfined,
        postToMain = { it.run() },
        background = unconfined,
    )

    @After
    fun tearDown() = fake.server.shutdown()

    private fun provisionArgs(password: String = "secret-pass") = mapOf(
        "serverUrl" to fake.url().toString(),
        "allowInsecureHttp" to true,
        "email" to "user@example.com",
        "password" to password,
        "accountUid" to "acc-1",
    )

    @Test
    fun `provision, refresh, expired session, silent re-login, confirmed toggle, clear`() = runBlocking {
        // 1. The Flutter app provisions the vault after login.
        session.dispatch(MethodCall("provision", provisionArgs()))
        assertEquals(true, (session.dispatch(MethodCall("state", null)) as Map<*, *>)["provisioned"])

        // 2. The widget refreshes: first request logs in, board shows the server's task.
        core.repository.refresh()
        assertEquals(ConnectionStatus.OK, core.repository.state.value.status)
        assertEquals(listOf("a1"), core.repository.state.value.board!!.open.map { it.uid })
        assertEquals(1, fake.loginCount)

        // 3. The server session expires.
        fake.expireAllSessions()

        // 4. Checking the task off gets a 401, logs in silently once, and the PATCH carries the CSRF token.
        assertTrue(core.repository.setDone("a1", true))
        assertEquals(2, fake.loginCount)
        val patch = fake.requests.last { it.method == "PATCH" }
        assertEquals("/api/task/a1", patch.path)
        val sid = patch.getHeader("Cookie")!!.substringAfter("tududi.sid=").substringBefore(';')
        assertEquals(fake.sessions.getValue(sid), patch.getHeader("x-csrf-token"))
        assertTrue(patch.body.readUtf8().contains("\"status\":2"))

        // 5. The confirmed change is visible to Flutter, through the bridge.
        val pending = widget.dispatch(MethodCall("pendingChanges", mapOf("sinceSeq" to 0))) as List<*>
        assertEquals(1, pending.size)
        val change = pending.single() as Map<*, *>
        assertEquals(1L, change["seq"])
        assertEquals("a1", change["uid"])
        assertEquals(2, change["status"])

        // Acknowledged entries are gone.
        widget.dispatch(MethodCall("ack", mapOf("seq" to 1)))
        assertTrue((widget.dispatch(MethodCall("pendingChanges", mapOf("sinceSeq" to 0))) as List<*>).isEmpty())

        // 6. Logout: server logout with the native cookie, vault empty, widget shows signed out.
        widget.dispatch(MethodCall("overlay", mapOf("uid" to "a1", "status" to 2)))
        session.dispatch(MethodCall("writeCookies", mapOf("host" to "h", "cookies" to listOf("flutter=1"))))
        session.dispatch(MethodCall("clear", null))
        assertEquals(1, fake.logoutCount)
        assertNotNull(fake.lastLogoutCookie)
        assertEquals(VaultData(), vault.read())
        assertTrue(overlays.state.value.isEmpty())
        assertEquals(ConnectionStatus.LOGGED_OUT, core.repository.state.value.status)
        assertNull(core.repository.state.value.board)
        assertNull(session.dispatch(MethodCall("getCredentials", null)))
        assertEquals(emptyList<String>(), session.dispatch(MethodCall("readCookies", mapOf("host" to "h"))))
        assertTrue((widget.dispatch(MethodCall("pendingChanges", mapOf("sinceSeq" to 0))) as List<*>).isEmpty())
    }

    @Test
    fun `a wrong password leads to exactly one login attempt`() = runBlocking {
        session.dispatch(MethodCall("provision", provisionArgs(password = "wrong")))

        // (provision already started a background refresh; this one queues behind it.)
        core.repository.refresh()
        assertTrue(core.repository.state.value.isSignedOut)
        assertEquals(1, fake.loginCount)
        assertEquals(true, (session.dispatch(MethodCall("state", null)) as Map<*, *>)["loginFailed"])

        // Later widget updates and toggles do not hammer the (rate limited) login endpoint.
        core.repository.refresh()
        core.repository.setDone("a1", true)
        assertEquals(1, fake.loginCount)

        // Provisioning again (the user fixed the password in the app) re-enables silent login.
        session.dispatch(MethodCall("provision", provisionArgs()))
        assertFalse((session.dispatch(MethodCall("state", null)) as Map<*, *>)["loginFailed"] as Boolean)
        core.repository.refresh()
        assertEquals(ConnectionStatus.OK, core.repository.state.value.status)
        assertEquals(2, fake.loginCount)
    }
}
