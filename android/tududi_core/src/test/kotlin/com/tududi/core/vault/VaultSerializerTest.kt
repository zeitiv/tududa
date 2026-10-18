package com.tududi.core.vault

import androidx.datastore.core.CorruptionException
import androidx.datastore.core.DataStoreFactory
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream

/** XOR "cipher" with an authentication tag; good enough to test the plumbing, not the crypto. */
class FakeCipher : Cipher {
    override fun encrypt(plain: ByteArray, associatedData: ByteArray): ByteArray {
        val body = plain.map { (it.toInt() xor 0x5A).toByte() }.toByteArray()
        return tag(body, associatedData) + body
    }

    override fun decrypt(encrypted: ByteArray, associatedData: ByteArray): ByteArray {
        require(encrypted.size >= 4) { "too short" }
        val body = encrypted.copyOfRange(4, encrypted.size)
        require(encrypted.copyOfRange(0, 4).contentEquals(tag(body, associatedData))) { "bad tag" }
        return body.map { (it.toInt() xor 0x5A).toByte() }.toByteArray()
    }

    private fun tag(body: ByteArray, aad: ByteArray): ByteArray {
        val h = (body.contentHashCode() * 31) xor aad.contentHashCode()
        return byteArrayOf((h shr 24).toByte(), (h shr 16).toByte(), (h shr 8).toByte(), h.toByte())
    }
}

class VaultSerializerTest {
    @get:Rule
    val tmp = TemporaryFolder()

    private val sample = VaultData(
        serverUrl = "https://tududi.example.com",
        email = "user@example.com",
        password = "hunter2-very-secret",
        accountUid = "acc-1",
        nativeCookies = listOf("tududi.sid=abc"),
        flutterCookies = mapOf("tududi.example.com" to listOf("tududi.sid=def")),
        boardJson = """{"tasks":[]}""",
        loginBackoffUntilMillis = 42,
    )

    private fun encode(serializer: VaultSerializer, data: VaultData): ByteArray =
        ByteArrayOutputStream().also { out -> runBlocking { serializer.writeTo(data, out) } }
            .toByteArray()

    @Test
    fun `round trips with a fake cipher`() = runTest {
        val s = VaultSerializer(FakeCipher(), "vault.pb")
        val bytes = encode(s, sample)
        assertEquals(sample, s.readFrom(ByteArrayInputStream(bytes)))
    }

    @Test
    fun `empty file decodes to defaults`() = runTest {
        val s = VaultSerializer(FakeCipher(), "vault.pb")
        assertEquals(VaultData(), s.readFrom(ByteArrayInputStream(ByteArray(0))))
    }

    @Test
    fun `password never appears in plaintext in the stored bytes`() {
        val s = VaultSerializer(FakeCipher(), "vault.pb")
        val bytes = encode(s, sample)
        val text = String(bytes, Charsets.ISO_8859_1)
        assertFalse(text.contains("hunter2"))
        assertFalse(text.contains("user@example.com"))
        assertFalse(text.contains("tududi.sid"))
    }

    @Test
    fun `tampered bytes fail to decode`() = runTest {
        val s = VaultSerializer(FakeCipher(), "vault.pb")
        val bytes = encode(s, sample)
        bytes[bytes.size / 2] = (bytes[bytes.size / 2].toInt() xor 1).toByte()
        try {
            s.readFrom(ByteArrayInputStream(bytes))
            fail("expected CorruptionException")
        } catch (_: CorruptionException) {
        }
    }

    @Test
    fun `blob is bound to its file name`() = runTest {
        val bytes = encode(VaultSerializer(FakeCipher(), "vault.pb"), sample)
        try {
            VaultSerializer(FakeCipher(), "other.pb").readFrom(ByteArrayInputStream(bytes))
            fail("expected CorruptionException")
        } catch (_: CorruptionException) {
        }
    }

    @Test
    fun `datastore vault persists across instances and clears`() = runBlocking {
        val file = tmp.newFolder().resolve("vault.pb")
        fun open(scope: CoroutineScope) = DataStoreVault(
            DataStoreFactory.create(VaultSerializer(FakeCipher(), "vault.pb"), scope = scope) { file },
        )

        val scope1 = CoroutineScope(Job())
        open(scope1).update { sample }
        scope1.cancel() // the single DataStore per file must be gone before reopening
        assertTrue(file.length() > 0)
        assertFalse(String(file.readBytes(), Charsets.ISO_8859_1).contains("hunter2"))

        val scope2 = CoroutineScope(Job())
        val v = open(scope2)
        assertEquals(sample, v.read())
        v.clear()
        assertEquals(VaultData(), v.read())
        scope2.cancel()
    }
}
