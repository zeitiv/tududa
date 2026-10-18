package com.tududi.core.sync

import com.tududi.core.vault.Vault
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.serialization.Serializable

/** A task status change the widget made and the server confirmed. */
@Serializable
data class WidgetChange(val seq: Long, val uid: String, val status: Int, val atMillis: Long)

/**
 * Append-only log of server-confirmed widget changes, for the Flutter side to reconcile.
 * Persisted inside the encrypted vault data (same atomic write as the sequence counter, wiped
 * together with the credentials). Sequence numbers only grow, even after [ack] empties the log.
 */
class ChangeLog(
    private val vault: Vault,
    private val clock: () -> Long = { System.currentTimeMillis() },
) {
    suspend fun append(uid: String, status: Int): WidgetChange {
        var added: WidgetChange? = null
        vault.update { d ->
            val change = WidgetChange(d.lastChangeSeq + 1, uid, status, clock())
            added = change
            d.copy(lastChangeSeq = change.seq, changes = (d.changes + change).takeLast(MAX_ENTRIES))
        }
        return added!!
    }

    suspend fun since(seq: Long): List<WidgetChange> = vault.read().changes.filter { it.seq > seq }

    /** Drops all entries with `seq <= seq`. */
    suspend fun ack(seq: Long) {
        vault.update { d -> d.copy(changes = d.changes.filter { it.seq > seq }) }
    }

    suspend fun latestSeq(): Long = vault.read().lastChangeSeq

    /** Emits the latest sequence number now and whenever it changes. */
    val latestSeqFlow: Flow<Long> get() = vault.data.map { it.lastChangeSeq }.distinctUntilChanged()

    companion object {
        const val MAX_ENTRIES = 1000
    }
}
