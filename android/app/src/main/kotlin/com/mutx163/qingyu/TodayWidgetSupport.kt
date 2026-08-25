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
    /** 今天课程已结束时，显示明天的课程列表 */
    val tomorrowCourses: List<TodayWidgetCourseInfo> = emptyList(),
    /** 今天课程已结束时，明天是第几周 */
    val tomorrowWeek: Int = currentWeek,
    /** 今天课程已结束时，明天的星期几 (1=周一 ... 7=周日) */
    val tomorrowDayOfWeek: Int = 0,
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
    val suspendedWeeks: List<Int>?,
) {
    fun isInWeek(week: Int): Boolean {
        // 停课周次检查
        if (suspendedWeeks?.contains(week) == true) {
            return false
        }
        return isInWeekIgnoringSuspension(week)
    }

    fun isInWeekIgnoringSuspension(week: Int): Boolean {
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
    private const val KEY_CUSTOM_HOLIDAYS = "flutter.custom_holidays"
    private const val KEY_HOLIDAY_DATA_PREFIX = "flutter.holiday_data_"

    fun readSnapshot(context: Context): TodayWidgetSnapshotInfo? {
        // Prefer real-time computed snapshot (state reflects current time).
        // The stored snapshot from Flutter has a stale `state` that doesn't
        // update when a class ends, causing the widget to show "上课中"
        // after the countdown reaches zero.
        val computed = buildSnapshotFromFlutterState(context)
        if (computed != null) {
            return computed
        }
        // Fallback: stored snapshot from Flutter sync.
        val payload = HomeWidgetStorage.getSnapshotJson(context)
        if (payload != null) {
            try {
                return parseSnapshot(context, JSONObject(payload))
            } catch (_: Exception) {
                // fall through
            }
        }
        return null
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
        val nowCalendar = Calendar.getInstance().apply { timeInMillis = nowMillis }
        val todayDateStr = widgetFormatDate(
            year = nowCalendar.get(Calendar.YEAR),
            month = nowCalendar.get(Calendar.MONTH) + 1,
            dayOfMonth = nowCalendar.get(Calendar.DAY_OF_MONTH),
        )
        val holidayEntries = loadHolidayEntriesForDate(context, nowCalendar)
        val enableHolidayMarking = settingsJson.optBoolean("enableHolidayMarking", true)
        val holidayOverrideEnabled = settingsJson.optBoolean("holidayOverrideEnabled", false)
        // Prefer full holiday resolution from Flutter prefs. The legacy profile-level
        // isHoliday flag is only a same-day hint and is usually missing entirely.
        val isHoliday = widgetResolveIsHoliday(
            entries = holidayEntries,
            dateStr = todayDateStr,
            enableHolidayMarking = enableHolidayMarking,
            holidayOverrideEnabled = holidayOverrideEnabled,
        ) || liveSchedulerIsLegacyHolidayFlagActive(
            isHoliday = profileJson.optBoolean("isHoliday", false),
            isHolidayDate = profileJson.optString("isHolidayDate").takeIf { it.isNotBlank() },
            year = nowCalendar.get(Calendar.YEAR),
            month = nowCalendar.get(Calendar.MONTH) + 1,
            dayOfMonth = nowCalendar.get(Calendar.DAY_OF_MONTH),
        )
        val holidayName = if (isHoliday) {
            widgetResolveHolidayName(holidayEntries, todayDateStr)
        } else {
            null
        }
        val semesterWeekCount = settingsJson.optInt("semesterWeekCount", 20).coerceAtLeast(1)
        val semesterStartMillis = settingsJson.optLong("semesterStartDate").takeIf { it > 0L }
        // Course filtering must use calendar week (no semesterWeekCount clamp).
        // Clamping to the last teaching week after the term ends would revive
        // endWeek=N courses on every matching weekday forever.
        val scheduleWeek = liveSchedulerCalculateCalendarWeekForDate(
            semesterStartMillis = settingsJson.optLong("semesterStartDate").takeIf { it > 0L },
            currentWeek = profileJson.optInt("currentWeek", 1).coerceAtLeast(1),
            dateMillis = nowMillis,
        )
        // Label can stay UI-clamped for browsing consistency; filtering uses scheduleWeek.
        val currentWeek = if (scheduleWeek < 1) {
            1
        } else {
            scheduleWeek.coerceIn(1, semesterWeekCount)
        }
        val todayWeekday = nowCalendar.get(Calendar.DAY_OF_WEEK).let(::calendarDayToWeekday)
        val allCourses = parseSourceCourses(profileJson.optJSONArray("courses"))
        // 含停课的原始课程数（用于区分"没课"和"课都停了"）
        val originalTodayCourseCount = if (isHoliday) 0 else {
            allCourses.count { it.dayOfWeek == todayWeekday && it.isInWeekIgnoringSuspension(scheduleWeek) }
        }
        val todayCourses = if (isHoliday) {
            emptyList()
        } else {
            allCourses
                .filter { it.dayOfWeek == todayWeekday && it.isInWeek(scheduleWeek) }
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
            todayCourses.isEmpty() && originalTodayCourseCount == 0 -> "no_course"
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
        val examsArray = profileJson.optJSONArray("exams")
        var nextExamName: String? = null
        var nextExamDate: String? = null
        var nextExamDaysUntil: Int? = null
        var nextExamLocation: String? = null
        var nextExamStartTime: String? = null
        var nextExamEndTime: String? = null
        if (examsArray != null) {
            var bestDate: String? = null
            var bestStartTime: String? = null
            for (i in 0 until examsArray.length()) {
                val exam = examsArray.optJSONObject(i) ?: continue
                val dateStr = exam.optString("dateTime").takeIf { it.isNotBlank() } ?: continue
                val dateOnly = dateStr.take(10) // "yyyy-MM-dd"
                if (dateOnly < todayDateStr) continue // fully past days
                val startTime = sanitizeNullableField(exam.optString("startTime"))
                val endTime = sanitizeNullableField(exam.optString("endTime"))
                // Same calendar day: hide after exam end (match Flutter Exam.isExpired).
                if (dateOnly == todayDateStr && !endTime.isNullOrBlank()) {
                    val endMillis = buildCourseDateTimeMillis(nowMillis, endTime)
                    if (endMillis != null && nowMillis >= endMillis) {
                        continue
                    }
                }
                val isBetter = when {
                    bestDate == null -> true
                    dateOnly < bestDate!! -> true
                    dateOnly == bestDate -> {
                        // Prefer earlier start time on the same day.
                        val candidate = startTime.orEmpty()
                        val current = bestStartTime.orEmpty()
                        candidate.isNotEmpty() && (current.isEmpty() || candidate < current)
                    }
                    else -> false
                }
                if (isBetter) {
                    bestDate = dateOnly
                    bestStartTime = startTime
                    nextExamName = sanitizeNullableField(exam.optString("name"))
                        ?: context.getString(R.string.widget_exam_fallback_name)
                    nextExamDate = dateOnly
                    nextExamLocation = sanitizeNullableField(exam.optString("location"))
                    nextExamStartTime = startTime
                    nextExamEndTime = endTime
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

        // 今天课程已结束时，计算明天的课程
        var tomorrowCourses: List<TodayWidgetCourseInfo> = emptyList()
        var tomorrowWeek = currentWeek
        var tomorrowDayOfWeek = 0
        val showTomorrowCourses = settingsJson.optBoolean("widgetShowTomorrowCourses", true)
        if ((state == "completed" || state == "no_course") && !isHoliday && showTomorrowCourses) {
            val tomorrowCal = Calendar.getInstance().apply {
                timeInMillis = nowMillis
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            tomorrowDayOfWeek = tomorrowCal.get(Calendar.DAY_OF_WEEK).let(::calendarDayToWeekday)
            val tomorrowWeekday = tomorrowDayOfWeek
            val tomorrowScheduleWeek = liveSchedulerCalculateCalendarWeekForDate(
                semesterStartMillis = semesterStartMillis,
                currentWeek = currentWeek,
                dateMillis = tomorrowCal.timeInMillis,
            )
            tomorrowWeek = if (tomorrowScheduleWeek < 1) {
                1
            } else {
                tomorrowScheduleWeek.coerceIn(1, semesterWeekCount)
            }
            val tomorrowDateStr = widgetFormatDate(
                year = tomorrowCal.get(Calendar.YEAR),
                month = tomorrowCal.get(Calendar.MONTH) + 1,
                dayOfMonth = tomorrowCal.get(Calendar.DAY_OF_MONTH),
            )
            val tomorrowHolidayEntries = loadHolidayEntriesForDate(context, tomorrowCal)
            val isTomorrowHoliday = widgetResolveIsHoliday(
                entries = tomorrowHolidayEntries,
                dateStr = tomorrowDateStr,
                enableHolidayMarking = enableHolidayMarking,
                holidayOverrideEnabled = holidayOverrideEnabled,
            )
            tomorrowCourses = if (isTomorrowHoliday) {
                emptyList()
            } else {
                allCourses
                    .filter { it.dayOfWeek == tomorrowWeekday && it.isInWeek(tomorrowScheduleWeek) }
                    .sortedWith(compareBy<WidgetSourceCourse>({ it.startSection }, { it.startTime }))
                    .map { it.toWidgetCourseInfo() }
            }
        }

        return TodayWidgetSnapshotInfo(
            profileName = profileJson.optString("name", context.getString(R.string.widget_app_name)),
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
            holidayName = holidayName,
            tomorrowCourses = tomorrowCourses,
            tomorrowWeek = tomorrowWeek,
            tomorrowDayOfWeek = tomorrowDayOfWeek,
        )
    }

    fun findNextRefreshAtMillis(
        context: Context,
        nowMillis: Long = System.currentTimeMillis(),
    ): Long? {
        val profileJson = readActiveProfileJson(context) ?: return null
        val settingsJson = profileJson.optJSONObject("settings") ?: JSONObject()
        val nowCalendar = Calendar.getInstance().apply { timeInMillis = nowMillis }
        val todayDateStr = widgetFormatDate(
            year = nowCalendar.get(Calendar.YEAR),
            month = nowCalendar.get(Calendar.MONTH) + 1,
            dayOfMonth = nowCalendar.get(Calendar.DAY_OF_MONTH),
        )
        val isHoliday = widgetResolveIsHoliday(
            entries = loadHolidayEntriesForDate(context, nowCalendar),
            dateStr = todayDateStr,
            enableHolidayMarking = settingsJson.optBoolean("enableHolidayMarking", true),
            holidayOverrideEnabled = settingsJson.optBoolean("holidayOverrideEnabled", false),
        ) || liveSchedulerIsLegacyHolidayFlagActive(
            isHoliday = profileJson.optBoolean("isHoliday", false),
            isHolidayDate = profileJson.optString("isHolidayDate").takeIf { it.isNotBlank() },
            year = nowCalendar.get(Calendar.YEAR),
            month = nowCalendar.get(Calendar.MONTH) + 1,
            dayOfMonth = nowCalendar.get(Calendar.DAY_OF_MONTH),
        )
        // On a holiday there are no same-day course flip points, but still schedule
        // a midnight refresh so the widget can leave holiday mode the next day.
        if (isHoliday) {
            val tomorrowStart = Calendar.getInstance().apply {
                timeInMillis = nowMillis
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            return if (tomorrowStart > nowMillis) tomorrowStart else null
        }
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
        // Refresh at next exam start/end so "今天考试" flips to "考试中" on time.
        val snapshotForExam = buildSnapshotFromFlutterState(context, nowMillis)
        val examStart = snapshotForExam?.nextExamStartTime
            ?.takeIf { it.isNotBlank() }
            ?.let { buildCourseDateTimeMillis(nowMillis, it) }
        val examEnd = snapshotForExam?.nextExamEndTime
            ?.takeIf { it.isNotBlank() }
            ?.let { buildCourseDateTimeMillis(nowMillis, it) }
        if (examStart != null && examStart > nowMillis) {
            triggers += examStart
        }
        if (examEnd != null && examEnd > nowMillis) {
            triggers += examEnd + 1000L
        }
        // 倒计时激活时每 60 秒刷新
        val snapshot = snapshotForExam
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

    fun statusText(context: Context, state: String): String {
        return when (state) {
            "ongoing" -> context.getString(R.string.widget_status_ongoing)
            "upcoming" -> context.getString(R.string.widget_status_upcoming)
            "completed" -> context.getString(R.string.widget_status_completed)
            "holiday" -> context.getString(R.string.widget_status_holiday)
            else -> context.getString(R.string.widget_status_no_course)
        }
    }

    /**
     * Course [state] alone can be "completed" while an exam is still in progress.
     * When the next exam is live, elevate chrome to exam-first so chips don't say "今日已结束".
     */
    enum class ExamWidgetPhase {
        NONE,
        FUTURE_DAYS,
        TODAY_BEFORE,
        ONGOING,
        ENDED_TODAY,
    }

    fun resolveExamPhase(
        snapshot: TodayWidgetSnapshotInfo,
        nowMillis: Long = System.currentTimeMillis(),
    ): ExamWidgetPhase {
        if (snapshot.nextExamName.isNullOrBlank()) {
            return ExamWidgetPhase.NONE
        }
        val daysUntil = snapshot.nextExamDaysUntil ?: return ExamWidgetPhase.NONE
        if (daysUntil < 0) {
            return ExamWidgetPhase.NONE
        }
        if (daysUntil > 0) {
            return ExamWidgetPhase.FUTURE_DAYS
        }

        val startMillis = snapshot.nextExamStartTime
            ?.takeIf { it.isNotBlank() }
            ?.let { buildCourseDateTimeMillis(nowMillis, it) }
        val endMillis = snapshot.nextExamEndTime
            ?.takeIf { it.isNotBlank() }
            ?.let { buildCourseDateTimeMillis(nowMillis, it) }

        return when {
            startMillis != null && endMillis != null &&
                nowMillis >= startMillis && nowMillis < endMillis -> ExamWidgetPhase.ONGOING
            endMillis != null && nowMillis >= endMillis -> ExamWidgetPhase.ENDED_TODAY
            startMillis != null && nowMillis < startMillis -> ExamWidgetPhase.TODAY_BEFORE
            // Missing end time but already past start: treat as ongoing until day rolls.
            startMillis != null && nowMillis >= startMillis -> ExamWidgetPhase.ONGOING
            else -> ExamWidgetPhase.TODAY_BEFORE
        }
    }

    fun isExamOngoing(
        snapshot: TodayWidgetSnapshotInfo,
        nowMillis: Long = System.currentTimeMillis(),
    ): Boolean = resolveExamPhase(snapshot, nowMillis) == ExamWidgetPhase.ONGOING

    fun examDisplayName(snapshot: TodayWidgetSnapshotInfo): String? {
        return snapshot.nextExamName?.takeIf { it.isNotBlank() }
    }

    fun examOngoingMetaText(
        context: Context,
        snapshot: TodayWidgetSnapshotInfo,
    ): String {
        val endTimeText = snapshot.nextExamEndTime.orEmpty()
        val rawLocation = snapshot.nextExamLocation.orEmpty()
        val location = if (rawLocation.isNotBlank() && !rawLocation.equals("null", ignoreCase = true)) {
            " · $rawLocation"
        } else {
            ""
        }
        return if (endTimeText.isNotBlank()) {
            context.getString(R.string.widget_exam_until, endTimeText) + location
        } else {
            context.getString(R.string.widget_status_exam_ongoing) + location
        }
    }

    /** Status chip / label text, exam-first when an exam is in progress. */
    fun displayStatusText(
        context: Context,
        snapshot: TodayWidgetSnapshotInfo,
        nowMillis: Long = System.currentTimeMillis(),
    ): String {
        if (isExamOngoing(snapshot, nowMillis)) {
            return context.getString(R.string.widget_status_exam_ongoing)
        }
        if (isShowingTomorrowCourses(snapshot, nowMillis)) {
            return context.getString(R.string.widget_tomorrow_courses)
        }
        return statusText(context, snapshot.state)
    }

    /** Chip visual state; map live exam to "ongoing" styling. */
    fun displayStatusState(
        snapshot: TodayWidgetSnapshotInfo,
        nowMillis: Long = System.currentTimeMillis(),
    ): String {
        if (isExamOngoing(snapshot, nowMillis)) {
            return "ongoing"
        }
        return snapshot.state
    }

    /** Returns true when today is done or has no courses AND tomorrow has courses to show. */
    fun isShowingTomorrowCourses(
        snapshot: TodayWidgetSnapshotInfo,
        nowMillis: Long = System.currentTimeMillis(),
    ): Boolean {
        // Don't demote a live exam in favor of tomorrow's course preview.
        if (isExamOngoing(snapshot, nowMillis)) {
            return false
        }
        return (snapshot.state == "completed" || snapshot.state == "no_course")
            && snapshot.tomorrowCourses.isNotEmpty()
    }

    fun headingText(
        context: Context,
        snapshot: TodayWidgetSnapshotInfo,
        nowMillis: Long = System.currentTimeMillis(),
    ): String {
        if (isExamOngoing(snapshot, nowMillis)) {
            return context.getString(R.string.widget_status_exam_ongoing)
        }
        return if (isShowingTomorrowCourses(snapshot, nowMillis)) {
            context.getString(R.string.widget_tomorrow_courses)
        } else {
            context.getString(R.string.widget_today_courses)
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

    fun heroCourseName(context: Context, snapshot: TodayWidgetSnapshotInfo): String {
        return when {
            snapshot.state == "holiday" ->
                snapshot.holidayName ?: context.getString(R.string.widget_on_holiday)
            snapshot.highlightedCourse != null -> snapshot.highlightedCourse.name
            isShowingTomorrowCourses(snapshot) ->
                snapshot.tomorrowCourses.first().name
            snapshot.state == "completed" -> context.getString(R.string.widget_today_ended)
            else -> context.getString(R.string.widget_no_courses_today)
        }
    }

    fun heroTimeText(context: Context, snapshot: TodayWidgetSnapshotInfo): String {
        if (snapshot.state == "holiday") {
            return context.getString(R.string.widget_rest_well)
        }
        val highlighted = snapshot.highlightedCourse
        return when {
            highlighted != null &&
                highlighted.startTime.isNotBlank() &&
                highlighted.endTime.isNotBlank() -> {
                "${highlighted.startTime} - ${highlighted.endTime}"
            }
            isShowingTomorrowCourses(snapshot) -> {
                val first = snapshot.tomorrowCourses.first()
                "${first.startTime} - ${first.endTime}"
            }
            snapshot.state == "completed" -> context.getString(R.string.widget_no_more_courses)
            else -> context.getString(R.string.widget_take_a_break)
        }
    }

    fun heroMetaText(context: Context, snapshot: TodayWidgetSnapshotInfo): String {
        if (snapshot.state == "holiday") {
            return context.getString(R.string.widget_week_number, snapshot.currentWeek)
        }
        if (isShowingTomorrowCourses(snapshot)) {
            val first = snapshot.tomorrowCourses.first()
            return if (snapshot.showLocation && first.location.isNotBlank()) {
                first.location
            } else {
                context.getString(R.string.widget_week_number, snapshot.tomorrowWeek)
            }
        }
        val highlighted = snapshot.highlightedCourse
        return when {
            !snapshot.showLocation -> context.getString(R.string.widget_week_number, snapshot.currentWeek)
            highlighted != null && highlighted.location.isNotBlank() -> highlighted.location
            snapshot.totalTodayCourseCount > 0 ->
                context.getString(
                    R.string.widget_week_with_count,
                    snapshot.currentWeek,
                    snapshot.totalTodayCourseCount,
                )
            else -> context.getString(R.string.widget_week_number, snapshot.currentWeek)
        }
    }

    fun compactMetaText(context: Context, snapshot: TodayWidgetSnapshotInfo): String {
        if (snapshot.state == "holiday") {
            return context.getString(R.string.widget_rest_well)
        }
        val highlighted = snapshot.highlightedCourse
        return when {
            highlighted == null -> heroTimeText(context, snapshot)
            snapshot.showLocation && highlighted.location.isNotBlank() ->
                "${heroTimeText(context, snapshot)}\n${highlighted.location}"
            else -> heroTimeText(context, snapshot)
        }
    }

    fun countdownText(
        context: Context,
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
                context.getString(
                    R.string.widget_countdown_until_end,
                    CountdownFormat.formatDuration(durationMillis, style),
                )
            }
            "upcoming" -> {
                val startMillis = buildCourseDateTimeMillis(nowMillis, course.startTime) ?: return null
                val durationMillis = startMillis - nowMillis
                if (durationMillis <= 0) return null
                context.getString(
                    R.string.widget_countdown_until_start,
                    CountdownFormat.formatDuration(durationMillis, style),
                )
            }
            else -> null
        }
    }

    fun examCountdownText(
        context: Context,
        snapshot: TodayWidgetSnapshotInfo,
        nowMillis: Long = System.currentTimeMillis(),
    ): String? {
        val name = snapshot.nextExamName?.takeIf { it.isNotBlank() } ?: return null
        val phase = resolveExamPhase(snapshot, nowMillis)
        if (phase == ExamWidgetPhase.NONE || phase == ExamWidgetPhase.ENDED_TODAY) {
            return null
        }

        val timeRange = if (!snapshot.nextExamStartTime.isNullOrBlank() && !snapshot.nextExamEndTime.isNullOrBlank()) {
            " ${snapshot.nextExamStartTime}-${snapshot.nextExamEndTime}"
        } else if (!snapshot.nextExamStartTime.isNullOrBlank()) {
            " ${snapshot.nextExamStartTime}"
        } else {
            ""
        }
        val rawLocation = snapshot.nextExamLocation.orEmpty()
        val location = if (rawLocation.isNotBlank() && !rawLocation.equals("null", ignoreCase = true)) {
            " $rawLocation"
        } else {
            ""
        }

        return when (phase) {
            ExamWidgetPhase.FUTURE_DAYS -> {
                val daysUntil = snapshot.nextExamDaysUntil ?: return null
                context.getString(
                    R.string.widget_exam_countdown,
                    name,
                    daysUntil,
                    timeRange,
                    location,
                )
            }
            ExamWidgetPhase.ONGOING -> {
                val endTimeText = snapshot.nextExamEndTime.orEmpty()
                context.getString(
                    R.string.widget_exam_ongoing,
                    name,
                    endTimeText,
                    location,
                )
            }
            ExamWidgetPhase.TODAY_BEFORE -> {
                context.getString(R.string.widget_exam_today, name, timeRange, location)
            }
            ExamWidgetPhase.NONE, ExamWidgetPhase.ENDED_TODAY -> null
        }
    }

    fun rightInfoText(context: Context, snapshot: TodayWidgetSnapshotInfo): String {
        val cal = Calendar.getInstance()
        val month = cal.get(Calendar.MONTH) + 1
        val day = cal.get(Calendar.DAY_OF_MONTH)
        val dayNames = arrayOf(
            context.getString(R.string.widget_day_sun),
            context.getString(R.string.widget_day_mon),
            context.getString(R.string.widget_day_tue),
            context.getString(R.string.widget_day_wed),
            context.getString(R.string.widget_day_thu),
            context.getString(R.string.widget_day_fri),
            context.getString(R.string.widget_day_sat),
        )
        val dow = dayNames[cal.get(Calendar.DAY_OF_WEEK) - 1]
        val datePart = "${month}/${day} $dow"

        val isShowingTomorrow = isShowingTomorrowCourses(snapshot)
        val week = if (isShowingTomorrow) snapshot.tomorrowWeek else snapshot.currentWeek

        return when {
            snapshot.state == "holiday" ->
                context.getString(R.string.widget_week_holiday, week)
            isShowingTomorrow ->
                context.getString(R.string.widget_week_tomorrow_count, week, snapshot.tomorrowCourses.size)
            snapshot.totalTodayCourseCount == 0 ->
                context.getString(R.string.widget_week_date, week, datePart)
            snapshot.state == "completed" ->
                context.getString(R.string.widget_week_date, week, datePart)
            else ->
                context.getString(
                    R.string.widget_week_date_count,
                    week,
                    datePart,
                    snapshot.totalTodayCourseCount,
                )
        }
    }

    fun footerText(context: Context, snapshot: TodayWidgetSnapshotInfo): String {
        return when {
            snapshot.state == "holiday" ->
                context.getString(
                    R.string.widget_footer_holiday,
                    snapshot.profileName,
                    snapshot.holidayName ?: context.getString(R.string.widget_on_holiday),
                )
            isShowingTomorrowCourses(snapshot) ->
                context.getString(
                    R.string.widget_footer_tomorrow,
                    snapshot.profileName,
                    snapshot.tomorrowCourses.size,
                )
            snapshot.totalTodayCourseCount > 0 ->
                context.getString(
                    R.string.widget_footer_today,
                    snapshot.profileName,
                    snapshot.totalTodayCourseCount,
                )
            else ->
                context.getString(
                    R.string.widget_footer_week,
                    snapshot.profileName,
                    snapshot.currentWeek,
                )
        }
    }

    fun secondaryCourses(snapshot: TodayWidgetSnapshotInfo, limit: Int): List<TodayWidgetCourseInfo> {
        if (isShowingTomorrowCourses(snapshot)) {
            // 明日课程：第一个作为 hero，其余作为 secondary
            return snapshot.tomorrowCourses.drop(1).take(limit)
        }
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

    private fun parseSnapshot(context: Context, json: JSONObject): TodayWidgetSnapshotInfo {
        val allCourses = parseCourses(json.optJSONArray("todayCourses"))
        val visibleCourses = json.optJSONArray("visibleTodayCourses")?.let(::parseCourses)
            ?: allCourses
        return TodayWidgetSnapshotInfo(
            profileName = json.optString("profileName", context.getString(R.string.widget_app_name)),
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
            nextExamName = sanitizeNullableField(json.optString("nextExamName")),
            nextExamDate = sanitizeNullableField(json.optString("nextExamDate")),
            nextExamDaysUntil = json.optInt("nextExamDaysUntil", -1).takeIf { it >= 0 },
            nextExamLocation = sanitizeNullableField(json.optString("nextExamLocation")),
            nextExamStartTime = sanitizeNullableField(json.optString("nextExamStartTime")),
            nextExamEndTime = sanitizeNullableField(json.optString("nextExamEndTime")),
            holidayName = sanitizeNullableField(json.optString("holidayName")),
            tomorrowCourses = json.optJSONArray("tomorrowCourses")?.let(::parseCourses) ?: emptyList(),
            tomorrowWeek = json.optInt("tomorrowWeek", json.optInt("currentWeek", 1)),
            tomorrowDayOfWeek = json.optInt("tomorrowDayOfWeek", 0),
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

    fun readActiveProfileJson(context: Context): JSONObject? {
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

    /**
     * Load holiday entries for [calendar]'s year (and next year near year-end)
     * from Flutter SharedPreferences, matching [HolidayService] cache keys.
     */
    private fun loadHolidayEntriesForDate(
        context: Context,
        calendar: Calendar,
    ): List<WidgetHolidayEntry> {
        val flutterPrefs = context.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
        val year = calendar.get(Calendar.YEAR)
        val years = buildList {
            add(year)
            // Semester / custom ranges near Dec 31 may need next year's cache.
            if (calendar.get(Calendar.MONTH) >= Calendar.NOVEMBER) {
                add(year + 1)
            }
        }
        val entries = mutableListOf<WidgetHolidayEntry>()
        for (targetYear in years) {
            entries += widgetParseHolidayEntriesFromHolidayDataJson(
                flutterPrefs.getString("$KEY_HOLIDAY_DATA_PREFIX$targetYear", null),
            )
        }
        entries += widgetParseHolidayEntriesFromCustomJson(
            flutterPrefs.getString(KEY_CUSTOM_HOLIDAYS, null),
        )
        return entries
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
                        suspendedWeeks = item.optJSONArray("suspendedWeeks")?.let { rawWeeks ->
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
        // Align to Monday like Flutter getWeekIndex / LiveUpdateScheduler so
        // desktop widgets do not show the wrong week when semesterStart is mid-week.
        val week = liveSchedulerCalculateWeekForDate(
            semesterStartMillis = semesterStartMillis,
            currentWeek = fallbackWeek,
            dateMillis = nowMillis,
            semesterWeekCount = semesterWeekCount,
        )
        if (week < 1) {
            // Before semester start: show week 1 content rather than empty (UI clamp).
            return 1
        }
        return week.coerceIn(1, semesterWeekCount)
    }

    /** Returns null if the string is null, blank, or the literal "null". */
    private fun sanitizeNullableField(value: String?): String? {
        return value?.takeIf {
            it.isNotBlank() && !it.equals("null", ignoreCase = true)
        }
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
