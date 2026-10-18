package com.tududi.core.vault

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update

/** Non-persistent [Vault] for tests and previews. */
class InMemoryVault(initial: VaultData = VaultData()) : Vault {
    private val state = MutableStateFlow(initial)

    override val data: Flow<VaultData> get() = state

    override suspend fun read(): VaultData = state.value

    override suspend fun update(transform: (VaultData) -> VaultData): VaultData {
        var result: VaultData? = null
        state.update { transform(it).also { next -> result = next } }
        return result!!
    }

    override suspend fun clear() {
        state.value = VaultData()
    }
}
