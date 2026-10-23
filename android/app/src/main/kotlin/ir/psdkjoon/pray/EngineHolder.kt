package ir.psdkjoon.pray

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.net.VpnService
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

object EngineHolder {
    const val EXTRA_CONSENT = "ir.psdkjoon.pray.CONSENT"
    const val EXTRA_TILE_CONNECT = "ir.psdkjoon.pray.TILE_CONNECT"
    const val REQUEST_VPN = 4711
    const val REQUEST_SAVE = 4712
    const val REQUEST_PICK = 4713
    private const val CONSENT_TIMEOUT_MS = 120_000L
    private const val SERVICE_TIMEOUT_MS = 10_000L

    private lateinit var appContext: Context
    private val main = Handler(Looper.getMainLooper())

    private var engine: FlutterEngine? = null
    private var tileChannel: MethodChannel? = null
    private var themeSyncChannel: MethodChannel? = null
    private var tileReady = false
    private val startTimeout = Runnable {
        finishStart(-1, "The VPN did not start in time.")
    }
    private var pendingStart: MethodChannel.Result? = null
    private var awaitingConsent = false
    private var pendingToggle = false
    private var pendingFile: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private var pendingInstall: File? = null

    @Volatile
    var activity: MainActivity? = null

    @Volatile
    var resumed = false

    fun ensure(context: Context): FlutterEngine {
        engine?.let { return it }
        appContext = context.applicationContext
        val created = FlutterEngine(appContext)
        setUpChannels(created)
        created.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
        engine = created
        return created
    }

    fun toast(message: String) {
        main.post {
            try {
                android.widget.Toast.makeText(appContext, message, android.widget.Toast.LENGTH_LONG).show()
            } catch (_: Exception) {
            }
        }
    }

    fun toggleFromTile(context: Context) {
        ensure(context)
        val channel = tileChannel
        if (!tileReady || channel == null) {
            pendingToggle = true
            return
        }
        channel.invokeMethod(
            "toggleRequested",
            null,
            object : MethodChannel.Result {
                override fun success(result: Any?) {}

                override fun error(code: String, message: String?, details: Any?) {
                    QuickTileService.setState(appContext, "off")
                }

                override fun notImplemented() {
                    tileReady = false
                    pendingToggle = true
                }
            },
        )
    }

    fun dropPendingToggle() {
        pendingToggle = false
    }

    fun connectAfterOpen() {
        toggleFromTile(appContext)
    }

    fun requestThemeSync(context: Context, done: () -> Unit) {
        ensure(context)
        val channel = themeSyncChannel
        if (channel == null) {
            done()
            return
        }
        channel.invokeMethod(
            "refresh",
            null,
            object : MethodChannel.Result {
                override fun success(result: Any?) = done()
                override fun error(code: String, message: String?, details: Any?) = done()
                override fun notImplemented() = done()
            },
        )
    }

    private fun setUpChannels(e: FlutterEngine) {
        val messenger = e.dartExecutor.binaryMessenger

        MethodChannel(messenger, "pray/paths").setMethodCallHandler { call, result ->
            when (call.method) {
                "resolve" -> result.success(
                    mapOf(
                        "nativeLibraryDir" to appContext.applicationInfo.nativeLibraryDir,
                        "filesDir" to appContext.filesDir.absolutePath,
                    ),
                )
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "pray/launcher_icon").setMethodCallHandler { call, result ->
            when (call.method) {
                "configure" -> {
                    LauncherIcon.configure(
                        call.argument<String>("mode") ?: "system",
                        call.argument<String>("accent") ?: "",
                        call.argument<Number>("updatedAt")?.toLong() ?: 0L,
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        val themeSync = MethodChannel(messenger, "pray/theme_sync")
        themeSyncChannel = themeSync
        themeSync.setMethodCallHandler { call, result ->
            when (call.method) {
                "publish" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    val accent = call.argument<String>("accent") ?: ""
                    val mode = call.argument<String>("mode") ?: "system"
                    val updatedAt = call.argument<Number>("updatedAt")?.toLong() ?: 0L
                    ThemeSync.async(result) {
                        ThemeSync.toMap(ThemeSync.publish(appContext, enabled, accent, mode, updatedAt))
                    }
                }
                "pull" -> ThemeSync.async(result) {
                    ThemeSync.toMap(ThemeSync.pull(appContext))
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "pray/system").setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrl" -> openUrl(call.argument<String>("url"), result)
                "installApk" -> installApk(call.argument<String>("path"), result)
                "abi" -> result.success(android.os.Build.SUPPORTED_ABIS.firstOrNull())
                "requestNotifications" -> {
                    requestNotifications()
                    result.success(null)
                }
                "isBackgroundAllowed" ->
                    result.success(BatteryService.isIgnoring(appContext))
                "requestBackgroundAccess" -> {
                    BatteryService.request(appContext)
                    result.success(null)
                }
                "saveFile" -> startFile(
                    REQUEST_SAVE,
                    call.argument<String>("name"),
                    call.argument<ByteArray>("bytes"),
                    result,
                )
                "pickFile" -> startFile(REQUEST_PICK, null, null, result)
                else -> result.notImplemented()
            }
        }

        val tile = MethodChannel(messenger, "pray/tile")
        tileChannel = tile
        tile.setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    setTileEnabled(true)
                    offerTile()
                    result.success(null)
                }
                "setState" -> {
                    val value = call.argument<String>("state") ?: "off"
                    if (!(pendingToggle && value == "off")) {
                        QuickTileService.setState(appContext, value)
                    }
                    result.success(null)
                }
                "consumeToggle" -> {
                    tileReady = true
                    val value = pendingToggle
                    pendingToggle = false
                    result.success(value)
                }
                "toast" -> {
                    toast(call.argument<String>("message") ?: "")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        val vpn = MethodChannel(messenger, "pray/vpn")
        vpn.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    PrayVpnService.allowedApps =
                        call.argument<List<String>>("allowed") ?: emptyList()
                    startVpn(result)
                }
                "listApps" -> listApps(result)
                "stop" -> {
                    stopVpn()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        PrayVpnService.onRevoked = {
            main.post { vpn.invokeMethod("revoked", null) }
        }
    }

    private fun openUrl(url: String?, result: MethodChannel.Result) {
        if (url == null) {
            result.error("bad_url", "No URL.", null)
            return
        }
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            appContext.startActivity(intent)
            result.success(null)
        } catch (e: Exception) {
            result.error("no_browser", "No app can open this link.", null)
        }
    }

    private fun canInstall(): Boolean =
        android.os.Build.VERSION.SDK_INT < 26 ||
            appContext.packageManager.canRequestPackageInstalls()

    private fun installApk(path: String?, result: MethodChannel.Result) {
        val file = path?.let { File(it) }
        if (file == null || !file.isFile) {
            result.error("no_file", "The update file is missing.", null)
            return
        }
        try {
            if (canInstall()) {
                pendingInstall = null
                launchInstaller(file)
                result.success("installing")
            } else {
                pendingInstall = file
                appContext.startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:${appContext.packageName}"),
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                result.success("needs_permission")
            }
        } catch (e: Exception) {
            pendingInstall = null
            result.error("install_failed", e.message ?: "Could not start the installer.", null)
        }
    }

    fun installIfWaiting() {
        val file = pendingInstall ?: return
        pendingInstall = null
        if (!canInstall()) return
        try {
            launchInstaller(file)
        } catch (_: Exception) {
        }
    }

    private fun launchInstaller(file: File) {
        val uri = FileProvider.getUriForFile(appContext, "${appContext.packageName}.updates", file)
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        appContext.startActivity(intent)
    }

    private fun requestNotifications() {
        if (android.os.Build.VERSION.SDK_INT < 33) return
        val host = activity ?: return
        if (host.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        host.requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 0)
    }

    private fun startFile(
        code: Int,
        name: String?,
        bytes: ByteArray?,
        result: MethodChannel.Result,
    ) {
        val host = activity
        if (host == null) {
            result.error("no_activity", "Open the app first.", null)
            return
        }
        if (pendingFile != null) {
            result.error("busy", "A file dialog is already open.", null)
            return
        }
        pendingFile = result
        pendingBytes = bytes
        val intent = if (code == REQUEST_SAVE) {
            Intent(Intent.ACTION_CREATE_DOCUMENT)
                .addCategory(Intent.CATEGORY_OPENABLE)
                .setType("application/octet-stream")
                .putExtra(Intent.EXTRA_TITLE, name ?: "pray.pray")
        } else {
            Intent(Intent.ACTION_OPEN_DOCUMENT)
                .addCategory(Intent.CATEGORY_OPENABLE)
                .setType("*/*")
        }
        @Suppress("DEPRECATION")
        host.startActivityForResult(intent, code)
    }

    fun onFileResult(code: Int, resultCode: Int, data: Intent?): Boolean {
        if (code != REQUEST_SAVE && code != REQUEST_PICK) return false
        val result = pendingFile ?: return true
        val bytes = pendingBytes
        pendingFile = null
        pendingBytes = null
        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (uri == null) {
            result.success(if (code == REQUEST_SAVE) false else null)
            return true
        }
        Thread {
            try {
                if (code == REQUEST_SAVE) {
                    appContext.contentResolver.openOutputStream(uri, "wt")?.use {
                        it.write(bytes ?: ByteArray(0))
                    }
                    main.post { result.success(true) }
                } else {
                    val read = appContext.contentResolver.openInputStream(uri)?.use {
                        it.readBytes()
                    }
                    main.post { result.success(read) }
                }
            } catch (e: Exception) {
                main.post { result.error("io", e.message ?: "File error", null) }
            }
        }.start()
        return true
    }

    private fun startVpn(result: MethodChannel.Result) {
        if (pendingStart != null) {
            result.error("busy", "A VPN start is already in progress.", null)
            return
        }
        pendingStart = result
        awaitingConsent = false
        main.removeCallbacks(startTimeout)
        main.postDelayed(startTimeout, CONSENT_TIMEOUT_MS)
        try {
            val consent = VpnService.prepare(appContext)
            if (consent == null) {
                launchVpnService()
                return
            }
            val current = activity
            if (current != null && resumed) {
                @Suppress("DEPRECATION")
                current.startActivityForResult(consent, REQUEST_VPN)
            } else {
                awaitingConsent = true
                appContext.startActivity(
                    Intent(appContext, MainActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        .putExtra(EXTRA_CONSENT, true),
                )
            }
        } catch (e: Exception) {
            awaitingConsent = false
            finishStart(-1, e.message ?: "Could not start the VPN.")
        }
    }

    fun consentIfWaiting(host: MainActivity) {
        if (!awaitingConsent) return
        awaitingConsent = false
        try {
            val consent = VpnService.prepare(host)
            if (consent == null) {
                launchVpnService()
            } else {
                @Suppress("DEPRECATION")
                host.startActivityForResult(consent, REQUEST_VPN)
            }
        } catch (e: Exception) {
            finishStart(-1, e.message ?: "Could not start the VPN.")
        }
    }

    fun onConsentResult(granted: Boolean) {
        if (!granted) {
            finishStart(-1)
            return
        }
        try {
            launchVpnService()
        } catch (e: Exception) {
            finishStart(-1, e.message ?: "Could not start the VPN.")
        }
    }

    private fun launchVpnService() {
        main.removeCallbacks(startTimeout)
        main.postDelayed(startTimeout, SERVICE_TIMEOUT_MS)
        PrayVpnService.onEstablished = { fd -> main.post { finishStart(fd) } }
        val intent = Intent(appContext, PrayVpnService::class.java)
            .setAction(PrayVpnService.ACTION_START)
        if (android.os.Build.VERSION.SDK_INT >= 26) {
            appContext.startForegroundService(intent)
        } else {
            appContext.startService(intent)
        }
    }

    private fun listApps(result: MethodChannel.Result) {
        Thread {
            val apps = try {
                val pm = appContext.packageManager
                val query = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                pm.queryIntentActivities(query, 0)
                    .map {
                        mapOf(
                            "package" to it.activityInfo.packageName,
                            "label" to it.loadLabel(pm).toString(),
                        )
                    }
                    .distinctBy { it["package"] }
                    .sortedBy { it["label"]!!.lowercase() }
            } catch (e: Exception) {
                emptyList()
            }
            main.post { result.success(apps) }
        }.start()
    }

    private fun finishStart(fd: Int, error: String? = null) {
        main.removeCallbacks(startTimeout)
        PrayVpnService.onEstablished = null
        awaitingConsent = false
        val result = pendingStart ?: return
        pendingStart = null
        if (error != null) {
            result.error("vpn_failed", error, null)
        } else {
            result.success(fd)
        }
    }

    private fun stopVpn() {
        if (pendingStart != null) finishStart(-1)
        PrayVpnService.instance?.shutdown()
        appContext.stopService(Intent(appContext, PrayVpnService::class.java))
    }

    private fun setTileEnabled(enabled: Boolean) {
        appContext.packageManager.setComponentEnabledSetting(
            ComponentName(appContext, "ir.psdkjoon.pray.QuickTileService"),
            if (enabled) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            },
            PackageManager.DONT_KILL_APP,
        )
    }

    private fun offerTile() {
        if (android.os.Build.VERSION.SDK_INT < 33) return
        val prefs = appContext.getSharedPreferences("pray", Context.MODE_PRIVATE)
        if (prefs.getBoolean("tile_offered", false)) return
        prefs.edit().putBoolean("tile_offered", true).apply()
        try {
            appContext.getSystemService(android.app.StatusBarManager::class.java)?.requestAddTileService(
                ComponentName(appContext, QuickTileService::class.java),
                appContext.getString(R.string.app_name),
                android.graphics.drawable.Icon.createWithResource(appContext, R.drawable.ic_tile),
                appContext.mainExecutor,
            ) { _: Int -> }
        } catch (_: Exception) {
        }
    }
}
