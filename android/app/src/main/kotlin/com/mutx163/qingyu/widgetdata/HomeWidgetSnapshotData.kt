package com.mutx163.qingyu.widgetdata

import com.mutx163.qingyu.core.Course
import java.time.LocalDateTime

/**
 * 桌面卡片快照组装（移植 lib/services/home_widget_snapshot_service.dart:190-435，
 * 纯函数零 IO）。
 *
 * 与真机 TodayWidgetSupport.buildSnapshotFromFlutterState 的判定口径一致
 * （「上课中/下一节」的边界、倒计时门、隐藏已结束、明天列表、周末档位全部同源），
 * 差异只在数据源：这里吃内存态模型，真机那份直接读 Flutter 存档 JSON。
 */
class HomeWidgetSnapshotService {

    fun build(
        profileId: String,
        profileName: String,
        currentWeek: Int,
        settings: WidgetSettingsFace,
        todayCourses: List<Course>,
        now: LocalDateTime,
        countdownLeadMinutes: Int = 20,
        countdownTextStyle: String = "smart",
        nextExam: ExamFace? = null,
        isHoliday: Boolean = false,
        holidayName: String? = null,
        tomorrowCourses: List<Course> = emptyList(),
        tomorrowWeek: Int = 0,
        tomorrowDayOfWeek: Int = 0,
        showTomorrowCourses: Boolean = true,
        originalTodayCourseCount: Int = 0,
        isAdjustedWorkdayToday: Boolean = false,
        isAdjustedWorkdayTomorrow: Boolean = false,
    ): HomeWidgetSnapshot {
        // 假期态：清空课程，但仍带下一场考试（卡片倒计时不能在假期消失）。
        if (isHoliday) {
            return HomeWidgetSnapshot(
                profileId = profileId,
                profileName = profileName,
                currentWeek = currentWeek,
                dayOfWeek = now.dayOfWeek.value,
                generatedAtMillis = WidgetDataClock.toEpochMillis(now),
                state = HomeWidgetSnapshotState.HOLIDAY,
                backgroundStyle = settings.widgetBackgroundStyle,
                courseAccentMode = settings.widgetCourseAccentMode,
                showLocation = settings.widgetShowLocation,
                showCountdown = false,
                countdownTextStyle = countdownTextStyle,
                hideCompletedCourses = settings.widgetHideCompletedCourses,
                heightAdjustment = settings.widgetHeightAdjustment,
                cornerRadius = settings.widgetCornerRadius,
                totalTodayCourseCount = 0,
                todayCourses = emptyList(),
                visibleTodayCourses = emptyList(),
                highlightedCourse = null,
                nextExamFace = nextExam,
                holidayName = holidayName ?: "Holiday",
            )
        }

        val currentCourse = findCurrentCourse(todayCourses, now)
        val upcomingCourse = findNextCourse(todayCourses, now)

        val visibleCourses: List<Course> = if (settings.widgetHideCompletedCourses) {
            todayCourses.filter { course ->
                val end = WidgetDataClock.courseDateTimeOn(now, course.endTime)
                end != null && end.isAfter(now)
            }
        } else {
            todayCourses
        }

        val hasCoursesScheduled = todayCourses.isNotEmpty() || originalTodayCourseCount > 0
        // 周末文案档位：必须在 currentCourse/upcomingCourse 之后算——周五那句
        // 「周末要开始了」的门槛就是这两个都为空（weekend_mood_logic 调用点注释）。
        val weekendMood = WeekendMoodLogic.resolve(
            dayOfWeek = now.dayOfWeek.value,
            hasAnyCourseToday = hasCoursesScheduled,
            hasRemainingCourseToday = currentCourse != null || upcomingCourse != null,
            isHolidayToday = isHoliday,
            isAdjustedWorkdayToday = isAdjustedWorkdayToday,
            isAdjustedWorkdayTomorrow = isAdjustedWorkdayTomorrow,
        )
        val state = when {
            !hasCoursesScheduled -> HomeWidgetSnapshotState.NO_COURSE
            currentCourse != null -> HomeWidgetSnapshotState.ONGOING
            upcomingCourse != null -> HomeWidgetSnapshotState.UPCOMING
            else -> HomeWidgetSnapshotState.COMPLETED
        }

        // 倒计时显示门（:288-300）。
        val effectiveShowCountdown: Boolean = when {
            !settings.widgetShowCountdown -> false
            countdownLeadMinutes == 0 -> true
            else ->
                state == HomeWidgetSnapshotState.ONGOING ||
                    (
                        state == HomeWidgetSnapshotState.UPCOMING &&
                            upcomingCourse != null &&
                            isWithinLeadMinutes(now, upcomingCourse, countdownLeadMinutes)
                        )
        }

        return HomeWidgetSnapshot(
            profileId = profileId,
            profileName = profileName,
            currentWeek = currentWeek,
            dayOfWeek = now.dayOfWeek.value,
            generatedAtMillis = WidgetDataClock.toEpochMillis(now),
            state = state,
            backgroundStyle = settings.widgetBackgroundStyle,
            courseAccentMode = settings.widgetCourseAccentMode,
            showLocation = settings.widgetShowLocation,
            showCountdown = effectiveShowCountdown,
            countdownTextStyle = countdownTextStyle,
            hideCompletedCourses = settings.widgetHideCompletedCourses,
            heightAdjustment = settings.widgetHeightAdjustment,
            cornerRadius = settings.widgetCornerRadius,
            totalTodayCourseCount = todayCourses.size,
            todayCourses = todayCourses.map(HomeWidgetCourseSummary::fromCourse),
            visibleTodayCourses = visibleCourses.map(HomeWidgetCourseSummary::fromCourse),
            highlightedCourse = (currentCourse ?: upcomingCourse)?.let(HomeWidgetCourseSummary::fromCourse),
            nextCourseSummary = upcomingCourse?.let(HomeWidgetCourseSummary::fromCourse),
            nextExamFace = nextExam,
            tomorrowCourses = if (showTomorrowCourses) {
                tomorrowCourses.map(HomeWidgetCourseSummary::fromCourse)
            } else {
                emptyList()
            },
            tomorrowWeek = tomorrowWeek,
            tomorrowDayOfWeek = tomorrowDayOfWeek,
            weekendMood = weekendMood,
            countdownLeadMinutes = countdownLeadMinutes,
        )
    }

    /**
     * 刷新触发点（buildRefreshTriggers，:347-383）：
     * 未来每节课的开始/结束 + 倒计时激活点（start - lead）；倒计时显示中追加
     * +60s 心跳；最后补次日零点跨天翻面。升序去重返回。
     */
    fun buildRefreshTriggers(
        todayCourses: List<Course>,
        now: LocalDateTime,
        showCountdown: Boolean = false,
        state: String = "no_course",
        countdownLeadMinutes: Int = 20,
    ): List<Long> {
        val triggers = linkedSetOf<Long>()
        for (course in todayCourses) {
            val start = WidgetDataClock.courseDateTimeOn(now, course.startTime)
            val end = WidgetDataClock.courseDateTimeOn(now, course.endTime)
            if (start != null && start.isAfter(now)) {
                triggers.add(WidgetDataClock.toEpochMillis(start))
                if (countdownLeadMinutes > 0) {
                    val activation = start.minusMinutes(countdownLeadMinutes.toLong())
                    if (activation.isAfter(now)) {
                        triggers.add(WidgetDataClock.toEpochMillis(activation))
                    }
                }
            }
            if (end != null && end.isAfter(now)) {
                triggers.add(WidgetDataClock.toEpochMillis(end))
            }
        }
        if (showCountdown && (state == "ongoing" || state == "upcoming")) {
            triggers.add(WidgetDataClock.toEpochMillis(now) + 60_000L)
        }
        val nextMidnight = WidgetDataClock.nextMidnight(now)
        if (WidgetDataClock.toEpochMillis(nextMidnight) > WidgetDataClock.toEpochMillis(now)) {
            triggers.add(WidgetDataClock.toEpochMillis(nextMidnight))
        }
        return triggers.toList().sorted()
    }

    /** 正在上：start ≤ now < end（_findCurrentCourse，:385-397）。 */
    private fun findCurrentCourse(courses: List<Course>, now: LocalDateTime): Course? {
        for (course in courses) {
            val start = WidgetDataClock.courseDateTimeOn(now, course.startTime) ?: continue
            val end = WidgetDataClock.courseDateTimeOn(now, course.endTime) ?: continue
            if (!now.isBefore(start) && now.isBefore(end)) return course
        }
        return null
    }

    /** 下一节：start > now（_findNextCourse，:399-410）。 */
    private fun findNextCourse(courses: List<Course>, now: LocalDateTime): Course? {
        for (course in courses) {
            val start = WidgetDataClock.courseDateTimeOn(now, course.startTime) ?: continue
            if (start.isAfter(now)) return course
        }
        return null
    }

    private fun isWithinLeadMinutes(now: LocalDateTime, course: Course, leadMinutes: Int): Boolean {
        val start = WidgetDataClock.courseDateTimeOn(now, course.startTime) ?: return false
        val threshold = start.minusMinutes(leadMinutes.toLong())
        return !now.isBefore(threshold)
    }
}

/**
 * 快照值对象（home_widget_snapshot_service.dart:72-188）。
 *
 * [toJson] 的键名与 Dart 逐字一致（Kotlin 渲染侧按这些键读）；
 * [toDedupJson] 排除 generatedAtMillis——内容相同的周期性重建不应迫使原生重写。
 */
data class HomeWidgetSnapshot(
    val profileId: String,
    val profileName: String,
    val currentWeek: Int,
    val dayOfWeek: Int,
    val generatedAtMillis: Long,
    val state: HomeWidgetSnapshotState,
    val backgroundStyle: String,
    val courseAccentMode: WidgetCourseAccentModeData,
    val showLocation: Boolean,
    val showCountdown: Boolean,
    val countdownTextStyle: String,
    val hideCompletedCourses: Boolean,
    val heightAdjustment: Int,
    val cornerRadius: Int,
    val totalTodayCourseCount: Int,
    val todayCourses: List<HomeWidgetCourseSummary>,
    val visibleTodayCourses: List<HomeWidgetCourseSummary>,
    val highlightedCourse: HomeWidgetCourseSummary?,
    val nextCourseSummary: HomeWidgetCourseSummary? = null,
    val nextExamFace: ExamFace? = null,
    val holidayName: String? = null,
    val tomorrowCourses: List<HomeWidgetCourseSummary> = emptyList(),
    val tomorrowWeek: Int = 0,
    val tomorrowDayOfWeek: Int = 0,
    val weekendMood: WeekendMoodData = WeekendMoodData.NONE,
    val countdownLeadMinutes: Int = 20,
) {
    /** Dart nextExamDate 的格式化：yyyy-MM-dd。 */
    val nextExamDate: String?
        get() = nextExamFace?.let {
            "%04d-%02d-%02d".format(it.dateTime.year, it.dateTime.monthValue, it.dateTime.dayOfMonth)
        }

    /** Dart Exam.daysUntil：按日历日差算「还有几天」。 */
    fun examDaysUntil(now: LocalDateTime): Int? = nextExamFace?.let {
        val today = now.toLocalDate()
        val examDate = it.dateTime.toLocalDate()
        java.time.temporal.ChronoUnit.DAYS.between(today, examDate).toInt()
    }

    fun toJson(): Map<String, Any?> = linkedMapOf(
        "profileId" to profileId,
        "profileName" to profileName,
        "currentWeek" to currentWeek,
        "dayOfWeek" to dayOfWeek,
        "generatedAtMillis" to generatedAtMillis,
        "state" to state.value,
        "backgroundStyle" to backgroundStyle,
        "courseAccentMode" to courseAccentMode.value,
        "showLocation" to showLocation,
        "showCountdown" to showCountdown,
        "countdownTextStyle" to countdownTextStyle,
        "hideCompletedCourses" to hideCompletedCourses,
        "heightAdjustment" to heightAdjustment,
        "cornerRadius" to cornerRadius,
        "totalTodayCourseCount" to totalTodayCourseCount,
        "todayCourses" to todayCourses.map { it.toJson() },
        "visibleTodayCourses" to visibleTodayCourses.map { it.toJson() },
        "highlightedCourse" to highlightedCourse?.toJson(),
        "nextCourse" to nextCourseSummary?.toJson(),
        "nextExamName" to nextExamFace?.name,
        "nextExamDate" to nextExamDate,
        "nextExamDaysUntil" to nextExamFace?.let { examDaysUntil(LocalDateTime.now()) },
        "nextExamLocation" to nextExamFace?.location,
        "nextExamStartTime" to nextExamFace?.startTime,
        "nextExamEndTime" to nextExamFace?.endTime,
        "holidayName" to holidayName,
        "tomorrowCourses" to tomorrowCourses.map { it.toJson() },
        "tomorrowWeek" to tomorrowWeek,
        "tomorrowDayOfWeek" to tomorrowDayOfWeek,
        "weekendMood" to weekendMood.value,
    )

    fun toDedupJson(): Map<String, Any?> {
        val payload = LinkedHashMap<String, Any?>(toJson())
        payload.remove("generatedAtMillis")
        return payload
    }
}
