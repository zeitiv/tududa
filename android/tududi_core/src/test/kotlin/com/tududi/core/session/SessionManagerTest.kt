package com.tududi.core.session

import com.tududi.core.FakeTududi
import com.tududi.core.TududiCore
import com.tududi.core.vault.InMemoryVault
import com.tududi.core.vault.VaultData
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class SessionManagerTest {
    private val fake = FakeTududi()
    private val vault = InMemoryVault()
    private val core = TududiCore.create(vault)
    private val sm = core.sessionManager
    private val url get() = fake.url().toString()

    @After
    fun tearDown() = fake.server.shutdown()

    private suspend fun provision(uid: String = "acc-1", server: String = url) =
        sm.provision(server, true, "user@example.com", "secret-pass", uid)

    @Test
    fun `provision stores credentials and reports state`() = runTest {
        assertFalse(sm.state().provisioned)
        provision()
        assertEquals(SessionState(true, url, "acc-1", false), sm.state())
        assertEquals(StoredCredentials(url, "user@example.com", "secret-pass"), sm.credentials())
    }

    @Test
    fun `same account keeps cache and log, re-enables login`() = runTest {
        provision()
        vault.update { it.copy(boardJson = "{}", autoLoginDisabled = true, loginBackoffUntilMillis = 5) }
        core.changeLog.append("a", 2)

        provision()

        val d = vault.read()
        assertNotNull(d.boardJson)
        assertEquals(1, d.changes.size)
        assertFalse(d.autoLoginDisabled)
        assertEquals(0L, d.loginBackoffUntilMillis)
    }

    @Test
    fun `provision resets state when the account changes`() = runTest {
        provision()
        vault.update { it.copy(boardJson = "{}", boardAtMillis = 9, nativeCookies = listOf("tududi.sid=x"), autoLoginDisabled = true, loginBackoffUntilMillis = 5) }
        core.changeLog.append("a", 2)

        provision(uid = "acc-2")

        val d = vault.read()
        assertNull(d.boardJson)
        assertTrue(d.nativeCookies.isEmpty())
        assertTrue(d.changes.isEmpty())
        assertEquals(0L, d.lastChangeSeq)
        assertFalse(d.autoLoginDisabled)
        assertEquals(0L, d.loginBackoffUntilMillis)
        assertEquals("acc-2", d.accountUid)
    }

    @Test
    fun `provision resets state when the server changes`() = runTest {
        provision()
        vault.update { it.copy(boardJson = "{}") }
        provision(server = "http://127.0.0.1:1/")
        assertNull(vault.read().boardJson)
    }

    @Test
    fun `http is refused without allowInsecureHttp`() = runTest {
        try {
            sm.provision("http://192.168.1.5:3002", false, "u@e.com", "pw", "acc")
            fail("expected ProvisionException")
        } catch (_: ProvisionException) {
        }
        assertEquals(VaultData(), vault.read())
        // https is fine; http is fine once confirmed.
        sm.provision("https://tududi.example.com", false, "u@e.com", "pw", "acc")
        sm.provision("http://192.168.1.5:3002", true, "u@e.com", "pw", "acc")
    }

    @Test
    fun `invalid url is rejected`() = runTest {
        try {
            sm.provision("not a url", true, "u@e.com", "pw", "acc")
            fail("expected ProvisionException")
        } catch (_: ProvisionException) {
        }
    }

    @Test
    // runBlocking, not runTest: the logout is real IO under a 5 s timeout, which virtual time would skip.
    fun `clear logs out with the native cookie and wipes everything`() = runBlocking {
        provision()
        core.repository.refresh()
        core.changeLog.append("a", 2)
        sm.writeFlutterCookies("h", listOf("c=1"))

        sm.clear()

        assertEquals(1, fake.logoutCount)
        assertTrue(fake.lastLogoutCookie!!.contains("tududi.sid=sid-1"))
        assertEquals(VaultData(), vault.read())
        assertFalse(sm.state().provisioned)
    }

    @Test
    fun `clear still wipes when the server is unreachable`() = runTest {
        provision()
        fake.server.shutdown()
        sm.clear()
        assertEquals(VaultData(), vault.read())
    }

    @Test
    fun `flutter cookies are stored per host`() = runTest {
        sm.writeFlutterCookies("a.example", listOf("x=1", "y=2"))
        sm.writeFlutterCookies("b.example", listOf("z=3"))
        assertEquals(listOf("x=1", "y=2"), sm.readFlutterCookies("a.example"))
        sm.writeFlutterCookies("a.example", emptyList())
        assertTrue(sm.readFlutterCookies("a.example").isEmpty())
        assertEquals(listOf("z=3"), sm.readFlutterCookies("b.example"))
    }
}
