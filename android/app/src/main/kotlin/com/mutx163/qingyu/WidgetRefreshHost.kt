package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.mutx163.qingyu.app.FrozenValueCodec
import com.mutx163.qingyu.app.WidgetRefreshSignature
import java.time.LocalDate

/**
 * 课表内容变化 → 唤醒桌面小组件与统计卡片（Phase 3.5 · W1 的最后一段接线）。
 *
 * ## 为什么需要它
 *
 * 判据层 [WidgetRefreshBridge] 早在 `73c8c73e` 就写好了、也有单测，但**全仓没有生产调用点**：
 * 在 App 里改完课表，桌面卡片要等到下一次闹钟 / WorkManager（最长 15 分钟）才换画面。
 * 本对象补的就是「订阅存储变更 → 交给判据层 → 真去重画」这一段。
 *
 * ## 为什么订阅存储层，而不是订阅 `TimetableRepository`
 *
 * 卡片读数据的**唯一来源**是 `FlutterSharedPreferences` 里的落盘值
 *（`TodayWidgetSupport.buildSnapshotFromFlutterState` / `StatsWidgetSupport.readSnapshot`），
 * 不是某个内存对象。直接盯存储有三个好处：
 *
 * 1. 签名（[WidgetRefreshSignature]）与卡片真正读的数据同源，不会出现「内存变了、盘上还没变」
 *    或反过来「盘上变了、内存对象没收到通知」的错位；
 * 2. 不需要知道是哪个仓储实例写的，也不需要把 Context 塞进纯模型层；
 * 3. Flutter 版（同一进程、同一份 prefs）写入时同样会触发——迁移期两套 UI 都能吃到。
 *
 * ## 去抖与线程
 *
 * 一次保存会连续写多个键，所以回调先合并 `SETTLE_DELAY_MILLIS` 再处理；
 * 真正的重画在 [WidgetRefreshSerial] 的单线程串行器上跑（要解析整份档案 JSON、
 * 逐张构建 RemoteViews），不占主线程，并与闹钟入口 [HomeWidgetRefreshReceiver]、
 * 15 分钟兜底 [WidgetRefreshWorker] 排队 —— 三者并发会互抢 `rescheduleRefresh`
 * 里闹钟的 cancel/set。判据层的「签名去重 / 跨天 / 今天有没有课」都在
 * [WidgetRefreshBridge] 里，本对象不重复实现一遍。
 *
 * ## 没放桌面卡片时直接跳过
 *
 * `updateAll` 自己会查 id、空集合时是空转，但 [HomeWidgetStorage.rescheduleRefresh]
 * 会解析档案算下一个刷新点。用户一张卡片都没放时这些活没有收益，先查一次 id 再决定。
 */
object WidgetRefreshHost {

    private const val TAG = "WidgetRefreshHost"

    /** 与 [PrefsKeyValueStore] 同一个文件（冻结格式）。 */
    private const val PREFS_NAME = "FlutterSharedPreferences"

    /** 一次编辑会连写多个键；合并窗口取 250ms，肉眼无感、又能把整批写入合并成一次。 */
    private const val SETTLE_DELAY_MILLIS = 250L

    @Volatile
    private var initialized = false

    private var appContext: Context? = null
    private var bridge: WidgetRefreshBridge? = null

    private val mainHandler: Handler by lazy { Handler(Looper.getMainLooper()) }

    private val settleRunnable = Runnable { submitRefresh() }

    /**
     * 强引用必须留在单例里：`SharedPreferences` 对监听器是**弱引用**，
     * 只把 lambda 注册进去、不持有的话，下一次 GC 后监听就静默失效了。
     */
    private val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        val physicalKey = key ?: return@OnSharedPreferenceChangeListener
        val logicalKey = FrozenValueCodec.logicalKey(physicalKey)
            ?: return@OnSharedPreferenceChangeListener
        if (!WidgetRefreshSignature.isRelevant(logicalKey)) {
            return@OnSharedPreferenceChangeListener
        }
        mainHandler.removeCallbacks(settleRunnable)
        mainHandler.postDelayed(settleRunnable, SETTLE_DELAY_MILLIS)
    }

    /**
     * 在 `Application.onCreate` 里调一次。重复调用无副作用。
     *
     * 基线（[WidgetRefreshBridge.seedBaseline]）必须在注册监听之前登记：
     * 否则启动后的第一次写入会拿「null 基线」去比，白白多刷一次。
     */
    fun initialize(context: Context) {
        synchronized(this) {
            if (initialized) return
            val app = context.applicationContext
            val preferences = app.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val refreshBridge = WidgetRefreshBridge(
                contentSignature = { signatureOf(preferences) },
                todayCourseCount = {
                    TodayWidgetSupport.readSnapshot(app)?.totalTodayCourseCount ?: 0
                },
                todayEpochDay = { LocalDate.now().toEpochDay() },
                onRefresh = { refreshWidgets(app) },
            )
            refreshBridge.seedBaseline()
            preferences.registerOnSharedPreferenceChangeListener(listener)
            appContext = app
            bridge = refreshBridge
            initialized = true
            Log.i(TAG, "subscribed to timetable prefs; widget refresh on change is live")
        }
    }

    /**
     * 把去抖后的这一次处理丢到 [WidgetRefreshSerial] 的 `widget-refresh` 线程；
     * 与闹钟入口、15 分钟兜底排同一条队，避免并发重排闹钟。
     *
     * 卡死保底：这一轮若超过 [WidgetRefreshSerial.ROUND_TIMEOUT_MILLIS] 不返回，
     * 由 `onTimeout` 记日志并补一次重排（正常路径本来也会重排，重复一次是幂等的取消+重设）。
     */
    private fun submitRefresh() {
        val app = appContext ?: return
        val refreshBridge = bridge ?: return
        WidgetRefreshSerial.executeGuarded(
            onTimeout = {
                Log.w(
                    TAG,
                    "widget refresh after timetable change stuck > ${WidgetRefreshSerial.ROUND_TIMEOUT_MILLIS}ms; " +
                        "forcing reschedule",
                )
                runCatching { HomeWidgetStorage.rescheduleRefresh(app) }
            },
        ) {
            try {
                if (!hasPlacedWidgets(app)) return@executeGuarded
                refreshBridge.onTimetableChanged()
            } catch (error: Throwable) {
                // 刷新失败不能打断用户正在做的事：记一条日志，等下一次变更 / 闹钟再来。
                Log.w(TAG, "widget refresh after timetable change failed", error)
            }
        }
    }

    /**
     * 当前落盘内容的签名：顺序固定 = 先 [WidgetRefreshSignature.WATCHED_KEYS] 的登记顺序，
     * 再按 key 字典序追加年度假期数据（`prefs.all` 的迭代顺序不保证稳定）。
     */
    private fun signatureOf(preferences: SharedPreferences): String {
        val all = preferences.all
        val parts = ArrayList<String?>()
        for (key in WidgetRefreshSignature.WATCHED_KEYS) {
            parts += all[FrozenValueCodec.physicalKey(key)]?.toString()
        }
        val holidayPrefix = FrozenValueCodec.physicalKey(WidgetRefreshSignature.HOLIDAY_DATA_KEY_PREFIX)
        all.entries
            .filter { (physicalKey, _) -> physicalKey.startsWith(holidayPrefix) }
            .sortedBy { it.key }
            .forEach { (physicalKey, value) ->
                parts += physicalKey.removePrefix(FrozenValueCodec.KEY_PREFIX)
                parts += value?.toString()
            }
        return WidgetRefreshSignature.build(parts)
    }

    /** 桌面上是否至少放了一张本 App 的卡片（十种卡型全部算）。 */
    private fun hasPlacedWidgets(context: Context): Boolean {
        val manager = AppWidgetManager.getInstance(context)
        return WidgetProviderCatalog.all.any { (_, providerClass) ->
            manager.getAppWidgetIds(ComponentName(context, providerClass)).isNotEmpty()
        }
    }

    private fun refreshWidgets(context: Context) {
        TodayWidgetSupport.updateAll(context)
        StatsWidgetSupport.updateAll(context)
        HomeWidgetStorage.rescheduleRefresh(context)
    }
}
