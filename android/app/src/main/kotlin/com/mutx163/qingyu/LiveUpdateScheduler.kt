package com.mutx163.qingyu

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

internal fun liveSchedulerCourseIsInWeek(
    week: Int,
    startWeek: Int,
    endWeek: Int,
    isOddWeek: Boolean,
    isEvenWeek: Boolean,
    customWeeks: List<Int>?,
): Boolean {
    val normalizedCustomWeeks = customWeeks
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

internal fun liveSchedulerCourseIsActiveInWeek(
    week: Int,
    suspendedWeeks: List<Int>?,
    startWeek: Int,
    endWeek: Int,
    isOddWeek: Boolean,
    isEvenWeek: Boolean,
    customWeeks: List<Int>?,
): Boolean {
    if (suspendedWeeks?.contains(week) == true) {
        return false
    }
    return liveSchedulerCourseIsInWeek(
        week = week,
        startWeek = startWeek,
        endWeek = endWeek,
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        customWeeks = customWeeks,
    )
}

/**
 * The legacy snapshot-level `isHoliday` flag captures Flutter's full holiday
 * semantics (including adjusted workdays) but only for the day the snapshot
 * was synced. It must never be applied to later days, otherwise one holiday
 * sync would suppress the island for every following day until the app is
 * reopened.
 */
internal fun liveSchedulerIsLegacyHolidayFlagActive(
    isHoliday: Boolean,
    isHolidayDate: String?,
    year: Int,
    month: Int,
    dayOfMonth: Int,
): Boolean {
    if (!isHoliday) {
        return false
    }
    if (isHolidayDate.isNullOrBlank()) {
        return false
    }
    return isHolidayDate == String.format("%04d-%02d-%02d", year, month, dayOfMonth)
}

/**
 * Same priority as Flutter [TimetableProvider.isHoliday]:
 * 1. Effective adjusted workday (makeup) → not holiday (beats override)
 * 2. holidayOverrideEnabled → holiday
 * 3. enableHolidayMarking off → not holiday
 * 4. Else membership in [holidayDates]
 */
internal fun liveSchedulerIsDateHoliday(
    holidayDates: Set<String>,
    holidayOverrideEnabled: Boolean,
    enableHolidayMarking: Boolean,
    year: Int,
    month: Int,
    dayOfMonth: Int,
    adjustedWorkdayDates: Set<String> = emptySet(),
): Boolean {
    val dateStr = String.format("%04d-%02d-%02d", year, month, dayOfMonth)
    if (adjustedWorkdayDates.contains(dateStr)) {
        return false
    }
    if (holidayOverrideEnabled) {
        return true
    }
    if (!enableHolidayMarking || holidayDates.isEmpty()) {
        return false
    }
    return holidayDates.contains(dateStr)
}

internal fun liveSchedulerCanDisplayDuring(
    liveEnableDuringClass: Boolean,
    livePromoteDuringClass: Boolean,
    liveShowDuringClassNotification: Boolean,
): Boolean {
    return liveEnableDuringClass &&
        (livePromoteDuringClass || liveShowDuringClassNotification)
}

internal fun liveSchedulerResolveStage(
    nowMillis: Long,
    startAtMillis: Long,
    endAtMillis: Long,
    blockedUntilMillis: Long?,
    liveShowBeforeClassMinutes: Int,
    liveClassReminderStartMinutes: Int,
    endReminderLeadMillis: Long,
    liveEnableBeforeClass: Boolean,
    liveEnableDuringClass: Boolean,
    liveEnableBeforeEnd: Boolean,
    livePromoteDuringClass: Boolean,
    liveShowDuringClassNotification: Boolean,
): String? {
    val beforeClassLeadMillis = liveShowBeforeClassMinutes * 60_000L
    val aheadTime = maxOf(
        startAtMillis - beforeClassLeadMillis,
        blockedUntilMillis ?: Long.MIN_VALUE,
    )
    if (nowMillis < aheadTime || nowMillis >= endAtMillis) {
        return null
    }
    if (nowMillis < startAtMillis) {
        return if (liveEnableBeforeClass) "beforeClass" else null
    }
    val reminderStartMillis = if (liveClassReminderStartMinutes == 0) {
        startAtMillis
    } else {
        maxOf(startAtMillis, endAtMillis - liveClassReminderStartMinutes * 60_000L)
    }
    if (liveClassReminderStartMinutes > 0 && nowMillis < reminderStartMillis) {
        return if (liveEnableDuringClass && liveShowDuringClassNotification) {
            "duringClassStatusBar"
        } else {
            null
        }
    }
    if (liveClassReminderStartMinutes > 0) {
        if (liveEnableBeforeEnd) {
            return "beforeEnd"
        }
        return if (
            liveSchedulerCanDisplayDuring(
                liveEnableDuringClass,
                livePromoteDuringClass,
                liveShowDuringClassNotification,
            )
        ) {
            "duringClass"
        } else {
            null
        }
    }
    val endReminderStart = maxOf(startAtMillis, endAtMillis - endReminderLeadMillis)
    if (nowMillis >= endReminderStart) {
        if (liveEnableBeforeEnd) {
            return "beforeEnd"
        }
        if (
            liveSchedulerCanDisplayDuring(
                liveEnableDuringClass,
                livePromoteDuringClass,
                liveShowDuringClassNotification,
            )
        ) {
            return "duringClass"
        }
        return null
    }
    return if (
        liveSchedulerCanDisplayDuring(
            liveEnableDuringClass,
            livePromoteDuringClass,
            liveShowDuringClassNotification,
        )
    ) {
        "duringClass"
    } else {
        null
    }
}

internal data class LiveSchedulerTestCourse(
    val id: String,
    val dayOfWeek: Int,
    val startSection: Int,
    val endSection: Int,
    val startTime: String,
    val endTime: String,
    val startWeek: Int,
    val endWeek: Int,
    val isOddWeek: Boolean = false,
    val isEvenWeek: Boolean = false,
    val customWeeks: List<Int>? = null,
    val suspendedWeeks: List<Int>? = null,
)

internal data class LiveSchedulerTestSettings(
    val liveShowBeforeClassMinutes: Int = 20,
    val liveClassReminderStartMinutes: Int = 0,
    val liveEnableBeforeClass: Boolean = true,
    val liveEnableDuringClass: Boolean = true,
    val liveEnableBeforeEnd: Boolean = true,
    val livePromoteDuringClass: Boolean = true,
    val liveShowDuringClassNotification: Boolean = true,
    val liveTimeCorrectionSeconds: Int = 0,
)

internal data class LiveSchedulerTestSnapshot(
    val currentWeek: Int,
    val semesterStartMillis: Long?,
    val endReminderLeadMillis: Long = 600_000L,
    val holidayDates: Set<String> = emptySet(),
    val adjustedWorkdayDates: Set<String> = emptySet(),
    val holidayOverrideEnabled: Boolean = false,
    val enableHolidayMarking: Boolean = true,
    val courses: List<LiveSchedulerTestCourse>,
    val settings: LiveSchedulerTestSettings = LiveSchedulerTestSettings(),
)

internal data class LiveSchedulerActiveSelection(
    val courseId: String,
    val stage: String,
)

internal fun liveSchedulerFindActiveSelection(
    snapshot: LiveSchedulerTestSnapshot,
    nowMillis: Long,
): LiveSchedulerActiveSelection? {
    if (snapshot.semesterStartMillis == null) {
        return null
    }

    val nowCalendar = Calendar.getInstance().apply { timeInMillis = nowMillis }
    if (
        liveSchedulerIsDateHoliday(
            holidayDates = snapshot.holidayDates,
            holidayOverrideEnabled = snapshot.holidayOverrideEnabled,
            enableHolidayMarking = snapshot.enableHolidayMarking,
            year = nowCalendar.get(Calendar.YEAR),
            month = nowCalendar.get(Calendar.MONTH) + 1,
            dayOfMonth = nowCalendar.get(Calendar.DAY_OF_MONTH),
            adjustedWorkdayDates = snapshot.adjustedWorkdayDates,
        )
    ) {
        return null
    }

    val targetWeek = liveSchedulerCalculateCalendarWeekForDate(
        semesterStartMillis = snapshot.semesterStartMillis,
        currentWeek = snapshot.currentWeek,
        dateMillis = nowMillis,
    )
    if (targetWeek < 1) {
        return null
    }

    val todayCourses = snapshot.courses
        .filter { course ->
            course.dayOfWeek ==
                nowCalendar.get(Calendar.DAY_OF_WEEK).toWeekday() &&
                liveSchedulerCourseIsActiveInWeek(
                    week = targetWeek,
                    suspendedWeeks = course.suspendedWeeks,
                    startWeek = course.startWeek,
                    endWeek = course.endWeek,
                    isOddWeek = course.isOddWeek,
                    isEvenWeek = course.isEvenWeek,
                    customWeeks = course.customWeeks,
                )
        }
        .sortedBy { it.startSection }
    if (todayCourses.isEmpty()) {
        return null
    }

    for ((index, course) in todayCourses.withIndex()) {
        val startAtMillis = liveSchedulerBuildCorrectedCourseDateTimeMillis(
            nowCalendar,
            course.startTime,
            snapshot.settings.liveTimeCorrectionSeconds,
        ) ?: continue
        val endAtMillis = liveSchedulerBuildCorrectedCourseDateTimeMillis(
            nowCalendar,
            course.endTime,
            snapshot.settings.liveTimeCorrectionSeconds,
        ) ?: continue
        val blockedUntilMillis = liveSchedulerResolveBeforeClassBlockedUntil(
            todayCourses,
            index,
            nowCalendar,
            snapshot.settings.liveTimeCorrectionSeconds,
        )
        val stage = liveSchedulerResolveStage(
            nowMillis = nowMillis,
            startAtMillis = startAtMillis,
            endAtMillis = endAtMillis,
            blockedUntilMillis = blockedUntilMillis,
            liveShowBeforeClassMinutes = snapshot.settings.liveShowBeforeClassMinutes,
            liveClassReminderStartMinutes = snapshot.settings.liveClassReminderStartMinutes,
            endReminderLeadMillis = snapshot.endReminderLeadMillis,
            liveEnableBeforeClass = snapshot.settings.liveEnableBeforeClass,
            liveEnableDuringClass = snapshot.settings.liveEnableDuringClass,
            liveEnableBeforeEnd = snapshot.settings.liveEnableBeforeEnd,
            livePromoteDuringClass = snapshot.settings.livePromoteDuringClass,
            liveShowDuringClassNotification = snapshot.settings.liveShowDuringClassNotification,
        ) ?: continue
        return LiveSchedulerActiveSelection(courseId = course.id, stage = stage)
    }
    return null
}

private fun liveSchedulerBuildCourseDateTimeMillis(
    dateCalendar: Calendar,
    courseTime: String,
): Long? {
    val parts = courseTime.split(":")
    if (parts.size != 2) {
        return null
    }
    val hour = parts[0].toIntOrNull() ?: return null
    val minute = parts[1].toIntOrNull() ?: return null
    return Calendar.getInstance().apply {
        timeInMillis = dateCalendar.timeInMillis
        set(Calendar.HOUR_OF_DAY, hour)
        set(Calendar.MINUTE, minute)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }.timeInMillis
}

private fun liveSchedulerBuildCorrectedCourseDateTimeMillis(
    dateCalendar: Calendar,
    courseTime: String,
    liveTimeCorrectionSeconds: Int,
): Long? {
    val baseMillis = liveSchedulerBuildCourseDateTimeMillis(dateCalendar, courseTime) ?: return null
    return baseMillis + liveTimeCorrectionSeconds * 1000L
}

private fun liveSchedulerResolveBeforeClassBlockedUntil(
    sameDayCourses: List<LiveSchedulerTestCourse>,
    courseIndex: Int,
    dateCalendar: Calendar,
    liveTimeCorrectionSeconds: Int,
): Long? {
    if (courseIndex <= 0 || courseIndex >= sameDayCourses.size) {
        return null
    }

    val course = sameDayCourses[courseIndex]
    val courseStartAtMillis = liveSchedulerBuildCorrectedCourseDateTimeMillis(
        dateCalendar,
        course.startTime,
        liveTimeCorrectionSeconds,
    ) ?: return null

    var blockedUntilMillis: Long? = null
    for (index in 0 until courseIndex) {
        val previousCourse = sameDayCourses[index]
        val previousStartAtMillis = liveSchedulerBuildCorrectedCourseDateTimeMillis(
            dateCalendar,
            previousCourse.startTime,
            liveTimeCorrectionSeconds,
        ) ?: continue
        val previousEndAtMillis = liveSchedulerBuildCorrectedCourseDateTimeMillis(
            dateCalendar,
            previousCourse.endTime,
            liveTimeCorrectionSeconds,
        ) ?: continue
        if (previousStartAtMillis > courseStartAtMillis) {
            continue
        }
        blockedUntilMillis = maxOf(
            blockedUntilMillis ?: Long.MIN_VALUE,
            previousEndAtMillis,
        )
    }

    return blockedUntilMillis
}

internal fun liveSchedulerCalculateWeekForDate(
    semesterStartMillis: Long?,
    currentWeek: Int,
    dateMillis: Long,
    semesterWeekCount: Int? = null,
): Int {
    if (semesterStartMillis == null) {
        return currentWeek
    }
    val normalizedDate = Calendar.getInstance().apply {
        timeInMillis = dateMillis
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
        add(Calendar.DAY_OF_YEAR, -(get(Calendar.DAY_OF_WEEK).toWeekday() - 1))
    }
    val normalizedStart = Calendar.getInstance().apply {
        timeInMillis = semesterStartMillis
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
        add(Calendar.DAY_OF_YEAR, -(get(Calendar.DAY_OF_WEEK).toWeekday() - 1))
    }
    // Round instead of truncate so a DST transition inside the range
    // (23h/25h day) cannot shift the whole diff down by one day.
    val diffDays = Math.round(
        (normalizedDate.timeInMillis - normalizedStart.timeInMillis) / 86_400_000.0
    ).toInt()
    val week = (diffDays / 7) + 1
    if (week < 1) {
        return 0
    }
    if (semesterWeekCount != null && week > semesterWeekCount) {
        return semesterWeekCount
    }
    return week
}

/** Calendar week for live-activity scheduling (no [semesterWeekCount] clamp). */
internal fun liveSchedulerCalculateCalendarWeekForDate(
    semesterStartMillis: Long?,
    currentWeek: Int,
    dateMillis: Long,
): Int {
    return liveSchedulerCalculateWeekForDate(
        semesterStartMillis = semesterStartMillis,
        currentWeek = currentWeek,
        dateMillis = dateMillis,
        semesterWeekCount = null,
    )
}

private data class NativeSectionTime(
    val startTime: String,
    val endTime: String,
)

private data class NativeCourse(
    val id: String,
    val name: String,
    val shortName: String?,
    val teacher: String,
    val location: String,
    val dayOfWeek: Int,
    val startSection: Int,
    val endSection: Int,
    val startTime: String,
    val endTime: String,
    val startWeek: Int,
    val endWeek: Int,
    val isOddWeek: Boolean,
    val isEvenWeek: Boolean,
    val customWeeks: List<Int>?,
    val suspendedWeeks: List<Int>?,
    val note: String?,
) {
    fun isInWeek(week: Int): Boolean {
        if (suspendedWeeks?.contains(week) == true) return false
        return liveSchedulerCourseIsInWeek(
            week = week,
            startWeek = startWeek,
            endWeek = endWeek,
            isOddWeek = isOddWeek,
            isEvenWeek = isEvenWeek,
            customWeeks = customWeeks,
        )
    }
}

private data class NativeLiveSettings(
    val sections: List<NativeSectionTime>,
    val semesterWeekCount: Int,
    val liveShowCourseName: Boolean,
    val liveShowLocation: Boolean,
    val liveShowCountdown: Boolean,
    val liveCountdownTextStyle: String,
    val liveShowStageText: Boolean,
    val liveEnableBeforeClass: Boolean,
    val liveEnableDuringClass: Boolean,
    val liveEnableBeforeEnd: Boolean,
    val livePromoteDuringClass: Boolean,
    val liveShowDuringClassNotification: Boolean,
    val liveUseShortName: Boolean,
    val liveHidePrefixText: Boolean,
    val liveDuringClassTimeDisplayMode: String,
    val liveEnableMiuiIslandLabelImage: Boolean,
    val liveDuringEndShowCourseName: Boolean,
    val liveDuringEndShowLocation: Boolean,
    val liveDuringEndShowCountdown: Boolean,
    val liveDuringEndCountdownTextStyle: String,
    val liveDuringEndShowStageText: Boolean,
    val liveDuringEndUseShortName: Boolean,
    val liveDuringEndHidePrefixText: Boolean,
    val liveDuringEndFollowBeforeClass: Boolean,
    val liveDuringEndTimeDisplayMode: String,
    val liveDuringEndEnableMiuiIslandLabelImage: Boolean,
    val liveMiuiIslandLabelStyle: String,
    val liveMiuiIslandLabelContent: String,
    val liveMiuiIslandLabelFontColor: String,
    val liveMiuiIslandLabelFontWeight: String,
    val liveMiuiIslandLabelRenderQuality: String,
    val liveMiuiIslandLabelFontSize: Float,
    val liveMiuiIslandLabelOffsetX: Float,
    val liveMiuiIslandLabelOffsetY: Float,
    val liveMiuiIslandLabelLogoPath: String?,
    val liveMiuiIslandLabelLogoCornerRadius: Float,
    val liveMiuiIslandExpandedIconMode: String,
    val liveMiuiIslandExpandedIconPath: String?,
    val liveDuringEndMiuiIslandLabelStyle: String,
    val liveDuringEndMiuiIslandLabelContent: String,
    val liveDuringEndMiuiIslandLabelFontColor: String,
    val liveDuringEndMiuiIslandLabelFontWeight: String,
    val liveDuringEndMiuiIslandLabelRenderQuality: String,
    val liveDuringEndMiuiIslandLabelFontSize: Float,
    val liveDuringEndMiuiIslandLabelOffsetX: Float,
    val liveDuringEndMiuiIslandLabelOffsetY: Float,
    val liveDuringEndMiuiIslandLabelLogoPath: String?,
    val liveDuringEndMiuiIslandLabelLogoCornerRadius: Float,
    val liveDuringEndMiuiIslandExpandedIconMode: String,
    val liveDuringEndMiuiIslandExpandedIconPath: String?,
    val liveShowBeforeClassMinutes: Int,
    val liveClassReminderStartMinutes: Int,
    val liveEndSecondsCountdownThreshold: Int,
    val liveTimeCorrectionSeconds: Int,
    val liveBeforeClassQuickAction: String,
    val liveBeforeClassQuickActionAutoMinutes: Int,
)

private data class NativeScheduleSnapshot(
    val currentWeek: Int,
    val semesterStartMillis: Long?,
    val endReminderLeadMillis: Long,
    val isHoliday: Boolean,
    /** Date (yyyy-MM-dd) the [isHoliday] flag was computed for; flag is only valid on that day. */
    val isHolidayDate: String?,
    val holidayDates: Set<String>,
    val adjustedWorkdayDates: Set<String>,
    val holidayOverrideEnabled: Boolean,
    val enableHolidayMarking: Boolean,
    val courses: List<NativeCourse>,
    val settings: NativeLiveSettings,
)

private data class ScheduledSelection(
    val currentCourse: NativeCourse,
    val nextCourse: NativeCourse?,
    val stage: String,
    val triggerAtMillis: Long,
    val startAtMillis: Long,
    val endAtMillis: Long,
    val progressBreakOffsetsMillis: LongArray,
    val progressMilestoneLabels: List<String>,
    val progressMilestoneTimeTexts: List<String>,
)

private data class FutureStageTrigger(
    val stage: String,
    val triggerAtMillis: Long,
)

/** Future alarm time for the auto before-class quick action, or null when
 *  disabled / not strictly in the future. Honors [blockedUntilMillis] so the
 *  trigger of a later course never fires while an earlier course still runs. */
internal fun liveSchedulerQuickActionTriggerAt(
    autoMinutes: Int,
    action: String,
    startAtMillis: Long,
    blockedUntilMillis: Long?,
    nowMillis: Long,
): Long? {
    val leadMillis = autoMinutes * 60_000L
    if (leadMillis <= 0L || action == "none") {
        return null
    }
    val triggerAt = maxOf(
        startAtMillis - leadMillis,
        blockedUntilMillis ?: Long.MIN_VALUE,
    )
    return triggerAt.takeIf { it > nowMillis && it < startAtMillis }
}

/** Whether the auto quick action window [startAt - lead, startAt) already
 *  covers [nowMillis] (due to apply now, e.g. after an alarm or app open). */
internal fun liveSchedulerQuickActionIsDue(
    autoMinutes: Int,
    action: String,
    startAtMillis: Long,
    blockedUntilMillis: Long?,
    nowMillis: Long,
): Boolean {
    if (nowMillis >= startAtMillis) {
        return false
    }
    return liveSchedulerQuickActionTriggerAt(
        autoMinutes = autoMinutes,
        action = action,
        startAtMillis = startAtMillis,
        blockedUntilMillis = blockedUntilMillis,
        nowMillis = Long.MIN_VALUE,
    )?.let { nowMillis >= it } ?: false
}

private data class LiveUpdatePayload(
    val currentCourse: NativeCourse,
    val nextCourse: NativeCourse?,
    val stage: String,
    val startAtMillis: Long,
    val endAtMillis: Long,
    val beforeClassLeadMillis: Long,
    val endReminderLeadMillis: Long,
    val liveClassReminderStartMinutes: Int,
    val endSecondsCountdownThreshold: Int,
    val enableBeforeClass: Boolean,
    val enableDuringClass: Boolean,
    val enableBeforeEnd: Boolean,
    val promoteDuringClass: Boolean,
    val showNotificationDuringClass: Boolean,
    val showCountdown: Boolean,
    val countdownTextStyle: String,
    val showStageText: Boolean,
    val showCourseNameInIsland: Boolean,
    val showLocationInIsland: Boolean,
    val useShortNameInIsland: Boolean,
    val hidePrefixText: Boolean,
    val duringClassTimeDisplayMode: String,
    val enableMiuiIslandLabelImage: Boolean,
    val miuiIslandLabelStyle: String,
    val miuiIslandLabelContent: String,
    val miuiIslandLabelFontColor: String,
    val miuiIslandLabelFontWeight: String,
    val miuiIslandLabelRenderQuality: String,
    val miuiIslandLabelFontSize: Float,
    val miuiIslandLabelOffsetX: Float,
    val miuiIslandLabelOffsetY: Float,
    val miuiIslandLabelLogoPath: String?,
    val miuiIslandLabelLogoCornerRadius: Float,
    val miuiIslandExpandedIconMode: String,
    val miuiIslandExpandedIconPath: String?,
    val beforeClassQuickAction: String,
    val beforeClassQuickActionAutoLeadMillis: Long,
    val progressBreakOffsetsMillis: LongArray,
    val progressMilestoneLabels: List<String>,
    val progressMilestoneTimeTexts: List<String>,
    /** When true, ticker re-validates against the schedule snapshot (scheduler path). */
    val validateAgainstSchedule: Boolean = true,
)

private fun normalizeNullableText(value: String?): String? {
    val normalized = value?.trim() ?: return null
    if (normalized.isEmpty() || normalized.equals("null", ignoreCase = true)) {
        return null
    }
    return normalized
}

private fun normalizeText(value: String?): String = normalizeNullableText(value) ?: ""

private fun parseIntList(raw: Any?): List<Int>? {
    return when (raw) {
        is JSONArray -> buildList {
            for (index in 0 until raw.length()) {
                val value = raw.opt(index)
                when (value) {
                    is Number -> add(value.toInt())
                    is String -> value.toIntOrNull()?.let(::add)
                }
            }
        }.takeIf { it.isNotEmpty() }
        is List<*> -> raw.mapNotNull {
            when (it) {
                is Number -> it.toInt()
                is String -> it.toIntOrNull()
                else -> null
            }
        }.takeIf { it.isNotEmpty() }
        else -> null
    }
}

/** FGS 后台启动被拒后的重试参数：指数退避（60s→120s→240s→…），封顶 15 分钟；
 *  超过次数上限后放弃本次 FGS 拉起、降级为普通通知，链条交由下一课节闹钟自愈。 */
private const val FGS_RETRY_BASE_DELAY_MILLIS = 60_000L
private const val FGS_RETRY_MAX_DELAY_MILLIS = 15 * 60_000L
const val FGS_RETRY_MAX_ATTEMPTS = 3

/// 第 [attempt] 次重试（从 1 计）前的退避时长；纯函数，单测与调度共用。
fun liveSchedulerFgsRetryDelayMillis(attempt: Int): Long =
    (FGS_RETRY_BASE_DELAY_MILLIS shl (attempt - 1).coerceAtMost(4))
        .coerceAtMost(FGS_RETRY_MAX_DELAY_MILLIS)

/// [LiveUpdateScheduler.rescheduleDetailed] 的结果：调用方据其决定超级岛的生死。
enum class LiveUpdateRescheduleOutcome {
    /// 本次已成功拉起/刷新前台服务。
    STARTED,

    /// 拉起被拒，退避重试闹钟已排（岛必须保持，等重试送达新负载）。
    RETRY_PENDING,

    /// 当前无活跃课节，已排下一次课节闹钟（岛应停止）。
    SCHEDULED,

    /// 无快照/假期/无后续课节（岛应停止）。
    IDLE,

    /// 测试会话接管调度（岛保持现状）。
    SUSPENDED,
}

object LiveUpdateScheduler {
    private const val TAG = "LiveUpdateScheduler"
    private const val PREFS_NAME = "live_update_scheduler"
    private const val KEY_SNAPSHOT_JSON = "snapshot_json"
    private const val KEY_SNAPSHOT_VERSION = "snapshot_version"
    private const val KEY_SUSPEND_UNTIL_MILLIS = "suspend_until_millis"
    private const val REQUEST_CODE_TRIGGER = 2002

    private const val KEY_FGS_RETRY_COUNT = "fgs_retry_count"
    private const val KEY_FGS_LAST_ATTEMPT_MILLIS = "fgs_last_attempt_millis"
    private const val FALLBACK_NOTIFICATION_TAG = "live_update_fallback"
    private const val FALLBACK_NOTIFICATION_ID = 3002
    private const val FALLBACK_NOTIFICATION_REQUEST_CODE = 3003

    /** Upper bound for the week lookahead scan so a corrupt/huge endWeek
     *  cannot make [findNextSelection] loop over thousands of weeks. */
    private const val MAX_LOOKAHEAD_WEEKS = 104

    const val ACTION_TRIGGER = "com.mutx163.qingyu.ACTION_TRIGGER_LIVE_UPDATE"

    fun syncSnapshot(context: Context, snapshotJson: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SNAPSHOT_JSON, snapshotJson)
            .putString(KEY_SNAPSHOT_VERSION, resolveAppVersionToken(context))
            .apply()
        // Diagnostic: log key settings from the synced snapshot
        try {
            val settingsJson = JSONObject(snapshotJson).optJSONObject("settings")
            if (settingsJson != null) {
                UmengDiagnosticReporter.record(
                    context = context.applicationContext,
                    category = "live_update_snapshot_settings",
                    message = DiagnosticLogMessages.LIVE_UPDATE_SNAPSHOT_SETTINGS,
                    extras = mapOf(
                        "liveEnableDuringClass" to settingsJson.optBoolean("liveEnableDuringClass", true),
                        "liveEnableBeforeEnd" to settingsJson.optBoolean("liveEnableBeforeEnd", true),
                        "liveEnableBeforeClass" to settingsJson.optBoolean("liveEnableBeforeClass", true),
                        "livePromoteDuringClass" to settingsJson.optBoolean("livePromoteDuringClass", true),
                    )
                )
            }
        } catch (_: Exception) {}
        UmengDiagnosticReporter.record(
            context = context.applicationContext,
            category = "live_update_snapshot_synced",
            message = DiagnosticLogMessages.LIVE_UPDATE_SNAPSHOT_SYNCED,
            extras = mapOf(
                "snapshotLength" to snapshotJson.length
            )
        )
        // Allow immediate start: syncing inside an already-open before-class
        // window must show the island right away. Otherwise resolveNextTrigger
        // only finds future triggers and the reminder is silently skipped
        // until the next stage boundary.
        // stopStaleSessions=true: a holiday/empty selection snapshot must stop
        // any session still showing courses from before the holiday sync.
        reschedule(
            context,
            allowImmediateStart = true,
            stopStaleSessions = true,
        )
        // WorkManager backup: ensures live update can still trigger
        // when AlarmManager is suppressed (e.g. MIUI + accessibility).
        LiveUpdateRefreshWorker.ensureScheduled(context)
    }

    fun clearSnapshot(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_SNAPSHOT_JSON)
            .remove(KEY_SNAPSHOT_VERSION)
            .apply()
        UmengDiagnosticReporter.record(
            context = context.applicationContext,
            category = "live_update_snapshot_cleared",
            message = DiagnosticLogMessages.LIVE_UPDATE_SNAPSHOT_CLEARED,
        )
        cancelPendingTriggers(context)
        LiveUpdateRefreshWorker.cancel(context)
    }

    /** Cancel AlarmManager triggers without clearing the schedule snapshot. */
    fun cancelPendingTriggers(context: Context) {
        cancelScheduledAlarm(context)
    }

    fun handleAlarm(context: Context) {
        UmengDiagnosticReporter.record(
            context = context.applicationContext,
            category = "live_update_alarm_triggered",
            message = DiagnosticLogMessages.LIVE_UPDATE_ALARM_TRIGGERED,
        )
        reschedule(context, allowImmediateStart = true, stopStaleSessions = true)
    }

    /** Pause scheduler-driven session management until [untilMillis] (used by live-update tests). */
    fun suspendScheduleTriggers(context: Context, untilMillis: Long) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putLong(KEY_SUSPEND_UNTIL_MILLIS, untilMillis)
            .apply()
        cancelScheduledAlarm(context)
        if (untilMillis > System.currentTimeMillis()) {
            scheduleAlarm(context, untilMillis)
        }
    }

    private fun suspendedUntilMillis(context: Context): Long {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getLong(KEY_SUSPEND_UNTIL_MILLIS, 0L)
    }

    /** Whether the persisted schedule snapshot still has a course to show right now. */
    fun hasActiveLiveSelection(context: Context, nowMillis: Long = System.currentTimeMillis()): Boolean {
        val snapshot = loadSnapshot(context) ?: return false
        return hasActiveLiveSelection(snapshot, context, nowMillis)
    }

    /** Stop the foreground live-update service without clearing the schedule snapshot. */
    fun stopRunningLiveUpdate(context: Context) {
        context.stopService(Intent(context, LiveUpdateService::class.java))
    }

    fun handleBootReschedule(context: Context) {
        BeforeClassQuickActionRestore.restoreOnBoot(context.applicationContext)
        reschedule(context, allowImmediateStart = true, stopStaleSessions = true)
    }

    fun handleTimeReschedule(context: Context) {
        reschedule(context, allowImmediateStart = true, stopStaleSessions = true)
    }

    fun onLiveUpdateStopped(context: Context) {
        UmengDiagnosticReporter.record(
            context = context.applicationContext,
            category = "live_update_scheduler_resume",
            message = DiagnosticLogMessages.LIVE_UPDATE_SCHEDULER_RESUME,
        )
        reschedule(context, allowImmediateStart = false)
    }

    fun buildServiceIntentFromMethodPayload(
        context: Context,
        data: Map<String, Any>,
    ): Intent {
        val current = data["currentCourse"] as? Map<String, Any> ?: emptyMap()
        val next = data["nextCourse"] as? Map<String, Any>
        val islandConfig = data["islandConfig"] as? Map<String, Any> ?: emptyMap()
        val progressBreakOffsetsMillis =
            (data["progressBreakOffsetsMillis"] as? List<*>)?.mapNotNull {
                (it as? Number)?.toLong()
            }?.toLongArray() ?: longArrayOf()
        val progressMilestoneLabels =
            (data["progressMilestoneLabels"] as? List<*>)?.mapNotNull { it as? String }
                ?: emptyList()
        val progressMilestoneTimeTexts =
            (data["progressMilestoneTimeTexts"] as? List<*>)?.mapNotNull { it as? String }
                ?: emptyList()

        val payload = LiveUpdatePayload(
            currentCourse = mapToNativeCourse(current),
            nextCourse = next?.let(::mapToNativeCourse),
            stage = data["stage"] as? String ?: "",
            startAtMillis = (data["startAtMillis"] as? Number)?.toLong() ?: 0L,
            endAtMillis = (data["endAtMillis"] as? Number)?.toLong() ?: 0L,
            beforeClassLeadMillis = (data["beforeClassLeadMillis"] as? Number)?.toLong() ?: 0L,
            endReminderLeadMillis = (data["endReminderLeadMillis"] as? Number)?.toLong()
                ?: 600_000L,
            liveClassReminderStartMinutes =
                (data["liveClassReminderStartMinutes"] as? Number)?.toInt() ?: 0,
            endSecondsCountdownThreshold =
                (data["endSecondsCountdownThreshold"] as? Number)?.toInt() ?: 60,
            enableBeforeClass = data["enableBeforeClass"] as? Boolean ?: true,
            enableDuringClass = data["enableDuringClass"] as? Boolean ?: true,
            enableBeforeEnd = data["enableBeforeEnd"] as? Boolean ?: true,
            promoteDuringClass = data["promoteDuringClass"] as? Boolean ?: true,
            showNotificationDuringClass =
                data["showNotificationDuringClass"] as? Boolean ?: true,
            showCountdown = data["showCountdown"] as? Boolean ?: true,
            countdownTextStyle = data["countdownTextStyle"] as? String ?: "smart",
            showStageText = data["showStageText"] as? Boolean ?: true,
            showCourseNameInIsland = islandConfig["showCourseName"] as? Boolean ?: true,
            showLocationInIsland = islandConfig["showLocation"] as? Boolean ?: true,
            useShortNameInIsland = islandConfig["useShortName"] as? Boolean ?: false,
            hidePrefixText = islandConfig["hidePrefixText"] as? Boolean ?: false,
            duringClassTimeDisplayMode =
                islandConfig["duringClassTimeDisplayMode"] as? String ?: "nearest",
            enableMiuiIslandLabelImage =
                islandConfig["enableMiuiIslandLabelImage"] as? Boolean ?: false,
            miuiIslandLabelStyle =
                islandConfig["miuiIslandLabelStyle"] as? String ?: "text_only",
            miuiIslandLabelContent =
                islandConfig["miuiIslandLabelContent"] as? String ?: "course_name",
            miuiIslandLabelFontColor =
                islandConfig["miuiIslandLabelFontColor"] as? String ?: "#FFFFFF",
            miuiIslandLabelFontWeight =
                islandConfig["miuiIslandLabelFontWeight"] as? String ?: "bold",
            miuiIslandLabelRenderQuality =
                islandConfig["miuiIslandLabelRenderQuality"] as? String ?: "standard",
            miuiIslandLabelFontSize =
                (islandConfig["miuiIslandLabelFontSize"] as? Number)?.toFloat() ?: 14f,
            miuiIslandLabelOffsetX =
                (islandConfig["miuiIslandLabelOffsetX"] as? Number)?.toFloat() ?: 0f,
            miuiIslandLabelOffsetY =
                (islandConfig["miuiIslandLabelOffsetY"] as? Number)?.toFloat() ?: 0f,
            miuiIslandLabelLogoPath =
                islandConfig["miuiIslandLabelLogoPath"] as? String,
            miuiIslandLabelLogoCornerRadius =
                (islandConfig["miuiIslandLabelLogoCornerRadius"] as? Number)?.toFloat() ?: 8f,
            miuiIslandExpandedIconMode =
                islandConfig["miuiIslandExpandedIconMode"] as? String ?: "app_icon",
            miuiIslandExpandedIconPath =
                islandConfig["miuiIslandExpandedIconPath"] as? String,
            beforeClassQuickAction =
                data["beforeClassQuickAction"] as? String ?: "none",
            beforeClassQuickActionAutoLeadMillis =
                ((data["beforeClassQuickActionAutoMinutes"] as? Number)?.toLong()
                    ?: 0L) * 60_000L,
            progressBreakOffsetsMillis = progressBreakOffsetsMillis,
            progressMilestoneLabels = progressMilestoneLabels,
            progressMilestoneTimeTexts = progressMilestoneTimeTexts,
            // Production Flutter starts pass true so the ticker keeps
            // re-validating against the schedule snapshot after the app goes
            // to the background. Test sessions omit the flag (false) because
            // their fixture course is intentionally absent from the snapshot.
            validateAgainstSchedule =
                data["validateAgainstSchedule"] as? Boolean ?: false,
        )
        return buildServiceIntent(context, payload)
    }

    // 兼容旧布尔语义：仅当本次成功拉起前台服务时为 true。
    fun reschedule(
        context: Context,
        allowImmediateStart: Boolean,
        stopStaleSessions: Boolean = false,
    ): Boolean {
        return rescheduleDetailed(context, allowImmediateStart, stopStaleSessions) ==
            LiveUpdateRescheduleOutcome.STARTED
    }

    // 重排调度并返回结构化结果；岛的生死由结果决定（详见 [LiveUpdateRescheduleOutcome]）。
    fun rescheduleDetailed(
        context: Context,
        allowImmediateStart: Boolean,
        stopStaleSessions: Boolean = false,
    ): LiveUpdateRescheduleOutcome {
        cancelScheduledAlarm(context)
        val suspendUntil = suspendedUntilMillis(context)
        if (suspendUntil > System.currentTimeMillis()) {
            // A live-update test session owns the island right now; defer any
            // scheduler-driven start/stop so it cannot overwrite the test.
            scheduleAlarm(context, suspendUntil)
            return LiveUpdateRescheduleOutcome.SUSPENDED
        }
        val snapshot = loadSnapshot(context) ?: run {
            if (stopStaleSessions) {
                stopRunningLiveUpdate(context)
            }
            return LiveUpdateRescheduleOutcome.IDLE
        }
        if (stopStaleSessions && snapshot.semesterStartMillis == null) {
            stopRunningLiveUpdate(context)
            UmengDiagnosticReporter.record(
                context = context.applicationContext,
                category = "live_update_semester_start_missing",
                message = DiagnosticLogMessages.LIVE_UPDATE_SEMESTER_START_MISSING,
            )
            return LiveUpdateRescheduleOutcome.IDLE
        }
        // Check if today is a holiday (uses both legacy isHoliday flag and full date list)
        val nowCalendar = Calendar.getInstance()
        if (isLegacyHolidayFlagActive(snapshot, nowCalendar) ||
            isDateHoliday(snapshot, nowCalendar)
        ) {
            if (stopStaleSessions) {
                stopRunningLiveUpdate(context)
            }
            UmengDiagnosticReporter.record(
                context = context.applicationContext,
                category = "live_update_reschedule_holiday",
                message = DiagnosticLogMessages.LIVE_UPDATE_RESCHEDULE_HOLIDAY,
            )
            return LiveUpdateRescheduleOutcome.IDLE
        }
        val now = System.currentTimeMillis()
        val activeSelection = findActiveSelection(context, snapshot, now)
        if (allowImmediateStart) {
            if (activeSelection != null) {
                UmengDiagnosticReporter.record(
                    context = context.applicationContext,
                    category = "live_update_reschedule_active",
                    message = DiagnosticLogMessages.LIVE_UPDATE_RESCHEDULE_ACTIVE,
                    extras = mapOf(
                        "courseName" to activeSelection.currentCourse.name,
                        "stage" to activeSelection.stage,
                    )
                )
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val attempts = prefs.getInt(KEY_FGS_RETRY_COUNT, 0)
                val lastAttemptAt = prefs.getLong(KEY_FGS_LAST_ATTEMPT_MILLIS, 0L)
                // 退避窗口内不重复尝试：ticker 每秒会重入本函数，若无此闸，
                // 保持岛的同时会演变成每秒一次的 startForegroundService 风暴。
                // 本函数开头已 cancel 旧闹钟，必须把退避重试闹钟补排回来。
                if (attempts > 0 &&
                    now - lastAttemptAt < liveSchedulerFgsRetryDelayMillis(attempts)
                ) {
                    scheduleAlarm(
                        context,
                        lastAttemptAt + liveSchedulerFgsRetryDelayMillis(attempts),
                    )
                    return LiveUpdateRescheduleOutcome.RETRY_PENDING
                }
                val started = startForegroundService(
                    context,
                    selectionToPayload(snapshot, activeSelection),
                )
                if (started) {
                    prefs.edit().putInt(KEY_FGS_RETRY_COUNT, 0).apply()
                    return LiveUpdateRescheduleOutcome.STARTED
                }
                // FGS start can be blocked in the background（A 类：ContextImpl 拒绝，
                // 服务根本没起来）。旧实现固定 60s 无限重试，且假设"闹钟广播授予临时
                // 豁免"——在 HyperOS 3 (sdkInt>=36) 上实测不成立。改为指数退避 +
                // 次数上限，耗尽后降级为普通通知，本课节提醒不丢。
                val nextAttempt = attempts + 1
                prefs.edit()
                    .putInt(KEY_FGS_RETRY_COUNT, nextAttempt)
                    .putLong(KEY_FGS_LAST_ATTEMPT_MILLIS, now)
                    .apply()
                if (nextAttempt <= FGS_RETRY_MAX_ATTEMPTS) {
                    val backoff = liveSchedulerFgsRetryDelayMillis(nextAttempt)
                    UmengDiagnosticReporter.record(
                        context = context.applicationContext,
                        category = "live_update_fgs_retry_scheduled",
                        message = DiagnosticLogMessages.LIVE_UPDATE_FGS_RETRY_SCHEDULED,
                        extras = mapOf(
                            "courseName" to activeSelection.currentCourse.name,
                            "attempt" to nextAttempt,
                            "backoffMillis" to backoff,
                        )
                    )
                    scheduleAlarm(context, now + backoff)
                    return LiveUpdateRescheduleOutcome.RETRY_PENDING
                }
                // 退避耗尽：放弃本次 FGS，降级普通通知；计数复位，继续走下方
                // 下一课节闹钟调度（返回 SCHEDULED/IDLE，岛由调用方停止）。
                prefs.edit().putInt(KEY_FGS_RETRY_COUNT, 0).apply()
                UmengDiagnosticReporter.record(
                    context = context.applicationContext,
                    category = "live_update_fgs_start_gave_up",
                    message = DiagnosticLogMessages.LIVE_UPDATE_FGS_START_GAVE_UP,
                    extras = mapOf(
                        "courseName" to activeSelection.currentCourse.name,
                        "stage" to activeSelection.stage,
                    )
                )
                postFallbackNotification(context, activeSelection)
            } else if (stopStaleSessions) {
                stopRunningLiveUpdate(context)
                UmengDiagnosticReporter.record(
                    context = context.applicationContext,
                    category = "live_update_stopped_no_active_selection",
                    message = DiagnosticLogMessages.LIVE_UPDATE_STOPPED_NO_ACTIVE_SELECTION,
                )
            }
        }

        // Restore overdue quick actions first so a new apply for the next
        // course extends rather than swallows the pending restore window.
        BeforeClassQuickActionRestore.restoreIfClassEnded(context)
        applyDueAutoQuickAction(context, snapshot, now)

        val nextSelection = findNextSelection(context, snapshot, now) ?:
            return LiveUpdateRescheduleOutcome.IDLE
        UmengDiagnosticReporter.record(
            context = context.applicationContext,
            category = "live_update_reschedule_scheduled",
            message = DiagnosticLogMessages.LIVE_UPDATE_RESCHEDULE_SCHEDULED,
            extras = mapOf(
                "courseName" to nextSelection.currentCourse.name,
                "stage" to nextSelection.stage,
                "triggerAtMillis" to nextSelection.triggerAtMillis,
            )
        )
        scheduleAlarm(context, nextSelection.triggerAtMillis)
        return LiveUpdateRescheduleOutcome.SCHEDULED
    }

    /** FGS 反复被拒后的兜底：以普通（非前台服务）通知把本课节提醒送达用户。 */
    private fun postFallbackNotification(context: Context, selection: ScheduledSelection) {
        try {
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // 与 LiveUpdateService.CHANNEL_ID 同渠道；渠道已存在时本调用为幂等 no-op。
                manager.createNotificationChannel(
                    NotificationChannel(
                        LiveUpdateService.CHANNEL_ID,
                        context.getString(R.string.notification_channel_live_update_name),
                        NotificationManager.IMPORTANCE_LOW,
                    ).apply {
                        description = context.getString(
                            R.string.notification_channel_live_update_desc,
                        )
                    },
                )
            }
            val contentIntent = PendingIntent.getActivity(
                context,
                FALLBACK_NOTIFICATION_REQUEST_CODE,
                context.packageManager.getLaunchIntentForPackage(context.packageName),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, LiveUpdateService.CHANNEL_ID)
            } else {
                Notification.Builder(context)
            }
                .setContentTitle(
                    context.getString(
                        R.string.notification_course_reminder_title,
                        selection.currentCourse.name,
                    ),
                )
                .setContentText(context.getString(R.string.notification_fgs_fallback_text))
                .setSmallIcon(R.drawable.ic_course)
                .setContentIntent(contentIntent)
                .setAutoCancel(true)
            manager.notify(
                FALLBACK_NOTIFICATION_TAG,
                FALLBACK_NOTIFICATION_ID,
                builder.build(),
            )
        } catch (e: Exception) {
            Log.w(TAG, DiagnosticLogMessages.LOG_POST_FALLBACK_NOTIFICATION_FAILED, e)
        }
    }

    /**
     * Apply the auto quick action for a course whose lead window already
     * started ([startAt - lead, startAt)) but whose stage trigger has not
     * fired yet — e.g. the exact alarm woke us at the quick-action time, or
     * the app was opened mid-window. Dedup lives in
     * [BeforeClassQuickActionRestore.applyAutoQuickAction].
     */
    private fun applyDueAutoQuickAction(
        context: Context,
        snapshot: NativeScheduleSnapshot,
        nowMillis: Long,
    ) {
        val settings = snapshot.settings
        val leadMillis = settings.liveBeforeClassQuickActionAutoMinutes * 60_000L
        if (leadMillis <= 0L ||
            settings.liveBeforeClassQuickAction == "none" ||
            snapshot.semesterStartMillis == null
        ) {
            return
        }
        val nowCalendar = Calendar.getInstance().apply { timeInMillis = nowMillis }
        val targetWeek = calculateCalendarWeekForDate(snapshot, nowCalendar)
        val todayCourses = snapshot.courses
            .filter {
                it.dayOfWeek == nowCalendar.get(Calendar.DAY_OF_WEEK).toWeekday() &&
                    it.isInWeek(targetWeek)
            }
            .sortedBy { it.startSection }
        if (todayCourses.isEmpty()) {
            return
        }
        for ((index, course) in todayCourses.withIndex()) {
            val startAtMillis =
                buildCorrectedCourseDateTimeMillis(nowCalendar, course.startTime, settings)
                    ?: continue
            if (nowMillis >= startAtMillis) {
                // Window closed; later courses may still be pending today.
                continue
            }
            val endAtMillis =
                buildCorrectedCourseDateTimeMillis(nowCalendar, course.endTime, settings)
                    ?: continue
            val blockedUntilMillis =
                resolveBeforeClassBlockedUntil(todayCourses, index, nowCalendar, settings)
            val isDue = liveSchedulerQuickActionIsDue(
                autoMinutes = settings.liveBeforeClassQuickActionAutoMinutes,
                action = settings.liveBeforeClassQuickAction,
                startAtMillis = startAtMillis,
                blockedUntilMillis = blockedUntilMillis,
                nowMillis = nowMillis,
            )
            if (!isDue) {
                continue
            }
            BeforeClassQuickActionRestore.applyAutoQuickAction(
                context = context.applicationContext,
                action = settings.liveBeforeClassQuickAction,
                triggerKeyMillis = startAtMillis,
                restoreAtMillis = endAtMillis,
            )
            return
        }
    }

    private fun loadSnapshot(context: Context): NativeScheduleSnapshot? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val snapshotJson = prefs.getString(KEY_SNAPSHOT_JSON, null) ?: return null
        val snapshotVersion = prefs.getString(KEY_SNAPSHOT_VERSION, null)
        val currentVersion = resolveAppVersionToken(context)
        if (snapshotVersion.isNullOrBlank() || (
                !currentVersion.isNullOrBlank() &&
                    snapshotVersion != currentVersion
                )
        ) {
            invalidateSnapshotForVersionChange(
                context = context,
                storedSnapshotVersion = snapshotVersion,
                currentVersion = currentVersion,
            )
            return null
        }
        return try {
            parseSnapshot(JSONObject(snapshotJson))
        } catch (e: Exception) {
            Log.w(TAG, DiagnosticLogMessages.LOG_PARSE_SNAPSHOT_FAILED, e)
            UmengDiagnosticReporter.report(
                context = context.applicationContext,
                category = "live_update_snapshot_parse_failed",
                message = DiagnosticLogMessages.LIVE_UPDATE_SNAPSHOT_PARSE_FAILED,
                throwable = e,
                dedupeKey = "live_update_snapshot_parse_failed",
            )
            null
        }
    }

    private fun invalidateSnapshotForVersionChange(
        context: Context,
        storedSnapshotVersion: String?,
        currentVersion: String?,
    ) {
        // 版本令牌不匹配只说明"旧版写入"，不代表新版解析器读不懂：先尝试解析旧
        // JSON，通过则保留数据、仅刷新版本令牌——升级后闹钟/Worker 可立即用旧快照
        // 恢复上岛，无需等用户打开 App 重新同步（此前直接清空导致升级后空转）。
        // 解析失败（格式真漂移）才维持原样作废，保留格式漂移安全性。
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val salvaged = if (currentVersion != null) {
            prefs.getString(KEY_SNAPSHOT_JSON, null)?.let { raw ->
                try {
                    parseSnapshot(JSONObject(raw))
                } catch (e: Exception) {
                    Log.w(TAG, DiagnosticLogMessages.LOG_PARSE_SNAPSHOT_FAILED, e)
                    null
                }
            }
        } else {
            // 版本令牌解析失败时无法回写有效令牌，保持旧路径（作废），
            // 避免 loadSnapshot 反复进入失效分支。
            null
        }
        if (salvaged != null) {
            prefs.edit().putString(KEY_SNAPSHOT_VERSION, currentVersion).apply()
            UmengDiagnosticReporter.record(
                context = context.applicationContext,
                category = "live_update_snapshot_salvaged_after_upgrade",
                message = DiagnosticLogMessages.LIVE_UPDATE_SNAPSHOT_SALVAGED,
                extras = mapOf(
                    "storedSnapshotVersion" to (storedSnapshotVersion ?: "missing"),
                    "currentVersion" to (currentVersion ?: "unknown"),
                )
            )
            // 外层 loadSnapshot 正常返回快照，reschedule 继续执行：闹钟与上岛自恢复。
        } else {
            prefs.edit()
                .remove(KEY_SNAPSHOT_JSON)
                .remove(KEY_SNAPSHOT_VERSION)
                .apply()
            cancelScheduledAlarm(context)
            context.stopService(Intent(context, LiveUpdateService::class.java))
            UmengDiagnosticReporter.record(
                context = context.applicationContext,
                category = "live_update_snapshot_invalidated_after_upgrade",
                message = DiagnosticLogMessages.LIVE_UPDATE_SNAPSHOT_INVALIDATED,
                extras = mapOf(
                    "storedSnapshotVersion" to (storedSnapshotVersion ?: "missing"),
                    "currentVersion" to (currentVersion ?: "unknown"),
                )
            )
        }
        // 升级后兜底 Worker 必须在位：UPDATE 策略幂等。
        LiveUpdateRefreshWorker.ensureScheduled(context)
    }

    private fun resolveAppVersionToken(context: Context): String? {
        return try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.PackageInfoFlags.of(0)
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(context.packageName, 0)
            }
            val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                packageInfo.versionCode.toLong()
            }
            "${packageInfo.versionName ?: ""}:$versionCode"
        } catch (e: Exception) {
            Log.w(TAG, DiagnosticLogMessages.LOG_RESOLVE_APP_VERSION_FAILED, e)
            null
        }
    }

    private fun parseSnapshot(json: JSONObject): NativeScheduleSnapshot {
        val settingsJson = json.optJSONObject("settings") ?: JSONObject()
        val sectionsJson = settingsJson.optJSONArray("sections") ?: JSONArray()
        val sections = mutableListOf<NativeSectionTime>()
        for (index in 0 until sectionsJson.length()) {
            val sectionJson = sectionsJson.optJSONObject(index) ?: continue
            sections += NativeSectionTime(
                startTime = sectionJson.optString("startTime"),
                endTime = sectionJson.optString("endTime"),
            )
        }
        val settings = NativeLiveSettings(
            sections = sections,
            semesterWeekCount = settingsJson.optInt("semesterWeekCount", 20),
            liveShowCourseName = settingsJson.optBoolean("liveShowCourseName", true),
            liveShowLocation = settingsJson.optBoolean("liveShowLocation", true),
            liveShowCountdown = settingsJson.optBoolean("liveShowCountdown", true),
            liveCountdownTextStyle =
                settingsJson.optString("liveCountdownTextStyle", "smart"),
            liveShowStageText = settingsJson.optBoolean("liveShowStageText", true),
            liveEnableBeforeClass = settingsJson.optBoolean("liveEnableBeforeClass", true),
            liveEnableDuringClass = settingsJson.optBoolean("liveEnableDuringClass", true),
            liveEnableBeforeEnd = settingsJson.optBoolean("liveEnableBeforeEnd", true),
            livePromoteDuringClass = settingsJson.optBoolean("livePromoteDuringClass", true),
            liveShowDuringClassNotification =
                settingsJson.optBoolean("liveShowDuringClassNotification", true),
            liveUseShortName = settingsJson.optBoolean("liveUseShortName", true),
            liveHidePrefixText = settingsJson.optBoolean("liveHidePrefixText", false),
            liveDuringClassTimeDisplayMode =
                settingsJson.optString("liveDuringClassTimeDisplayMode", "nearest"),
            liveEnableMiuiIslandLabelImage =
                settingsJson.optBoolean("liveEnableMiuiIslandLabelImage", false),
            liveDuringEndShowCourseName =
                settingsJson.optBoolean(
                    "liveDuringEndShowCourseName",
                    settingsJson.optBoolean("liveShowCourseName", true),
                ),
            liveDuringEndShowLocation =
                settingsJson.optBoolean(
                    "liveDuringEndShowLocation",
                    settingsJson.optBoolean("liveShowLocation", true),
                ),
            liveDuringEndShowCountdown =
                settingsJson.optBoolean(
                    "liveDuringEndShowCountdown",
                    settingsJson.optBoolean("liveShowCountdown", true),
                ),
            liveDuringEndCountdownTextStyle =
                settingsJson.optString(
                    "liveDuringEndCountdownTextStyle",
                    settingsJson.optString("liveCountdownTextStyle", "smart"),
                ),
            liveDuringEndShowStageText =
                settingsJson.optBoolean(
                    "liveDuringEndShowStageText",
                    settingsJson.optBoolean("liveShowStageText", true),
                ),
            liveDuringEndUseShortName =
                settingsJson.optBoolean(
                    "liveDuringEndUseShortName",
                    settingsJson.optBoolean("liveUseShortName", true),
                ),
            liveDuringEndHidePrefixText =
                settingsJson.optBoolean(
                    "liveDuringEndHidePrefixText",
                    settingsJson.optBoolean("liveHidePrefixText", false),
                ),
            liveDuringEndFollowBeforeClass =
                settingsJson.optBoolean("liveDuringEndFollowBeforeClass", true),
            liveDuringEndTimeDisplayMode =
                settingsJson.optString(
                    "liveDuringEndTimeDisplayMode",
                    settingsJson.optString("liveDuringClassTimeDisplayMode", "nearest"),
                ),
            liveDuringEndEnableMiuiIslandLabelImage =
                settingsJson.optBoolean(
                    "liveDuringEndEnableMiuiIslandLabelImage",
                    settingsJson.optBoolean("liveEnableMiuiIslandLabelImage", false),
                ),
            liveMiuiIslandLabelStyle =
                settingsJson.optString("liveMiuiIslandLabelStyle", "text_only"),
            liveMiuiIslandLabelContent =
                settingsJson.optString("liveMiuiIslandLabelContent", "course_name"),
            liveMiuiIslandLabelFontColor =
                settingsJson.optString("liveMiuiIslandLabelFontColor", "#FFFFFF"),
            liveMiuiIslandLabelFontWeight =
                settingsJson.optString("liveMiuiIslandLabelFontWeight", "bold"),
            liveMiuiIslandLabelRenderQuality =
                settingsJson.optString("liveMiuiIslandLabelRenderQuality", "standard"),
            liveMiuiIslandLabelFontSize =
                settingsJson.optDouble("liveMiuiIslandLabelFontSize", 14.0).toFloat(),
            liveMiuiIslandLabelOffsetX =
                settingsJson.optDouble("liveMiuiIslandLabelOffsetX", 0.0).toFloat(),
            liveMiuiIslandLabelOffsetY =
                settingsJson.optDouble("liveMiuiIslandLabelOffsetY", 0.0).toFloat(),
            liveMiuiIslandLabelLogoPath =
                settingsJson.optString("liveMiuiIslandLabelLogoPath").takeIf { it.isNotBlank() },
            liveMiuiIslandLabelLogoCornerRadius =
                settingsJson.optDouble("liveMiuiIslandLabelLogoCornerRadius", 8.0).toFloat(),
            liveMiuiIslandExpandedIconMode =
                settingsJson.optString("liveMiuiIslandExpandedIconMode", "app_icon"),
            liveMiuiIslandExpandedIconPath =
                settingsJson.optString("liveMiuiIslandExpandedIconPath").takeIf { it.isNotBlank() },
            liveDuringEndMiuiIslandLabelStyle =
                settingsJson.optString(
                    "liveDuringEndMiuiIslandLabelStyle",
                    settingsJson.optString("liveMiuiIslandLabelStyle", "text_only"),
                ),
            liveDuringEndMiuiIslandLabelContent =
                settingsJson.optString(
                    "liveDuringEndMiuiIslandLabelContent",
                    settingsJson.optString("liveMiuiIslandLabelContent", "course_name"),
                ),
            liveDuringEndMiuiIslandLabelFontColor =
                settingsJson.optString(
                    "liveDuringEndMiuiIslandLabelFontColor",
                    settingsJson.optString("liveMiuiIslandLabelFontColor", "#FFFFFF"),
                ),
            liveDuringEndMiuiIslandLabelFontWeight =
                settingsJson.optString(
                    "liveDuringEndMiuiIslandLabelFontWeight",
                    settingsJson.optString("liveMiuiIslandLabelFontWeight", "bold"),
                ),
            liveDuringEndMiuiIslandLabelRenderQuality =
                settingsJson.optString(
                    "liveDuringEndMiuiIslandLabelRenderQuality",
                    settingsJson.optString("liveMiuiIslandLabelRenderQuality", "standard"),
                ),
            liveDuringEndMiuiIslandLabelFontSize =
                settingsJson.optDouble(
                    "liveDuringEndMiuiIslandLabelFontSize",
                    settingsJson.optDouble("liveMiuiIslandLabelFontSize", 14.0),
                ).toFloat(),
            liveDuringEndMiuiIslandLabelOffsetX =
                settingsJson.optDouble(
                    "liveDuringEndMiuiIslandLabelOffsetX",
                    settingsJson.optDouble("liveMiuiIslandLabelOffsetX", 0.0),
                ).toFloat(),
            liveDuringEndMiuiIslandLabelOffsetY =
                settingsJson.optDouble(
                    "liveDuringEndMiuiIslandLabelOffsetY",
                    settingsJson.optDouble("liveMiuiIslandLabelOffsetY", 0.0),
                ).toFloat(),
            liveDuringEndMiuiIslandLabelLogoPath =
                settingsJson.optString("liveDuringEndMiuiIslandLabelLogoPath")
                    .takeIf { it.isNotBlank() }
                    ?: settingsJson.optString("liveMiuiIslandLabelLogoPath")
                        .takeIf { it.isNotBlank() },
            liveDuringEndMiuiIslandLabelLogoCornerRadius =
                settingsJson.optDouble(
                    "liveDuringEndMiuiIslandLabelLogoCornerRadius",
                    settingsJson.optDouble("liveMiuiIslandLabelLogoCornerRadius", 8.0),
                ).toFloat(),
            liveDuringEndMiuiIslandExpandedIconMode =
                settingsJson.optString(
                    "liveDuringEndMiuiIslandExpandedIconMode",
                    settingsJson.optString("liveMiuiIslandExpandedIconMode", "app_icon"),
                ),
            liveDuringEndMiuiIslandExpandedIconPath =
                settingsJson.optString("liveDuringEndMiuiIslandExpandedIconPath")
                    .takeIf { it.isNotBlank() }
                    ?: settingsJson.optString("liveMiuiIslandExpandedIconPath")
                        .takeIf { it.isNotBlank() },
            liveShowBeforeClassMinutes = settingsJson.optInt("liveShowBeforeClassMinutes", 20),
            liveClassReminderStartMinutes =
                settingsJson.optInt("liveClassReminderStartMinutes", 0),
            liveEndSecondsCountdownThreshold =
                settingsJson.optInt("liveEndSecondsCountdownThreshold", 60),
            liveTimeCorrectionSeconds =
                settingsJson.optInt("liveTimeCorrectionSeconds", 0),
            liveBeforeClassQuickAction =
                settingsJson.optString("liveBeforeClassQuickAction", "none"),
            liveBeforeClassQuickActionAutoMinutes =
                settingsJson.optInt("liveBeforeClassQuickActionAutoMinutes", 0),
        )

        val coursesJson = json.optJSONArray("courses") ?: JSONArray()
        val courses = mutableListOf<NativeCourse>()
        for (index in 0 until coursesJson.length()) {
            val courseJson = coursesJson.optJSONObject(index) ?: continue
            courses += NativeCourse(
                id = normalizeText(courseJson.opt("id")?.toString()),
                name = normalizeText(courseJson.opt("name")?.toString()),
                shortName = normalizeNullableText(courseJson.opt("shortName")?.toString()),
                teacher = normalizeText(courseJson.opt("teacher")?.toString()),
                location = normalizeText(courseJson.opt("location")?.toString()),
                dayOfWeek = courseJson.optInt("dayOfWeek", 1),
                startSection = courseJson.optInt("startSection", 1),
                endSection = courseJson.optInt("endSection", 1),
                startTime = normalizeText(courseJson.opt("startTime")?.toString()),
                endTime = normalizeText(courseJson.opt("endTime")?.toString()),
                startWeek = courseJson.optInt("startWeek", 1),
                endWeek = courseJson.optInt("endWeek", 16),
                isOddWeek = courseJson.optBoolean("isOddWeek", false),
                isEvenWeek = courseJson.optBoolean("isEvenWeek", false),
                customWeeks = parseIntList(courseJson.opt("customWeeks")),
                suspendedWeeks = parseIntList(courseJson.opt("suspendedWeeks")),
                note = normalizeNullableText(courseJson.opt("note")?.toString()),
            )
        }

        val holidayDatesArray = json.optJSONArray("holidayDates")
        val holidayDates = mutableSetOf<String>()
        if (holidayDatesArray != null) {
            for (i in 0 until holidayDatesArray.length()) {
                val dateStr = holidayDatesArray.optString(i)
                if (dateStr.isNotBlank()) holidayDates.add(dateStr)
            }
        }
        val adjustedWorkdayDatesArray = json.optJSONArray("adjustedWorkdayDates")
        val adjustedWorkdayDates = mutableSetOf<String>()
        if (adjustedWorkdayDatesArray != null) {
            for (i in 0 until adjustedWorkdayDatesArray.length()) {
                val dateStr = adjustedWorkdayDatesArray.optString(i)
                if (dateStr.isNotBlank()) adjustedWorkdayDates.add(dateStr)
            }
        }

        return NativeScheduleSnapshot(
            currentWeek = json.optInt("currentWeek", 1),
            semesterStartMillis = json.optLong("semesterStartMillis").takeIf { it > 0L },
            endReminderLeadMillis = json.optLong("endReminderLeadMillis", 600_000L),
            isHoliday = json.optBoolean("isHoliday", false),
            isHolidayDate = json.optString("isHolidayDate").takeIf { it.isNotBlank() },
            holidayDates = holidayDates,
            adjustedWorkdayDates = adjustedWorkdayDates,
            holidayOverrideEnabled = json.optBoolean("holidayOverrideEnabled", false),
            enableHolidayMarking = json.optBoolean("enableHolidayMarking", true),
            courses = courses,
            settings = settings,
        )
    }

    private fun buildServiceIntent(context: Context, payload: LiveUpdatePayload): Intent {
        return Intent(context, LiveUpdateService::class.java).apply {
            putExtra("courseName", payload.currentCourse.name)
            putExtra("shortName", payload.currentCourse.shortName ?: "")
            putExtra("location", payload.currentCourse.location)
            putExtra("teacher", payload.currentCourse.teacher)
            putExtra("note", payload.currentCourse.note ?: "")
            putExtra("startTime", payload.currentCourse.startTime)
            putExtra("endTime", payload.currentCourse.endTime)
            putExtra("nextName", payload.nextCourse?.name ?: "")
            putExtra("autoDismissAfterStartMinutes", 0)
            putExtra("stage", payload.stage)
            putExtra("beforeClassLeadMillis", payload.beforeClassLeadMillis)
            putExtra("startAtMillis", payload.startAtMillis)
            putExtra("endAtMillis", payload.endAtMillis)
            putExtra("endReminderLeadMillis", payload.endReminderLeadMillis)
            putExtra("liveClassReminderStartMinutes", payload.liveClassReminderStartMinutes)
            putExtra(
                "endSecondsCountdownThreshold",
                payload.endSecondsCountdownThreshold
            )
            putExtra("enableBeforeClass", payload.enableBeforeClass)
            putExtra("enableDuringClass", payload.enableDuringClass)
            putExtra("enableBeforeEnd", payload.enableBeforeEnd)
            putExtra("promoteDuringClass", payload.promoteDuringClass)
            putExtra(
                "showNotificationDuringClass",
                payload.showNotificationDuringClass
            )
            putExtra("showCountdown", payload.showCountdown)
            putExtra("countdownTextStyle", payload.countdownTextStyle)
            putExtra("showStageText", payload.showStageText)
            putExtra("progressBreakOffsetsMillis", payload.progressBreakOffsetsMillis)
            putStringArrayListExtra(
                "progressMilestoneLabels",
                ArrayList(payload.progressMilestoneLabels)
            )
            putStringArrayListExtra(
                "progressMilestoneTimeTexts",
                ArrayList(payload.progressMilestoneTimeTexts)
            )
            putExtra("showCourseNameInIsland", payload.showCourseNameInIsland)
            putExtra("showLocationInIsland", payload.showLocationInIsland)
            putExtra("useShortNameInIsland", payload.useShortNameInIsland)
            putExtra("hidePrefixText", payload.hidePrefixText)
            putExtra("duringClassTimeDisplayMode", payload.duringClassTimeDisplayMode)
            putExtra("enableMiuiIslandLabelImage", payload.enableMiuiIslandLabelImage)
            putExtra("miuiIslandLabelStyle", payload.miuiIslandLabelStyle)
            putExtra("miuiIslandLabelContent", payload.miuiIslandLabelContent)
            putExtra("miuiIslandLabelFontColor", payload.miuiIslandLabelFontColor)
            putExtra("miuiIslandLabelFontWeight", payload.miuiIslandLabelFontWeight)
            putExtra("miuiIslandLabelRenderQuality", payload.miuiIslandLabelRenderQuality)
            putExtra("miuiIslandLabelFontSize", payload.miuiIslandLabelFontSize)
            putExtra("miuiIslandLabelOffsetX", payload.miuiIslandLabelOffsetX)
            putExtra("miuiIslandLabelOffsetY", payload.miuiIslandLabelOffsetY)
            putExtra("miuiIslandLabelLogoPath", payload.miuiIslandLabelLogoPath)
            putExtra(
                "miuiIslandLabelLogoCornerRadius",
                payload.miuiIslandLabelLogoCornerRadius,
            )
            putExtra("miuiIslandExpandedIconMode", payload.miuiIslandExpandedIconMode)
            putExtra("miuiIslandExpandedIconPath", payload.miuiIslandExpandedIconPath)
            putExtra("beforeClassQuickAction", payload.beforeClassQuickAction)
            putExtra(
                "quickActionAutoLeadMillis",
                payload.beforeClassQuickActionAutoLeadMillis
            )
            putExtra("validateAgainstSchedule", payload.validateAgainstSchedule)
        }
    }

    private fun mapToNativeCourse(data: Map<String, Any>): NativeCourse {
        return NativeCourse(
            id = normalizeText(data["id"] as? String),
            name = normalizeText(data["name"] as? String),
            shortName = normalizeNullableText(data["shortName"] as? String),
            teacher = normalizeText(data["teacher"] as? String),
            location = normalizeText(data["location"] as? String),
            dayOfWeek = (data["dayOfWeek"] as? Number)?.toInt() ?: 1,
            startSection = (data["startSection"] as? Number)?.toInt() ?: 1,
            endSection = (data["endSection"] as? Number)?.toInt() ?: 1,
            startTime = normalizeText(data["startTime"] as? String),
            endTime = normalizeText(data["endTime"] as? String),
            startWeek = (data["startWeek"] as? Number)?.toInt() ?: 1,
            endWeek = (data["endWeek"] as? Number)?.toInt() ?: 16,
            isOddWeek = data["isOddWeek"] as? Boolean ?: false,
            isEvenWeek = data["isEvenWeek"] as? Boolean ?: false,
            customWeeks = parseIntList(data["customWeeks"]),
            suspendedWeeks = parseIntList(data["suspendedWeeks"]),
            note = normalizeNullableText(data["note"] as? String),
        )
    }

    private fun hasActiveLiveSelection(
        snapshot: NativeScheduleSnapshot,
        context: Context,
        nowMillis: Long,
    ): Boolean {
        if (snapshot.semesterStartMillis == null) {
            return false
        }
        val nowCalendar = Calendar.getInstance().apply { timeInMillis = nowMillis }
        if (isLegacyHolidayFlagActive(snapshot, nowCalendar) ||
            isDateHoliday(snapshot, nowCalendar)
        ) {
            return false
        }
        return findActiveSelection(context, snapshot, nowMillis) != null
    }

    private fun isLegacyHolidayFlagActive(
        snapshot: NativeScheduleSnapshot,
        dateCalendar: Calendar,
    ): Boolean {
        return liveSchedulerIsLegacyHolidayFlagActive(
            isHoliday = snapshot.isHoliday,
            isHolidayDate = snapshot.isHolidayDate,
            year = dateCalendar.get(Calendar.YEAR),
            month = dateCalendar.get(Calendar.MONTH) + 1,
            dayOfMonth = dateCalendar.get(Calendar.DAY_OF_MONTH),
        )
    }

    private fun findActiveSelection(
        context: Context,
        snapshot: NativeScheduleSnapshot,
        nowMillis: Long,
    ): ScheduledSelection? {
        val nowCalendar = Calendar.getInstance().apply { timeInMillis = nowMillis }
        // Skip if today is a holiday
        if (isDateHoliday(snapshot, nowCalendar)) {
            return null
        }
        val targetWeek = calculateCalendarWeekForDate(snapshot, nowCalendar)
        val todayCourses = snapshot.courses
            .filter { it.dayOfWeek == nowCalendar.get(Calendar.DAY_OF_WEEK).toWeekday() && it.isInWeek(targetWeek) }
            .sortedBy { it.startSection }
        if (todayCourses.isEmpty()) {
            return null
        }

        for ((index, course) in todayCourses.withIndex()) {
            val startAtMillis =
                buildCorrectedCourseDateTimeMillis(
                    nowCalendar,
                    course.startTime,
                    snapshot.settings,
                ) ?: continue
            val endAtMillis =
                buildCorrectedCourseDateTimeMillis(
                    nowCalendar,
                    course.endTime,
                    snapshot.settings,
                ) ?: continue
            val blockedUntilMillis =
                resolveBeforeClassBlockedUntil(
                    todayCourses,
                    index,
                    nowCalendar,
                    snapshot.settings,
                )
            val stage =
                resolveStage(
                    snapshot,
                    nowMillis,
                    startAtMillis,
                    endAtMillis,
                    blockedUntilMillis,
                ) ?: continue
            val progressMilestones =
                buildProgressMilestones(context, snapshot.settings.sections, course, startAtMillis, endAtMillis)
            return ScheduledSelection(
                currentCourse = course,
                nextCourse = todayCourses.getOrNull(index + 1),
                stage = stage,
                triggerAtMillis = startAtMillis,
                startAtMillis = startAtMillis,
                endAtMillis = endAtMillis,
                progressBreakOffsetsMillis =
                    progressMilestones.map { it.first }.toLongArray(),
                progressMilestoneLabels = progressMilestones.map { it.second.first },
                progressMilestoneTimeTexts = progressMilestones.map { it.second.second },
            )
        }
        return null
    }

    private fun findNextSelection(
        context: Context,
        snapshot: NativeScheduleSnapshot,
        nowMillis: Long,
    ): ScheduledSelection? {
        val nowCalendar = Calendar.getInstance().apply { timeInMillis = nowMillis }
        val targetWeek = calculateCalendarWeekForDate(snapshot, nowCalendar)
        val todayStart = Calendar.getInstance().apply {
            timeInMillis = nowMillis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val maxWeek = (snapshot.courses.maxOfOrNull { it.endWeek } ?: targetWeek)
            .coerceAtMost(targetWeek + MAX_LOOKAHEAD_WEEKS)

        var bestSelection: ScheduledSelection? = null

        for (course in snapshot.courses) {
            for (week in targetWeek..maxWeek) {
                if (!course.isInWeek(week)) {
                    continue
                }
                val dayOffset =
                    ((week - targetWeek) * 7) + course.dayOfWeek - nowCalendar.get(Calendar.DAY_OF_WEEK).toWeekday()
                if (dayOffset < 0) {
                    continue
                }
                val candidateDate = Calendar.getInstance().apply {
                    timeInMillis = todayStart.timeInMillis
                    add(Calendar.DAY_OF_YEAR, dayOffset)
                }
                // Skip courses that fall on a holiday
                if (isDateHoliday(snapshot, candidateDate)) {
                    continue
                }
                val startAtMillis =
                    buildCorrectedCourseDateTimeMillis(
                        candidateDate,
                        course.startTime,
                        snapshot.settings,
                    ) ?: continue
                val endAtMillis =
                    buildCorrectedCourseDateTimeMillis(
                        candidateDate,
                        course.endTime,
                        snapshot.settings,
                    ) ?: continue
                val sameDayCourses = snapshot.courses
                    .filter { it.dayOfWeek == course.dayOfWeek && it.isInWeek(week) }
                    .sortedBy { it.startSection }
                val currentIndex = sameDayCourses.indexOfFirst { it.id == course.id }
                if (currentIndex == -1) {
                    continue
                }
                val blockedUntilMillis =
                    resolveBeforeClassBlockedUntil(
                        sameDayCourses,
                        currentIndex,
                        candidateDate,
                        snapshot.settings,
                    )
                val nextTrigger =
                    resolveNextTrigger(
                        snapshot,
                        startAtMillis,
                        endAtMillis,
                        nowMillis,
                        blockedUntilMillis,
                    ) ?: continue
                if (nextTrigger.triggerAtMillis <= nowMillis) {
                    continue
                }
                val progressMilestones =
                    buildProgressMilestones(context, snapshot.settings.sections, course, startAtMillis, endAtMillis)
                val selection = ScheduledSelection(
                    currentCourse = course,
                    nextCourse = sameDayCourses.getOrNull(currentIndex + 1),
                    stage = nextTrigger.stage,
                    triggerAtMillis = nextTrigger.triggerAtMillis,
                    startAtMillis = startAtMillis,
                    endAtMillis = endAtMillis,
                    progressBreakOffsetsMillis =
                        progressMilestones.map { it.first }.toLongArray(),
                    progressMilestoneLabels = progressMilestones.map { it.second.first },
                    progressMilestoneTimeTexts = progressMilestones.map { it.second.second },
                )
                if (bestSelection == null || selection.triggerAtMillis < bestSelection.triggerAtMillis) {
                    bestSelection = selection
                }
                break
            }
        }

        return bestSelection
    }

    private fun selectionToPayload(
        snapshot: NativeScheduleSnapshot,
        selection: ScheduledSelection,
    ): LiveUpdatePayload {
        val isBeforeClass = selection.stage == "beforeClass"
        val followBeforeClass =
            !isBeforeClass && snapshot.settings.liveDuringEndFollowBeforeClass
        val showCourseName = if (isBeforeClass) {
            snapshot.settings.liveShowCourseName
        } else if (followBeforeClass) {
            snapshot.settings.liveShowCourseName
        } else {
            snapshot.settings.liveDuringEndShowCourseName
        }
        val showLocation = if (isBeforeClass) {
            snapshot.settings.liveShowLocation
        } else if (followBeforeClass) {
            snapshot.settings.liveShowLocation
        } else {
            snapshot.settings.liveDuringEndShowLocation
        }
        val showCountdown = if (isBeforeClass) {
            snapshot.settings.liveShowCountdown
        } else if (followBeforeClass) {
            snapshot.settings.liveShowCountdown
        } else {
            snapshot.settings.liveDuringEndShowCountdown
        }
        val countdownTextStyle = if (isBeforeClass) {
            snapshot.settings.liveCountdownTextStyle
        } else if (followBeforeClass) {
            snapshot.settings.liveCountdownTextStyle
        } else {
            snapshot.settings.liveDuringEndCountdownTextStyle
        }
        val showStageText = if (isBeforeClass) {
            snapshot.settings.liveShowStageText
        } else if (followBeforeClass) {
            snapshot.settings.liveShowStageText
        } else {
            snapshot.settings.liveDuringEndShowStageText
        }
        val useShortName = if (isBeforeClass) {
            snapshot.settings.liveUseShortName
        } else if (followBeforeClass) {
            snapshot.settings.liveUseShortName
        } else {
            snapshot.settings.liveDuringEndUseShortName
        }
        val hidePrefixText = if (isBeforeClass) {
            snapshot.settings.liveHidePrefixText
        } else if (followBeforeClass) {
            snapshot.settings.liveHidePrefixText
        } else {
            snapshot.settings.liveDuringEndHidePrefixText
        }
        val duringClassTimeDisplayMode = if (isBeforeClass) {
            snapshot.settings.liveDuringClassTimeDisplayMode
        } else if (followBeforeClass) {
            snapshot.settings.liveDuringClassTimeDisplayMode
        } else {
            snapshot.settings.liveDuringEndTimeDisplayMode
        }
        val enableMiuiIslandLabelImage = if (isBeforeClass) {
            snapshot.settings.liveEnableMiuiIslandLabelImage
        } else if (followBeforeClass) {
            snapshot.settings.liveEnableMiuiIslandLabelImage
        } else {
            snapshot.settings.liveDuringEndEnableMiuiIslandLabelImage
        }
        val miuiIslandLabelStyle = if (isBeforeClass) {
            snapshot.settings.liveMiuiIslandLabelStyle
        } else if (followBeforeClass) {
            snapshot.settings.liveMiuiIslandLabelStyle
        } else {
            snapshot.settings.liveDuringEndMiuiIslandLabelStyle
        }
        val miuiIslandLabelContent = if (isBeforeClass) {
            snapshot.settings.liveMiuiIslandLabelContent
        } else if (followBeforeClass) {
            snapshot.settings.liveMiuiIslandLabelContent
        } else {
            snapshot.settings.liveDuringEndMiuiIslandLabelContent
        }
        val miuiIslandLabelFontColor = if (isBeforeClass) {
            snapshot.settings.liveMiuiIslandLabelFontColor
        } else if (followBeforeClass) {
            snapshot.settings.liveMiuiIslandLabelFontColor
        } else {
            snapshot.settings.liveDuringEndMiuiIslandLabelFontColor
        }
        val miuiIslandLabelFontWeight = if (isBeforeClass) {
            snapshot.settings.liveMiuiIslandLabelFontWeight
        } else if (followBeforeClass) {
            snapshot.settings.liveMiuiIslandLabelFontWeight
        } else {
            snapshot.settings.liveDuringEndMiuiIslandLabelFontWeight
        }
        val miuiIslandLabelRenderQuality = if (isBeforeClass) {
            snapshot.settings.liveMiuiIslandLabelRenderQuality
        } else if (followBeforeClass) {
            snapshot.settings.liveMiuiIslandLabelRenderQuality
        } else {
            snapshot.settings.liveDuringEndMiuiIslandLabelRenderQuality
        }
        val miuiIslandLabelFontSize = if (isBeforeClass) {
            snapshot.settings.liveMiuiIslandLabelFontSize.toFloat()
        } else if (followBeforeClass) {
            snapshot.settings.liveMiuiIslandLabelFontSize.toFloat()
        } else {
            snapshot.settings.liveDuringEndMiuiIslandLabelFontSize
        }
        val miuiIslandLabelOffsetX = if (isBeforeClass) {
            snapshot.settings.liveMiuiIslandLabelOffsetX
        } else if (followBeforeClass) {
            snapshot.settings.liveMiuiIslandLabelOffsetX
        } else {
            snapshot.settings.liveDuringEndMiuiIslandLabelOffsetX
        }
        val miuiIslandLabelOffsetY = if (isBeforeClass) {
            snapshot.settings.liveMiuiIslandLabelOffsetY
        } else if (followBeforeClass) {
            snapshot.settings.liveMiuiIslandLabelOffsetY
        } else {
            snapshot.settings.liveDuringEndMiuiIslandLabelOffsetY
        }
        val miuiIslandLabelLogoPath = if (isBeforeClass) {
            snapshot.settings.liveMiuiIslandLabelLogoPath
        } else if (followBeforeClass) {
            snapshot.settings.liveMiuiIslandLabelLogoPath
        } else {
            snapshot.settings.liveDuringEndMiuiIslandLabelLogoPath
        }
        val miuiIslandLabelLogoCornerRadius = if (isBeforeClass) {
            snapshot.settings.liveMiuiIslandLabelLogoCornerRadius
        } else if (followBeforeClass) {
            snapshot.settings.liveMiuiIslandLabelLogoCornerRadius
        } else {
            snapshot.settings.liveDuringEndMiuiIslandLabelLogoCornerRadius
        }
        val miuiIslandExpandedIconMode = if (isBeforeClass) {
            snapshot.settings.liveMiuiIslandExpandedIconMode
        } else if (followBeforeClass) {
            snapshot.settings.liveMiuiIslandExpandedIconMode
        } else {
            snapshot.settings.liveDuringEndMiuiIslandExpandedIconMode
        }
        val miuiIslandExpandedIconPath = if (isBeforeClass) {
            snapshot.settings.liveMiuiIslandExpandedIconPath
        } else if (followBeforeClass) {
            snapshot.settings.liveMiuiIslandExpandedIconPath
        } else {
            snapshot.settings.liveDuringEndMiuiIslandExpandedIconPath
        }

        return LiveUpdatePayload(
            currentCourse = selection.currentCourse,
            nextCourse = selection.nextCourse,
            stage = selection.stage,
            startAtMillis = selection.startAtMillis,
            endAtMillis = selection.endAtMillis,
            beforeClassLeadMillis =
                snapshot.settings.liveShowBeforeClassMinutes * 60_000L,
            endReminderLeadMillis = snapshot.endReminderLeadMillis,
            liveClassReminderStartMinutes =
                snapshot.settings.liveClassReminderStartMinutes,
            endSecondsCountdownThreshold =
                snapshot.settings.liveEndSecondsCountdownThreshold,
            enableBeforeClass = snapshot.settings.liveEnableBeforeClass,
            enableDuringClass = snapshot.settings.liveEnableDuringClass,
            enableBeforeEnd = snapshot.settings.liveEnableBeforeEnd,
            promoteDuringClass =
                if (selection.stage == "duringClassStatusBar") {
                    false
                } else {
                    snapshot.settings.livePromoteDuringClass
                },
            showNotificationDuringClass =
                if (selection.stage == "duringClassStatusBar") {
                    true
                } else {
                    snapshot.settings.liveShowDuringClassNotification
                },
            showCountdown = showCountdown,
            countdownTextStyle = countdownTextStyle,
            showStageText = showStageText,
            showCourseNameInIsland = showCourseName,
            showLocationInIsland = showLocation,
            useShortNameInIsland = useShortName,
            hidePrefixText = hidePrefixText,
            duringClassTimeDisplayMode = duringClassTimeDisplayMode,
            enableMiuiIslandLabelImage = enableMiuiIslandLabelImage,
            miuiIslandLabelStyle = miuiIslandLabelStyle,
            miuiIslandLabelContent = miuiIslandLabelContent,
            miuiIslandLabelFontColor = miuiIslandLabelFontColor,
            miuiIslandLabelFontWeight = miuiIslandLabelFontWeight,
            miuiIslandLabelRenderQuality = miuiIslandLabelRenderQuality,
            miuiIslandLabelFontSize = miuiIslandLabelFontSize,
            miuiIslandLabelOffsetX = miuiIslandLabelOffsetX,
            miuiIslandLabelOffsetY = miuiIslandLabelOffsetY,
            miuiIslandLabelLogoPath = miuiIslandLabelLogoPath,
            miuiIslandLabelLogoCornerRadius = miuiIslandLabelLogoCornerRadius,
            miuiIslandExpandedIconMode = miuiIslandExpandedIconMode,
            miuiIslandExpandedIconPath = miuiIslandExpandedIconPath,
            beforeClassQuickAction = snapshot.settings.liveBeforeClassQuickAction,
            beforeClassQuickActionAutoLeadMillis =
                snapshot.settings.liveBeforeClassQuickActionAutoMinutes * 60_000L,
            progressBreakOffsetsMillis = selection.progressBreakOffsetsMillis,
            progressMilestoneLabels = selection.progressMilestoneLabels,
            progressMilestoneTimeTexts = selection.progressMilestoneTimeTexts,
            validateAgainstSchedule = true,
        )
    }

    private fun resolveNextTrigger(
        snapshot: NativeScheduleSnapshot,
        startAtMillis: Long,
        endAtMillis: Long,
        nowMillis: Long,
        blockedUntilMillis: Long?,
    ): FutureStageTrigger? {
        val settings = snapshot.settings
        val beforeClassLeadMillis = settings.liveShowBeforeClassMinutes * 60_000L
        val aheadTime = maxOf(
            startAtMillis - beforeClassLeadMillis,
            blockedUntilMillis ?: Long.MIN_VALUE,
        )
        val reminderStartMillis = if (settings.liveClassReminderStartMinutes == 0) {
            startAtMillis
        } else {
            maxOf(startAtMillis, endAtMillis - settings.liveClassReminderStartMinutes * 60_000L)
        }
        val endReminderStart = maxOf(startAtMillis, endAtMillis - snapshot.endReminderLeadMillis)
        val candidates = mutableListOf<FutureStageTrigger>()
        if (settings.liveEnableBeforeClass && aheadTime > nowMillis && aheadTime < startAtMillis) {
            candidates += FutureStageTrigger("beforeClass", aheadTime)
        }
        // Auto quick action: wake once before the before-class window so the
        // selected mode (silent/DND) is applied without any user interaction.
        liveSchedulerQuickActionTriggerAt(
            autoMinutes = settings.liveBeforeClassQuickActionAutoMinutes,
            action = settings.liveBeforeClassQuickAction,
            startAtMillis = startAtMillis,
            blockedUntilMillis = blockedUntilMillis,
            nowMillis = nowMillis,
        )?.let { candidates += FutureStageTrigger("quickAction", it) }
        if (settings.liveClassReminderStartMinutes == 0 &&
            canDisplayDuring(settings) &&
            startAtMillis > nowMillis
        ) {
            candidates += FutureStageTrigger("duringClass", startAtMillis)
        }
        if (settings.liveClassReminderStartMinutes > 0) {
            if (settings.liveEnableDuringClass &&
                settings.liveShowDuringClassNotification &&
                startAtMillis > nowMillis
            ) {
                candidates += FutureStageTrigger("duringClassStatusBar", startAtMillis)
            }
            if (settings.liveEnableBeforeEnd && reminderStartMillis > nowMillis) {
                candidates += FutureStageTrigger("beforeEnd", reminderStartMillis)
            } else if (canDisplayDuring(settings) && reminderStartMillis > nowMillis) {
                candidates += FutureStageTrigger("duringClass", reminderStartMillis)
            }
        } else if (settings.liveEnableBeforeEnd && endReminderStart > nowMillis) {
            candidates += FutureStageTrigger("beforeEnd", endReminderStart)
        }
        return candidates.minByOrNull { it.triggerAtMillis }
    }

    private fun resolveStage(
        snapshot: NativeScheduleSnapshot,
        nowMillis: Long,
        startAtMillis: Long,
        endAtMillis: Long,
        blockedUntilMillis: Long?,
    ): String? {
        val settings = snapshot.settings
        return liveSchedulerResolveStage(
            nowMillis = nowMillis,
            startAtMillis = startAtMillis,
            endAtMillis = endAtMillis,
            blockedUntilMillis = blockedUntilMillis,
            liveShowBeforeClassMinutes = settings.liveShowBeforeClassMinutes,
            liveClassReminderStartMinutes = settings.liveClassReminderStartMinutes,
            endReminderLeadMillis = snapshot.endReminderLeadMillis,
            liveEnableBeforeClass = settings.liveEnableBeforeClass,
            liveEnableDuringClass = settings.liveEnableDuringClass,
            liveEnableBeforeEnd = settings.liveEnableBeforeEnd,
            livePromoteDuringClass = settings.livePromoteDuringClass,
            liveShowDuringClassNotification = settings.liveShowDuringClassNotification,
        )
    }

    private fun resolveBeforeClassBlockedUntil(
        sameDayCourses: List<NativeCourse>,
        courseIndex: Int,
        dateCalendar: Calendar,
        settings: NativeLiveSettings,
    ): Long? {
        if (courseIndex <= 0 || courseIndex >= sameDayCourses.size) {
            return null
        }

        val course = sameDayCourses[courseIndex]
        val courseStartAtMillis =
            buildCorrectedCourseDateTimeMillis(
                dateCalendar,
                course.startTime,
                settings,
            ) ?: return null

        var blockedUntilMillis: Long? = null
        for (index in 0 until courseIndex) {
            val previousCourse = sameDayCourses[index]
            val previousStartAtMillis =
                buildCorrectedCourseDateTimeMillis(
                    dateCalendar,
                    previousCourse.startTime,
                    settings,
                ) ?: continue
            val previousEndAtMillis =
                buildCorrectedCourseDateTimeMillis(
                    dateCalendar,
                    previousCourse.endTime,
                    settings,
                ) ?: continue
            if (previousStartAtMillis > courseStartAtMillis) {
                continue
            }
            blockedUntilMillis = maxOf(
                blockedUntilMillis ?: Long.MIN_VALUE,
                previousEndAtMillis,
            )
        }

        return blockedUntilMillis
    }

    private fun buildCorrectedCourseDateTimeMillis(
        dateCalendar: Calendar,
        courseTime: String,
        settings: NativeLiveSettings,
    ): Long? {
        val baseMillis = buildCourseDateTimeMillis(dateCalendar, courseTime) ?: return null
        return baseMillis + settings.liveTimeCorrectionSeconds * 1000L
    }

    private fun canDisplayDuring(settings: NativeLiveSettings): Boolean {
        return liveSchedulerCanDisplayDuring(
            liveEnableDuringClass = settings.liveEnableDuringClass,
            livePromoteDuringClass = settings.livePromoteDuringClass,
            liveShowDuringClassNotification = settings.liveShowDuringClassNotification,
        )
    }

    private fun calculateWeekForDate(
        snapshot: NativeScheduleSnapshot,
        dateCalendar: Calendar,
    ): Int {
        return liveSchedulerCalculateWeekForDate(
            semesterStartMillis = snapshot.semesterStartMillis,
            currentWeek = snapshot.currentWeek,
            dateMillis = dateCalendar.timeInMillis,
            semesterWeekCount = snapshot.settings.semesterWeekCount,
        )
    }

    private fun calculateCalendarWeekForDate(
        snapshot: NativeScheduleSnapshot,
        dateCalendar: Calendar,
    ): Int {
        return liveSchedulerCalculateCalendarWeekForDate(
            semesterStartMillis = snapshot.semesterStartMillis,
            currentWeek = snapshot.currentWeek,
            dateMillis = dateCalendar.timeInMillis,
        )
    }

    /** Check whether a specific date should be treated as a holiday
     *  (courses should be hidden) based on the snapshot's holiday data. */
    private fun isDateHoliday(
        snapshot: NativeScheduleSnapshot,
        dateCalendar: Calendar,
    ): Boolean {
        return liveSchedulerIsDateHoliday(
            holidayDates = snapshot.holidayDates,
            holidayOverrideEnabled = snapshot.holidayOverrideEnabled,
            enableHolidayMarking = snapshot.enableHolidayMarking,
            year = dateCalendar.get(Calendar.YEAR),
            month = dateCalendar.get(Calendar.MONTH) + 1,
            dayOfMonth = dateCalendar.get(Calendar.DAY_OF_MONTH),
            adjustedWorkdayDates = snapshot.adjustedWorkdayDates,
        )
    }

    private fun buildCourseDateTimeMillis(
        dateCalendar: Calendar,
        courseTime: String,
    ): Long? {
        val parts = courseTime.split(":")
        if (parts.size != 2) {
            return null
        }
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        return Calendar.getInstance().apply {
            timeInMillis = dateCalendar.timeInMillis
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    private fun buildProgressMilestones(
        context: Context,
        sections: List<NativeSectionTime>,
        course: NativeCourse,
        startAtMillis: Long,
        endAtMillis: Long,
    ): List<Pair<Long, Pair<String, String>>> {
        if (course.endSection - course.startSection + 1 < 2) {
            return emptyList()
        }
        val firstSectionIndex = course.startSection - 1
        val lastSectionIndex = course.endSection - 1
        if (firstSectionIndex < 0 || lastSectionIndex >= sections.size) {
            return emptyList()
        }
        val sectionStartMinutes = parseClockMinutes(sections[firstSectionIndex].startTime) ?: return emptyList()
        val sectionEndMinutes = parseClockMinutes(sections[lastSectionIndex].endTime) ?: return emptyList()
        if (sectionEndMinutes <= sectionStartMinutes) {
            return emptyList()
        }
        val referenceTotalMinutes = sectionEndMinutes - sectionStartMinutes
        val totalDurationMillis = endAtMillis - startAtMillis
        if (totalDurationMillis <= 0L) {
            return emptyList()
        }

        val milestones = mutableListOf<Pair<Long, Pair<String, String>>>()
        for (sectionIndex in firstSectionIndex until lastSectionIndex) {
            val currentSection = sections[sectionIndex]
            val nextSection = sections[sectionIndex + 1]
            val currentEndMinutes = parseClockMinutes(currentSection.endTime) ?: continue
            val nextStartMinutes = parseClockMinutes(nextSection.startTime) ?: continue
            if (nextStartMinutes <= currentEndMinutes) {
                continue
            }
            val breakStartOffsetMillis =
                ((((currentEndMinutes - sectionStartMinutes).toDouble() / referenceTotalMinutes) *
                    totalDurationMillis).toLong()).coerceIn(1L, totalDurationMillis - 1L)
            val breakEndOffsetMillis =
                ((((nextStartMinutes - sectionStartMinutes).toDouble() / referenceTotalMinutes) *
                    totalDurationMillis).toLong()).coerceIn(1L, totalDurationMillis - 1L)
            milestones += breakStartOffsetMillis to (
                context.getString(R.string.milestone_recent_end) to currentSection.endTime
            )
            milestones += breakEndOffsetMillis to (
                context.getString(R.string.milestone_next_start) to nextSection.startTime
            )
        }
        return milestones.sortedBy { it.first }
    }

    private fun parseClockMinutes(value: String): Int? {
        val parts = value.split(":")
        if (parts.size != 2) {
            return null
        }
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        return hour * 60 + minute
    }

    private fun scheduleAlarm(context: Context, triggerAtMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pendingIntent = buildTriggerPendingIntent(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarmManager.canScheduleExactAlarms()) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
        } else {
            alarmManager.set(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
        }
    }

    private fun cancelScheduledAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        alarmManager.cancel(buildTriggerPendingIntent(context))
    }

    private fun buildTriggerPendingIntent(context: Context): PendingIntent {
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE_TRIGGER,
            Intent(context, LiveUpdateReceiver::class.java).apply {
                action = ACTION_TRIGGER
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun startForegroundService(context: Context, payload: LiveUpdatePayload): Boolean {
        return try {
            UmengDiagnosticReporter.record(
                context = context.applicationContext,
                category = "live_update_payload_selected",
                message = DiagnosticLogMessages.LIVE_UPDATE_PAYLOAD_SELECTED,
                extras = mapOf(
                    "stage" to payload.stage,
                    "courseName" to payload.currentCourse.name,
                    "showCourseNameInIsland" to payload.showCourseNameInIsland,
                    "showLocationInIsland" to payload.showLocationInIsland,
                    "showCountdown" to payload.showCountdown,
                    "showStageText" to payload.showStageText,
                    "promoteDuringClass" to payload.promoteDuringClass,
                    "showNotificationDuringClass" to payload.showNotificationDuringClass,
                    "enableMiuiIslandLabelImage" to payload.enableMiuiIslandLabelImage,
                    "miuiIslandLabelFontSize" to payload.miuiIslandLabelFontSize,
                    "miuiIslandLabelOffsetX" to payload.miuiIslandLabelOffsetX,
                    "miuiIslandLabelOffsetY" to payload.miuiIslandLabelOffsetY,
                    "miuiIslandExpandedIconMode" to payload.miuiIslandExpandedIconMode,
                )
            )
            ContextCompat.startForegroundService(context, buildServiceIntent(context, payload))
            true
        } catch (e: Exception) {
            Log.w(TAG, DiagnosticLogMessages.LOG_START_LIVE_UPDATE_SERVICE_FAILED, e)
            UmengDiagnosticReporter.report(
                context = context.applicationContext,
                category = "live_update_scheduler_start_failed",
                message = DiagnosticLogMessages.LIVE_UPDATE_SCHEDULER_START_FAILED,
                throwable = e,
                dedupeKey = "live_update_scheduler_start_failed",
                bypassThrottle = true,
                extras = mapOf(
                    "courseName" to payload.currentCourse.name,
                    "stage" to payload.stage,
                )
            )
            false
        }
    }
}

class LiveUpdateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED ->
                LiveUpdateScheduler.handleBootReschedule(context)
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED ->
                LiveUpdateScheduler.handleTimeReschedule(context)
            LiveUpdateScheduler.ACTION_TRIGGER -> LiveUpdateScheduler.handleAlarm(context)
        }
    }
}

private fun Int.toWeekday(): Int {
    return when (this) {
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
