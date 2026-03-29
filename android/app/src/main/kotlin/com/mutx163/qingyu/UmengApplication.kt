package com.mutx163.qingyu

import android.app.Application
import android.content.Context
import android.util.Log
import com.umeng.commonsdk.UMConfigure

class UmengApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        UMConfigure.setLogEnabled(BuildConfig.DEBUG)
        UMConfigure.preInit(
            this,
            BuildConfig.UMENG_APP_KEY,
            BuildConfig.UMENG_CHANNEL
        )
    }

    companion object {
        @Volatile
        private var initialized = false

        fun isAnalyticsInitialized(): Boolean = initialized

        fun initializeAnalyticsIfNeeded(context: Context): Boolean {
            if (initialized) {
                return false
            }

            synchronized(this) {
                if (initialized) {
                    return false
                }

                Log.i("UmengApplication", "Initializing Umeng analytics")
                UMConfigure.init(
                    context.applicationContext,
                    BuildConfig.UMENG_APP_KEY,
                    BuildConfig.UMENG_CHANNEL,
                    UMConfigure.DEVICE_TYPE_PHONE,
                    ""
                )
                initialized = true
                return true
            }
        }
    }
}

