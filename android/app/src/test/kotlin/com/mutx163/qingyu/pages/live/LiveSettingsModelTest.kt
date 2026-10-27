package com.mutx163.qingyu.pages.live

import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 实时活动与超级岛模型层单元测试（P3-J）。
 *
 * 覆盖：
 * 1. 阶段判定链（IDLE -> BEFORE -> ONGOING -> AFTER -> IDLE）
 * 2. 边界临界时刻精确推导
 * 3. 各种开关禁用与异常时间容错
 * 4. 展示文案与进度条推导
 * 5. 提前与延后时间数值有效区间夹紧与状态变异
 */
class LiveSettingsModelTest {

    private val baseDate = LocalDateTime.of(2026, 10, 27, 0, 0)
    private val classStart = baseDate.plusHours(10) // 10:00
    private val classEnd = baseDate.plusHours(11).plusMinutes(40) // 11:40 (时长 100 分钟)

    // ==========================================
    // 1. 阶段判定链测试
    // ==========================================

    @Test
    fun `resolveLiveDisplayPhase 正常时段判定与边界测试`() {
        val leadMinutes = 20
        val keepMinutes = 10

        // 09:39:59 -> 早于提前开始时刻 (09:40) -> IDLE
        val early = classStart.minusMinutes(20).minusSeconds(1)
        assertEquals(
            LiveDisplayPhase.IDLE,
            LiveSettingsModel.resolveLiveDisplayPhase(early, classStart, classEnd, leadMinutes, keepMinutes),
        )

        // 09:40:00 -> 恰好到达提前提醒时间 -> BEFORE
        val leadExact = classStart.minusMinutes(20)
        assertEquals(
            LiveDisplayPhase.BEFORE,
            LiveSettingsModel.resolveLiveDisplayPhase(leadExact, classStart, classEnd, leadMinutes, keepMinutes),
        )

        // 09:50:00 -> 上课前 10 分钟 -> BEFORE
        val beforeMid = classStart.minusMinutes(10)
        assertEquals(
            LiveDisplayPhase.BEFORE,
            LiveSettingsModel.resolveLiveDisplayPhase(beforeMid, classStart, classEnd, leadMinutes, keepMinutes),
        )

        // 09:59:59 -> 上课前 1 秒 -> BEFORE
        val beforeLastSec = classStart.minusSeconds(1)
        assertEquals(
            LiveDisplayPhase.BEFORE,
            LiveSettingsModel.resolveLiveDisplayPhase(beforeLastSec, classStart, classEnd, leadMinutes, keepMinutes),
        )

        // 10:00:00 -> 正好上课 -> ONGOING
        assertEquals(
            LiveDisplayPhase.ONGOING,
            LiveSettingsModel.resolveLiveDisplayPhase(classStart, classStart, classEnd, leadMinutes, keepMinutes),
        )

        // 10:50:00 -> 上课中途 -> ONGOING
        val duringMid = classStart.plusMinutes(50)
        assertEquals(
            LiveDisplayPhase.ONGOING,
            LiveSettingsModel.resolveLiveDisplayPhase(duringMid, classStart, classEnd, leadMinutes, keepMinutes),
        )

        // 11:39:59 -> 下课前 1 秒 -> ONGOING
        val duringLastSec = classEnd.minusSeconds(1)
        assertEquals(
            LiveDisplayPhase.ONGOING,
            LiveSettingsModel.resolveLiveDisplayPhase(duringLastSec, classStart, classEnd, leadMinutes, keepMinutes),
        )

        // 11:40:00 -> 正好下课 -> AFTER
        assertEquals(
            LiveDisplayPhase.AFTER,
            LiveSettingsModel.resolveLiveDisplayPhase(classEnd, classStart, classEnd, leadMinutes, keepMinutes),
        )

        // 11:45:00 -> 下课驻留中 -> AFTER
        val afterMid = classEnd.plusMinutes(5)
        assertEquals(
            LiveDisplayPhase.AFTER,
            LiveSettingsModel.resolveLiveDisplayPhase(afterMid, classStart, classEnd, leadMinutes, keepMinutes),
        )

        // 11:49:59 -> 驻留最后一秒 -> AFTER
        val afterLastSec = classEnd.plusMinutes(10).minusSeconds(1)
        assertEquals(
            LiveDisplayPhase.AFTER,
            LiveSettingsModel.resolveLiveDisplayPhase(afterLastSec, classStart, classEnd, leadMinutes, keepMinutes),
        )

        // 11:50:00 -> 驻留结束 -> IDLE
        val afterEnd = classEnd.plusMinutes(10)
        assertEquals(
            LiveDisplayPhase.IDLE,
            LiveSettingsModel.resolveLiveDisplayPhase(afterEnd, classStart, classEnd, leadMinutes, keepMinutes),
        )

        // 12:00:00 -> 远在驻留结束后 -> IDLE
        val late = classEnd.plusMinutes(20)
        assertEquals(
            LiveDisplayPhase.IDLE,
            LiveSettingsModel.resolveLiveDisplayPhase(late, classStart, classEnd, leadMinutes, keepMinutes),
        )
    }

    @Test
    fun `isLiveEnabled 为 false 时无论何时均返回 IDLE`() {
        val leadExact = classStart.minusMinutes(10)
        val ongoing = classStart.plusMinutes(20)
        val after = classEnd.plusMinutes(5)

        assertEquals(
            LiveDisplayPhase.IDLE,
            LiveSettingsModel.resolveLiveDisplayPhase(leadExact, classStart, classEnd, isLiveEnabled = false),
        )
        assertEquals(
            LiveDisplayPhase.IDLE,
            LiveSettingsModel.resolveLiveDisplayPhase(ongoing, classStart, classEnd, isLiveEnabled = false),
        )
        assertEquals(
            LiveDisplayPhase.IDLE,
            LiveSettingsModel.resolveLiveDisplayPhase(after, classStart, classEnd, isLiveEnabled = false),
        )
    }

    @Test
    fun `keepMinutes 为 0 时下课立刻归于 IDLE`() {
        // 下课那一瞬已到达结束时刻 -> IDLE
        assertEquals(
            LiveDisplayPhase.IDLE,
            LiveSettingsModel.resolveLiveDisplayPhase(classEnd, classStart, classEnd, keepMinutesAfterClass = 0),
        )
    }

    @Test
    fun `起止时间异常时安全回退 IDLE`() {
        // 结束时间早于开始时间
        val invertedEnd = classStart.minusMinutes(30)
        assertEquals(
            LiveDisplayPhase.IDLE,
            LiveSettingsModel.resolveLiveDisplayPhase(classStart, classStart, invertedEnd),
        )
    }

    // ==========================================
    // 2. 展示文案与进度推导测试
    // ==========================================

    @Test
    fun `deriveLiveDisplayInfo 在各阶段下的文案与进度推导`() {
        val course = "高等数学"
        val location = "三教-401"
        val state = LiveSettingsState(
            isLiveEnabled = true,
            leadMinutesBeforeClass = 20,
            keepMinutesAfterClass = 10,
            showOngoingProgress = true,
        )

        // 1. 空闲态 (IDLE)
        val idleInfo = LiveSettingsModel.deriveLiveDisplayInfo(
            currentTime = classStart.minusMinutes(40),
            startTime = classStart,
            endTime = classEnd,
            courseName = course,
            location = location,
            settings = state,
        )
        assertEquals(LiveDisplayPhase.IDLE, idleInfo.phase)
        assertEquals("空闲", idleInfo.phaseLabel)
        assertEquals(0f, idleInfo.progress, 0.001f)
        assertEquals("", idleInfo.countdownText)

        // 2. 即将上课 (BEFORE) -> 距 10:00 还有 15 分钟
        val beforeTime = classStart.minusMinutes(15)
        val beforeInfo = LiveSettingsModel.deriveLiveDisplayInfo(
            currentTime = beforeTime,
            startTime = classStart,
            endTime = classEnd,
            courseName = course,
            location = location,
            settings = state,
        )
        assertEquals(LiveDisplayPhase.BEFORE, beforeInfo.phase)
        assertEquals(LiveStrings.liveIslandPreviewStageBeforeClass.zh, beforeInfo.phaseLabel)
        assertEquals("即将上课：高等数学", beforeInfo.title)
        assertEquals(location, beforeInfo.subtitle)
        assertEquals("距上课 15:00", beforeInfo.countdownText)
        assertEquals(0f, beforeInfo.progress, 0.001f)

        // 3. 上课中 (ONGOING) -> 10:50 (已过去 50 分钟，总长 100 分钟，进度正好 0.5)
        val ongoingTime = classStart.plusMinutes(50)
        val ongoingInfo = LiveSettingsModel.deriveLiveDisplayInfo(
            currentTime = ongoingTime,
            startTime = classStart,
            endTime = classEnd,
            courseName = course,
            location = location,
            settings = state,
        )
        assertEquals(LiveDisplayPhase.ONGOING, ongoingInfo.phase)
        assertEquals(LiveStrings.liveIslandPreviewStageInClass.zh, ongoingInfo.phaseLabel)
        assertEquals(course, ongoingInfo.title)
        assertEquals("距下课 50:00", ongoingInfo.countdownText)
        assertEquals(0.5f, ongoingInfo.progress, 0.01f)

        // 当 showOngoingProgress 关闭时，进度强制为 0
        val ongoingNoProgress = LiveSettingsModel.deriveLiveDisplayInfo(
            currentTime = ongoingTime,
            startTime = classStart,
            endTime = classEnd,
            courseName = course,
            location = location,
            settings = state.copy(showOngoingProgress = false),
        )
        assertEquals(0f, ongoingNoProgress.progress, 0.001f)

        // 4. 已下课驻留 (AFTER)
        val afterTime = classEnd.plusMinutes(5)
        val afterInfo = LiveSettingsModel.deriveLiveDisplayInfo(
            currentTime = afterTime,
            startTime = classStart,
            endTime = classEnd,
            courseName = course,
            location = location,
            settings = state,
        )
        assertEquals(LiveDisplayPhase.AFTER, afterInfo.phase)
        assertEquals(LiveStrings.liveIslandPreviewStageBeforeEnd.zh, afterInfo.phaseLabel)
        assertEquals("下课提醒：高等数学", afterInfo.title)
        assertEquals("已下课", afterInfo.countdownText)
        assertEquals(1f, afterInfo.progress, 0.001f)
    }

    // ==========================================
    // 3. 边界值夹紧与状态变异测试
    // ==========================================

    @Test
    fun `提前与延后时间数值有效区间有效限制`() {
        // 提前时间边界 (5..60)
        assertEquals(5, LiveSettingsModel.clampLeadMinutes(0))
        assertEquals(5, LiveSettingsModel.clampLeadMinutes(4))
        assertEquals(5, LiveSettingsModel.clampLeadMinutes(5))
        assertEquals(25, LiveSettingsModel.clampLeadMinutes(25))
        assertEquals(60, LiveSettingsModel.clampLeadMinutes(60))
        assertEquals(60, LiveSettingsModel.clampLeadMinutes(100))

        // 延后驻留时间边界 (0..30)
        assertEquals(0, LiveSettingsModel.clampKeepMinutes(-10))
        assertEquals(0, LiveSettingsModel.clampKeepMinutes(0))
        assertEquals(15, LiveSettingsModel.clampKeepMinutes(15))
        assertEquals(30, LiveSettingsModel.clampKeepMinutes(30))
        assertEquals(30, LiveSettingsModel.clampKeepMinutes(50))
    }

    @Test
    fun `状态变异纯函数正确更新属性`() {
        val initial = LiveSettingsState()

        val toggledLive = initial.withToggledLive()
        assertFalse(toggledLive.isLiveEnabled)

        val toggledIsland = initial.withToggledIsland()
        assertFalse(toggledIsland.showIsland)

        val toggledProgress = initial.withToggledOngoingProgress()
        assertFalse(toggledProgress.showOngoingProgress)

        val changedLead = initial.withLeadMinutes(45)
        assertEquals(45, changedLead.leadMinutesBeforeClass)

        val clampedLead = initial.withLeadMinutes(100)
        assertEquals(60, clampedLead.leadMinutesBeforeClass)

        val changedKeep = initial.withKeepMinutes(20)
        assertEquals(20, changedKeep.keepMinutesAfterClass)

        val clampedKeep = initial.withKeepMinutes(-5)
        assertEquals(0, clampedKeep.keepMinutesAfterClass)

        val styled = initial.withIslandStyle(LiveIslandStyle.CARD)
        assertEquals(LiveIslandStyle.CARD, styled.islandStyle)

        val reset = styled.withLeadMinutes(55).resetDefaults()
        assertEquals(LiveSettingsState(), reset)
    }
}
