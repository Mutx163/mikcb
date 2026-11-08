package com.mutx163.qingyu.pages.statistics

import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 统计设置页（`lib/screens/statistics_settings_screen.dart`）模型层测试。
 *
 * 期望值全部从 Dart 源手推：
 * - 下次推送时刻取自 `lib/services/weekly_report_service.dart:WeeklyReportService.nextFireAt`
 *   （「今天起算到最近的周日 21:00，若今天已是/已过推送时刻则顺延一周」）；
 * - 文案取自 `i18n/app_zh.arb`（`weeklyReportNextFire` 等）。
 *
 * 日期基准：2026-10-27 是**周二**；该周的周日是 2026-11-01。
 */
class StatisticsSettingsModelTest {

    // ── 1. 下次推送时刻（对齐 Dart nextFireAt） ──

    @Test
    fun `下周内任一天的下次推送都是本周日 21 点`() {
        // 周二 10:30 → 距周日 5 天（周二→周三→周四→周五→周六→周日）
        val tuesday = LocalDateTime.of(2026, 10, 27, 10, 30)
        assertEquals(
            LocalDateTime.of(2026, 11, 1, 21, 0),
            WeeklyReportSchedule.nextFireAt(tuesday),
        )

        // 周三 23:59 同理顺延到同一周日
        val wednesdayLate = LocalDateTime.of(2026, 10, 28, 23, 59)
        assertEquals(
            LocalDateTime.of(2026, 11, 1, 21, 0),
            WeeklyReportSchedule.nextFireAt(wednesdayLate),
        )
    }

    @Test
    fun `周日当天未到 21 点仍是当天`() {
        // 周日 20:00 → 距周日 0 天，21:00 尚未到
        val sundayBefore = LocalDateTime.of(2026, 11, 1, 20, 0)
        assertEquals(
            LocalDateTime.of(2026, 11, 1, 21, 0),
            WeeklyReportSchedule.nextFireAt(sundayBefore),
        )
    }

    @Test
    fun `周日恰好在 21 点整则顺延一周（Dart 用 fire isAfter current 判定，等于不算之后）`() {
        val sundayOnTime = LocalDateTime.of(2026, 11, 1, 21, 0)
        assertEquals(
            LocalDateTime.of(2026, 11, 8, 21, 0),
            WeeklyReportSchedule.nextFireAt(sundayOnTime),
        )
    }

    @Test
    fun `周日已过 21 点则顺延一周`() {
        val sundayAfter = LocalDateTime.of(2026, 11, 1, 21, 30)
        assertEquals(
            LocalDateTime.of(2026, 11, 8, 21, 0),
            WeeklyReportSchedule.nextFireAt(sundayAfter),
        )
    }

    @Test
    fun `周一下午推送时刻已过、下一周周日才是目标`() {
        // 周一 09:00 → 距周日 6 天 → 2026-11-08 21:00
        val monday = LocalDateTime.of(2026, 11, 2, 9, 0)
        assertEquals(
            LocalDateTime.of(2026, 11, 8, 21, 0),
            WeeklyReportSchedule.nextFireAt(monday),
        )
    }

    // ── 2. 日期 / 时间标签（对齐 intl 的 zh 口径） ──

    @Test
    fun `日期标签与时间标签按 zh 格式渲染`() {
        // DateFormat.MMMd('zh') → "11月1日"；HH:mm 零填充 → "21:00"
        val fire = LocalDateTime.of(2026, 11, 1, 21, 0)
        assertEquals("11月1日", StatisticsDateLabels.monthDay(fire))
        assertEquals("21:00", StatisticsDateLabels.clockTime(fire))

        // 个位数小时与分钟都要补零
        val early = LocalDateTime.of(2026, 1, 5, 9, 5)
        assertEquals("1月5日", StatisticsDateLabels.monthDay(early))
        assertEquals("09:05", StatisticsDateLabels.clockTime(early))
    }

    @Test
    fun `yMMMd 用于学期进度区间，zh 口径是年月日`() {
        // DateFormat.yMMMd('zh') → "2026年9月1日"
        assertEquals("2026年9月1日", StatisticsDateLabels.yearMonthDay(LocalDateTime.of(2026, 9, 1, 0, 0)))
        assertEquals("", StatisticsDateLabels.yearMonthDay(null))
    }

    // ── 3. 开关副标题（weeklyReportNextFire / weeklyReportDisabledHint） ──

    @Test
    fun `开启态副标题是下次推送日期与时刻`() {
        val fire = LocalDateTime.of(2026, 11, 1, 21, 0)
        // ARB: "下次推送 {date} {time}"
        assertEquals("下次推送 11月1日 21:00", StatisticsSettingsLogic.subtitle(true, fire))
    }

    @Test
    fun `关闭态副标题是已关闭提示`() {
        val fire = LocalDateTime.of(2026, 11, 1, 21, 0)
        // ARB: "已关闭每周周报推送"
        assertEquals("已关闭每周周报推送", StatisticsSettingsLogic.subtitle(false, fire))
    }

    // ── 4. 整页视图状态 ──

    @Test
    fun `整页视图状态在开启态带标题与下次推送`() {
        val now = LocalDateTime.of(2026, 10, 27, 10, 30)
        val state = StatisticsSettingsLogic.buildViewState(weeklyReportEnabled = true, now = now)

        assertEquals("统计设置", state.title)                       // statisticsSettingsTitle
        assertEquals("本周课程小结", state.sectionTitle)            // weeklyReportTitle（块头）
        assertEquals("本周课程小结", state.tileTitle)               // weeklyReportTitle（开关行同名，Dart 原样重复）
        assertEquals("下次推送 11月1日 21:00", state.subtitle)
        assertTrue(state.isEnabled)
        assertEquals(LocalDateTime.of(2026, 11, 1, 21, 0), state.nextFireAt)
    }

    @Test
    fun `整页视图状态在关闭态仍是同一组标题、副标题换成关闭提示`() {
        val now = LocalDateTime.of(2026, 10, 27, 10, 30)
        val state = StatisticsSettingsLogic.buildViewState(weeklyReportEnabled = false, now = now)

        assertEquals("统计设置", state.title)
        assertEquals("本周课程小结", state.sectionTitle)
        assertEquals("本周课程小结", state.tileTitle)
        assertEquals("已关闭每周周报推送", state.subtitle)
        assertFalse(state.isEnabled)
    }

    // ── 5. 操作反馈文案 ──

    @Test
    fun `成功切换后的提示按开与关取不同文案`() {
        // weeklyReportEnabledHint / weeklyReportDisabledHint
        assertEquals("已开启每周周报推送", StatisticsSettingsLogic.toggleResultMessage(true))
        assertEquals("已关闭每周周报推送", StatisticsSettingsLogic.toggleResultMessage(false))
    }

    @Test
    fun `保存失败的提示是 saveFailed`() {
        assertEquals("保存失败", StatisticsSettingsLogic.SAVE_FAILED_MESSAGE)
    }
}
