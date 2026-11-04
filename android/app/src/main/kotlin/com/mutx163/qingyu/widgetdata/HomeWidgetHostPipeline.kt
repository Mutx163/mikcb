package com.mutx163.qingyu.widgetdata

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.WeekCalculator
import java.time.LocalDateTime
import java.util.Locale

/**
 * 快照宿主管线（移植 timetable_live_activity_service.dart:556-708
 * buildHomeWidgetSnapshot / buildHomeWidgetSnapshotForProfile /
 * buildCoupleMergedHomeWidgetSnapshot 的纯逻辑，:1189-1231 的触发点并集）。
 *
 * 数据源由调用方通过参数注入（active 路径吃宿主内存态、绑定路径吃档案快照），
 * 本文件不做任何 IO。
 */

/** 情侣课表（我的+TA 合并视图）绑定的哨兵 id（home_widget_binding_service.dart:19）。 */
const val K_HOME_WIDGET_COUPLE_MERGED_BINDING_ID = "couple-merged"

/** 今日课程类卡片的类型标识（home_widget_binding_service.dart:22-42）。 */
enum class HomeWidgetTypeData(val value: String) {
    COMPACT("compact"),
    MINI_LIST("mini_list"),
    MEDIUM("medium"),
    LARGE("large"),
    TODAY_STRIP("today_strip"),
    TODAY_WIDE("today_wide"),
    ;

    companion object {
        fun fromValue(value: String?): HomeWidgetTypeData? =
            entries.firstOrNull { it.value == value }
    }
}

/** 桌面上一个真实存在的今日课程卡片实例（home_widget_binding_service.dart:45-66）。 */
data class HomeWidgetInstanceData(
    val appWidgetId: Int,
    val widgetType: HomeWidgetTypeData?,
    /** 绑定的课表 id；null = 未登记（跟随当前课表）。 */
    val boundProfileId: String?,
) {
    companion object {
        /** 通道 payload 解析：非负 id 才有效（Dart fromChannel + where 过滤）。 */
        fun fromChannel(raw: Map<*, *>?): HomeWidgetInstanceData? {
            val id = (raw?.get("appWidgetId") as? Number)?.toInt() ?: -1
            if (id < 0) return null
            return HomeWidgetInstanceData(
                appWidgetId = id,
                widgetType = HomeWidgetTypeData.fromValue(raw?.get("widgetType") as? String),
                boundProfileId = raw?.get("boundProfileId") as? String,
            )
        }
    }
}

/** 绑定校验（home_widget_binding_service.dart 语义）：该实例绑定是否还有效。 */
object HomeWidgetBindingData {

    /**
     * 绑定卡片该用哪份数据：couple-merged 哨兵 → 情侣合并；其余 → 对应档案；
     * 绑定的课表不存在 → 回落「跟随当前课表」（返回 null 表示跟随）。
     */
    fun resolveBindingTarget(instance: HomeWidgetInstanceData): BindingTarget = when (instance.boundProfileId) {
        null -> BindingTarget.FOLLOW_ACTIVE
        K_HOME_WIDGET_COUPLE_MERGED_BINDING_ID -> BindingTarget.COUPLE_MERGED
        else -> BindingTarget.PROFILE(instance.boundProfileId)
    }

    sealed class BindingTarget {
        object FOLLOW_ACTIVE : BindingTarget()
        object COUPLE_MERGED : BindingTarget()
        data class PROFILE(val profileId: String) : BindingTarget()
    }
}

// ── active 路径（宿主内存态） ─────────────────────────────────────

/**
 * 按当前课表构建桌面卡片快照（buildHomeWidgetSnapshot，:556-615）。
 *
 * 必须用真实日历周（无 semesterWeekCount 钳制）——结课后钳进最后一周会把
 * endWeek=N 的课在每个匹配的星期复活。节假日当天把课程清空但保留
 * originalTodayCourseCount=0 语义（与 :611 一致）。
 */
fun buildHomeWidgetSnapshot(
    host: LiveHostFace,
    now: LocalDateTime,
    activeProfile: ProfileFace? = null,
): HomeWidgetSnapshot? {
    val profile = activeProfile ?: host.activeProfileFace ?: return null
    val currentTime = now
    val targetWeek = host.calculateCalendarWeekForDate(currentTime)
    val originalTodayCount = host.getCoursesForDay(currentTime.dayOfWeek.value, targetWeek).size
    val todayIsHoliday = host.isHoliday(currentTime)
    val todayCourses = if (todayIsHoliday) {
        emptyList()
    } else {
        host.getActiveCoursesForDay(currentTime.dayOfWeek.value, targetWeek)
            .map { host.resolveCourseDisplayName(it) }
    }

    val tomorrow = currentTime.plusDays(1)
    val tomorrowWeek = host.calculateCalendarWeekForDate(tomorrow)
    val tomorrowIsHoliday = host.isHoliday(tomorrow)
    val tomorrowCourses = if (tomorrowIsHoliday) {
        emptyList()
    } else {
        host.getActiveCoursesForDay(tomorrow.dayOfWeek.value, tomorrowWeek)
            .map { host.resolveCourseDisplayName(it) }
    }

    // 周末文案档位用：调休补班的周六日是上班日，卡片不能说「周末愉快」。
    val todayIsAdjustedWorkday = host.isAdjustedWorkday(currentTime)
    val tomorrowIsAdjustedWorkday = host.isAdjustedWorkday(tomorrow)

    return HomeWidgetSnapshotService().build(
        profileId = profile.id,
        profileName = profile.name,
        currentWeek = targetWeek,
        settings = host.settings,
        todayCourses = todayCourses,
        now = currentTime,
        countdownLeadMinutes = host.settings.widgetCountdownLeadMinutes,
        countdownTextStyle = host.settings.widgetCountdownTextStyle,
        nextExam = host.nextExam,
        isHoliday = todayIsHoliday,
        holidayName = host.holidayNameFor(currentTime)?.takeIf { todayIsHoliday },
        tomorrowCourses = tomorrowCourses,
        tomorrowWeek = tomorrowWeek,
        tomorrowDayOfWeek = tomorrow.dayOfWeek.value,
        showTomorrowCourses = host.settings.widgetShowTomorrowCourses,
        originalTodayCourseCount = if (todayIsHoliday) 0 else originalTodayCount,
        isAdjustedWorkdayToday = todayIsAdjustedWorkday,
        isAdjustedWorkdayTomorrow = tomorrowIsAdjustedWorkday,
    )
}

/**
 * 按任意课表（含 TA 课表）构建快照（buildHomeWidgetSnapshotForProfile，:621-708）：
 * 周次/课程/节假日开关/外观全部取自 [profile] 自身；调休补班标记没有开关，
 * 只认全局假期数据（host.isAdjustedWorkday）。
 */
fun buildHomeWidgetSnapshotForProfile(
    host: LiveHostFace,
    profile: ProfileFace,
    now: LocalDateTime,
): HomeWidgetSnapshot? {
    val currentTime = now
    val settings = profile.settings
    // Must use calendar week (no semesterWeekCount clamp), same as active path.
    val targetWeek = WeekCalculator.calendarWeekForDate(
        currentTime,
        settings.semesterStartDate,
        profile.currentWeek,
    )

    fun coursesForDay(dayOfWeek: Int, week: Int, activeOnly: Boolean): List<Course> =
        profile.courses
            .filter { it.dayOfWeek == dayOfWeek && (if (activeOnly) it.isActiveInWeek(week) else it.isInWeek(week)) }
            .sortedBy { it.startSection }

    val originalTodayCount = coursesForDay(currentTime.dayOfWeek.value, targetWeek, activeOnly = false).size
    val todayIsHoliday = resolveHoliday(
        currentTime,
        host.holidayDateKeys,
        host.adjustedWorkdayDateKeys,
        overrideEnabled = settings.holidayOverrideEnabled,
        markingEnabled = settings.enableHolidayMarking,
    )
    val todayCourses = if (todayIsHoliday) {
        emptyList()
    } else {
        coursesForDay(currentTime.dayOfWeek.value, targetWeek, activeOnly = true)
    }

    val tomorrow = currentTime.plusDays(1)
    val tomorrowWeek = WeekCalculator.calendarWeekForDate(
        tomorrow,
        settings.semesterStartDate,
        profile.currentWeek,
    )
    val tomorrowIsHoliday = resolveHoliday(
        tomorrow,
        host.holidayDateKeys,
        host.adjustedWorkdayDateKeys,
        overrideEnabled = settings.holidayOverrideEnabled,
        markingEnabled = settings.enableHolidayMarking,
    )
    val tomorrowCourses = if (tomorrowIsHoliday) {
        emptyList()
    } else {
        coursesForDay(tomorrow.dayOfWeek.value, tomorrowWeek, activeOnly = true)
    }

    val upcomingExams = profile.exams.filter { !it.isExpired(currentTime) }.sortedWith(ExamFace.Companion::compareByStart)
    val nextExam = upcomingExams.firstOrNull()

    val todayIsAdjustedWorkday = host.isAdjustedWorkday(currentTime)
    val tomorrowIsAdjustedWorkday = host.isAdjustedWorkday(tomorrow)

    return HomeWidgetSnapshotService().build(
        profileId = profile.id,
        profileName = profile.name,
        currentWeek = targetWeek,
        settings = settings,
        todayCourses = todayCourses,
        now = currentTime,
        countdownLeadMinutes = settings.widgetCountdownLeadMinutes,
        countdownTextStyle = settings.widgetCountdownTextStyle,
        nextExam = nextExam,
        isHoliday = todayIsHoliday,
        holidayName = host.holidayNameFor(currentTime)?.takeIf { todayIsHoliday },
        tomorrowCourses = tomorrowCourses,
        tomorrowWeek = tomorrowWeek,
        tomorrowDayOfWeek = tomorrow.dayOfWeek.value,
        showTomorrowCourses = settings.widgetShowTomorrowCourses,
        originalTodayCourseCount = if (todayIsHoliday) 0 else originalTodayCount,
        isAdjustedWorkdayToday = todayIsAdjustedWorkday,
        isAdjustedWorkdayTomorrow = tomorrowIsAdjustedWorkday,
    )
}

// ── 情侣合并路径 ─────────────────────────────────────────────────

/**
 * TA 侧某天「含停课」的原始课程数（_livePartnerOriginalCourseCount，:786-806）：
 * 与 active 路径的 originalTodayCount 同口径（isInWeek 含停课）。
 */
fun partnerOriginalCourseCount(
    partnerCourses: List<Course>,
    dayOfWeek: Int,
    myWeek: Int,
    weekOffset: Int,
): Int {
    val partnerWeek = CoupleTimetableData.partnerWeekForMyWeek(myWeek, weekOffset)
    return partnerCourses.count { it.dayOfWeek == dayOfWeek && it.isInWeek(partnerWeek) }
}

/**
 * 情侣课表（合并视图）绑定卡片的快照（buildCoupleMergedHomeWidgetSnapshot，:813-879）：
 * 学期/节假日/考试/外观/周次标签全部锚定我方，课程为合并结果；
 * TA 解绑或课表不存在时返回 null（调用方清掉专属快照回落「跟随当前课表」）。
 */
fun buildCoupleMergedHomeWidgetSnapshot(
    host: LiveHostFace,
    now: LocalDateTime,
    activeProfile: ProfileFace? = null,
    partnerProfile: ProfileFace? = null,
    binding: PartnerTimetableBinding? = null,
): HomeWidgetSnapshot? {
    val myProfile = activeProfile ?: host.activeProfileFace ?: return null
    val partner = partnerProfile ?: host.partnerProfileFace ?: return null
    val coupleBinding = binding ?: host.partnerBinding ?: return null
    if (!host.hasPartnerBinding && binding == null) return null

    val currentTime = now
    val targetWeek = host.calculateCalendarWeekForDate(currentTime)
    val originalTodayCount = host.getCoursesForDay(currentTime.dayOfWeek.value, targetWeek).size +
        partnerOriginalCourseCount(
            partner.courses,
            currentTime.dayOfWeek.value,
            targetWeek,
            coupleBinding.weekOffset,
        )
    val todayIsHoliday = host.isHoliday(currentTime)
    val todayCourses = if (todayIsHoliday) {
        emptyList()
    } else {
        coupleMergedDayCoursesForDay(host, currentTime.dayOfWeek.value, targetWeek, myProfile, partner, coupleBinding)
    }

    val tomorrow = currentTime.plusDays(1)
    val tomorrowWeek = host.calculateCalendarWeekForDate(tomorrow)
    val tomorrowIsHoliday = host.isHoliday(tomorrow)
    val tomorrowCourses = if (tomorrowIsHoliday) {
        emptyList()
    } else {
        coupleMergedDayCoursesForDay(host, tomorrow.dayOfWeek.value, tomorrowWeek, myProfile, partner, coupleBinding)
    }

    val todayIsAdjustedWorkday = host.isAdjustedWorkday(currentTime)
    val tomorrowIsAdjustedWorkday = host.isAdjustedWorkday(tomorrow)

    return HomeWidgetSnapshotService().build(
        profileId = K_HOME_WIDGET_COUPLE_MERGED_BINDING_ID,
        profileName = myProfile.name,
        currentWeek = targetWeek,
        settings = host.settings,
        todayCourses = todayCourses,
        now = currentTime,
        countdownLeadMinutes = host.settings.widgetCountdownLeadMinutes,
        countdownTextStyle = host.settings.widgetCountdownTextStyle,
        nextExam = host.nextExam,
        isHoliday = todayIsHoliday,
        holidayName = host.holidayNameFor(currentTime)?.takeIf { todayIsHoliday },
        tomorrowCourses = tomorrowCourses,
        tomorrowWeek = tomorrowWeek,
        tomorrowDayOfWeek = tomorrow.dayOfWeek.value,
        showTomorrowCourses = host.settings.widgetShowTomorrowCourses,
        originalTodayCourseCount = if (todayIsHoliday) 0 else originalTodayCount,
        isAdjustedWorkdayToday = todayIsAdjustedWorkday,
        isAdjustedWorkdayTomorrow = tomorrowIsAdjustedWorkday,
    )
}

/** 某一天的情侣合并课程（_liveCoupleMergedDayCourses，:715-782 的宿主侧编排）。 */
fun coupleMergedDayCoursesForDay(
    host: LiveHostFace,
    dayOfWeek: Int,
    myWeek: Int,
    myProfile: ProfileFace,
    partnerProfile: ProfileFace,
    binding: PartnerTimetableBinding,
): List<Course> {
    val mine = host.getActiveCoursesForDay(dayOfWeek, myWeek).map { host.resolveCourseDisplayName(it) }
    val partnerWeek = CoupleTimetableData.partnerWeekForMyWeek(myWeek, binding.weekOffset)
    val partner = partnerProfile.courses
        .filter { it.dayOfWeek == dayOfWeek && it.isActiveInWeek(partnerWeek) }
        .sortedBy { it.startSection }
    return coupleMergedDayCourses(
        mineCourses = mine,
        partnerCourses = partner,
        week = myWeek,
        partnerWeekOffset = binding.weekOffset,
        mineColorHex = binding.mineColorHex,
        partnerColorHex = binding.partnerColorHex,
        togetherColorHex = binding.togetherColorHex,
    )
}

// ── 刷新触发点并集 ───────────────────────────────────────────────

/**
 * 当前课表卡片的刷新触发点（syncHomeWidgetSnapshot 的触发点段，:1212-1223）：
 * 假期态无触发点（跨天翻面由 buildRefreshTriggers 自己补的午夜点承担）。
 */
fun buildHostRefreshTriggers(
    host: LiveHostFace,
    todayCourses: List<Course>,
    now: LocalDateTime,
    showCountdown: Boolean,
    state: String,
    countdownLeadMinutes: Int,
): List<Long> = HomeWidgetSnapshotService().buildRefreshTriggers(
    todayCourses = todayCourses,
    now = now,
    showCountdown = showCountdown,
    state = state,
    countdownLeadMinutes = countdownLeadMinutes,
)

// ── 节假日判定（HolidayResolver，holiday_resolver.dart:11-31）────

/**
 * 展示口径的节假日判定（HolidayResolver.isHoliday）：
 * 1. 调休上班日优先级最高——即使假期覆盖开着也要显示课程；
 * 2. 假期覆盖模式开启时所有假期都隐藏课程；
 * 3. 假期标记关闭时不隐藏；
 * 4. 其余按假期日期键判定；数据缺失视为无假期。
 *
 * 日期键为 `yyyy-MM-dd`（与 HolidayData._dateKey 同格式），由宿主注入。
 */
fun resolveHoliday(
    date: LocalDateTime,
    holidayDateKeys: Set<String>,
    adjustedWorkdayDateKeys: Set<String>,
    overrideEnabled: Boolean,
    markingEnabled: Boolean,
): Boolean {
    val key = String.format(Locale.ROOT, "%04d-%02d-%02d", date.year, date.monthValue, date.dayOfMonth)
    if (adjustedWorkdayDateKeys.contains(key)) return false
    if (overrideEnabled) return true
    if (!markingEnabled) return false
    return holidayDateKeys.contains(key)
}

/** 调休上班日判定（HolidayResolver.isAdjustedWorkday）。 */
fun resolveAdjustedWorkday(date: LocalDateTime, adjustedWorkdayDateKeys: Set<String>): Boolean {
    val key = String.format(Locale.ROOT, "%04d-%02d-%02d", date.year, date.monthValue, date.dayOfMonth)
    return adjustedWorkdayDateKeys.contains(key)
}
