package com.mutx163.qingyu

import android.app.Application
import android.content.Context
import android.os.SystemClock
import com.mutx163.qingyu.infra.AppLogStore
import com.mutx163.qingyu.infra.CrashLogInstaller
import com.mutx163.qingyu.pages.diagnostics.PerfProbeCore
import com.mutx163.qingyu.pages.guide.PrivacyConsentPreferences
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import com.umeng.commonsdk.UMConfigure

class UmengApplication : Application() {
    override fun onCreate() {
        // A2（2026-11-03）：启动打点「进程进入」段。此刻探针尚未安装（安装发生在壳
        // Activity 的 onCreate），必须用 **PerfProbeCore 的显式时间戳重载**（其注释明说
        // 给 Application 用）：打点先缓冲，安装时按原时刻补记。platform 包装层
        // `PerfProbe.markStartup(label)` 依赖内部时钟、此刻未配置，会把打点丢掉，
        // 所以这里直接调内核；时间戳与探针装成后的时钟同源
        //（elapsedRealtimeNanos / 1000，微秒），分段不会错位。
        // 正式包探针不安装：这一条只是往进程内缓冲放一对 (标签, 时戳)，无 I/O 无计算。
        PerfProbeCore.markStartup("mainEnter", SystemClock.elapsedRealtimeNanos() / 1000L)
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
        // 本地崩溃落盘**不在 Application 启动时安装**（2026-11-10 B1 复核修正）：
        // 旧版 Dart 在未同意隐私政策前连崩溃都不落盘（`app_log_service.dart:424-426`
        // 的 `_shouldRecord` 直接返回 false），用户口径是「对齐发布版」。现在只在同意后、
        // `initializeAnalyticsIfNeeded` 里（`UMConfigure.init` 之后）安装；未同意阶段的
        // 崩溃交给系统默认 handler，不写 `app_runtime.log`。

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

        /**
         * 「已同意隐私才初始化」的**语义化生产入口**（B1，2026-11-10）。
         *
         * 它和 [initializeAnalyticsIfNeeded] 的区别只是「名字表明用途」：后者现在也
         * 自己查同意键（2026-11-10 复核补的结构保证），所以两条路径都不会在同意前
         * init。保留本方法的理由：生产调用点一眼能看出「这里是有意等同意」，
         * 与旧版 Dart `if (await hasAcceptedPrivacyPolicy())` 的门形对齐
         *（`v2.1.4.1:lib/main.dart:1100-1102`）。
         *
         * @return true = 本次真的初始化了；false = 未同意 / 已初始化过 / 重复调用
         */
        fun initializeAnalyticsIfConsented(context: Context): Boolean {
            val accepted = PrivacyConsentPreferences(PrefsKeyValueStore(context))
                .hasAcceptedPrivacyPolicy()
            if (!accepted) {
                return false
            }
            return initializeAnalyticsIfNeeded(context)
        }

        fun initializeAnalyticsIfNeeded(context: Context): Boolean {
            // 结构保证（B1 复核补）：raw 入口也先查同意键——调试页 / 未来任何新调用点
            // 都绕不过隐私门；`UMConfigure.init` 与崩溃落盘（`CrashLogInstaller`）都只
            // 可能发生在同意之后。行为约定升级成代码保证。
            if (!PrivacyConsentPreferences(PrefsKeyValueStore(context)).hasAcceptedPrivacyPolicy()) {
                return false
            }
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
                    // U-APM init 已换掉默认 handler：在脱敏层外面再包一层本地落盘，
                    // 保证崩溃先写进 app_runtime.log，再交给 U-APM 的脱敏 handler。
                    CrashLogInstaller.install()
                } catch (_: Throwable) {
                }
                return true
            }
        }
    }
}
