package com.tududi.core.net

import com.tududi.core.vault.Vault
import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit

object HttpFactory {
    /** Client whose session cookies live in [vault]. */
    fun create(vault: Vault, base: OkHttpClient = OkHttpClient()): OkHttpClient =
        base.newBuilder()
            .cookieJar(VaultCookieJar(vault))
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(20, TimeUnit.SECONDS)
            .writeTimeout(20, TimeUnit.SECONDS)
            .build()
}
