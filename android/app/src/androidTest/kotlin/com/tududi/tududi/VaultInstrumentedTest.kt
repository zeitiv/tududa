package com.tududi.tududi

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.google.crypto.tink.Aead
import com.google.crypto.tink.KeyTemplates
import com.google.crypto.tink.RegistryConfiguration
import com.google.crypto.tink.aead.AeadConfig
import com.google.crypto.tink.integration.android.AndroidKeysetManager
import com.tududi.core.vault.TinkCipher
import com.tududi.core.vault.TinkVault
import com.tududi.core.vault.VaultSerializer
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File

/**
 * Real Android Keystore + Tink + DataStore. Run on a device/emulator:
 * `./gradlew :app:connectedDebugAndroidTest` (clears the app's vault, so use a test device).
 */
class VaultInstrumentedTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val vault = TinkVault.get(context)

    @Before
    fun clean() = runBlocking { vault.clear() }

    @After
    fun wipe() = runBlocking { vault.clear() }

    @Test
    fun roundTripThroughTheKeystoreBackedVault() = runBlocking {
        vault.update { it.copy(serverUrl = "https://t.example.com", email = "me@example.com", password = "pw-123", flutterCookies = mapOf("h" to listOf("a=1"))) }

        val read = vault.read()
        assertEquals("https://t.example.com", read.serverUrl)
        assertEquals("pw-123", read.password)
        assertEquals(listOf("a=1"), read.flutterCookies["h"])
    }

    @Test
    fun fileIsEncryptedAndReadableWithAFreshKeysetHandle() = runBlocking {
        vault.update { it.copy(email = "me@example.com", password = "plain-needle-9") }
        val file = File(context.filesDir, "datastore/${TinkVault.FILE_NAME}")
        assertTrue(file.exists())
        val bytes = file.readBytes()
        assertFalse(String(bytes, Charsets.ISO_8859_1).contains("plain-needle-9"))

        // "Restart": a second keyset handle from the persisted keyset + the Keystore master key
        // must decrypt what the first one wrote.
        AeadConfig.register()
        val aead = AndroidKeysetManager.Builder()
            .withSharedPref(context, "tududa_vault_keyset", "tududa_vault_keyset_prefs")
            .withKeyTemplate(KeyTemplates.get("AES256_GCM"))
            .withMasterKeyUri(TinkVault.MASTER_KEY_URI)
            .build()
            .keysetHandle
            .getPrimitive(RegistryConfiguration.get(), Aead::class.java)
        val restored = VaultSerializer(TinkCipher(aead), TinkVault.FILE_NAME).readFrom(bytes.inputStream())
        assertEquals("plain-needle-9", restored.password)
    }

    @Test
    fun clearEmptiesTheVault() = runBlocking {
        vault.update { it.copy(email = "me@example.com", password = "pw", boardJson = "{}") }
        vault.clear()
        assertEquals("", vault.read().password)
        assertEquals(null, vault.read().boardJson)
    }
}
