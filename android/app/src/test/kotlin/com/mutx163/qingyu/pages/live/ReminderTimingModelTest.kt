package com.mutx163.qingyu.pages.live

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「提醒时间」子屏模型层单测（P35-live-reminder）。
 *
 * 期望值全部**手推**：照 Flutter `_LiveReminderTimingScreenState`
 * （`lib/screens/live_settings_subpages.dart:80-289`）与
 * `_buildLiveClassReminderLeadSummary`（`:50-67`）的判据一条条推出来，不从实现里抄。
 *
 * 覆盖：
 * 1. 默认状态与 Dart 构造函数真值一致；
 * 2. 「课中与下课提醒」OR 判据与拨动联动（两字段一起写）；
 * 3. 切入时机摘要四口径（含「用的是 liveEnableDuringClass 单字段而非 OR」这条）；
 * 4. 「课中状态栏通知」副标题三口径；
 * 5. 三个下拉的取值边界（贴选项 + 区间 clamp）；
 * 6. 状态清洗与枚举反序列化。
 */
class ReminderTimingModelTest {

    // ── 1. 默认值 ──

    @Test
    fun `默认状态与 Dart 构造函数真值一致`() {
        val state = ReminderTimingState()
        assertTrue(state.liveEnableBeforeClass)
        assertTrue(state.liveEnableDuringClass)
        assertTrue(state.liveEnableBeforeEnd)
        assertEquals(0, state.liveClassReminderStartMinutes)
        assertTrue(state.liveShowDuringClassNotification)
        assertTrue(state.livePromoteDuringClass)
        assertEquals(20, state.liveShowBeforeClassMinutes)
        assertEquals(60, state.liveEndSecondsCountdownThreshold)
        assertEquals(LiveDuringClassTimeDisplayMode.NEAREST, state.liveDuringEndTimeDisplayMode)
    }

    // ── 2. 开关联动 ──

    @Test
    fun `课中提醒显示值是两个字段的 OR`() {
        // Dart `_draft.liveEnableDuringClass || _draft.liveEnableBeforeEnd`。
        assertFalse(ReminderTimingLogic.isDuringClassReminderEnabled(state(duringClass = false, beforeEnd = false)))
        assertTrue(ReminderTimingLogic.isDuringClassReminderEnabled(state(duringClass = true, beforeEnd = false)))
        assertTrue(ReminderTimingLogic.isDuringClassReminderEnabled(state(duringClass = false, beforeEnd = true)))
        assertTrue(ReminderTimingLogic.isDuringClassReminderEnabled(state(duringClass = true, beforeEnd = true)))
    }

    @Test
    fun `拨动课中提醒把两个字段一起写`() {
        val off = ReminderTimingState(liveEnableDuringClass = false, liveEnableBeforeEnd = false)
        val on = ReminderTimingLogic.withDuringClassReminderEnabled(off, enabled = true)
        assertTrue(on.liveEnableDuringClass)
        assertTrue(on.liveEnableBeforeEnd)

        val back = ReminderTimingLogic.withDuringClassReminderEnabled(on, enabled = false)
        assertFalse(back.liveEnableDuringClass)
        assertFalse(back.liveEnableBeforeEnd)
    }

    @Test
    fun `拨动课中提醒不碰其它字段`() {
        val base = ReminderTimingState(
            liveShowBeforeClassMinutes = 40,
            liveEndSecondsCountdownThreshold = 30,
            liveShowDuringClassNotification = false,
        )
        val next = ReminderTimingLogic.withDuringClassReminderEnabled(base, enabled = true)
        assertEquals(40, next.liveShowBeforeClassMinutes)
        assertEquals(30, next.liveEndSecondsCountdownThreshold)
        assertFalse(next.liveShowDuringClassNotification)
    }

    @Test
    fun `切入时机下拉仅课中提醒开启时出现`() {
        assertFalse(
            ReminderTimingLogic.shouldShowLeadSelect(
                ReminderTimingState(liveEnableDuringClass = false, liveEnableBeforeEnd = false),
            ),
        )
        assertTrue(
            ReminderTimingLogic.shouldShowLeadSelect(
                ReminderTimingState(liveEnableDuringClass = true, liveEnableBeforeEnd = false),
            ),
        )
        assertTrue(
            ReminderTimingLogic.shouldShowLeadSelect(
                ReminderTimingState(liveEnableDuringClass = false, liveEnableBeforeEnd = true),
            ),
        )
    }

    // ── 3. 切入时机摘要四口径 ──

    @Test
    fun `切入时机为零一律是立即切换`() {
        // 即便别的开关怎么摆，startMinutes==0 都走 IMMEDIATE 那一条。
        val state = ReminderTimingState(
            liveClassReminderStartMinutes = 0,
            liveEnableDuringClass = true,
            liveShowDuringClassNotification = false,
            livePromoteDuringClass = false,
        )
        assertEquals(ReminderLeadSummary.IMMEDIATE, ReminderTimingLogic.resolveLeadSummary(state))
    }

    @Test
    fun `课中普通通知且未开超级岛 → 下课前切重点提醒`() {
        val state = ReminderTimingState(
            liveClassReminderStartMinutes = 10,
            liveEnableDuringClass = true,
            liveShowDuringClassNotification = true,
            livePromoteDuringClass = false,
        )
        assertEquals(ReminderLeadSummary.KEEP_NORMAL, ReminderTimingLogic.resolveLeadSummary(state))
    }

    @Test
    fun `课中普通通知且开超级岛 → 下课前切超级岛`() {
        val state = ReminderTimingState(
            liveClassReminderStartMinutes = 10,
            liveEnableDuringClass = true,
            liveShowDuringClassNotification = true,
            livePromoteDuringClass = true,
        )
        assertEquals(ReminderLeadSummary.ISLAND, ReminderTimingLogic.resolveLeadSummary(state))
    }

    @Test
    fun `课中无状态通知 → 下课前才重点提醒`() {
        val state = ReminderTimingState(
            liveClassReminderStartMinutes = 10,
            liveEnableDuringClass = true,
            liveShowDuringClassNotification = false,
            livePromoteDuringClass = true,
        )
        assertEquals(ReminderLeadSummary.FOCUSED, ReminderTimingLogic.resolveLeadSummary(state))
    }

    @Test
    fun `摘要用的是 liveEnableDuringClass 单字段而不是 OR`() {
        // beforeEnd=true 会让 OR 为 true，但 Dart 摘要取的是 liveEnableDuringClass（false），
        // 所以这里必须是 FOCUSED——钉住「照抄原版、不顺手改成 OR」。
        val state = ReminderTimingState(
            liveClassReminderStartMinutes = 10,
            liveEnableDuringClass = false,
            liveEnableBeforeEnd = true,
            liveShowDuringClassNotification = true,
            livePromoteDuringClass = false,
        )
        assertEquals(ReminderLeadSummary.FOCUSED, ReminderTimingLogic.resolveLeadSummary(state))
    }

    // ── 4. 课中状态栏通知副标题 ──

    @Test
    fun `切入时机为零显示保留状态栏通知`() {
        // 优先级最高：即便 promote=false 也不走 PERSISTENT。
        val state = ReminderTimingState(
            liveClassReminderStartMinutes = 0,
            livePromoteDuringClass = false,
        )
        assertEquals(
            DuringClassStatusHint.KEEP_STATUS_NOTIFICATION,
            ReminderTimingLogic.resolveDuringClassStatusHint(state),
        )
    }

    @Test
    fun `切入时机非零且开超级岛 → 重点提醒前用普通通知`() {
        val state = ReminderTimingState(
            liveClassReminderStartMinutes = 15,
            livePromoteDuringClass = true,
        )
        assertEquals(
            DuringClassStatusHint.NORMAL_THEN_LEAD,
            ReminderTimingLogic.resolveDuringClassStatusHint(state),
        )
    }

    @Test
    fun `切入时机非零且未开超级岛 → 全程普通通知`() {
        val state = ReminderTimingState(
            liveClassReminderStartMinutes = 15,
            livePromoteDuringClass = false,
        )
        assertEquals(
            DuringClassStatusHint.PERSISTENT,
            ReminderTimingLogic.resolveDuringClassStatusHint(state),
        )
    }

    // ── 5. 取值边界 ──

    @Test
    fun `切入时机贴到 0 5 10 15 20 30`() {
        assertEquals(0, ReminderTimingLogic.snapClassReminderStartMinutes(0))
        assertEquals(5, ReminderTimingLogic.snapClassReminderStartMinutes(7))   // |7-5|=2 < |7-10|=3
        assertEquals(10, ReminderTimingLogic.snapClassReminderStartMinutes(12)) // |12-10|=2 < |12-15|=3
        assertEquals(15, ReminderTimingLogic.snapClassReminderStartMinutes(13)) // |13-15|=2 < |13-10|=3
        assertEquals(30, ReminderTimingLogic.snapClassReminderStartMinutes(31))
        assertEquals(0, ReminderTimingLogic.snapClassReminderStartMinutes(-5))
    }

    @Test
    fun `上课前分钟贴到选项且并列取较小者`() {
        assertEquals(1, ReminderTimingLogic.snapBeforeClassMinutes(2))   // |2-1|=1 < |2-5|=3
        assertEquals(5, ReminderTimingLogic.snapBeforeClassMinutes(7))   // |7-5|=2 < |7-10|=3
        assertEquals(50, ReminderTimingLogic.snapBeforeClassMinutes(55)) // 与 50/60 等距 -> 取较小 50
        assertEquals(60, ReminderTimingLogic.snapBeforeClassMinutes(61))
        assertEquals(1, ReminderTimingLogic.snapBeforeClassMinutes(0))
        assertEquals(20, ReminderTimingLogic.snapBeforeClassMinutes(20))
    }

    @Test
    fun `下课秒级阈值贴到 15 30 45 60 90`() {
        assertEquals(15, ReminderTimingLogic.snapEndSecondsThreshold(20))
        assertEquals(90, ReminderTimingLogic.snapEndSecondsThreshold(89))
        assertEquals(15, ReminderTimingLogic.snapEndSecondsThreshold(14))
        assertEquals(60, ReminderTimingLogic.snapEndSecondsThreshold(60))
    }

    @Test
    fun `上课前分钟区间 clamp 到 1 到 60`() {
        assertEquals(1, ReminderTimingLogic.clampBeforeClassMinutes(0))
        assertEquals(1, ReminderTimingLogic.clampBeforeClassMinutes(-3))
        assertEquals(60, ReminderTimingLogic.clampBeforeClassMinutes(61))
        assertEquals(30, ReminderTimingLogic.clampBeforeClassMinutes(30))
    }

    @Test
    fun `空选项表原样返回不崩`() {
        assertEquals(42, ReminderTimingLogic.snapToOption(42, emptyList()))
    }

    // ── 6. 清洗与枚举 ──

    @Test
    fun `清洗把三个整数字段贴到合法选项且不动布尔`() {
        val dirty = ReminderTimingState(
            liveClassReminderStartMinutes = 7,
            liveShowBeforeClassMinutes = 0,
            liveEndSecondsCountdownThreshold = 20,
            liveEnableBeforeClass = false,
            liveShowDuringClassNotification = false,
        )
        val clean = ReminderTimingLogic.sanitize(dirty)
        assertEquals(5, clean.liveClassReminderStartMinutes)
        assertEquals(1, clean.liveShowBeforeClassMinutes)
        assertEquals(15, clean.liveEndSecondsCountdownThreshold)
        assertFalse(clean.liveEnableBeforeClass)
        assertFalse(clean.liveShowDuringClassNotification)
    }

    @Test
    fun `选项常量内容与 Dart 一致`() {
        assertEquals(listOf(0, 5, 10, 15, 20, 30), ReminderTimingLogic.CLASS_REMINDER_START_MINUTES)
        assertEquals(
            listOf(1, 5, 10, 15, 20, 30, 40, 50, 60),
            ReminderTimingLogic.BEFORE_CLASS_MINUTES_OPTIONS,
        )
        assertEquals(listOf(15, 30, 45, 60, 90), ReminderTimingLogic.END_SECONDS_OPTIONS)
    }

    @Test
    fun `显示模式反序列化未知值回落最近时间`() {
        assertEquals(LiveDuringClassTimeDisplayMode.NEAREST, LiveDuringClassTimeDisplayMode.fromValue("nearest"))
        assertEquals(LiveDuringClassTimeDisplayMode.TOTAL, LiveDuringClassTimeDisplayMode.fromValue("total"))
        assertEquals(LiveDuringClassTimeDisplayMode.NEAREST, LiveDuringClassTimeDisplayMode.fromValue(null))
        assertEquals(LiveDuringClassTimeDisplayMode.NEAREST, LiveDuringClassTimeDisplayMode.fromValue("unknown"))
    }

    /** 便利构造：只想验证 OR 判据时省掉一堆字段。 */
    private fun state(duringClass: Boolean, beforeEnd: Boolean): ReminderTimingState =
        ReminderTimingState(
            liveEnableDuringClass = duringClass,
            liveEnableBeforeEnd = beforeEnd,
        )
}
