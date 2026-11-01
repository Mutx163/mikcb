package com.mutx163.qingyu

import android.app.Application
import android.content.Context
import com.mutx163.qingyu.infra.AppLogStore
import com.umeng.commonsdk.UMConfigure

class UmengApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // 金标联盟公平运行内存：进程级动态注册，不依赖 Flutter 引擎是否存活。
        FairMemoryAdapter.initialize(this)
        // 系统深浅模式换档后重画桌面卡片：平台不会把这种变化回调给卡片 Provider，
        // 不补这一步会出现「浅底 + 浅字」的错位卡片。见 WidgetThemeWatcher。
        WidgetThemeWatcher.initialize(this)
        // 课表内容变化后唤醒桌面小组件与统计卡片：判据在 WidgetRefreshBridge，
        // 这里只负责在进程级订阅存储变更（此前全仓无生产调用点，改完课表要等最长 15 分钟）。
        WidgetRefreshHost.initialize(this)
        // 调试版 / 性能版：启动内存会话采样（正式版 no-op）。
        MemoryStatsCollector.initializeIfAllowed(this)
        // 应用日志写入层（诊断族的日志查看器、设置快照行都靠它落盘）。
        // 与 Flutter 侧 `AppLogService` **同一个文件、同一个格式**：`filesDir/logs/app_runtime.log`，
        // 所以在迁移期两边写的东西能互相读到；未初始化时 append 返回 false，不会崩、不会打断业务。
        AppLogStore.initialize(this)

        BeforeClassQuickActionRestore.restoreIfClassEnded(applicationContext)

        // 友盟 SDK 的 UMLog/MobclickAgent 在 debug 下会大量刷屏；诊断走应用内日志文件。
        UMConfigure.setLogEnabled(false)
        UMConfigure.preInit(
            this,
            BuildConfig.UMENG_APP_KEY,
            BuildConfig.UMENG_CHANNEL
        )
    }

    override fun onLowMemory() {
        super.onLowMemory()
        MemoryStatsCollector.onSystemLowMemory()
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
                // 自动崩溃链路的脱敏一致性（审计 #27）：U-APM 的崩溃上报没有
                // 改写负载的公开 API，init 装好自己的默认 UncaughtExceptionHandler
                // 之后，再包一层把异常 message 过 redactPersonalFields 再交上报。
                // 安装失败不影响初始化本身（回退为既有行为）。
                try {
                    UmengCrashRedaction.install()
                } catch (_: Throwable) {
                }
                return true
            }
        }
    }
}
