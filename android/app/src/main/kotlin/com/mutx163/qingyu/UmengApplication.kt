package com.mutx163.qingyu

import android.app.Application
import android.content.Context
import com.umeng.commonsdk.UMConfigure

class UmengApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        BeforeClassQuickActionRestore.restoreIfClassEnded(applicationContext)

        // 友盟 SDK 的 UMLog/MobclickAgent 在 debug 下会大量刷屏；诊断走应用内日志文件。
        UMConfigure.setLogEnabled(false)
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

