package com.mutx163.qingyu.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * 「实时活动当前阶段」唯一内核的直测（P1-13，2026-11-11）。
 *
 * 这一份算法原先有三处：调度侧纯函数 + 调度适配层 + 服务侧独立实现。
 * 合并后调度侧与服务侧都是薄转调，差异被做成签名里的显式参数：
 * - `beforeClassLeadMillis = null` 表示「调用方没给窗口，信任 start」（服务口径）；
 * - `blockedUntilMillis` 是连堂课屏蔽点（只有调度侧传；服务侧传 null，行为差异保留）。
 *
 * 断言里的阶段字符串是按**对外契约**写的字面量（`beforeClass` / `duringClassStatusBar` /
 * `beforeEnd` / `duringClass`），改常量不算通过。
 */
class LiveUpdateStageLogicTest {

    private val minute = 60_000L
    /** 某节课 08:00–09:40。 */
    private val startAt = 8 * 60 * minute
    private val endAt = 9 * 60 * minute + 40 * minute

    private fun at(hour: Int, minOfHour: Int = 0): Long = (hour * 60L + minOfHour) * minute

    @Test
    fun `课前窗口外为 null 窗口内是 beforeClass 前端禁用也是 null`() {
        assertNull(
            "早于窗口起点（08:00 - 20min = 07:40）",
            LiveUpdateStageLogic.resolveStage(
                nowMillis = at(7, 30),
                startAtMillis = startAt,
                endAtMillis = endAt,
                beforeClassLeadMillis = 20 * minute,
            ),
        )
        assertEquals(
            "beforeClass",
            LiveUpdateStageLogic.resolveStage(
                nowMillis = at(7, 45),
                startAtMillis = startAt,
                endAtMillis = endAt,
                beforeClassLeadMillis = 20 * minute,
            ),
        )
        assertNull(
            "前端阶段被禁用",
            LiveUpdateStageLogic.resolveStage(
                nowMillis = at(7, 45),
                startAtMillis = startAt,
                endAtMillis = endAt,
                beforeClassLeadMillis = 20 * minute,
                enableBeforeClass = false,
            ),
        )
    }

    @Test
    fun `连堂课屏蔽点会把课前窗口起点抬起来`() {
        // 窗口起点 07:40，但上一节课到 07:50 才屏蔽解除。
        assertNull(
            LiveUpdateStageLogic.resolveStage(
                nowMillis = at(7, 45),
                startAtMillis = startAt,
                endAtMillis = endAt,
                blockedUntilMillis = at(7, 50),
                beforeClassLeadMillis = 20 * minute,
            ),
        )
        assertEquals(
            "beforeClass",
            LiveUpdateStageLogic.resolveStage(
                nowMillis = at(7, 55),
                startAtMillis = startAt,
                endAtMillis = endAt,
                blockedUntilMillis = at(7, 50),
                beforeClassLeadMillis = 20 * minute,
            ),
        )
    }

    @Test
    fun `没给窗口时信任 start 服务口径并在屏蔽点前为 null`() {
        // 服务侧语义：lead 传 null ⇒ 上课前不设窗口起点。
        assertEquals(
            "beforeClass",
            LiveUpdateStageLogic.resolveStage(
                nowMillis = at(7, 30),
                startAtMillis = startAt,
                endAtMillis = endAt,
                beforeClassLeadMillis = null,
            ),
        )
        assertNull(
            "没有窗口时屏蔽点仍是硬门槛",
            LiveUpdateStageLogic.resolveStage(
                nowMillis = at(7, 30),
                startAtMillis = startAt,
                endAtMillis = endAt,
                blockedUntilMillis = at(8, 0),
                beforeClassLeadMillis = null,
            ),
        )
    }

    @Test
    fun `课前窗口宽 0 时课前阶段不出现`() {
        assertNull(
            LiveUpdateStageLogic.resolveStage(
                nowMillis = at(7, 59),
                startAtMillis = startAt,
                endAtMillis = endAt,
                beforeClassLeadMillis = 0L,
            ),
        )
    }

    @Test
    fun `课中提醒窗口之前只上状态栏 关掉课中通知则 null`() {
        // reminder 15min ⇒ reminderStart = 09:25；08:30 落在「课中但未到下课提醒」。
        assertEquals(
            "duringClassStatusBar",
            LiveUpdateStageLogic.resolveStage(
                nowMillis = at(8, 30),
                startAtMillis = startAt,
                endAtMillis = endAt,
                beforeClassLeadMillis = 20 * minute,
                liveClassReminderStartMinutes = 15,
            ),
        )
        assertNull(
            LiveUpdateStageLogic.resolveStage(
                nowMillis = at(8, 30),
                startAtMillis = startAt,
                endAtMillis = endAt,
                beforeClassLeadMillis = 20 * minute,
                liveClassReminderStartMinutes = 15,
                showDuringClassNotification = false,
            ),
        )
    }

    @Test
    fun `到了下课提醒窗口 开启 beforeEnd 给 beforeEnd 否则课中或在禁用时 null`() {
        assertEquals(
            "beforeEnd",
            LiveUpdateStageLogic.resolveStage(
                nowMillis = at(9, 30),
                startAtMillis = startAt,
                endAtMillis = endAt,
                beforeClassLeadMillis = 20 * minute,
                liveClassReminderStartMinutes = 15,
            ),
        )
        assertEquals(
            "duringClass",
            LiveUpdateStageLogic.resolveStage(
                nowMillis = at(9, 30),
                startAtMillis = startAt,
                endAtMillis = endAt,
                beforeClassLeadMillis = 20 * minute,
                liveClassReminderStartMinutes = 15,
                enableBeforeEnd = false,
            ),
        )
        assertNull(
            LiveUpdateStageLogic.resolveStage(
                nowMillis = at(9, 30),
                startAtMillis = startAt,
                endAtMillis = endAt,
                beforeClassLeadMillis = 20 * minute,
                liveClassReminderStartMinutes = 15,
                enableBeforeEnd = false,
                enableDuringClass = false,
            ),
        )
    }

    @Test
    fun `无课中提醒时按结束前窗口切 beforeEnd 与 duringClass`() {
        // endReminderLead 10min ⇒ endReminderStart = 09:30。
        assertEquals(
            "duringClass",
            LiveUpdateStageLogic.resolveStage(
                nowMillis = at(9, 0),
                startAtMillis = startAt,
                endAtMillis = endAt,
                beforeClassLeadMillis = 20 * minute,
                endReminderLeadMillis = 10 * minute,
            ),
        )
        assertEquals(
            "beforeEnd",
            LiveUpdateStageLogic.resolveStage(
                nowMillis = at(9, 35),
                startAtMillis = startAt,
                endAtMillis = endAt,
                beforeClassLeadMillis = 20 * minute,
                endReminderLeadMillis = 10 * minute,
            ),
        )
        assertEquals(
            "关掉 beforeEnd 时退回课中",
            "duringClass",
            LiveUpdateStageLogic.resolveStage(
                nowMillis = at(9, 35),
                startAtMillis = startAt,
                endAtMillis = endAt,
                beforeClassLeadMillis = 20 * minute,
                endReminderLeadMillis = 10 * minute,
                enableBeforeEnd = false,
            ),
        )
        assertNull(
            LiveUpdateStageLogic.resolveStage(
                nowMillis = at(9, 35),
                startAtMillis = startAt,
                endAtMillis = endAt,
                beforeClassLeadMillis = 20 * minute,
                endReminderLeadMillis = 10 * minute,
                enableBeforeEnd = false,
                enableDuringClass = false,
            ),
        )
    }

    @Test
    fun `下课之后一律 null`() {
        assertNull(
            LiveUpdateStageLogic.resolveStage(
                nowMillis = at(9, 40),
                startAtMillis = startAt,
                endAtMillis = endAt,
                beforeClassLeadMillis = 20 * minute,
                enableBeforeEnd = true,
            ),
        )
    }
}
