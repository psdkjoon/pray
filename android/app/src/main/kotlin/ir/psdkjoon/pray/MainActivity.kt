package ir.psdkjoon.pray

import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.graphics.drawable.LayerDrawable
import android.view.Gravity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return EngineHolder.ensure(context)
    }

    private fun splashDrawable(): Drawable? {
        val prefs = getSharedPreferences("launcher_icon", Context.MODE_PRIVATE)
        val accent = prefs.getString("accent", null)?.takeIf { name -> name.all { it in 'a'..'z' } }
            ?: "mauve"
        val dark = when (prefs.getString("mode", "system")) {
            "dark" -> true
            "light" -> false
            else -> {
                val night = resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
                night == Configuration.UI_MODE_NIGHT_YES
            }
        }
        val name = "ic_launcher_${accent}_${if (dark) "mocha" else "latte"}"
        val id = resources.getIdentifier(name, "mipmap", packageName)
        if (id == 0) return null
        val icon = try {
            resources.getDrawable(id, theme)
        } catch (_: Exception) {
            return null
        }
        val background = ColorDrawable(Color.parseColor(if (dark) "#1E1E2E" else "#EFF1F5"))
        val size = (SPLASH_ICON_DP * resources.displayMetrics.density).toInt()
        return LayerDrawable(arrayOf(background, icon)).apply {
            setLayerSize(1, size, size)
            setLayerGravity(1, Gravity.CENTER)
        }
    }

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        splashDrawable()?.let { window.setBackgroundDrawable(it) }
        EngineHolder.activity = this
    }

    override fun onPause() {
        EngineHolder.resumed = false
        super.onPause()
    }

    override fun onPostResume() {
        super.onPostResume()
        EngineHolder.activity = this
        EngineHolder.resumed = true
        EngineHolder.consentIfWaiting(this)
        EngineHolder.installIfWaiting()
        handleTileIntent()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        EngineHolder.consentIfWaiting(this)
    }

    private fun handleTileIntent() {
        val current = intent ?: return
        if (!current.getBooleanExtra(EngineHolder.EXTRA_TILE_CONNECT, false)) return
        current.removeExtra(EngineHolder.EXTRA_TILE_CONNECT)
        EngineHolder.connectAfterOpen()
    }

    override fun onDestroy() {
        if (EngineHolder.activity === this) {
            EngineHolder.activity = null
            EngineHolder.resumed = false
        }
        super.onDestroy()
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == EngineHolder.REQUEST_VPN) {
            EngineHolder.onConsentResult(resultCode == RESULT_OK)
            return
        }
        if (EngineHolder.onFileResult(requestCode, resultCode, data)) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    companion object {
        private const val SPLASH_ICON_DP = 192
    }
}
