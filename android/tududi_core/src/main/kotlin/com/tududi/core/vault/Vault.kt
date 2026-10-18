package com.tududi.core.vault

import kotlinx.coroutines.flow.Flow

/** Encrypted key store for credentials, cookies, the board cache and the widget change log. */
interface Vault {
    /** Emits the current data and every later change. */
    val data: Flow<VaultData>

    suspend fun read(): VaultData

    /** Atomically applies [transform] and returns the new value. */
    suspend fun update(transform: (VaultData) -> VaultData): VaultData

    /** Resets to an empty [VaultData]. */
    suspend fun clear()
}
