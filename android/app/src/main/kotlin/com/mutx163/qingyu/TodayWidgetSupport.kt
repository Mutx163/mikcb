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
import java.util.Calendar

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
    val countdownTextStyle: String,
    val hideCompletedCourses: Boolean,
    val heightAdjustment: Int,
    val cornerRadius: Int,
    val totalTodayCourseCount: Int,
    val todayCourses: List<TodayWidgetCourseInfo>,
    val visibleTodayCourses: List<TodayWidgetCourseInfo>,
    val highlightedCourse: TodayWidgetCourseInfo?,
    val nextCourse: TodayWidgetCourseInfo?,
    val nextExamName: String?,
    val nextExamDate: String?,
    val nextExamDaysUntil: Int?,
    val nextExamLocation: String?,
    val nextExamStartTime: String?,
    val nextExamEndTime: String?,
    val holidayName: String? = null,
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

private data class WidgetSourceCourse(
    val id: String,
    val name: String,
    val shortName: String?,
    val location: String,
    val startTime: String,
    val endTime: String,
    val dayOfWeek: Int,
    val startSection: Int,
    val endSection: Int,
    val startWeek: Int,
    val endWeek: Int,
    val isOddWeek: Boolean,
    val isEvenWeek: Boolean,
    val customWeeks: List<Int>?,
) {
    fun isInWeek(week: Int): Boolean {
        val normalizedCustomWeeks = customWeeks
            ?.filter { it > 0 }
            ?.distinct()
            ?.sorted()
            ?.takeIf { it.isNotEmpty() }
        if (normalizedCustomWeeks != null) {
            return normalizedCustomWeeks.contains(week)
        }
        if (week < startWeek || week > endWeek) {
            return false
        }
        if (isOddWeek && week % 2 == 0) {
            return false
        }
        if (isEvenWeek && week % 2 != 0) {
            return false
        }
        return true
    }

    fun toWidgetCourseInfo(): TodayWidgetCourseInfo {
        return TodayWidgetCourseInfo(
            id = id,
            name = name,
            shortName = shortName,
            location = location,
            startTime = startTime,
            endTime = endTime,
        )
    }
}

object TodayWidgetSupport {
    private const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
    private const val KEY_TIMETABLE_PROFILES = "flutter.timetable_profiles"
    private const val KEY_ACTIVE_PROFILE_ID = "flutter.active_timetable_profile_id"

    fun readSnapshot(context: Context): TodayWidgetSnapshotInfo? {
        val payload = HomeWidgetStorage.getSnapshotJson(context)
        if (payload != null) {
            try {
                return parseSnapshot(JSONObject(payload))
            } catch (_: Exception) {
                // fall through to native fallback
            }
        }
        return buildSnapshotFromFlutterState(context)
    }

    fun updateAll(context: Context) {
        TodayCompactWidgetProvider.updateAll(context)
        TodayMiniListWidgetProvider.updateAll(context)
        TodayMediumWidgetProvider.updateAll(context)
        TodayLargeWidgetProvider.updateAll(context)
    }

    fun buildSnapshotFromFlutterState(
        context: Context,
        nowMillis: Long = System.currentTimeMillis(),
    ): TodayWidgetSnapshotInfo? {
        val profileJson = readActiveProfileJson(context) ?: return null
        val settingsJson = profileJson.optJSONObject("settings") ?: JSONObject()
        val isHoliday = profileJson.optBoolean("isHoliday", false)
            || settingsJson.optBoolean("holidayOverrideEnabled", false)
        val semesterWeekCount = settingsJson.optInt("semesterWeekCount", 20).coerceAtLeast(1)
        val currentWeek = calculateWeekForDate(
            semesterStartMillis = settingsJson.optLong("semesterStartDate").takeIf { it > 0L },
            fallbackWeek = profileJson.optInt("currentWeek", 1).coerceAtLeast(1),
            semesterWeekCount = semesterWeekCount,
            nowMillis = nowMillis,
        )
        val todayWeekday = Calendar.getInstance().apply {
            timeInMillis = nowMillis
        }.get(Calendar.DAY_OF_WEEK).let(::calendarDayToWeekday)
        val allCourses = parseSourceCourses(profileJson.optJSONArray("courses"))
        val todayCourses = if (isHoliday) {
            emptyList()
        } else {
            allCourses
                .filter { it.dayOfWeek == todayWeekday && it.isInWeek(currentWeek) }
                .sortedWith(compareBy<WidgetSourceCourse>({ it.startSection }, { it.startTime }))
        }
        val currentCourse = if (isHoliday) {
            null
        } else {
            todayCourses.firstOrNull { course ->
                val startMillis = buildCourseDateTimeMillis(nowMillis, course.startTime) ?: return@firstOrNull false
                val endMillis = buildCourseDateTimeMillis(nowMillis, course.endTime) ?: return@firstOrNull false
                nowMillis in startMillis..endMillis
            }
        }
        val upcomingCourse = if (isHoliday) {
            null
        } else {
            todayCourses.firstOrNull { course ->
                val startMillis = buildCourseDateTimeMillis(nowMillis, course.startTime) ?: return@firstOrNull false
                startMillis > nowMillis
            }
        }
        val hideCompletedCourses = settingsJson.optBoolean("widgetHideCompletedCourses", false)
        val visibleTodayCourses = if (isHoliday) {
            emptyList()
        } else if (hideCompletedCourses) {
            todayCourses.filter { course ->
                val endMillis = buildCourseDateTimeMillis(nowMillis, course.endTime) ?: return@filter false
                endMillis > nowMillis
            }
        } else {
            todayCourses
        }
        val state = when {
            isHoliday -> "holiday"
            todayCourses.isEmpty() -> "no_course"
            currentCourse != null -> "ongoing"
            upcomingCourse != null -> "upcoming"
            else -> "completed"
        }
        val widgetShowCountdown = settingsJson.optBoolean("widgetShowCountdown", true)
        val countdownLeadMinutes = settingsJson.optInt("widgetCountdownLeadMinutes", 20)
        val effectiveShowCountdown = when {
            !widgetShowCountdown -> false
            countdownLeadMinutes == 0 -> true
            state == "ongoing" -> true
            state == "upcoming" && upcomingCourse != null -> {
                val startMillis = buildCourseDateTimeMillis(nowMillis, upcomingCourse.startTime)
                if (startMillis != null) {
                    val threshold = startMillis - countdownLeadMinutes * 60_000L
                    nowMillis >= threshold
                } else {
                    false
                }
            }
            else -> false
        }
        // Find next upcoming exam
        val nowCalendar = Calendar.getInstance().apply { timeInMillis = nowMillis }
        val todayDateStr = String.format("%04d-%02d-%02d",
            nowCalendar.get(Calendar.YEAR),
            nowCalendar.get(Calendar.MONTH) + 1,
            nowCalendar.get(Calendar.DAY_OF_MONTH),
        )
        val examsArray = profileJson.optJSONArray("exams")
        var nextExamName: String? = null
        var nextExamDate: String? = null
        var nextExamDaysUntil: Int? = null
        var nextExamLocation: String? = null
        var nextExamStartTime: String? = null
        var nextExamEndTime: String? = null
        if (examsArray != null) {
            var bestDate: String? = null
            for (i in 0 until examsArray.length()) {
                val exam = examsArray.optJSONObject(i) ?: continue
                val dateStr = exam.optString("dateTime").takeIf { it.isNotBlank() } ?: continue
                val dateOnly = dateStr.take(10) // "yyyy-MM-dd"
                if (dateOnly < todayDateStr) continue // expired
                if (bestDate == null || dateOnly < bestDate) {
                    bestDate = dateOnly
                    nextExamName = exam.optString("name").takeIf { it.isNotBlank() }
                    nextExamDate = dateOnly
                    nextExamLocation = exam.optString("location").takeIf { it.isNotBlank() }
                    nextExamStartTime = exam.optString("startTime").takeIf { it.isNotBlank() }
                    nextExamEndTime = exam.optString("endTime").takeIf { it.isNotBlank() }
                }
            }
            if (bestDate != null) {
                // Calculate daysUntil
                val examCal = Calendar.getInstance().apply {
                    val parts = bestDate!!.split("-")
                    if (parts.size == 3) {
                        set(Calendar.YEAR, parts[0].toInt())
                        set(Calendar.MONTH, parts[1].toInt() - 1)
                        set(Calendar.DAY_OF_MONTH, parts[2].toInt())
                        set(Calendar.HOUR_OF_DAY, 0)
                        set(Calendar.MINUTE, 0)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                    }
                }
                val todayCal = Calendar.getInstance().apply {
                    timeInMillis = nowMillis
                    set(Calendar.HOUR_OF_DAY, 0)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                val diffDays = ((examCal.timeInMillis - todayCal.timeInMillis) / 86_400_000L).toInt()
                nextExamDaysUntil = diffDays.coerceAtLeast(0)
            }
        }
        return TodayWidgetSnapshotInfo(
            profileName = profileJson.optString("name", "轻屿课表"),
            currentWeek = currentWeek,
            state = state,
            backgroundStyle = settingsJson.optString("widgetBackgroundStyle", "solid"),
            showLocation = settingsJson.optBoolean("widgetShowLocation", true),
            showCountdown = effectiveShowCountdown,
            countdownTextStyle = settingsJson.optString("widgetCountdownTextStyle", "smart"),
            hideCompletedCourses = hideCompletedCourses,
            heightAdjustment = settingsJson.optDouble("widgetHeightAdjustment", -11.0).toInt(),
            cornerRadius = settingsJson.optDouble("widgetCornerRadius", 22.0).toInt(),
            totalTodayCourseCount = todayCourses.size,
            todayCourses = todayCourses.map { it.toWidgetCourseInfo() },
            visibleTodayCourses = visibleTodayCourses.map { it.toWidgetCourseInfo() },
            highlightedCourse = (currentCourse ?: upcomingCourse)?.toWidgetCourseInfo(),
            nextCourse = upcomingCourse?.toWidgetCourseInfo(),
            nextExamName = nextExamName,
            nextExamDate = nextExamDate,
            nextExamDaysUntil = nextExamDaysUntil,
            nextExamLocation = nextExamLocation,
            nextExamStartTime = nextExamStartTime,
            nextExamEndTime = nextExamEndTime,
        )
    }

    fun findNextRefreshAtMillis(
        context: Context,
        nowMillis: Long = System.currentTimeMillis(),
    ): Long? {
        val profileJson = readActiveProfileJson(context) ?: return null
        val settingsJson = profileJson.optJSONObject("settings") ?: JSONObject()
        val isHoliday = profileJson.optBoolean("isHoliday", false)
            || settingsJson.optBoolean("holidayOverrideEnabled", false)
        if (isHoliday) return null
        val semesterWeekCount = settingsJson.optInt("semesterWeekCount", 20).coerceAtLeast(1)
        val currentWeek = calculateWeekForDate(
            semesterStartMillis = settingsJson.optLong("semesterStartDate").takeIf { it > 0L },
            fallbackWeek = profileJson.optInt("currentWeek", 1).coerceAtLeast(1),
            semesterWeekCount = semesterWeekCount,
            nowMillis = nowMillis,
        )
        val weekday = Calendar.getInstance().apply {
            timeInMillis = nowMillis
        }.get(Calendar.DAY_OF_WEEK).let(::calendarDayToWeekday)
        val todayCourses = parseSourceCourses(profileJson.optJSONArray("courses"))
            .filter { it.dayOfWeek == weekday && it.isInWeek(currentWeek) }
            .sortedWith(compareBy<WidgetSourceCourse>({ it.startSection }, { it.startTime }))

        val countdownLeadMinutes = settingsJson.optInt("widgetCountdownLeadMinutes", 20)
        val triggers = mutableListOf<Long>()
        for (course in todayCourses) {
            val startMillis = buildCourseDateTimeMillis(nowMillis, course.startTime)
            val endMillis = buildCourseDateTimeMillis(nowMillis, course.endTime)
            if (startMillis != null && startMillis > nowMillis) {
                triggers += startMillis
                if (countdownLeadMinutes > 0) {
                    val activation = startMillis - countdownLeadMinutes * 60_000L
                    if (activation > nowMillis) {
                        triggers += activation
                    }
                }
            }
            if (endMillis != null && endMillis > nowMillis) {
                triggers += endMillis + 1000L
            }
        }
        // 倒计时激活时每 60 秒刷新
        val snapshot = buildSnapshotFromFlutterState(context, nowMillis)
        if (snapshot != null
            && snapshot.showCountdown
            && (snapshot.state == "ongoing" || snapshot.state == "upcoming")) {
            triggers += nowMillis + 60_000L
        }
        triggers += buildNextMidnightMillis(nowMillis) + 1000L
        return triggers.filter { it > nowMillis }.minOrNull()
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
            "glass" -> glassBackgroundRes(radius)
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
            "holiday" -> "今日假期"
            else -> "今日无课"
        }
    }

    fun statusBackgroundRes(state: String, style: String): Int {
        return when (state) {
            "ongoing", "upcoming", "holiday" -> {
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
            snapshot.state == "holiday" -> snapshot.holidayName ?: "假期中"
            snapshot.highlightedCourse != null -> snapshot.highlightedCourse.name
            snapshot.state == "completed" -> "今天课程已结束"
            else -> "今天没有课程"
        }
    }

    fun heroTimeText(snapshot: TodayWidgetSnapshotInfo): String {
        if (snapshot.state == "holiday") {
            return "好好休息"
        }
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
        if (snapshot.state == "holiday") {
            return "第${snapshot.currentWeek}周"
        }
        val highlighted = snapshot.highlightedCourse
        return when {
            !snapshot.showLocation -> "第${snapshot.currentWeek}周"
            highlighted != null && highlighted.location.isNotBlank() -> highlighted.location
            snapshot.totalTodayCourseCount > 0 -> "第${snapshot.currentWeek}周 · 共${snapshot.totalTodayCourseCount}节"
            else -> "第${snapshot.currentWeek}周"
        }
    }

    fun compactMetaText(snapshot: TodayWidgetSnapshotInfo): String {
        if (snapshot.state == "holiday") {
            return "好好休息"
        }
        val highlighted = snapshot.highlightedCourse
        return when {
            highlighted == null -> heroTimeText(snapshot)
            snapshot.showLocation && highlighted.location.isNotBlank() ->
                "${heroTimeText(snapshot)}\n${highlighted.location}"
            else -> heroTimeText(snapshot)
        }
    }

    fun countdownText(
        snapshot: TodayWidgetSnapshotInfo,
        nowMillis: Long = System.currentTimeMillis(),
    ): String? {
        if (!snapshot.showCountdown) return null
        val course = snapshot.highlightedCourse ?: return null
        val style = snapshot.countdownTextStyle
        return when (snapshot.state) {
            "ongoing" -> {
                val endMillis = buildCourseDateTimeMillis(nowMillis, course.endTime) ?: return null
                val durationMillis = endMillis - nowMillis
                if (durationMillis <= 0) return null
                "还有 ${CountdownFormat.formatDuration(durationMillis, style)} 下课"
            }
            "upcoming" -> {
                val startMillis = buildCourseDateTimeMillis(nowMillis, course.startTime) ?: return null
                val durationMillis = startMillis - nowMillis
                if (durationMillis <= 0) return null
                "还有 ${CountdownFormat.formatDuration(durationMillis, style)} 上课"
            }
            else -> null
        }
    }

    fun examCountdownText(snapshot: TodayWidgetSnapshotInfo): String? {
        val name = snapshot.nextExamName ?: return null
        val daysUntil = snapshot.nextExamDaysUntil ?: return null
        val timeRange = if (!snapshot.nextExamStartTime.isNullOrBlank() && !snapshot.nextExamEndTime.isNullOrBlank()) {
            " ${snapshot.nextExamStartTime}-${snapshot.nextExamEndTime}"
        } else {
            ""
        }
        val location = if (!snapshot.nextExamLocation.isNullOrBlank()) {
            " ${snapshot.nextExamLocation}"
        } else {
            ""
        }
        return when {
            daysUntil == 0 -> "考试日 ${name}${timeRange}${location}"
            daysUntil <= 7 -> "距${name}还有${daysUntil}天${timeRange}${location}"
            else -> null
        }
    }

    fun footerText(snapshot: TodayWidgetSnapshotInfo): String {
        return if (snapshot.state == "holiday") {
            "${snapshot.profileName} · ${snapshot.holidayName ?: "假期中"}"
        } else if (snapshot.totalTodayCourseCount > 0) {
            "${snapshot.profileName} · 今日 ${snapshot.totalTodayCourseCount} 节"
        } else {
            "${snapshot.profileName} · 第${snapshot.currentWeek}周"
        }
    }

    fun secondaryCourses(snapshot: TodayWidgetSnapshotInfo, limit: Int): List<TodayWidgetCourseInfo> {
        val highlightedId = snapshot.highlightedCourse?.id
        val courses = if (highlightedId == null) {
            snapshot.visibleTodayCourses
        } else {
            snapshot.visibleTodayCourses.filterNot { it.id == highlightedId }
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
            countdownTextStyle = json.optString("countdownTextStyle", "smart"),
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
            nextExamName = json.optString("nextExamName").takeIf { it.isNotBlank() },
            nextExamDate = json.optString("nextExamDate").takeIf { it.isNotBlank() },
            nextExamDaysUntil = json.optInt("nextExamDaysUntil", -1).takeIf { it >= 0 },
            nextExamLocation = json.optString("nextExamLocation").takeIf { it.isNotBlank() },
            nextExamStartTime = json.optString("nextExamStartTime").takeIf { it.isNotBlank() },
            nextExamEndTime = json.optString("nextExamEndTime").takeIf { it.isNotBlank() },
            holidayName = json.optString("holidayName").takeIf { it.isNotBlank() },
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

    private fun readActiveProfileJson(context: Context): JSONObject? {
        val flutterPrefs = context.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
        val profilesPayload = flutterPrefs.getString(KEY_TIMETABLE_PROFILES, null) ?: return null
        return try {
            val activeProfileId = flutterPrefs.getString(KEY_ACTIVE_PROFILE_ID, null)
            val profiles = JSONArray(profilesPayload)
            var fallbackProfile: JSONObject? = null
            for (index in 0 until profiles.length()) {
                val profile = profiles.optJSONObject(index) ?: continue
                if (fallbackProfile == null) {
                    fallbackProfile = profile
                }
                if (!activeProfileId.isNullOrBlank() &&
                    profile.optString("id") == activeProfileId
                ) {
                    return profile
                }
            }
            fallbackProfile
        } catch (_: Exception) {
            null
        }
    }

    private fun parseSourceCourses(json: JSONArray?): List<WidgetSourceCourse> {
        if (json == null) {
            return emptyList()
        }
        return buildList {
            for (index in 0 until json.length()) {
                val item = json.optJSONObject(index) ?: continue
                add(
                    WidgetSourceCourse(
                        id = item.optString("id"),
                        name = item.optString("name"),
                        shortName = item.optString("shortName").takeIf { it.isNotBlank() },
                        location = item.optString("location"),
                        startTime = item.optString("startTime"),
                        endTime = item.optString("endTime"),
                        dayOfWeek = item.optInt("dayOfWeek", 1),
                        startSection = item.optInt("startSection", 1),
                        endSection = item.optInt("endSection", 1),
                        startWeek = item.optInt("startWeek", 1),
                        endWeek = item.optInt("endWeek", 20),
                        isOddWeek = item.optBoolean("isOddWeek", false),
                        isEvenWeek = item.optBoolean("isEvenWeek", false),
                        customWeeks = item.optJSONArray("customWeeks")?.let { rawWeeks ->
                            buildList {
                                for (weekIndex in 0 until rawWeeks.length()) {
                                    val week = rawWeeks.optInt(weekIndex, 0)
                                    if (week > 0) {
                                        add(week)
                                    }
                                }
                            }
                        },
                    )
                )
            }
        }
    }

    private fun calculateWeekForDate(
        semesterStartMillis: Long?,
        fallbackWeek: Int,
        semesterWeekCount: Int,
        nowMillis: Long,
    ): Int {
        if (semesterStartMillis == null) {
            return fallbackWeek.coerceIn(1, semesterWeekCount)
        }
        val normalizedNow = Calendar.getInstance().apply {
            timeInMillis = nowMillis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val normalizedStart = Calendar.getInstance().apply {
            timeInMillis = semesterStartMillis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val diffDays =
            ((normalizedNow.timeInMillis - normalizedStart.timeInMillis) / 86_400_000L).toInt()
        val week = (diffDays / 7) + 1
        return week.coerceIn(1, semesterWeekCount)
    }

    private fun buildCourseDateTimeMillis(
        nowMillis: Long,
        courseTime: String,
    ): Long? {
        val parts = courseTime.split(":")
        if (parts.size != 2) {
            return null
        }
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        return Calendar.getInstance().apply {
            timeInMillis = nowMillis
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    private fun buildNextMidnightMillis(nowMillis: Long): Long {
        return Calendar.getInstance().apply {
            timeInMillis = nowMillis
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    private fun calendarDayToWeekday(dayOfWeek: Int): Int {
        return when (dayOfWeek) {
            Calendar.MONDAY -> 1
            Calendar.TUESDAY -> 2
            Calendar.WEDNESDAY -> 3
            Calendar.THURSDAY -> 4
            Calendar.FRIDAY -> 5
            Calendar.SATURDAY -> 6
            Calendar.SUNDAY -> 7
            else -> 1
        }
    }

    private fun normalizedCornerRadius(cornerRadius: Int): Int {
        return (cornerRadius.coerceIn(0, 36) / 2) * 2
    }

    private fun glassBackgroundRes(radius: Int): Int {
        return when (radius) {
            0 -> R.drawable.widget_today_bg_glass_r00
            2 -> R.drawable.widget_today_bg_glass_r02
            4 -> R.drawable.widget_today_bg_glass_r04
            6 -> R.drawable.widget_today_bg_glass_r06
            8 -> R.drawable.widget_today_bg_glass_r08
            10 -> R.drawable.widget_today_bg_glass_r10
            12 -> R.drawable.widget_today_bg_glass_r12
            14 -> R.drawable.widget_today_bg_glass_r14
            16 -> R.drawable.widget_today_bg_glass_r16
            18 -> R.drawable.widget_today_bg_glass_r18
            20 -> R.drawable.widget_today_bg_glass_r20
            22 -> R.drawable.widget_today_bg_glass_r22
            24 -> R.drawable.widget_today_bg_glass_r24
            26 -> R.drawable.widget_today_bg_glass_r26
            28 -> R.drawable.widget_today_bg_glass_r28
            30 -> R.drawable.widget_today_bg_glass_r30
            32 -> R.drawable.widget_today_bg_glass_r32
            34 -> R.drawable.widget_today_bg_glass_r34
            else -> R.drawable.widget_today_bg_glass_r36
        }
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

