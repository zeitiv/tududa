package com.tududi.core

import com.tududi.core.data.Credentials
import com.tududi.core.session.StoredCredentials
import com.tududi.core.vault.VaultData
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CredentialRedactionTest {
    private val secret = "hunter2-very-secret"

    @Test
    fun `credential types never print the password`() {
        assertFalse(Credentials("u@e.com", secret).toString().contains(secret))
        assertFalse(StoredCredentials("https://x", "u@e.com", secret).toString().contains(secret))
    }

    @Test
    fun `vault data never prints password, cookies or cached tasks`() {
        val text = VaultData(
            serverUrl = "https://x",
            email = "u@e.com",
            password = secret,
            nativeCookies = listOf("tududi.sid=cookie-secret"),
            flutterCookies = mapOf("h" to listOf("tududi.sid=flutter-secret")),
            boardJson = "private task title",
        ).toString()
        assertFalse(text.contains(secret))
        assertFalse(text.contains("cookie-secret"))
        assertFalse(text.contains("flutter-secret"))
        assertFalse(text.contains("private task"))
        assertTrue(text.contains("redacted"))
    }
}
