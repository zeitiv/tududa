package com.tududi.tududi.bridge

import com.tududi.core.FakeTududi
import com.tududi.core.TududiCore
import com.tududi.core.vault.InMemoryVault
import io.flutter.plugin.common.MethodCall
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class SessionBridgeTest {
    // Only the fake ever sees traffic (logout on clear); nothing here may reach a real host.
    private val fake = FakeTududi()
    private val serverUrl = fake.url().toString()
    private val vault = InMemoryVault()
    private val core = TududiCore.create(vault)
    private var changed = 0
    private val bridge = SessionBridge(
        core = { core },
        onSessionChanged = { changed++ },
        scope = CoroutineScope(Dispatchers.Unconfined),
        postToMain = { it.run() },
    )

    @After
    fun tearDown() = fake.server.shutdown()

    private fun provisionArgs(
        url: String = serverUrl,
        insecure: Boolean = true,
        account: String = "acc-1",
    ) = mapOf(
        "serverUrl" to url,
        "allowInsecureHttp" to insecure,
        "email" to "me@example.com",
        "password" to "s3cret",
        "accountUid" to account,
    )

    private suspend fun call(method: String, args: Map<String, Any?>? = null) = bridge.dispatch(MethodCall(method, args))

    @Test
    fun `provision stores credentials and reports state`() = runTest {
        assertNull(call("getCredentials"))
        assertEquals(false, (call("state") as Map<*, *>)["provisioned"])

        assertNull(call("provision", provisionArgs()))

        assertEquals(
            mapOf("serverUrl" to serverUrl, "email" to "me@example.com", "password" to "s3cret"),
            call("getCredentials"),
        )
        assertEquals(
            mapOf("provisioned" to true, "serverUrl" to serverUrl, "accountUid" to "acc-1", "loginFailed" to false),
            call("state"),
        )
        assertEquals(1, changed)
    }

    @Test
    fun `provision rejects http without opt in and bad urls`() = runTest {
        for (args in listOf(provisionArgs(url = "http://nas.local:3002", insecure = false), provisionArgs(url = "not a url"))) {
            try {
                call("provision", args)
                fail("expected INVALID_ARGUMENT")
            } catch (e: BridgeException) {
                assertEquals("INVALID_ARGUMENT", e.code)
            }
        }
        assertNull(call("getCredentials"))
        assertEquals(0, changed)
        // With the in-app confirmation (allowInsecureHttp) the same URL is accepted.
        call("provision", provisionArgs(url = "http://nas.local:3002", insecure = true))
        assertEquals(true, vault.read().allowInsecureHttp)
    }

    @Test
    fun `provision reports missing and mistyped arguments`() = runTest {
        for (args in listOf(provisionArgs() - "password", provisionArgs() + ("allowInsecureHttp" to "yes"))) {
            try {
                call("provision", args)
                fail("expected INVALID_ARGUMENT")
            } catch (e: BridgeException) {
                assertEquals("INVALID_ARGUMENT", e.code)
                // The password must never end up in an error message.
                assertFalse(e.message!!.contains("s3cret"))
            }
        }
    }

    @Test
    fun `cookies are stored per host and an empty list removes the host`() = runTest {
        assertEquals(emptyList<String>(), call("readCookies", mapOf("host" to "h")))
        call("writeCookies", mapOf("host" to "h", "cookies" to listOf("a=1", "b=2")))
        call("writeCookies", mapOf("host" to "other", "cookies" to listOf("c=3")))
        assertEquals(listOf("a=1", "b=2"), call("readCookies", mapOf("host" to "h")))
        call("writeCookies", mapOf("host" to "h", "cookies" to emptyList<String>()))
        assertEquals(emptyList<String>(), call("readCookies", mapOf("host" to "h")))
        assertEquals(listOf("c=3"), call("readCookies", mapOf("host" to "other")))
    }

    @Test
    fun `provision with another account resets native session data`() = runTest {
        call("provision", provisionArgs())
        vault.update { it.copy(nativeCookies = listOf("tududi.sid=x"), boardJson = "{}", lastChangeSeq = 7, autoLoginDisabled = true) }

        call("provision", provisionArgs(account = "acc-2"))

        val d = vault.read()
        assertTrue(d.nativeCookies.isEmpty())
        assertNull(d.boardJson)
        assertEquals(0, d.lastChangeSeq)
        assertFalse(d.autoLoginDisabled)
        assertEquals(2, changed)
    }

    @Test
    fun `clear wipes the vault and notifies`() = runBlocking {
        call("provision", provisionArgs())
        call("writeCookies", mapOf("host" to "h", "cookies" to listOf("a=1")))

        assertNull(call("clear"))

        assertEquals(com.tududi.core.vault.VaultData(), vault.read())
        assertEquals(1, fake.logoutCount)
        assertNull(call("getCredentials"))
        assertEquals(2, changed)
    }

    @Test
    fun `unknown method is not implemented`() = runTest {
        assertSame(NotImplemented, call("nope"))
        val result = RecordingResult()
        bridge.onMethodCall(MethodCall("nope", null), result)
        assertTrue(result.notImplemented)
    }

    @Test
    fun `onMethodCall replies through the main thread poster`() {
        val posted = mutableListOf<Runnable>()
        val deferred = SessionBridge(core = { core }, onSessionChanged = {}, scope = CoroutineScope(Dispatchers.Unconfined), postToMain = { posted += it })
        val ok = RecordingResult()
        deferred.onMethodCall(MethodCall("provision", provisionArgs()), ok)
        // Work is done, but nothing is delivered until the main thread runs the posted reply.
        assertEquals(0, ok.replies)
        posted.removeAll { it.run(); true }
        assertEquals(1, ok.replies)
        assertNull(ok.success)

        val bad = RecordingResult()
        deferred.onMethodCall(MethodCall("provision", provisionArgs(url = "http://x.local", insecure = false)), bad)
        posted.removeAll { it.run(); true }
        assertEquals("INVALID_ARGUMENT", bad.errorCode)
        runBlocking { assertEquals(serverUrl, vault.read().serverUrl) }
    }
}
