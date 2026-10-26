package com.mutx163.qingyu.widgetdata

import com.mutx163.qingyu.core.Course
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 「上课中/下一节/课前/将结束」阶段引擎的端口测试。
 *
 * 期望值来源：test/services/timetable_live_activity_service_test.dart 既有用例
 * （[Dart抄录]），或按 lib/domain/live_activity_logic.dart 注释规则人工推演
 * （[Dart推演]）。全部纯函数、零 IO。
 */
class LiveActivityLogicTest {

    private val day: LocalDateTime = LocalDateTime.of(2026, 3, 2, 0, 0) // 周一

    private fun at(h: Int, m: Int): LocalDateTime = day.plusHours(h.toLong()).plusMinutes(m.toLong())

    private fun course(
        id: String = "course-1",
        name: String = "高等数学",
        startSection: Int = 1,
        endSection: Int = 2,
        startTime: String = "08:00",
        endTime: String = "09:40",
    ): Course = Course(
        id = id, name = name, teacher = "张老师", location = "A101",
        dayOfWeek = 1, startSection = startSection, endSection = endSection,
        startTime = startTime, endTime = endTime,
    )

    // —— resolveLiveActivityStage ——

    @Test
    fun beforeAheadWindowIsNull() { // [Dart推演] currentTime < aheadTime → null
        val settings = WidgetSettingsFace()
        val stage = LiveActivityLogicData.resolveLiveActivityStage(
            currentTime = at(9, 0),
            startTime = at(10, 0),
            endTime = at(11, 40),
            aheadTime = at(9, 40),
            settings = settings,
        )
        assertNull(stage)
    }

    @Test
    fun aheadWindowBeforeStartYieldsBeforeClass() { // [Dart推演]
        val stage = LiveActivityLogicData.resolveLiveActivityStage(
            currentTime = at(9, 41),
            startTime = at(10, 0),
            endTime = at(11, 40),
            aheadTime = at(9, 40),
            settings = WidgetSettingsFace(),
        )
        assertEquals(LiveActivityStage.BEFORE_CLASS, stage)
    }

    @Test
    fun beforeClassDisabledFallsBackToNull() { // [Dart推演]
        val settings = WidgetSettingsFace().copy(liveEnableBeforeClass = false)
        val stage = LiveActivityLogicData.resolveLiveActivityStage(
            currentTime = at(9, 41),
            startTime = at(10, 0),
            endTime = at(11, 40),
            aheadTime = at(9, 40),
            settings = settings,
        )
        assertNull(stage)
    }

    @Test
    fun atOrAfterEndIsNull() { // [Dart推演] !currentTime.isBefore(endTime) → null
        val settings = WidgetSettingsFace()
        assertNull(
            LiveActivityLogicData.resolveLiveActivityStage(
                at(11, 40), at(10, 0), at(11, 40), at(9, 40), settings,
            ),
        )
        assertNull(
            LiveActivityLogicData.resolveLiveActivityStage(
                at(11, 41), at(10, 0), at(11, 40), at(9, 40), settings,
            ),
        )
    }

    @Test
    fun midClassYieldsDuringClassWhenReminderStartIsZero() { // [Dart推演]
        val stage = LiveActivityLogicData.resolveLiveActivityStage(
            currentTime = at(10, 30),
            startTime = at(10, 0),
            endTime = at(11, 40),
            aheadTime = at(9, 40),
            settings = WidgetSettingsFace(), // liveClassReminderStartMinutes = 0
        )
        assertEquals(LiveActivityStage.DURING_CLASS, stage)
    }

    @Test
    fun endReminderWindowYieldsBeforeEnd() { // [Dart推演] 课末 10 分钟窗口
        val stage = LiveActivityLogicData.resolveLiveActivityStage(
            currentTime = at(11, 35),
            startTime = at(10, 0),
            endTime = at(11, 40),
            aheadTime = at(9, 40),
            settings = WidgetSettingsFace(),
        )
        assertEquals(LiveActivityStage.BEFORE_END, stage)
    }

    @Test
    fun statusbarStageBeforeReminderStartWhenStartMinutesPositive() { // [Dart推演]
        val settings = WidgetSettingsFace().copy(liveClassReminderStartMinutes = 5)
        val inMiddle = LiveActivityLogicData.resolveLiveActivityStage(
            currentTime = at(10, 30),
            startTime = at(10, 0),
            endTime = at(11, 40),
            aheadTime = at(9, 40),
            settings = settings,
        )
        // reminderStart = end - 5min = 11:35；10:30 早于它 → 状态栏档
        assertEquals(LiveActivityStage.DURING_CLASS_STATUS_BAR, inMiddle)
        val inWindow = LiveActivityLogicData.resolveLiveActivityStage(
            currentTime = at(11, 36),
            startTime = at(10, 0),
            endTime = at(11, 40),
            aheadTime = at(9, 40),
            settings = settings,
        )
        assertEquals(LiveActivityStage.BEFORE_END, inWindow)
    }

    @Test
    fun statusbarNeedsNotificationSwitch() { // [Dart推演] 通知关 → 状态栏档 null
        // reminderStart = end - 5min = 11:35；10:30 早于它 → 状态栏档要求通知开着
        val settings = WidgetSettingsFace().copy(
            liveClassReminderStartMinutes = 5,
            liveShowDuringClassNotification = false,
            livePromoteDuringClass = true,
        )
        val stage = LiveActivityLogicData.resolveLiveActivityStage(
            currentTime = at(10, 30),
            startTime = at(10, 0),
            endTime = at(11, 40),
            aheadTime = at(9, 40),
            settings = settings,
        )
        assertNull(stage)
    }

    @Test
    fun promotedDuringClassAfterReminderStartWhenBeforeEndOff() { // [Dart推演]
        // reminderStart(11:35) 之后：beforeEnd 关 → 兜底 duringClass（通知关但提升开）
        val settings = WidgetSettingsFace().copy(
            liveClassReminderStartMinutes = 5,
            liveShowDuringClassNotification = false,
            livePromoteDuringClass = true,
            liveEnableBeforeEnd = false,
        )
        val stage = LiveActivityLogicData.resolveLiveActivityStage(
            currentTime = at(11, 36),
            startTime = at(10, 0),
            endTime = at(11, 40),
            aheadTime = at(9, 40),
            settings = settings,
        )
        assertEquals(LiveActivityStage.DURING_CLASS, stage)
    }

    @Test
    fun everythingDisabledYieldsNull() { // [Dart推演]
        val settings = WidgetSettingsFace().copy(
            liveEnableDuringClass = false,
            liveEnableBeforeEnd = false,
        )
        assertNull(
            LiveActivityLogicData.resolveLiveActivityStage(
                at(10, 30), at(10, 0), at(11, 40), at(9, 40), settings,
            ),
        )
    }

    // —— preferredTestStage ——

    @Test
    fun preferredTestStagePrefersBeforeClass() { // [Dart推演] 优先级 before > during > beforeEnd
        assertEquals(
            LiveActivityStage.BEFORE_CLASS,
            LiveActivityLogicData.preferredTestStage(WidgetSettingsFace()),
        )
        assertEquals(
            LiveActivityStage.DURING_CLASS,
            LiveActivityLogicData.preferredTestStage(
                WidgetSettingsFace().copy(liveEnableBeforeClass = false),
            ),
        )
        assertEquals(
            LiveActivityStage.BEFORE_END,
            LiveActivityLogicData.preferredTestStage(
                WidgetSettingsFace()
                    .copy(liveEnableBeforeClass = false, liveEnableDuringClass = false),
            ),
        )
        assertNull(
            LiveActivityLogicData.preferredTestStage(
                WidgetSettingsFace().copy(
                    liveEnableBeforeClass = false,
                    liveEnableDuringClass = false,
                    liveEnableBeforeEnd = false,
                ),
            ),
        )
    }

    // —— buildLiveProgressMilestones ——

    @Test
    fun milestonesMapSectionBreaksToOffsets() { // [Dart推演]
        // sections 08:00-08:45 / 08:55-09:40：参考跨度 100 分钟（08:00→09:40），
        // 合成窗口也取 08:00→09:40。休息起点偏移 = (08:45-08:00)/100 = 45%，
        // 恢复点 = (08:55-08:00)/100 = 55%。
        val sections = listOf(SectionTimeData("08:00", "08:45"), SectionTimeData("08:55", "09:40"))
        val startMillis = WidgetDataClock.toEpochMillis(at(8, 0))
        val endMillis = WidgetDataClock.toEpochMillis(at(9, 40))
        val milestones = LiveActivityLogicData.buildLiveProgressMilestones(
            course = course(startSection = 1, endSection = 2),
            sections = sections,
            startAtMillis = startMillis,
            endAtMillis = endMillis,
        )
        assertEquals(2, milestones.size)
        assertEquals(2_700_000L, milestones[0].offsetMillis)
        assertEquals("milestone_recent_end", milestones[0].labelKey)
        assertEquals("08:45", milestones[0].timeText)
        assertEquals(3_300_000L, milestones[1].offsetMillis)
        assertEquals("milestone_next_start", milestones[1].labelKey)
        assertEquals("08:55", milestones[1].timeText)
        assertEquals(
            listOf(2_700_000L, 3_300_000L),
            LiveActivityLogicData.buildLiveProgressBreakOffsetsMillis(
                course(startSection = 1, endSection = 2), sections, startMillis, endMillis,
            ),
        )
    }

    @Test
    fun identicalAdjacentSectionsProduceNoMilestones() { // [Dart推演] nextStart <= currentEnd → 跳过
        val sections = listOf(SectionTimeData("08:00", "08:45"), SectionTimeData("08:45", "09:40"))
        val startMillis = WidgetDataClock.toEpochMillis(at(8, 0))
        val endMillis = WidgetDataClock.toEpochMillis(at(9, 40))
        val milestones = LiveActivityLogicData.buildLiveProgressMilestones(
            course = course(startSection = 1, endSection = 2),
            sections = sections,
            startAtMillis = startMillis,
            endAtMillis = endMillis,
        )
        assertTrue(milestones.isEmpty())
    }

    @Test
    fun singleSectionCourseProduceNoMilestones() { // [Dart推演] sectionCount < 2 → []
        val sections = listOf(SectionTimeData("08:00", "08:45"), SectionTimeData("08:55", "09:40"))
        val milestones = LiveActivityLogicData.buildLiveProgressMilestones(
            course = course(startSection = 1, endSection = 1),
            sections = sections,
            startAtMillis = WidgetDataClock.toEpochMillis(at(8, 0)),
            endAtMillis = WidgetDataClock.toEpochMillis(at(8, 45)),
        )
        assertTrue(milestones.isEmpty())
    }

    @Test
    fun outOfRangeSectionsProduceNoMilestones() { // [Dart推演] 节次越界 → []
        val sections = listOf(SectionTimeData("08:00", "08:45"))
        val milestones = LiveActivityLogicData.buildLiveProgressMilestones(
            course = course(startSection = 1, endSection = 3),
            sections = sections,
            startAtMillis = WidgetDataClock.toEpochMillis(at(8, 0)),
            endAtMillis = WidgetDataClock.toEpochMillis(at(9, 40)),
        )
        assertTrue(milestones.isEmpty())
    }

    // —— buildStageTransitionKey ——

    @Test
    fun stageTransitionKeyFormatMatchesDart() { // [Dart抄录] '${id}:${stage}:${name}:${start}:${end}:${location}:${teacher}'
        val key = LiveActivityLogicData.buildStageTransitionKey(
            LiveActivityCourseSelection(
                currentCourse = course(id = "c1", startSection = 1, endSection = 2),
                nextCourse = null,
                stage = LiveActivityStage.DURING_CLASS,
            ),
        )
        assertEquals("c1:duringClass:高等数学:1:2:A101:张老师", key)
    }

    // —— 快照线上限 ——

    @Test
    fun endReminderWindowIsTenMinutes() { // [Dart抄录] _endReminderWindow = Duration(minutes: 10)
        assertEquals(10L, LIVE_END_REMINDER_WINDOW_MINUTES)
    }

    @Test
    fun stageNamesMatchDartContract() { // [Dart抄录] 岛/原生通道用 Dart 枚举名字符串
        assertEquals("beforeClass", LiveActivityStage.BEFORE_CLASS.value)
        assertEquals("duringClassStatusBar", LiveActivityStage.DURING_CLASS_STATUS_BAR.value)
        assertEquals("duringClass", LiveActivityStage.DURING_CLASS.value)
        assertEquals("beforeEnd", LiveActivityStage.BEFORE_END.value)
        assertEquals(4, LiveActivityStage.entries.size)
    }
}
