package com.tududi.core.data

import com.tududi.core.net.ApiException
import com.tududi.core.net.TududiApi
import com.tududi.core.sync.ChangeLog
import com.tududi.core.vault.Vault
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.LocalDate
import java.util.concurrent.CopyOnWriteArrayList

data class Credentials(val email: String, val password: String) {
    val isUsable: Boolean get() = email.isNotBlank() && password.isNotBlank()
    override fun toString(): String = "Credentials(<redacted>)"
}

enum class ConnectionStatus { IDLE, OK, LOGGED_OUT, LOGIN_FAILED, OFFLINE, ERROR }

data class BoardState(
    val board: TodayBoard? = null,
    val status: ConnectionStatus = ConnectionStatus.IDLE,
    val message: String? = null,
    val loading: Boolean = false,
    val updatedAtMillis: Long = 0,
) {
    val isSignedOut: Boolean
        get() = status == ConnectionStatus.LOGGED_OUT || status == ConnectionStatus.LOGIN_FAILED
}

/** Called after any successful refresh or mutation (used to update widgets). */
fun interface ChangeListener {
    suspend fun onChanged()
}

/**
 * Single source of truth for the widget. Credentials, cookies, the cache and backoff state all
 * live in the [vault]. A silent re-login happens only after the server answered 401, at most once
 * per operation, and never while a login backoff (HTTP 429) or `autoLoginDisabled` is in force.
 */
class TaskRepository(
    private val api: TududiApi,
    private val vault: Vault,
    private val boardCache: BoardCache,
    private val changeLog: ChangeLog,
    private val today: () -> LocalDate = { LocalDate.now() },
    private val clock: () -> Long = { System.currentTimeMillis() },
) {
    // Serialises every operation, so only one login can ever be in flight.
    private val mutex = Mutex()
    private val _state = MutableStateFlow(BoardState())
    val state: StateFlow<BoardState> = _state.asStateFlow()

    private val listeners = CopyOnWriteArrayList<ChangeListener>()
    private var cacheLoaded = false

    fun addOnChangedListener(listener: ChangeListener) {
        listeners.addIfAbsent(listener)
    }

    fun removeOnChangedListener(listener: ChangeListener) {
        listeners.remove(listener)
    }

    private suspend fun notifyChanged() {
        for (l in listeners) runCatching { l.onChanged() }
    }

    /** Loads the cached board into [state] (once); called implicitly by every operation. */
    suspend fun restoreCache() {
        mutex.withLock { ensureCacheLoaded() }
    }

    private suspend fun ensureCacheLoaded() {
        if (cacheLoaded) return
        cacheLoaded = true
        val cached = boardCache.load() ?: return
        val board = runCatching { TaskMapper.parseBoard(cached.json, today()) }.getOrNull() ?: return
        _state.update { if (it.board == null) it.copy(board = board, updatedAtMillis = cached.atMillis) else it }
    }

    suspend fun refresh(): BoardState {
        mutex.withLock {
            ensureCacheLoaded()
            _state.update { it.copy(loading = true) }
            runCatching { authed { api.fetchToday() } }
                .onSuccess { applyBoard(it) }
                .onFailure { fail(it) }
        }
        notifyChanged()
        return state.value
    }

    /**
     * Drops the in-memory board and re-reads the vault cache on next use. Called after the vault
     * changed underneath the repository (provision, clear), so another account's tasks never linger.
     */
    suspend fun reset() {
        mutex.withLock {
            cacheLoaded = false
            _state.value = BoardState()
        }
    }

    /** Refreshes unless fresh data is already present; used by widget updates to avoid loops. */
    suspend fun refreshIfStale(maxAgeMillis: Long = 60_000): BoardState {
        val s = state.value
        val fresh = s.status == ConnectionStatus.OK && clock() - s.updatedAtMillis < maxAgeMillis
        return if (fresh || s.loading) s else refresh()
    }

    /** Optimistic toggle with rollback when the server request fails (including offline). */
    suspend fun setDone(uid: String, done: Boolean): Boolean {
        restoreCache()
        _state.update { s -> s.copy(board = s.board?.let { toggleLocally(it, uid, done) }) }
        val status = if (done) TaskStatus.DONE else TaskStatus.NOT_STARTED
        val ok = mutex.withLock {
            runCatching { authed { api.setStatus(uid, status) } }
                .onFailure { fail(it) }
                .isSuccess
                // Only a server-confirmed PATCH is recorded for the Flutter reconciler.
                .also { if (it) changeLog.append(uid, status.code) }
        }
        if (ok) {
            refresh()
        } else {
            _state.update { s -> s.copy(board = s.board?.let { toggleLocally(it, uid, !done) }) }
            notifyChanged()
        }
        return ok
    }

    /** Re-enables silent sign-in (clears `autoLoginDisabled`) and retries. */
    suspend fun retryLogin(): BoardState {
        vault.update { it.copy(autoLoginDisabled = false) }
        return refresh()
    }

    /** Runs [block]; on 401 logs in again once and retries it once. */
    private suspend fun <T> authed(block: suspend () -> T): T =
        try {
            block()
        } catch (e: ApiException.Unauthorized) {
            vault.update { it.copy(nativeCookies = emptyList()) }
            login()
            block()
        }

    private suspend fun login() {
        val d = vault.read()
        if (d.autoLoginDisabled || !d.hasCredentials) throw ApiException.Unauthorized()
        val now = clock()
        if (now < d.loginBackoffUntilMillis) {
            throw ApiException.RateLimited((d.loginBackoffUntilMillis - now + 999) / 1000)
        }
        try {
            api.login(d.email.trim(), d.password)
        } catch (e: ApiException.InvalidCredentials) {
            // Don't retry rejected credentials on every widget update (login is rate limited).
            vault.update { it.copy(autoLoginDisabled = true) }
            throw e
        } catch (e: ApiException.RateLimited) {
            vault.update { it.copy(loginBackoffUntilMillis = clock() + LOGIN_BACKOFF_MILLIS) }
            throw e
        }
    }

    private suspend fun applyBoard(body: String) {
        val board = TaskMapper.parseBoard(body, today())
        val now = clock()
        boardCache.save(body, now)
        _state.value = BoardState(board = board, status = ConnectionStatus.OK, updatedAtMillis = now)
    }

    private suspend fun fail(e: Throwable) {
        val status = when (e) {
            is ApiException.Unauthorized -> ConnectionStatus.LOGGED_OUT
            is ApiException.InvalidCredentials -> ConnectionStatus.LOGIN_FAILED
            is ApiException.Unreachable -> ConnectionStatus.OFFLINE
            else -> ConnectionStatus.ERROR
        }
        if (status == ConnectionStatus.LOGGED_OUT || status == ConnectionStatus.LOGIN_FAILED) {
            vault.update { it.copy(nativeCookies = emptyList()) }
        }
        val message = when (e) {
            is ApiException.Server -> e.message
            is ApiException.RateLimited -> "Rate limited"
            is ApiException.InsecureTransport -> e.message
            else -> null
        }
        _state.update {
            it.copy(
                status = status,
                message = message,
                loading = false,
                // Keep cached tasks visible while offline/erroring; hide them when signed out.
                board = if (status == ConnectionStatus.OFFLINE || status == ConnectionStatus.ERROR) it.board else null,
            )
        }
    }

    private fun toggleLocally(board: TodayBoard, uid: String, done: Boolean): TodayBoard {
        val task = (board.open + board.done).firstOrNull { it.uid == uid } ?: return board
        val updated = task.copy(status = if (done) TaskStatus.DONE else TaskStatus.NOT_STARTED)
        val open = board.open.filterNot { it.uid == uid } + listOfNotNull(updated.takeIf { !done })
        val doneList = board.done.filterNot { it.uid == uid } + listOfNotNull(updated.takeIf { done })
        return TodayBoard(open = open, overdue = open.filter { it.isOverdue(today()) }, done = doneList)
    }

    companion object {
        const val LOGIN_BACKOFF_MILLIS = 15 * 60 * 1000L
    }
}
