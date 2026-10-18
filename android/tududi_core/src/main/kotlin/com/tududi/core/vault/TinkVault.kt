package com.tududi.core.vault

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.core.DataStoreFactory
import androidx.datastore.core.handlers.ReplaceFileCorruptionHandler
import com.google.crypto.tink.Aead
import com.google.crypto.tink.KeyTemplates
import com.google.crypto.tink.RegistryConfiguration
import com.google.crypto.tink.aead.AeadConfig
import com.google.crypto.tink.integration.android.AndroidKeysetManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import java.io.File

/** [Cipher] backed by a Tink AES256-GCM AEAD. */
class TinkCipher(private val aead: Aead) : Cipher {
    override fun encrypt(plain: ByteArray, associatedData: ByteArray): ByteArray =
        aead.encrypt(plain, associatedData)

    override fun decrypt(encrypted: ByteArray, associatedData: ByteArray): ByteArray =
        aead.decrypt(encrypted, associatedData)
}

/**
 * Process-wide encrypted [Vault]. The AES256-GCM keyset is wrapped by an Android Keystore master
 * key (`android-keystore://tududa_vault`) and kept in a private SharedPreferences file; the data
 * lives in a DataStore file whose serializer encrypts with that keyset.
 *
 * There must be only one DataStore per file per process, hence the singleton [get].
 */
object TinkVault {
    const val MASTER_KEY_URI = "android-keystore://tududa_vault"
    const val FILE_NAME = "tududa_vault.pb"
    private const val KEYSET_NAME = "tududa_vault_keyset"
    private const val KEYSET_PREFS = "tududa_vault_keyset_prefs"

    @Volatile
    private var instance: Vault? = null

    fun get(context: Context): Vault =
        instance ?: synchronized(this) {
            instance ?: create(context.applicationContext).also { instance = it }
        }

    private fun create(context: Context): Vault {
        AeadConfig.register()
        val handle = AndroidKeysetManager.Builder()
            .withSharedPref(context, KEYSET_NAME, KEYSET_PREFS)
            .withKeyTemplate(KeyTemplates.get("AES256_GCM"))
            .withMasterKeyUri(MASTER_KEY_URI)
            .build()
            .keysetHandle
        val aead = handle.getPrimitive(RegistryConfiguration.get(), Aead::class.java)
        val store: DataStore<VaultData> = DataStoreFactory.create(
            serializer = VaultSerializer(TinkCipher(aead), FILE_NAME),
            // Unreadable vault (e.g. restored on another device, key lost): start empty.
            corruptionHandler = ReplaceFileCorruptionHandler { VaultData() },
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
            produceFile = { File(context.filesDir, "datastore/$FILE_NAME") },
        )
        return DataStoreVault(store)
    }
}
