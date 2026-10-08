package ir.psdkjoon.pray

import android.app.Application

class PrayApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        EngineHolder.ensure(this)
    }
}
