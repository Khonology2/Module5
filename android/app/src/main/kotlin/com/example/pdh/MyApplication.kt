package com.example.pdh

import android.app.Application
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // FacebookSdk.sdkInitialize(applicationContext) // Deprecated: SDK is auto-initialized
        AppEventsLogger.activateApp(this)
    }
}
