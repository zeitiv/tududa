package com.tududi.core.data

import com.tududi.core.vault.Vault

/** Last Today response, stored inside the encrypted [Vault] (task titles are private data). */
class BoardCache(private val vault: Vault) {
    data class Entry(val json: String, val atMillis: Long)

    suspend fun load(): Entry? {
        val d = vault.read()
        return d.boardJson?.let { Entry(it, d.boardAtMillis) }
    }

    suspend fun save(json: String, atMillis: Long) {
        vault.update { it.copy(boardJson = json, boardAtMillis = atMillis) }
    }

    suspend fun clear() {
        vault.update { it.copy(boardJson = null, boardAtMillis = 0) }
    }
}
