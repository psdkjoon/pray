package ir.psdkjoon.pray

import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

class PrayTileService : TileService() {

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
        state = if (state == "disconnected") "connecting" else "disconnected"
        render()
        EngineHolder.toggleFromTile(applicationContext)
    }

    private fun render() {
        val tile = qsTile ?: return
        tile.state = if (state == "disconnected") Tile.STATE_INACTIVE else Tile.STATE_ACTIVE
        tile.label = "Pray"
        if (Build.VERSION.SDK_INT >= 29) {
            tile.subtitle = when (state) {
                "connecting" -> getString(R.string.connecting)
                "connected" -> getString(R.string.connected)
                else -> getString(R.string.disconnected)
            }
        }
        tile.updateTile()
    }

    companion object {
        @Volatile
        private var state = "disconnected"

        @Volatile
        private var live: PrayTileService? = null

        fun setConnected(context: Context, value: String) {
            state = value
            val current = live
            if (current != null) {
                current.render()
            } else {
                requestListeningState(
                    context,
                    ComponentName(context, PrayTileService::class.java),
                )
            }
        }
    }
}
