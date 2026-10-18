package com.tududi.core

import android.content.Context
import com.tududi.core.data.BoardCache
import com.tududi.core.data.TaskRepository
import com.tududi.core.net.HttpFactory
import com.tududi.core.net.TududiApi
import com.tududi.core.session.SessionManager
import com.tududi.core.sync.ChangeLog
import com.tududi.core.vault.TinkVault
import com.tududi.core.vault.Vault
import okhttp3.OkHttpClient
import java.time.LocalDate

/** Object graph of the native core. Hold one instance per process ([from]). */
class TududiCore(
    val vault: Vault,
    val api: TududiApi,
    val boardCache: BoardCache,
    val changeLog: ChangeLog,
    val repository: TaskRepository,
    val sessionManager: SessionManager,
) {
    companion object {
        @Volatile
        private var instance: TududiCore? = null

        /** Process singleton on the Tink-encrypted vault. The only Android-specific entry point. */
        fun from(context: Context): TududiCore =
            instance ?: synchronized(this) {
                instance ?: create(TinkVault.get(context)).also { instance = it }
            }

        /** Builds the graph on any [vault] (tests use an in-memory one). */
        fun create(
            vault: Vault,
            client: OkHttpClient = HttpFactory.create(vault),
            today: () -> LocalDate = { LocalDate.now() },
            clock: () -> Long = { System.currentTimeMillis() },
        ): TududiCore {
            val api = TududiApi(vault, client)
            val cache = BoardCache(vault)
            val log = ChangeLog(vault, clock)
            return TududiCore(
                vault = vault,
                api = api,
                boardCache = cache,
                changeLog = log,
                repository = TaskRepository(api, vault, cache, log, today, clock),
                sessionManager = SessionManager(vault, api),
            )
        }
    }
}
