package ir.psdkjoon.pray

import android.content.BroadcastReceiver
import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Binder
import android.os.Handler
import android.os.Looper
import android.os.Process
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean
import org.json.JSONObject

object ThemeSync {
    const val ACTION_PROVIDER = "ir.psdkjoon.action.THEME_SYNC"
    const val ACTION_POKE = "ir.psdkjoon.action.THEME_SYNC_POKE"

    private const val FILE = "theme_sync.json"
    private const val SYNC_PROCESS = ":sync"

    data class State(val accent: String, val mode: String, val updatedAt: Long)

    private data class Stored(val enabled: Boolean, val state: State)

    private val lock = Any()
    private val worker by lazy { java.util.concurrent.Executors.newSingleThreadExecutor() }
    private val main = Handler(Looper.getMainLooper())

    fun isSyncProcess(): Boolean {
        return try {
            File("/proc/self/cmdline").readText().trimEnd('\u0000').endsWith(SYNC_PROCESS)
        } catch (_: Exception) {
            false
        }
    }

    fun publish(context: Context, enabled: Boolean, accent: String, mode: String, updatedAt: Long): State? {
        if (!valid(accent)) return null
        var fresh = false
        val result = synchronized(lock) {
            val previous = read(context)
            val known = previous?.state?.updatedAt ?: -1L
            val state = if (previous == null || updatedAt >= known) {
                State(accent, if (validMode(mode)) mode else "system", updatedAt)
            } else {
                previous.state
            }
            fresh = enabled && updatedAt > known && updatedAt > 0
            write(context, Stored(enabled, state))
            state
        }
        if (fresh) pokePeers(context)
        return if (enabled) result else null
    }

    fun pull(context: Context): State? {
        val own = synchronized(lock) { read(context) } ?: return null
        if (!own.enabled) return null
        var best = own.state
        for (peer in peers(context)) {
            val state = query(context, peer) ?: continue
            if (state.updatedAt > best.updatedAt) best = state
        }
        if (best.mode.isEmpty()) best = best.copy(mode = own.state.mode)
        if (best != own.state) {
            synchronized(lock) {
                val latest = read(context) ?: own
                if (best.updatedAt > latest.state.updatedAt) {
                    write(context, Stored(latest.enabled, best))
                }
            }
        }
        LauncherIcon.adoptSynced(best.accent, best.mode, best.updatedAt)
        return best
    }

    fun async(result: MethodChannel.Result, work: () -> Map<String, Any>?) {
        worker.execute {
            val value = try {
                work()
            } catch (_: Exception) {
                null
            }
            main.post { result.success(value) }
        }
    }

    fun toMap(state: State?): Map<String, Any>? {
        return state?.let { mapOf("accent" to it.accent, "mode" to it.mode, "updatedAt" to it.updatedAt) }
    }

    private fun peers(context: Context): List<String> {
        val pm = context.packageManager
        val found = try {
            @Suppress("DEPRECATION")
            pm.queryIntentContentProviders(Intent(ACTION_PROVIDER), 0)
        } catch (_: Exception) {
            return emptyList()
        }
        return found.mapNotNull { it.providerInfo }
            .filter { it.packageName != context.packageName && sameSigner(pm, context, it.packageName) }
            .mapNotNull { it.authority?.substringBefore(';') }
    }

    @Suppress("DEPRECATION")
    private fun sameSigner(pm: PackageManager, context: Context, other: String): Boolean {
        return pm.checkSignatures(context.packageName, other) == PackageManager.SIGNATURE_MATCH
    }

    private fun query(context: Context, authority: String): State? {
        val uri = Uri.parse("content://$authority/state")
        val client = context.contentResolver.acquireUnstableContentProviderClient(uri) ?: return null
        return try {
            client.query(uri, null, null, null, null)?.use { cursor ->
                if (!cursor.moveToFirst()) return@use null
                val accent = cursor.getString(0) ?: return@use null
                if (!valid(accent)) return@use null
                val mode = if (cursor.columnCount > 2) cursor.getString(2) else null
                State(accent, if (mode != null && validMode(mode)) mode else "", cursor.getLong(1))
            }
        } catch (_: Exception) {
            null
        } finally {
            client.release()
        }
    }

    private fun pokePeers(context: Context) {
        val pm = context.packageManager
        val found = try {
            @Suppress("DEPRECATION")
            pm.queryIntentContentProviders(Intent(ACTION_PROVIDER), 0)
        } catch (_: Exception) {
            return
        }
        for (info in found.mapNotNull { it.providerInfo }) {
            if (info.packageName == context.packageName) continue
            if (!sameSigner(pm, context, info.packageName)) continue
            context.sendBroadcast(Intent(ACTION_POKE).setPackage(info.packageName))
        }
    }

    private fun valid(accent: String) = accent.isNotEmpty() && accent.all { it in 'a'..'z' }

    private fun validMode(mode: String) = mode == "system" || mode == "light" || mode == "dark"

    private fun read(context: Context): Stored? {
        return try {
            val json = JSONObject(File(context.filesDir, FILE).readText())
            val accent = json.getString("accent")
            if (!valid(accent)) return null
            val mode = json.optString("mode", "system")
            Stored(
                json.optBoolean("enabled", true),
                State(accent, if (validMode(mode)) mode else "system", json.optLong("updatedAt", 0)),
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun write(context: Context, stored: Stored) {
        val json = JSONObject()
            .put("enabled", stored.enabled)
            .put("accent", stored.state.accent)
            .put("mode", stored.state.mode)
            .put("updatedAt", stored.state.updatedAt)
        val target = File(context.filesDir, FILE)
        val temp = File(context.filesDir, "$FILE.tmp")
        temp.writeText(json.toString())
        temp.renameTo(target)
    }

    internal fun readForProvider(context: Context): Pair<Boolean, State>? {
        return read(context)?.let { it.enabled to it.state }
    }
}

class ThemeSyncProvider : ContentProvider() {
    override fun onCreate() = true

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        val cursor = MatrixCursor(arrayOf("accent", "updated_at", "mode"))
        val context = context ?: return cursor
        @Suppress("DEPRECATION")
        val trusted = context.packageManager
            .checkSignatures(Binder.getCallingUid(), Process.myUid()) == PackageManager.SIGNATURE_MATCH
        if (!trusted) return cursor
        val (enabled, state) = ThemeSync.readForProvider(context) ?: return cursor
        if (enabled) cursor.addRow(arrayOf<Any?>(state.accent, state.updatedAt, state.mode))
        return cursor
    }

    override fun getType(uri: Uri): String? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = 0
    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ) = 0
}

class ThemeSyncReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ThemeSync.ACTION_POKE) return
        val pending = goAsync()
        val done = AtomicBoolean(false)
        val finish = { if (done.compareAndSet(false, true)) pending.finish() }
        val main = Handler(Looper.getMainLooper())
        main.postDelayed(finish, 8000)
        val app = context.applicationContext
        Thread {
            try {
                ThemeSync.pull(app)
            } catch (_: Exception) {
            }
            main.post { EngineHolder.requestThemeSync(app, finish) }
        }.start()
    }
}
