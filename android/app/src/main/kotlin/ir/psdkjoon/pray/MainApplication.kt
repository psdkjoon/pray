package ir.psdkjoon.pray

import android.app.Application

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        EngineHolder.ensure(this)
    }
}
