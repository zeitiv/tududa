package com.tududi.core.vault

import androidx.datastore.core.DataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first

/** [Vault] on top of a `DataStore<VaultData>` (whose serializer encrypts). */
class DataStoreVault(private val store: DataStore<VaultData>) : Vault {
    override val data: Flow<VaultData> get() = store.data

    override suspend fun read(): VaultData = store.data.first()

    override suspend fun update(transform: (VaultData) -> VaultData): VaultData =
        store.updateData(transform)

    override suspend fun clear() {
        store.updateData { VaultData() }
    }
}
