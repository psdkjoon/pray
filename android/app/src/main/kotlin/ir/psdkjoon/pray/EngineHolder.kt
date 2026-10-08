package ir.psdkjoon.pray

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.net.VpnService
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

object EngineHolder {
    const val EXTRA_CONSENT = "ir.psdkjoon.pray.CONSENT"
    const val REQUEST_VPN = 4711
    const val REQUEST_SAVE = 4712
    const val REQUEST_PICK = 4713

    private lateinit var appContext: Context
    private val main = Handler(Looper.getMainLooper())

    private var engine: FlutterEngine? = null
    private var vpnChannel: MethodChannel? = null
    private var pendingStart: MethodChannel.Result? = null
    private var awaitingConsent = false
    private var pendingToggle = false
    private var pendingFile: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    @Volatile
    var activity: MainActivity? = null

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

    fun toggleFromTile(context: Context) {
        val warm = engine != null
        pendingToggle = true
        ensure(context)
        if (warm) {
            vpnChannel?.invokeMethod("toggleRequested", null)
        }
    }

    private fun setUpChannels(e: FlutterEngine) {
        val messenger = e.dartExecutor.binaryMessenger

        MethodChannel(messenger, "pray/android_paths").setMethodCallHandler { call, result ->
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
                "set" -> {
                    setLauncherIcon(call.argument<Boolean>("dark") ?: true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "pray/system").setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrl" -> openUrl(call.argument<String>("url"), result)
                "abi" -> result.success(android.os.Build.SUPPORTED_ABIS.firstOrNull())
                "requestNotifications" -> {
                    requestNotifications()
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

        val vpn = MethodChannel(messenger, "pray/vpn")
        vpnChannel = vpn
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
                "setConnected" -> {
                    PrayTileService.setConnected(
                        appContext,
                        call.argument<String>("state") ?: "disconnected",
                    )
                    result.success(null)
                }
                "consumeToggle" -> {
                    val value = pendingToggle
                    pendingToggle = false
                    result.success(value)
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
        val consent = VpnService.prepare(appContext)
        if (consent == null) {
            launchVpnService()
            return
        }
        val current = activity
        if (current != null) {
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
    }

    fun consentIfWaiting(host: MainActivity) {
        if (!awaitingConsent) return
        awaitingConsent = false
        val consent = VpnService.prepare(host)
        if (consent == null) {
            launchVpnService()
        } else {
            @Suppress("DEPRECATION")
            host.startActivityForResult(consent, REQUEST_VPN)
        }
    }

    fun onConsentResult(granted: Boolean) {
        if (granted) launchVpnService() else finishStart(-1)
    }

    private fun launchVpnService() {
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

    private fun finishStart(fd: Int) {
        PrayVpnService.onEstablished = null
        val result = pendingStart ?: return
        pendingStart = null
        result.success(fd)
    }

    private fun stopVpn() {
        PrayVpnService.instance?.shutdown()
        appContext.stopService(Intent(appContext, PrayVpnService::class.java))
    }

    private fun setLauncherIcon(dark: Boolean) {
        val pm = appContext.packageManager
        val mocha = ComponentName(appContext, "ir.psdkjoon.pray.IconMocha")
        val latte = ComponentName(appContext, "ir.psdkjoon.pray.IconLatte")
        val enable = if (dark) mocha else latte
        val disable = if (dark) latte else mocha
        pm.setComponentEnabledSetting(
            enable,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        pm.setComponentEnabledSetting(
            disable,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
    }
}
