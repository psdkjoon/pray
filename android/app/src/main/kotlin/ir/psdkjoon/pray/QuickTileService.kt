package ir.psdkjoon.pray

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

class QuickTileService : TileService() {

    override fun onTileAdded() {
        super.onTileAdded()
        EngineHolder.ensure(applicationContext)
    }

    override fun onStartListening() {
        super.onStartListening()
        live = this
        render()
    }

    override fun onStopListening() {
        if (live === this) live = null
        super.onStopListening()
    }

    override fun onClick() {
        super.onClick()
        try {
            if (state == "busy") return
            if (state == "off" && VpnService.prepare(applicationContext) != null) {
                openApp()
                return
            }
            setState(applicationContext, "busy")
            EngineHolder.toggleFromTile(applicationContext)
        } catch (e: Exception) {
            EngineHolder.toast("${e.javaClass.simpleName}: ${e.message}")
            setState(applicationContext, "off")
        }
    }

    private fun openApp() {
        val intent = Intent(applicationContext, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra(EngineHolder.EXTRA_TILE_CONNECT, true)
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                startActivityAndCollapse(
                    PendingIntent.getActivity(
                        applicationContext,
                        0,
                        intent,
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                    ),
                )
            } else {
                @Suppress("DEPRECATION")
                startActivityAndCollapse(intent)
            }
        } catch (e: Exception) {
            EngineHolder.toast("${e.javaClass.simpleName}: ${e.message}")
        }
    }

    private fun render() {
        val tile = qsTile ?: return
        tile.state = if (state == "off") Tile.STATE_INACTIVE else Tile.STATE_ACTIVE
        tile.label = getString(R.string.app_name)
        if (Build.VERSION.SDK_INT >= 29) {
            tile.subtitle = when (state) {
                "busy" -> getString(R.string.tile_busy)
                "on" -> getString(R.string.tile_on)
                else -> getString(R.string.tile_off)
            }
        }
        tile.updateTile()
    }

    companion object {
        @Volatile
        private var state = "off"

        @Volatile
        private var live: QuickTileService? = null

        private const val BUSY_TIMEOUT_MS = 30_000L
        private val handler = Handler(Looper.getMainLooper())
        private val busyTimeout = Runnable {
            if (state == "busy") {
                EngineHolder.dropPendingToggle()
                state = "off"
                live?.render()
                EngineHolder.toast("Pray: the tile gave up waiting.")
            }
        }

        fun setState(context: Context, value: String) {
            state = value
            handler.removeCallbacks(busyTimeout)
            if (value == "busy") handler.postDelayed(busyTimeout, BUSY_TIMEOUT_MS)
            val current = live
            if (current != null) {
                current.render()
            } else {
                requestListeningState(
                    context,
                    ComponentName(context, QuickTileService::class.java),
                )
            }
        }
    }
}
