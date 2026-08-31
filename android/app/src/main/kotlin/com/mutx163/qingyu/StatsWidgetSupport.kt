package com.mutx163.qingyu

import android.content.Context
import android.util.Log
import org.json.JSONObject

data class StatsWidgetSnapshot(
    val profileName: String,
    val currentWeek: Int,
    val weekSections: Int,
    val weekCourseCount: Int,
    val deltaVsLastWeek: Int,
    val semesterDone: Int,
    val semesterTotal: Int,
    val requiredCount: Int,
    val electiveCount: Int,
    val longestStreak: Int,
) {
    companion object {
        fun fromJson(json: JSONObject): StatsWidgetSnapshot = StatsWidgetSnapshot(
            profileName = json.optString("profileName", ""),
            currentWeek = json.optInt("currentWeek", 0),
            weekSections = json.optInt("weekSections", 0),
            weekCourseCount = json.optInt("weekCourseCount", 0),
            deltaVsLastWeek = json.optInt("deltaVsLastWeek", 0),
            semesterDone = json.optInt("semesterDone", 0),
            semesterTotal = json.optInt("semesterTotal", 0),
            requiredCount = json.optInt("requiredCount", 0),
            electiveCount = json.optInt("electiveCount", 0),
            longestStreak = json.optInt("longestStreak", 0),
        )
    }
}

/**
 * 统计小组件的外观设置，与今日系列共用同一份用户配置：
 * 背景风格（solid/glass/gradient）、圆角档位、高度微调。
 */
data class StatsWidgetChrome(
    val backgroundStyle: String,
    val cornerRadius: Int,
    val heightAdjustment: Int,
)

/** Storage + shared rendering helpers for the stats widgets. */
object StatsWidgetSupport {
    private const val PREFS_NAME = "stats_widget_prefs"
    private const val KEY_SNAPSHOT_JSON = "snapshot_json"

    /** 默认值与 TimetableSettings 的默认外观保持一致（solid / 22dp / -11dp）。 */
    private val DEFAULT_CHROME = StatsWidgetChrome(
        backgroundStyle = "solid",
        cornerRadius = TodayWidgetSupport.DEFAULT_CORNER_RADIUS_DP,
        heightAdjustment = TodayWidgetSupport.DEFAULT_HEIGHT_ADJUSTMENT_DP,
    )

    fun syncSnapshot(context: Context, snapshot: Map<String, Any?>) {
        val payload = JSONObject(snapshot).toString()
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SNAPSHOT_JSON, payload)
            .apply()
        updateAll(context)
    }

    fun clearSnapshot(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_SNAPSHOT_JSON)
            .apply()
        updateAll(context)
    }

    private const val TAG = "StatsWidgetSupport"

    /**
     * 同一次批量刷新内的轻量缓存：三个 Stats Provider 的 onUpdate 会被
     * ACTION_APPWIDGET_UPDATE 一次性全部触发，各自调 readSnapshot + readChrome，
     * 不缓存的话同一份 profiles JSON 在一轮刷新里要被解析 6 次。
     * key 用 profiles 原始字符串 + 计算日期，快照跨天必然失配，不会返回过期数据。
     */
    @Volatile
    private var cachedProfileJson: String? = null

    @Volatile
    private var cachedSnapshot: StatsWidgetSnapshot? = null

    @Volatile
    private var cachedSnapshotDayStart: Long = Long.MIN_VALUE

    fun readSnapshot(context: Context): StatsWidgetSnapshot? {
        // Prefer real-time computation from Flutter prefs (same source as Today
        // widgets) so stats stay fresh without opening the app. The static
        // snapshot synced from Flutter is only a fallback.
        val rawProfile = TodayWidgetSupport.readActiveProfileRawJson(context)
        if (rawProfile != null) {
            val todayStart = TodayWidgetSupport.dayStartMillis()
            synchronized(this) {
                if (rawProfile == cachedProfileJson && todayStart == cachedSnapshotDayStart) {
                    return cachedSnapshot ?: readStaticSnapshot(context)
                }
            }
            val computed = try {
                WidgetStatsLogic.buildSnapshot(JSONObject(rawProfile))
            } catch (error: Exception) {
                // 实时计算失败不再静默：至少留 debug 日志，否则桌面数值陈旧无从排查。
                Log.d(TAG, "stats live compute failed, fall back to static snapshot", error)
                null
            }
            if (computed != null) {
                synchronized(this) {
                    cachedProfileJson = rawProfile
                    cachedSnapshot = computed
                    cachedSnapshotDayStart = todayStart
                }
                return computed
            }
        }
        return readStaticSnapshot(context)
    }

    private fun readStaticSnapshot(context: Context): StatsWidgetSnapshot? {
        val raw = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_SNAPSHOT_JSON, null) ?: return null
        return try {
            StatsWidgetSnapshot.fromJson(JSONObject(raw))
        } catch (error: Exception) {
            Log.d(TAG, "stats static snapshot parse failed", error)
            null
        }
    }

    /**
     * 直接从 Flutter SharedPreferences 读取与今日小组件同源的外观设置，
     * 无需 Dart 侧扩协议；无档案时回退到默认值。
     */
    fun readChrome(context: Context): StatsWidgetChrome {
        val settings = TodayWidgetSupport.readActiveProfileRawJson(context)
            ?.let { raw ->
                try {
                    JSONObject(raw).optJSONObject("settings")
                } catch (_: Exception) {
                    null
                }
            } ?: JSONObject()
        return StatsWidgetChrome(
            backgroundStyle = settings.optString("widgetBackgroundStyle", DEFAULT_CHROME.backgroundStyle),
            cornerRadius = settings.optDouble("widgetCornerRadius", DEFAULT_CHROME.cornerRadius.toDouble()).toInt(),
            heightAdjustment = settings.optDouble("widgetHeightAdjustment", DEFAULT_CHROME.heightAdjustment.toDouble()).toInt(),
        )
    }

    fun updateAll(context: Context) {
        StatsCompactWidgetProvider.updateAll(context)
        StatsMediumWidgetProvider.updateAll(context)
        StatsStripWidgetProvider.updateAll(context)
    }

    fun deltaLabel(context: Context, delta: Int): String {
        return when {
            delta > 0 -> context.getString(R.string.widget_stats_vs_last_up, delta)
            delta < 0 -> context.getString(R.string.widget_stats_vs_last_down, -delta)
            else -> context.getString(R.string.widget_stats_vs_last_flat)
        }
    }

    /** 窄宽度档的环比缩写（"+2 节"/"-2 节"/"持平"），配合两档显示门限使用。 */
    fun deltaShortLabel(context: Context, delta: Int): String {
        return when {
            delta > 0 -> context.getString(R.string.widget_stats_delta_short_up, delta)
            delta < 0 -> context.getString(R.string.widget_stats_delta_short_down, -delta)
            else -> context.getString(R.string.widget_stats_delta_short_flat)
        }
    }
}
