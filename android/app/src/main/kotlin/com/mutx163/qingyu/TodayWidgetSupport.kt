package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.util.TypedValue
import android.widget.RemoteViews
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
    val hideCompletedCourses: Boolean,
    val heightAdjustment: Int,
    val cornerRadius: Int,
    val totalTodayCourseCount: Int,
    val todayCourses: List<TodayWidgetCourseInfo>,
    val visibleTodayCourses: List<TodayWidgetCourseInfo>,
    val highlightedCourse: TodayWidgetCourseInfo?,
    val nextCourse: TodayWidgetCourseInfo?,
)

data class TodayWidgetSizeProfile(
    val widthDp: Int,
    val heightDp: Int,
) {
    val isNarrow: Boolean get() = widthDp < 130
    val isShort: Boolean get() = heightDp < 150
    val isTall: Boolean get() = heightDp > 250
    val isWide: Boolean get() = widthDp > heightDp + 36
}

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

    fun sizeProfile(
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ): TodayWidgetSizeProfile {
        val options: Bundle = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            .coerceAtLeast(110)
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
            .coerceAtLeast(110)
        return TodayWidgetSizeProfile(widthDp = width, heightDp = height)
    }

    fun applySquareishPadding(
        views: RemoteViews,
        rootId: Int,
        profile: TodayWidgetSizeProfile,
        baseHorizontalDp: Int,
        baseVerticalDp: Int,
        heightAdjustmentDp: Int,
        targetAspect: Float = 1f,
        maxAdaptiveInsetDp: Int = 18,
    ) {
        val horizontal = 0
        var vertical = baseVerticalDp

        val targetHeight = profile.widthDp / targetAspect
        if (profile.heightDp > targetHeight) {
            vertical += ((profile.heightDp - targetHeight) / 4f)
                .toInt()
                .coerceIn(0, maxAdaptiveInsetDp)
        } else if (profile.isShort) {
            vertical = (baseVerticalDp - 6).coerceAtLeast(0)
        }
        vertical = (vertical - heightAdjustmentDp).coerceIn(0, baseVerticalDp + maxAdaptiveInsetDp + 24)

        views.setViewPadding(
            rootId,
            horizontal,
            vertical,
            horizontal,
            vertical,
        )
    }

    fun setTextSizeSp(views: RemoteViews, viewId: Int, sizeSp: Float) {
        views.setTextViewTextSize(viewId, TypedValue.COMPLEX_UNIT_SP, sizeSp)
    }

    fun miniListVisibleRows(profile: TodayWidgetSizeProfile): Int {
        return when {
            profile.heightDp >= 190 -> 3
            profile.heightDp >= 150 -> 2
            else -> 1
        }
    }

    fun mediumVisibleRows(profile: TodayWidgetSizeProfile): Int {
        return when {
            profile.heightDp >= 250 -> 3
            profile.heightDp >= 210 -> 2
            else -> 1
        }
    }

    fun largeVisibleRows(profile: TodayWidgetSizeProfile): Int {
        return when {
            profile.heightDp >= 360 -> 5
            profile.heightDp >= 300 -> 4
            else -> 3
        }
    }

    fun backgroundRes(style: String, cornerRadius: Int): Int {
        val radius = normalizedCornerRadius(cornerRadius)
        return when (style) {
            "gradient" -> gradientBackgroundRes(radius)
            else -> solidBackgroundRes(radius)
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
            snapshot.totalTodayCourseCount > 0 -> "第${snapshot.currentWeek}周 · 共${snapshot.totalTodayCourseCount}节"
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
        return if (snapshot.totalTodayCourseCount > 0) {
            "${snapshot.profileName} · 今日 ${snapshot.totalTodayCourseCount} 节"
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
        val allCourses = parseCourses(json.optJSONArray("todayCourses"))
        val visibleCourses = json.optJSONArray("visibleTodayCourses")?.let(::parseCourses)
            ?: allCourses
        return TodayWidgetSnapshotInfo(
            profileName = json.optString("profileName", "轻屿课表"),
            currentWeek = json.optInt("currentWeek", 1),
            state = json.optString("state", "no_course"),
            backgroundStyle = json.optString("backgroundStyle", "solid"),
            showLocation = json.optBoolean("showLocation", true),
            showCountdown = json.optBoolean("showCountdown", true),
            hideCompletedCourses = json.optBoolean("hideCompletedCourses", false),
            heightAdjustment = json.optDouble("heightAdjustment", 0.0).toInt(),
            cornerRadius = json.optDouble("cornerRadius", 28.0).toInt(),
            totalTodayCourseCount = json.optInt(
                "totalTodayCourseCount",
                allCourses.size
            ),
            todayCourses = allCourses,
            visibleTodayCourses = visibleCourses,
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

    private fun normalizedCornerRadius(cornerRadius: Int): Int {
        return (cornerRadius.coerceIn(0, 36) / 2) * 2
    }

    private fun solidBackgroundRes(radius: Int): Int {
        return when (radius) {
            0 -> R.drawable.widget_today_bg_solid_r00
            2 -> R.drawable.widget_today_bg_solid_r02
            4 -> R.drawable.widget_today_bg_solid_r04
            6 -> R.drawable.widget_today_bg_solid_r06
            8 -> R.drawable.widget_today_bg_solid_r08
            10 -> R.drawable.widget_today_bg_solid_r10
            12 -> R.drawable.widget_today_bg_solid_r12
            14 -> R.drawable.widget_today_bg_solid_r14
            16 -> R.drawable.widget_today_bg_solid_r16
            18 -> R.drawable.widget_today_bg_solid_r18
            20 -> R.drawable.widget_today_bg_solid_r20
            22 -> R.drawable.widget_today_bg_solid_r22
            24 -> R.drawable.widget_today_bg_solid_r24
            26 -> R.drawable.widget_today_bg_solid_r26
            28 -> R.drawable.widget_today_bg_solid_r28
            30 -> R.drawable.widget_today_bg_solid_r30
            32 -> R.drawable.widget_today_bg_solid_r32
            34 -> R.drawable.widget_today_bg_solid_r34
            else -> R.drawable.widget_today_bg_solid_r36
        }
    }

    private fun gradientBackgroundRes(radius: Int): Int {
        return when (radius) {
            0 -> R.drawable.widget_today_bg_gradient_r00
            2 -> R.drawable.widget_today_bg_gradient_r02
            4 -> R.drawable.widget_today_bg_gradient_r04
            6 -> R.drawable.widget_today_bg_gradient_r06
            8 -> R.drawable.widget_today_bg_gradient_r08
            10 -> R.drawable.widget_today_bg_gradient_r10
            12 -> R.drawable.widget_today_bg_gradient_r12
            14 -> R.drawable.widget_today_bg_gradient_r14
            16 -> R.drawable.widget_today_bg_gradient_r16
            18 -> R.drawable.widget_today_bg_gradient_r18
            20 -> R.drawable.widget_today_bg_gradient_r20
            22 -> R.drawable.widget_today_bg_gradient_r22
            24 -> R.drawable.widget_today_bg_gradient_r24
            26 -> R.drawable.widget_today_bg_gradient_r26
            28 -> R.drawable.widget_today_bg_gradient_r28
            30 -> R.drawable.widget_today_bg_gradient_r30
            32 -> R.drawable.widget_today_bg_gradient_r32
            34 -> R.drawable.widget_today_bg_gradient_r34
            else -> R.drawable.widget_today_bg_gradient_r36
        }
    }
}

