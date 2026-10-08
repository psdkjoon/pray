package ir.psdkjoon.pray

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return EngineHolder.ensure(context)
    }

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        EngineHolder.activity = this
        offerTile()
    }

    override fun onPostResume() {
        super.onPostResume()
        EngineHolder.activity = this
        EngineHolder.consentIfWaiting(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        EngineHolder.consentIfWaiting(this)
    }

    override fun onDestroy() {
        if (EngineHolder.activity === this) EngineHolder.activity = null
        super.onDestroy()
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == EngineHolder.REQUEST_VPN) {
            EngineHolder.onConsentResult(resultCode == RESULT_OK)
            return
        }
        if (EngineHolder.onFileResult(requestCode, resultCode, data)) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun offerTile() {
        if (android.os.Build.VERSION.SDK_INT < 33) return
        val prefs = getSharedPreferences("pray", MODE_PRIVATE)
        if (prefs.getBoolean("tile_offered", false)) return
        prefs.edit().putBoolean("tile_offered", true).apply()
        try {
            getSystemService(android.app.StatusBarManager::class.java)?.requestAddTileService(
                android.content.ComponentName(this, PrayTileService::class.java),
                "Pray",
                android.graphics.drawable.Icon.createWithResource(this, R.drawable.ic_tile),
                mainExecutor,
            ) { _: Int -> }
        } catch (_: Exception) {
        }
    }
}
