package ir.psdkjoon.pray

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.system.Os
import android.system.OsConstants

class PrayVpnService : VpnService() {
    private var tun: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                startAsForeground()
                val fd = openTun()
                onEstablished?.invoke(fd)
                if (fd < 0) {
                    stopForegroundCompat()
                    stopSelf()
                }
            }
            ACTION_STOP -> shutdown()
        }
        return START_NOT_STICKY
    }

    private fun startAsForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, getString(R.string.vpn_channel), NotificationManager.IMPORTANCE_LOW),
            )
        }
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_tile)
            .setContentTitle("Pray")
            .setContentText(getString(R.string.connected))
            .setContentIntent(open)
            .setOngoing(true)
            .build()
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (_: Exception) {
        }
    }

    fun shutdown() {
        closeTun()
        stopForegroundCompat()
        stopSelf()
    }

    private fun stopForegroundCompat() {
        try {
            @Suppress("DEPRECATION")
            stopForeground(true)
        } catch (_: Exception) {
        }
    }

    override fun onRevoke() {
        closeTun()
        onRevoked?.invoke()
        stopSelf()
    }

    override fun onDestroy() {
        closeTun()
        instance = null
        super.onDestroy()
    }

    private fun openTun(): Int {
        closeTun()
        return try {
            val pfd = Builder()
                .setSession("Pray")
                .setMtu(MTU)
                .addAddress("172.19.0.1", 30)
                .addAddress("fdfe:dcba:9876::1", 126)
                .addRoute("0.0.0.0", 0)
                .addRoute("::", 0)
                .addDnsServer("1.1.1.1")
                .addDnsServer("8.8.8.8")
                .also { applyAppFilter(it) }
                .establish() ?: return -1
            Os.fcntlInt(pfd.fileDescriptor, OsConstants.F_SETFD, 0)
            tun = pfd
            instance = this
            pfd.fd
        } catch (e: Exception) {
            -1
        }
    }

    private fun applyAppFilter(builder: Builder) {
        var added = 0
        for (name in allowedApps) {
            if (name == packageName) continue
            try {
                builder.addAllowedApplication(name)
                added++
            } catch (_: Exception) {
            }
        }
        if (added == 0) builder.addDisallowedApplication(packageName)
    }

    private fun closeTun() {
        try {
            tun?.close()
        } catch (e: Exception) {
        }
        tun = null
    }

    companion object {
        const val ACTION_START = "ir.psdkjoon.pray.VPN_START"
        const val ACTION_STOP = "ir.psdkjoon.pray.VPN_STOP"
        private const val MTU = 1500
        private const val CHANNEL_ID = "vpn_service"
        private const val NOTIFICATION_ID = 7

        @Volatile
        var allowedApps: List<String> = emptyList()

        @Volatile
        var instance: PrayVpnService? = null

        var onEstablished: ((Int) -> Unit)? = null
        var onRevoked: (() -> Unit)? = null
    }
}
