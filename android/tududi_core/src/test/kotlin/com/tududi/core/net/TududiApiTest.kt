package com.tududi.core.net

import com.tududi.core.FakeTududi
import com.tududi.core.data.TaskStatus
import com.tududi.core.provisionedVault
import com.tududi.core.vault.InMemoryVault
import com.tududi.core.vault.VaultData
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class TududiApiTest {
    private val fake = FakeTududi()
    private val vault = provisionedVault(fake)
    private val api = TududiApi(vault, HttpFactory.create(vault))

    @After
    fun tearDown() = fake.server.shutdown()

    @Test
    fun `login persists only the session cookie`() = runTest {
        api.login("user@example.com", "secret-pass")

        val cookies = vault.read().nativeCookies
        assertEquals(1, cookies.size)
        assertTrue(cookies.single().startsWith("tududi.sid=sid-1"))
        assertTrue(cookies.none { it.contains("secret-pass") })
    }

    @Test
    fun `fetches today view with session cookie and expected query`() = runTest {
        api.login("user@example.com", "secret-pass")
        val body = api.fetchToday()

        assertTrue(body.contains("Task A"))
        val req = fake.requests.last()
        assertEquals("/api/tasks?type=today&include_lists=true", req.path)
        assertTrue(req.getHeader("Cookie")!!.contains("tududi.sid=sid-1"))
    }

    @Test
    fun `mutations send csrf token from csrf endpoint`() = runTest {
        api.login("user@example.com", "secret-pass")
        api.setStatus("a1", TaskStatus.DONE)
        api.setStatus("a2", TaskStatus.DONE)

        val patch = fake.requests.first { it.method == "PATCH" }
        assertEquals("/api/task/a1", patch.path)
        assertEquals("csrf-1", patch.getHeader("x-csrf-token"))
        assertEquals("""{"status":2}""", patch.body.readUtf8())
        // Token is cached: one csrf fetch for two mutations; login itself sends none.
        assertEquals(1, fake.requests.count { it.path == "/api/csrf-token" })
        assertNull(fake.requests.first { it.path == "/api/login" }.getHeader("x-csrf-token"))
    }

    @Test
    fun `uncomplete clears completed_at`() = runTest {
        api.login("user@example.com", "secret-pass")
        api.setStatus("a1", TaskStatus.NOT_STARTED)
        assertEquals("""{"status":0,"completed_at":null}""", fake.requests.first { it.method == "PATCH" }.body.readUtf8())
    }

    @Test
    fun `stale csrf token is refreshed once on 403`() = runTest {
        api.login("user@example.com", "secret-pass")
        api.setStatus("a1", TaskStatus.DONE)
        fake.rotateCsrf("sid-1")

        api.setStatus("a1", TaskStatus.DONE)

        assertEquals(2, fake.requests.count { it.path == "/api/csrf-token" })
    }

    @Test
    fun `wrong password maps to InvalidCredentials`() = runTest {
        try {
            api.login("user@example.com", "wrong")
            fail("expected exception")
        } catch (e: ApiException.InvalidCredentials) {
            assertTrue(vault.read().nativeCookies.isEmpty())
        }
    }

    @Test
    fun `missing session maps to Unauthorized`() = runTest {
        try {
            api.fetchToday()
            fail("expected exception")
        } catch (_: ApiException.Unauthorized) {
        }
    }

    @Test
    fun `unreachable host maps to Unreachable`() = runTest {
        val deadVault = InMemoryVault(VaultData(serverUrl = "http://127.0.0.1:9/", allowInsecureHttp = true))
        val dead = TududiApi(deadVault, HttpFactory.create(deadVault))
        try {
            dead.fetchToday()
            fail("expected exception")
        } catch (_: ApiException.Unreachable) {
        }
    }

    @Test
    fun `429 maps to RateLimited with retry-after`() = runTest {
        fake.lockoutAfterBadLogins = 1
        fake.retryAfterSeconds = 60
        try {
            api.login("user@example.com", "wrong")
            fail("expected InvalidCredentials")
        } catch (_: ApiException.InvalidCredentials) {
        }
        try {
            api.login("user@example.com", "secret-pass")
            fail("expected RateLimited")
        } catch (e: ApiException.RateLimited) {
            assertEquals(60L, e.retryAfterSeconds)
        }
    }

    @Test
    fun `password is never sent over http unless allowed`() = runTest {
        vault.update { it.copy(allowInsecureHttp = false) }
        try {
            api.login("user@example.com", "secret-pass")
            fail("expected InsecureTransport")
        } catch (_: ApiException.InsecureTransport) {
        }
        assertTrue(fake.requests.isEmpty())
    }

    @Test
    fun `base url is read from the vault at call time`() = runTest {
        val unprovisioned = InMemoryVault()
        val a = TududiApi(unprovisioned, HttpFactory.create(unprovisioned))
        try {
            a.fetchToday()
            fail("expected Unauthorized")
        } catch (_: ApiException.Unauthorized) {
        }
        unprovisioned.update { it.copy(serverUrl = fake.url().toString(), allowInsecureHttp = true) }
        a.login("user@example.com", "secret-pass")
        assertTrue(a.fetchToday().contains("Task A"))
    }

    @Test
    fun `logout is best effort`() = runTest {
        api.login("user@example.com", "secret-pass")
        api.logout()
        assertEquals(1, fake.logoutCount)
        fake.server.shutdown()
        api.logout() // unreachable: must not throw
    }
}
