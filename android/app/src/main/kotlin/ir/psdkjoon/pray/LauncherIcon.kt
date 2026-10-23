package ir.psdkjoon.pray

import android.app.Activity
import android.app.Application
import android.content.ComponentCallbacks
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.content.res.Resources
import android.os.Bundle
import android.os.Handler
import android.os.Looper

object LauncherIcon {
    private const val PREFS = "launcher_icon"
    private const val PREFIX = "Icon"
    private const val AFTER_CLOSE_MS = 1000L
    private const val AFTER_REQUEST_MS = 800L
    private const val AFTER_START_MS = 5000L

    private lateinit var app: Application
    private val main = Handler(Looper.getMainLooper())

    @Volatile
    private var installed = false

    @Volatile
    private var alive = 0
    private var aliases: List<String>? = null

    private val settle = Runnable { if (alive == 0) apply() }

    fun install(application: Application) {
        if (installed) return
        installed = true
        app = application

        application.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
                alive++
                main.removeCallbacks(settle)
            }

            override fun onActivityDestroyed(activity: Activity) {
                alive = (alive - 1).coerceAtLeast(0)
                if (alive == 0) later(AFTER_CLOSE_MS)
            }

            override fun onActivityStarted(activity: Activity) {
                main.removeCallbacks(settle)
            }

            override fun onActivityStopped(activity: Activity) {}
            override fun onActivityResumed(activity: Activity) {}
            override fun onActivityPaused(activity: Activity) {}
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
        })

        application.registerComponentCallbacks(object : ComponentCallbacks {
            override fun onConfigurationChanged(newConfig: Configuration) = later(AFTER_REQUEST_MS)

            override fun onLowMemory() {}
        })

        later(AFTER_START_MS)
    }

    @Synchronized
    fun configure(mode: String, accent: String, updatedAt: Long) {
        if (!installed) return
        val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (accent.isNotEmpty() && updatedAt >= prefs.getLong("accentAt", 0L)) {
            prefs.edit()
                .putString("mode", mode)
                .putString("accent", accent)
                .putLong("accentAt", updatedAt)
                .commit()
        }
        later(AFTER_REQUEST_MS)
    }

    @Synchronized
    fun adoptSynced(accent: String, mode: String, updatedAt: Long) {
        if (!installed || accent.isEmpty()) return
        val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (updatedAt < prefs.getLong("accentAt", 0L)) return
        val edit = prefs.edit().putString("accent", accent).putLong("accentAt", updatedAt)
        if (mode.isNotEmpty()) edit.putString("mode", mode)
        edit.commit()
        if (alive == 0) apply()
    }

    private fun later(delayMs: Long) {
        main.removeCallbacks(settle)
        if (alive == 0) main.postDelayed(settle, delayMs)
    }

    @Synchronized
    private fun apply() {
        val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val accent = prefs.getString("accent", null) ?: return
        if (accent.isEmpty() || !accent.all { it in 'a'..'z' }) return
        val dark = when (prefs.getString("mode", "system")) {
            "dark" -> true
            "light" -> false
            else -> {
                val night = Resources.getSystem().configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
                night == Configuration.UI_MODE_NIGHT_YES
            }
        }
        val target = PREFIX + accent.replaceFirstChar { it.uppercase() } +
            if (dark) "Mocha" else "Latte"
        if (!switchTo(target)) return
        prefs.edit().putString("applied", target).commit()
    }

    private fun switchTo(target: String): Boolean {
        val pm = app.packageManager
        val all = aliases ?: scanAliases(pm).also { aliases = it }
        val wanted = all.filter { it.substringAfterLast('.') == target }
        if (wanted.isEmpty()) return false
        val others = all - wanted.toSet()

        for (name in wanted) setState(pm, name, true)
        for (name in others) setState(pm, name, false)
        return true
    }

    private fun setState(pm: PackageManager, name: String, enable: Boolean) {
        val component = ComponentName(app.packageName, name)
        val current = try {
            pm.getComponentEnabledSetting(component)
        } catch (_: IllegalArgumentException) {
            return
        }
        val enabledNow = when (current) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED -> false
            else -> manifestDefault(pm, component)
        }
        if (enabledNow == enable) return
        pm.setComponentEnabledSetting(
            component,
            if (enable) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            },
            PackageManager.DONT_KILL_APP,
        )
    }

    @Suppress("DEPRECATION")
    private fun manifestDefault(pm: PackageManager, component: ComponentName): Boolean {
        return try {
            pm.getActivityInfo(component, PackageManager.GET_DISABLED_COMPONENTS).enabled
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    @Suppress("DEPRECATION")
    private fun scanAliases(pm: PackageManager): List<String> {
        val info = try {
            pm.getPackageInfo(
                app.packageName,
                PackageManager.GET_ACTIVITIES or PackageManager.GET_DISABLED_COMPONENTS,
            )
        } catch (_: PackageManager.NameNotFoundException) {
            return emptyList()
        }
        return info.activities.orEmpty()
            .filter { it.targetActivity != null && it.name.substringAfterLast('.').startsWith(PREFIX) }
            .map { it.name }
    }
}
