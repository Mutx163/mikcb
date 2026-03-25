package com.example.university_timetable

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import org.json.JSONArray
import org.json.JSONObject

data class TodayWidgetCourseInfo(
    val id: String,
    val name: String,
    val shortName: String?,
    val location: String,
    val startTime: String,
    val endTime: String,
)

data class TodayWidgetSnapshotInfo(
    val profileName: String,
    val currentWeek: Int,
    val state: String,
    val backgroundStyle: String,
    val showLocation: Boolean,
    val showCountdown: Boolean,
    val todayCourses: List<TodayWidgetCourseInfo>,
    val highlightedCourse: TodayWidgetCourseInfo?,
    val nextCourse: TodayWidgetCourseInfo?,
)

object TodayWidgetSupport {
    fun readSnapshot(context: Context): TodayWidgetSnapshotInfo? {
        val payload = HomeWidgetStorage.getSnapshotJson(context) ?: return null
        return try {
            parseSnapshot(JSONObject(payload))
        } catch (_: Exception) {
            null
        }
    }

    fun updateAll(context: Context) {
        TodayCompactWidgetProvider.updateAll(context)
        TodayMiniListWidgetProvider.updateAll(context)
        TodayMediumWidgetProvider.updateAll(context)
        TodayLargeWidgetProvider.updateAll(context)
    }

    fun backgroundRes(style: String): Int {
        return when (style) {
            "solid" -> R.drawable.widget_today_compact_bg_solid
            "gradient" -> R.drawable.widget_today_compact_bg_gradient
            else -> R.drawable.widget_today_compact_bg_solid
        }
    }

    fun primaryTextColor(style: String): Int {
        return if (style == "gradient") Color.WHITE else Color.parseColor("#0F172A")
    }

    fun secondaryTextColor(style: String): Int {
        return if (style == "gradient") {
            Color.parseColor("#DDE7FF")
        } else {
            Color.parseColor("#64748B")
        }
    }

    fun statusText(state: String): String {
        return when (state) {
            "ongoing" -> "正在上课"
            "upcoming" -> "下一节课"
            "completed" -> "今日已结束"
            else -> "今日无课"
        }
    }

    fun statusBackgroundRes(state: String, style: String): Int {
        return when (state) {
            "ongoing", "upcoming" -> {
                if (style == "gradient") {
                    R.drawable.widget_status_chip_light
                } else {
                    R.drawable.widget_status_chip_strong
                }
            }
            else -> {
                if (style == "gradient") {
                    R.drawable.widget_status_chip_dim_light
                } else {
                    R.drawable.widget_status_chip_dim
                }
            }
        }
    }

    fun heroCourseName(snapshot: TodayWidgetSnapshotInfo): String {
        return when {
            snapshot.highlightedCourse != null -> snapshot.highlightedCourse.name
            snapshot.state == "completed" -> "今天课程已结束"
            else -> "今天没有课程"
        }
    }

    fun heroTimeText(snapshot: TodayWidgetSnapshotInfo): String {
        val highlighted = snapshot.highlightedCourse
        return when {
            highlighted != null &&
                highlighted.startTime.isNotBlank() &&
                highlighted.endTime.isNotBlank() -> {
                "${highlighted.startTime} - ${highlighted.endTime}"
            }
            snapshot.state == "completed" -> "接下来没有课程"
            else -> "留一点时间给自己"
        }
    }

    fun heroMetaText(snapshot: TodayWidgetSnapshotInfo): String {
        val highlighted = snapshot.highlightedCourse
        return when {
            !snapshot.showLocation -> "第${snapshot.currentWeek}周"
            highlighted != null && highlighted.location.isNotBlank() -> highlighted.location
            snapshot.todayCourses.isNotEmpty() -> "第${snapshot.currentWeek}周 · 共${snapshot.todayCourses.size}节"
            else -> "第${snapshot.currentWeek}周"
        }
    }

    fun compactMetaText(snapshot: TodayWidgetSnapshotInfo): String {
        val highlighted = snapshot.highlightedCourse
        return when {
            highlighted == null -> heroTimeText(snapshot)
            snapshot.showLocation && highlighted.location.isNotBlank() ->
                "${heroTimeText(snapshot)}\n${highlighted.location}"
            else -> heroTimeText(snapshot)
        }
    }

    fun footerText(snapshot: TodayWidgetSnapshotInfo): String {
        return if (snapshot.todayCourses.isNotEmpty()) {
            "${snapshot.profileName} · 今日 ${snapshot.todayCourses.size} 节"
        } else {
            "${snapshot.profileName} · 第${snapshot.currentWeek}周"
        }
    }

    fun secondaryCourses(snapshot: TodayWidgetSnapshotInfo, limit: Int): List<TodayWidgetCourseInfo> {
        val highlightedId = snapshot.highlightedCourse?.id
        val courses = if (highlightedId == null) {
            snapshot.todayCourses
        } else {
            snapshot.todayCourses.filterNot { it.id == highlightedId }
        }
        return courses.take(limit)
    }

    fun buildLaunchPendingIntent(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun parseSnapshot(json: JSONObject): TodayWidgetSnapshotInfo {
        return TodayWidgetSnapshotInfo(
            profileName = json.optString("profileName", "轻屿课表"),
            currentWeek = json.optInt("currentWeek", 1),
            state = json.optString("state", "no_course"),
            backgroundStyle = json.optString("backgroundStyle", "solid"),
            showLocation = json.optBoolean("showLocation", true),
            showCountdown = json.optBoolean("showCountdown", true),
            todayCourses = parseCourses(json.optJSONArray("todayCourses")),
            highlightedCourse = json.optJSONObject("highlightedCourse")?.let(::parseCourse),
            nextCourse = json.optJSONObject("nextCourse")?.let(::parseCourse),
        )
    }

    private fun parseCourses(json: JSONArray?): List<TodayWidgetCourseInfo> {
        if (json == null) {
            return emptyList()
        }
        return buildList {
            for (index in 0 until json.length()) {
                val item = json.optJSONObject(index) ?: continue
                add(parseCourse(item))
            }
        }
    }

    private fun parseCourse(json: JSONObject): TodayWidgetCourseInfo {
        return TodayWidgetCourseInfo(
            id = json.optString("id"),
            name = json.optString("name"),
            shortName = json.optString("shortName").takeIf { it.isNotBlank() },
            location = json.optString("location"),
            startTime = json.optString("startTime"),
            endTime = json.optString("endTime"),
        )
    }
}
