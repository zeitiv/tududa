package com.tududi.core.data

import com.tududi.core.FakeTududi
import com.tududi.core.net.HttpFactory
import com.tududi.core.net.TududiApi
import com.tududi.core.provisionedVault
import com.tududi.core.sync.ChangeLog
import com.tududi.core.vault.InMemoryVault
import com.tududi.core.vault.Vault
import com.tududi.core.vault.VaultData
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.util.concurrent.atomic.AtomicInteger

class TaskRepositoryTest {
    private val fake = FakeTududi()
    private val vault = provisionedVault(fake)
    private val today = LocalDate.of(2026, 10, 18)
    private var now = 1_000_000L

    private fun repo(v: Vault = vault): TaskRepository {
        val log = ChangeLog(v) { now }
        return TaskRepository(TududiApi(v, HttpFactory.create(v)), v, BoardCache(v), log, { today }, { now })
    }

    @After
    fun tearDown() = fake.server.shutdown()

    @Test
    fun `first refresh logs in after a 401 and caches board`() = runTest {
        val state = repo().refresh()

        assertEquals(ConnectionStatus.OK, state.status)
        assertEquals(listOf("Task A"), state.board!!.open.map { it.name })
        assertEquals(1, fake.loginCount)
        assertNotNull(vault.read().boardJson)
    }

    @Test
    fun `persisted session is reused across instances`() = runTest {
        repo().refresh()
        repo().refresh()
        assertEquals(1, fake.loginCount)
    }

    @Test
    fun `expired session triggers a single re-login`() = runTest {
        val r = repo()
        r.refresh()
        fake.expireAllSessions()

        val state = r.refresh()

        assertEquals(ConnectionStatus.OK, state.status)
        assertEquals(2, fake.loginCount)
    }

    @Test
    fun `no login is attempted without a 401`() = runTest {
        repo().refresh()
        repo().refresh()
        repo().refresh()
        assertEquals(1, fake.loginCount)
    }

    @Test
    fun `rejected credentials disable auto login until retried`() = runTest {
        val v = provisionedVault(fake, password = "wrong")
        val r = repo(v)

        assertEquals(ConnectionStatus.LOGIN_FAILED, r.refresh().status)
        assertEquals(ConnectionStatus.LOGGED_OUT, r.refresh().status)
        assertEquals(1, fake.loginCount) // no hammering of the rate-limited login
        assertTrue(v.read().autoLoginDisabled)

        r.retryLogin()
        assertEquals(2, fake.loginCount)
    }

    @Test
    fun `without credentials or BuildConfig the state is logged out and nothing is sent to a login`() = runTest {
        val empty = InMemoryVault(VaultData(serverUrl = fake.url().toString(), allowInsecureHttp = true))
        val r = repo(empty)
        assertEquals(ConnectionStatus.LOGGED_OUT, r.refresh().status)
        assertTrue(r.state.value.isSignedOut)
        assertEquals(0, fake.loginCount)
    }

    @Test
    fun `unprovisioned vault is logged out without any request`() = runTest {
        val r = repo(InMemoryVault())
        assertEquals(ConnectionStatus.LOGGED_OUT, r.refresh().status)
        assertTrue(fake.requests.isEmpty())
    }

    @Test
    fun `completing a task refreshes the board and logs a confirmed change`() = runTest {
        val r = repo()
        r.refresh()
        fake.todayBody = """{"tasks":[{"uid":"a1","name":"Task A","status":2}]}"""

        assertTrue(r.setDone("a1", true))
        assertEquals(listOf("a1"), r.state.value.board!!.done.map { it.uid })

        val changes = ChangeLog(vault).since(0)
        assertEquals(1, changes.size)
        assertEquals("a1", changes.single().uid)
        assertEquals(2, changes.single().status)
    }

    @Test
    fun `offline keeps cached tasks and reports offline`() = runTest {
        repo().refresh()
        val offlineVault = InMemoryVault(vault.read().copy(serverUrl = "http://127.0.0.1:9/"))
        val offline = repo(offlineVault)

        val state = offline.refresh()

        assertEquals(ConnectionStatus.OFFLINE, state.status)
        assertEquals(listOf("Task A"), state.board!!.open.map { it.name })
    }

    @Test
    fun `failed toggle is reverted and not logged`() = runTest {
        val r = repo()
        r.refresh()
        fake.server.shutdown()

        assertFalse(r.setDone("a1", true))
        assertEquals(listOf("a1"), r.state.value.board!!.open.map { it.uid })
        assertEquals(ConnectionStatus.OFFLINE, r.state.value.status)
        assertTrue(ChangeLog(vault).since(0).isEmpty())
    }

    @Test
    fun `toggle after a 401 re-logins silently and the PATCH carries csrf`() = runTest {
        val r = repo()
        r.refresh()
        fake.expireAllSessions()

        assertTrue(r.setDone("a1", true))

        assertEquals(2, fake.loginCount)
        val patch = fake.requests.last { it.method == "PATCH" }
        assertEquals("csrf-2", patch.getHeader("x-csrf-token"))
    }

    @Test
    fun `429 on login starts a 15 minute backoff that suppresses login attempts`() = runTest {
        val r = repo()
        fake.lockoutAfterBadLogins = 1
        // Burn the lockout with a wrong password via another vault copy.
        val bad = repo(provisionedVault(fake, password = "wrong"))
        bad.refresh()
        assertTrue(fake.lockedOut())
        val loginsBefore = fake.loginCount

        assertEquals(ConnectionStatus.ERROR, r.refresh().status) // 401 -> login -> 429
        assertEquals(loginsBefore + 1, fake.loginCount)
        assertEquals(now + TaskRepository.LOGIN_BACKOFF_MILLIS, vault.read().loginBackoffUntilMillis)

        now += 60_000
        assertEquals(ConnectionStatus.ERROR, r.refresh().status)
        assertEquals(loginsBefore + 1, fake.loginCount) // suppressed

        now += TaskRepository.LOGIN_BACKOFF_MILLIS
        fake.lockoutAfterBadLogins = 0
        assertEquals(ConnectionStatus.OK, r.refresh().status)
    }

    @Test
    fun `all listeners are notified and removed listeners are not`() = runTest {
        val r = repo()
        val a = AtomicInteger()
        val b = AtomicInteger()
        val la = ChangeListener { a.incrementAndGet() }
        val lb = ChangeListener { b.incrementAndGet() }
        r.addOnChangedListener(la)
        r.addOnChangedListener(lb)

        r.refresh()
        assertEquals(1, a.get())
        assertEquals(1, b.get())

        r.removeOnChangedListener(la)
        r.refresh()
        assertEquals(1, a.get())
        assertEquals(2, b.get())
    }

    @Test
    fun `credentials never appear in toString`() {
        assertFalse(Credentials("user@example.com", "secret-pass").toString().contains("secret"))
    }
}
