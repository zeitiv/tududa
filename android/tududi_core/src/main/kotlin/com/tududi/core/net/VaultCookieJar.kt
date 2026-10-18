package com.tududi.core.net

import com.tududi.core.vault.Vault
import kotlinx.coroutines.runBlocking
import okhttp3.Cookie
import okhttp3.CookieJar
import okhttp3.HttpUrl

/**
 * OkHttp cookie jar persisted in [Vault.read]`.nativeCookies`. Cookies are merged by name and
 * expired ones are dropped. OkHttp calls this on its own (non-main) threads, hence `runBlocking`.
 */
class VaultCookieJar(
    private val vault: Vault,
    private val clock: () -> Long = { System.currentTimeMillis() },
) : CookieJar {

    override fun saveFromResponse(url: HttpUrl, cookies: List<Cookie>) {
        if (cookies.isEmpty()) return
        val now = clock()
        runBlocking {
            vault.update { d ->
                val kept = parse(url, d.nativeCookies, now).filterNot { old -> cookies.any { it.name == old.name } }
                val merged = kept + cookies.filter { it.expiresAt > now }
                d.copy(nativeCookies = merged.map { it.toString() })
            }
        }
    }

    override fun loadForRequest(url: HttpUrl): List<Cookie> {
        val now = clock()
        val stored = runBlocking { vault.read().nativeCookies }
        return parse(url, stored, now).filter { it.matches(url) }
    }

    private fun parse(url: HttpUrl, raw: List<String>, now: Long): List<Cookie> =
        raw.mapNotNull { Cookie.parse(url, it) }.filter { it.expiresAt > now }
}
