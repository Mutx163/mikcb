package com.mutx163.qingyu

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * 系统深浅模式换档后重画桌面卡片。
 *
 * 为什么必须有它：卡片的**底色**是 `drawable/` + `drawable-night/` 两套资源，由桌面
 * （启动器）在画的时候按它当时的配置现挑；而卡片的**文字色**是 App 渲染时算好的固定颜色值
 * （[TodayWidgetSupport.primaryTextColor] / [TodayWidgetSupport.secondaryTextColor] 等）。
 * 系统换档时平台**不会**回调任何 Provider（`ACTION_APPWIDGET_UPDATE` 不发给卡片），
 * 桌面重放 RemoteViews 只会把底色换成新的一档，文字色留在上一档 —— 用户看到的就是
 * 「底色是浅的、字也是浅的」这类半对半错、看不清的卡片，一直卡到下一次有人触发重画
 * （打开 App、闹钟刷新、Worker 到点）。
 *
 * 字色现在由 [TodayWidgetSupport.isDarkMode] 直读系统设置（`UiModeManager`），不再依赖
 * 本进程的 `resources.configuration`——后者在 MIUI/HyperOS 后台保活下可能长期不更新，
 * 会出现「每次后台重画都继续用旧档字色」的卡死。这里的换档判据也必须用同一来源：
 * 否则字色已经会画新档、却因为判据仍读到旧进程配置而不触发重画，卡片继续停在旧配色。
 *
 * 平台不允许用 manifest 声明 `ACTION_CONFIGURATION_CHANGED`（收不到），所以这里在进程活着时
 * 动态注册。进程已经死了不用管：下一次唤醒（闹钟 / Worker / 打开 App）起来时，进程配置本来
 * 就是当前档，那一轮渲染直接是对的。
 *
 * 只对「深浅档那一位」有反应：语言、密度、字号、屏幕方向等其它配置变化不重画，避免无谓的
 * RemoteViews 构建。
 */
object WidgetThemeWatcher {
    private const val TAG = "WidgetThemeWatcher"

    /** 换档常伴随一串配置变化广播（有时还会紧接着再来一次），延迟一小会儿合并成一次重画。 */
    private const val SETTLE_DELAY_MILLIS = 300L

    @Volatile
    private var initialized = false

    /** Application context；与 [FairMemoryAdapter] 一样跟着进程活，不构成泄漏。 */
    private var appContext: Context? = null

    /** 上次见到的深浅档（已按 [Configuration.UI_MODE_NIGHT_MASK] 掩码）；进程内有效，不落盘。 */
    private var lastNightMode: Int = Configuration.UI_MODE_NIGHT_UNDEFINED

    private val mainHandler: Handler by lazy { Handler(Looper.getMainLooper()) }

    private val settleRunnable = Runnable { rerenderAllWidgetsIfNightModeChanged() }

    fun initialize(context: Context) {
        synchronized(this) {
            if (initialized) {
                return
            }
            val applicationContext = context.applicationContext
            appContext = applicationContext
            lastNightMode = currentNightModeMask(applicationContext)
            val filter = IntentFilter(Intent.ACTION_CONFIGURATION_CHANGED)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                applicationContext.registerReceiver(
                    configurationChangedReceiver,
                    filter,
                    null,
                    null,
                    Context.RECEIVER_EXPORTED,
                )
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                applicationContext.registerReceiver(configurationChangedReceiver, filter)
            }
            initialized = true
            Log.i(TAG, "configuration-change receiver registered; nightMode=$lastNightMode")
        }
    }

    private val configurationChangedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent?) {
            if (intent?.action != Intent.ACTION_CONFIGURATION_CHANGED) {
                return
            }
            mainHandler.removeCallbacks(settleRunnable)
            mainHandler.postDelayed(settleRunnable, SETTLE_DELAY_MILLIS)
        }
    }

    private fun rerenderAllWidgetsIfNightModeChanged() {
        val context = appContext ?: return
        val current = currentNightModeMask(context)
        val changed = synchronized(this) {
            val previous = lastNightMode
            lastNightMode = current
            nightModeChanged(previous, current)
        }
        if (!changed) {
            return
        }
        try {
            // 十个卡型：七个今日/考试类 + 三个统计类。没有卡片时 updateAll 只查一次 id，开销可忽略。
            TodayWidgetSupport.updateAll(context)
            StatsWidgetSupport.updateAll(context)
            Log.i(TAG, "widgets rerendered for night mode change -> $current")
        } catch (error: Exception) {
            // 重画失败不能影响 App 本身；下一次唤醒（闹钟 / Worker / 打开 App）还会再画。
            Log.w(TAG, "widget rerender after night mode change failed", error)
        }
    }
}

/** 只取 uiMode 里的深浅档那一位（UI_MODE_NIGHT_NO / YES / UNDEFINED）。 */
internal fun nightModeMask(uiMode: Int): Int = uiMode and Configuration.UI_MODE_NIGHT_MASK

/**
 * 监听器自己的深浅档口径。
 *
 * 不直接读 `resources.configuration`：后台进程的这份配置可能长期停在旧档，让监听器误以为
 * 「没换档」而不重画。复用 [TodayWidgetSupport.isDarkMode] 后，监听器和实际渲染字色永远
 * 看到同一个答案；这里只把它映射回夜档掩码，继续复用上面的纯函数判断。
 */
private fun currentNightModeMask(context: Context): Int =
    if (TodayWidgetSupport.isDarkMode(context)) {
        Configuration.UI_MODE_NIGHT_YES
    } else {
        Configuration.UI_MODE_NIGHT_NO
    }

/**
 * 深浅档是否真的换了一档。
 *
 * `UI_MODE_NIGHT_UNDEFINED`（进程刚起来、还没拿到明确档）转到明确值也算换档——此时页面
 * 可能刚完成一次「未定 → 当前档」的纠正，卡片按旧档画过，需要重画一次。
 */
internal fun nightModeChanged(previousMasked: Int, currentMasked: Int): Boolean =
    previousMasked != currentMasked
