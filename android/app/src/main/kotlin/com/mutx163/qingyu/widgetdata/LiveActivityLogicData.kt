package com.mutx163.qingyu.widgetdata

import com.mutx163.qingyu.core.Course
import kotlin.math.roundToLong
import java.time.LocalDateTime

/**
 * 超级岛阶段引擎（移植 lib/domain/live_activity_logic.dart:37-281，纯函数零 IO）。
 *
 * 阶段判定链（resolveLiveActivityStage）：
 * 1. 窗口外（早于 aheadTime / 不早于 endTime）→ null；
 * 2. 开课前 → beforeClass（开关关则 null）；
 * 3. reminderStart = end - liveClassReminderStartMinutes：早于它 →
 *    状态栏档（开关与通知都开才亮）否则 null；
 * 4. reminderStart 之后：startMinutes > 0 → beforeEnd 优先、duringClass 兜底；
 *    startMinutes == 0 → 课末 10 分钟窗口内 beforeEnd 优先、duringClass 兜底，
 *    其余 duringClass。
 */
object LiveActivityLogicData {

    /** `"HH:MM"` → 相对当天 00:00 的分钟数（live_activity_logic.dart:47-48）。 */
    fun parseClockMinutes(value: String): Int? = WidgetDataClock.clockTextToMinutes(value)

    /**
     * 按节次表解析课程的真实钟点（resolveRealTime，:58-73）：
     * 节次下标越界或表缺失时回落课程自带钟点。
     */
    fun resolveRealTimePure(course: Course, isStart: Boolean, sections: List<SectionTimeData>?): String {
        val sectionIndex = (if (isStart) course.startSection else course.endSection) - 1
        if (sections != null && sectionIndex >= 0 && sectionIndex < sections.size) {
            return if (isStart) sections[sectionIndex].startTime else sections[sectionIndex].endTime
        }
        return if (isStart) course.startTime else course.endTime
    }

    /** 阶段显示开关（canDisplayStage，:181-198）。 */
    fun canDisplayStage(stage: LiveActivityStage, settings: WidgetSettingsFace): Boolean = when (stage) {
        LiveActivityStage.BEFORE_CLASS -> settings.liveEnableBeforeClass
        LiveActivityStage.DURING_CLASS_STATUS_BAR ->
            settings.liveEnableDuringClass && settings.liveShowDuringClassNotification
        LiveActivityStage.DURING_CLASS ->
            settings.liveEnableDuringClass &&
                (settings.livePromoteDuringClass || settings.liveShowDuringClassNotification)
        LiveActivityStage.BEFORE_END -> settings.liveEnableBeforeEnd
    }

    /** 测试兜底阶段优先级（preferredTestStage，:200-211）。 */
    fun preferredTestStage(settings: WidgetSettingsFace): LiveActivityStage? {
        if (canDisplayStage(LiveActivityStage.BEFORE_CLASS, settings)) return LiveActivityStage.BEFORE_CLASS
        if (canDisplayStage(LiveActivityStage.DURING_CLASS, settings)) return LiveActivityStage.DURING_CLASS
        if (canDisplayStage(LiveActivityStage.BEFORE_END, settings)) return LiveActivityStage.BEFORE_END
        return null
    }

    /**
     * 阶段判定（resolveLiveActivityStage，:222-280）。
     * [currentTime]/[startTime]/[endTime]/[aheadTime] 全是同一本地日历上的墙上时刻。
     */
    fun resolveLiveActivityStage(
        currentTime: LocalDateTime,
        startTime: LocalDateTime,
        endTime: LocalDateTime,
        aheadTime: LocalDateTime,
        settings: WidgetSettingsFace,
        endReminderWindowMinutes: Long = LIVE_END_REMINDER_WINDOW_MINUTES,
    ): LiveActivityStage? {
        if (currentTime.isBefore(aheadTime) || !currentTime.isBefore(endTime)) {
            return null
        }
        if (currentTime.isBefore(startTime)) {
            return if (canDisplayStage(LiveActivityStage.BEFORE_CLASS, settings)) {
                LiveActivityStage.BEFORE_CLASS
            } else {
                null
            }
        }

        val startMinutes = settings.liveClassReminderStartMinutes
        val reminderStartTime = if (startMinutes == 0) {
            startTime
        } else {
            endTime.minusMinutes(startMinutes.toLong())
        }
        if (currentTime.isBefore(reminderStartTime)) {
            if (startMinutes > 0 && canDisplayStage(LiveActivityStage.DURING_CLASS_STATUS_BAR, settings)) {
                return LiveActivityStage.DURING_CLASS_STATUS_BAR
            }
            return null
        }

        if (startMinutes > 0) {
            if (canDisplayStage(LiveActivityStage.BEFORE_END, settings)) return LiveActivityStage.BEFORE_END
            return if (canDisplayStage(LiveActivityStage.DURING_CLASS, settings)) {
                LiveActivityStage.DURING_CLASS
            } else {
                null
            }
        }

        val endReminderStart = resolveEndReminderStart(startTime, endTime, endReminderWindowMinutes)
        if (!currentTime.isBefore(endReminderStart)) {
            if (canDisplayStage(LiveActivityStage.BEFORE_END, settings)) return LiveActivityStage.BEFORE_END
            if (canDisplayStage(LiveActivityStage.DURING_CLASS, settings)) return LiveActivityStage.DURING_CLASS
            return null
        }
        return if (canDisplayStage(LiveActivityStage.DURING_CLASS, settings)) {
            LiveActivityStage.DURING_CLASS
        } else {
            null
        }
    }

    /** 课末提醒窗口起点不早于开课时刻（resolveEndReminderStart，:213-220）。 */
    fun resolveEndReminderStart(
        startTime: LocalDateTime,
        endTime: LocalDateTime,
        endReminderWindowMinutes: Long,
    ): LocalDateTime {
        val start = endTime.minusMinutes(endReminderWindowMinutes)
        return if (start.isBefore(startTime)) startTime else start
    }

    /**
     * 课间休息里程碑（buildLiveProgressMilestones，:75-158）。
     *
     * 只有跨节课程（节数 ≥ 2）才有里程碑：把节次表里相邻节之间的休息按
     * 参考跨度（首节开始 → 末节结束的分钟数）线性映射到合成窗口
     * [startAtMillis, endAtMillis] 上，偏移量钳在开区间 (0, duration)。
     */
    fun buildLiveProgressMilestones(
        course: Course,
        sections: List<SectionTimeData>?,
        startAtMillis: Long?,
        endAtMillis: Long?,
    ): List<LiveProgressMilestone> {
        if (course.sectionCount < 2 || sections == null) return emptyList()
        val firstSectionIndex = course.startSection - 1
        val lastSectionIndex = course.endSection - 1
        if (firstSectionIndex < 0 || lastSectionIndex >= sections.size) return emptyList()
        if (startAtMillis == null || endAtMillis == null || endAtMillis <= startAtMillis) return emptyList()

        val sectionStartMinutes = parseClockMinutes(sections[firstSectionIndex].startTime)
        val sectionEndMinutes = parseClockMinutes(sections[lastSectionIndex].endTime)
        if (sectionStartMinutes == null || sectionEndMinutes == null || sectionEndMinutes <= sectionStartMinutes) {
            return emptyList()
        }
        val referenceTotalMinutes = sectionEndMinutes - sectionStartMinutes
        val totalDurationMillis = endAtMillis - startAtMillis
        val milestones = mutableListOf<LiveProgressMilestone>()

        for (sectionIndex in firstSectionIndex until lastSectionIndex) {
            val currentSection = sections[sectionIndex]
            val nextSection = sections[sectionIndex + 1]
            val currentEndMinutes = parseClockMinutes(currentSection.endTime)
            val nextStartMinutes = parseClockMinutes(nextSection.startTime)
            if (currentEndMinutes == null || nextStartMinutes == null || nextStartMinutes <= currentEndMinutes) {
                continue
            }
            val breakStartOffsetMillis = (((currentEndMinutes - sectionStartMinutes).toDouble() / referenceTotalMinutes) *
                totalDurationMillis).roundToLong().coerceIn(1L, totalDurationMillis - 1)
            val breakEndOffsetMillis = (((nextStartMinutes - sectionStartMinutes).toDouble() / referenceTotalMinutes) *
                totalDurationMillis).roundToLong().coerceIn(1L, totalDurationMillis - 1)
            milestones.add(
                LiveProgressMilestone(breakStartOffsetMillis, MILESTONE_RECENT_END_LABEL_KEY, currentSection.endTime),
            )
            milestones.add(
                LiveProgressMilestone(breakEndOffsetMillis, MILESTONE_NEXT_START_LABEL_KEY, nextSection.startTime),
            )
        }
        return milestones.sortedBy { it.offsetMillis }
    }

    /** 只取偏移序列（buildLiveProgressBreakOffsetsMillis，:160-172）。 */
    fun buildLiveProgressBreakOffsetsMillis(
        course: Course,
        sections: List<SectionTimeData>?,
        startAtMillis: Long?,
        endAtMillis: Long?,
    ): List<Long> = buildLiveProgressMilestones(course, sections, startAtMillis, endAtMillis).map { it.offsetMillis }

    /** 阶段切换键（buildStageTransitionKey，:174-179）——键名漂移 = 去重失效。 */
    fun buildStageTransitionKey(selection: LiveActivityCourseSelection): String {
        val liveCourse = selection.currentCourse
        return "${liveCourse.id}:${selection.stage.value}:${liveCourse.name}:" +
            "${liveCourse.startSection}:${liveCourse.endSection}:" +
            "${liveCourse.location}:${liveCourse.teacher}"
    }
}
