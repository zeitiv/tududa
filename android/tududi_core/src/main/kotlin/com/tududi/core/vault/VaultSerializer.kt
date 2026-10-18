package com.tududi.core.vault

import androidx.datastore.core.CorruptionException
import androidx.datastore.core.Serializer
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import java.io.InputStream
import java.io.OutputStream

/** Authenticated encryption of byte arrays. Kept tiny so tests can substitute a fake. */
interface Cipher {
    fun encrypt(plain: ByteArray, associatedData: ByteArray): ByteArray

    /** Throws if the data was modified or [associatedData] differs. */
    fun decrypt(encrypted: ByteArray, associatedData: ByteArray): ByteArray
}

/**
 * DataStore serializer that stores [VaultData] as `cipher(json)`.
 * [fileName] is bound in as associated data, so the blob can't be swapped to another file.
 */
class VaultSerializer(
    private val cipher: Cipher,
    fileName: String,
) : Serializer<VaultData> {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val aad = fileName.toByteArray(Charsets.UTF_8)

    override val defaultValue: VaultData = VaultData()

    override suspend fun readFrom(input: InputStream): VaultData {
        val bytes = input.readBytes()
        if (bytes.isEmpty()) return defaultValue
        return try {
            json.decodeFromString(VaultData.serializer(), cipher.decrypt(bytes, aad).toString(Charsets.UTF_8))
        } catch (e: SerializationException) {
            throw CorruptionException("Cannot decode vault", e)
        } catch (e: Exception) {
            // AEAD failure (tampering, lost key, wrong file): surface as corruption.
            throw CorruptionException("Cannot decrypt vault", e)
        }
    }

    override suspend fun writeTo(t: VaultData, output: OutputStream) {
        val plain = json.encodeToString(VaultData.serializer(), t).toByteArray(Charsets.UTF_8)
        output.write(cipher.encrypt(plain, aad))
    }
}
