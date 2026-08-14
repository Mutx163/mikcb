package com.mutx163.qingyu

import android.content.Context
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

/** Storage + shared rendering helpers for the stats widgets. */
object StatsWidgetSupport {
    private const val PREFS_NAME = "stats_widget_prefs"
    private const val KEY_SNAPSHOT_JSON = "snapshot_json"

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

    fun readSnapshot(context: Context): StatsWidgetSnapshot? {
        val raw = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_SNAPSHOT_JSON, null) ?: return null
        return try {
            StatsWidgetSnapshot.fromJson(JSONObject(raw))
        } catch (_: Exception) {
            null
        }
    }

    fun updateAll(context: Context) {
        StatsCompactWidgetProvider.updateAll(context)
        StatsMediumWidgetProvider.updateAll(context)
    }

    fun deltaLabel(context: Context, delta: Int): String {
        return when {
            delta > 0 -> context.getString(R.string.widget_stats_vs_last_up, delta)
            delta < 0 -> context.getString(R.string.widget_stats_vs_last_down, -delta)
            else -> context.getString(R.string.widget_stats_vs_last_flat)
        }
    }
}
