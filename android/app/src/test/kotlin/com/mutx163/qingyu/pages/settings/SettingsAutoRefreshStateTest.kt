package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 「课表自动更新」本地存储 → 通用页状态 的映射（[SettingsPageBridge.toAutoRefreshState]），
 * 以及它喂进 spec 之后那一整块**真的会出现在屏上**。
 *
 * 期望值全部人推自 Dart 原件，不从 Kotlin 实现倒推：
 * - 档位短串：`lib/domain/course_auto_refresh_decision.dart:23-35`（`everyLaunch` /
 *   `intervalHours` / `dailyAt`），与磁盘值逐字一致；
 * - 时刻短格式：`lib/widgets/course_auto_refresh_settings.dart:246-252`
 *   （`_shortDateTime`：月**不**补零、日补零、24 小时制）；
 * - 灰字拼法：同文件 `:226-240`（`上次 X` 或 `上次 X · 下次约 Y`）。
 *
 * 这一条补的是审计里那个 P0：桥长期写死 `autoRefresh = null` ⇒ 整块不渲染，
 * 而**没有任何测试**盯着「喂了状态以后这块到底长什么样」。
 */
class SettingsAutoRefreshStateTest {

    private fun state(
        enabled: Boolean = true,
        modeValue: String = "everyLaunch",
        intervalHours: Int = 24,
        dailyMinuteOfDay: Int = 7 * 60 + 30,
        lastSuccess: LocalDateTime? = null,
        nextRun: LocalDateTime? = null,
    ): AutoRefreshState = SettingsPageBridge.toAutoRefreshState(
        enabled = enabled,
        modeValue = modeValue,
        intervalHours = intervalHours,
        dailyMinuteOfDay = dailyMinuteOfDay,
        lastSuccess = lastSuccess,
        nextRun = nextRun,
    )

    // ------------------------------------------------------------ 档位映射

    @Test
    fun `三档磁盘短串逐字映射到页面枚举`() {
        assertEquals(CourseAutoRefreshMode.EVERY_LAUNCH, state(modeValue = "everyLaunch").mode)
        assertEquals(CourseAutoRefreshMode.INTERVAL_HOURS, state(modeValue = "intervalHours").mode)
        assertEquals(CourseAutoRefreshMode.DAILY_AT, state(modeValue = "dailyAt").mode)
    }

    @Test
    fun `认不出的档位按每次打开时处理`() {
        // 人推：盘上是脏值（手改 JSON / 老版本）时不能把整块变成「没有档位选中」，
        // Dart `CourseAutoRefreshMode.fromName` 的容错口径就是回落 everyLaunch。
        assertEquals(CourseAutoRefreshMode.EVERY_LAUNCH, state(modeValue = "").mode)
        assertEquals(CourseAutoRefreshMode.EVERY_LAUNCH, state(modeValue = "daily_at").mode)
        assertEquals(CourseAutoRefreshMode.EVERY_LAUNCH, state(modeValue = "EVERY_LAUNCH").mode)
    }

    // ------------------------------------------------------------ 两个时刻标签

    @Test
    fun `时刻标签照短格式 月不补零 日补零`() {
        // `_shortDateTime`：month 用 padLeft(1) ⇒ 9 月写 "9"、12 月写 "12"；
        // day 用 padLeft(2) ⇒ 2 号写 "02"；时与分都补零。
        val s = state(
            lastSuccess = LocalDateTime.of(2026, 9, 21, 7, 30),
            nextRun = LocalDateTime.of(2026, 10, 2, 18, 5),
        )
        assertEquals("9-21 07:30", s.lastSuccessLabel)
        assertEquals("10-02 18:05", s.nextRunLabel)
    }

    @Test
    fun `没有台账时两段标签都是 null`() {
        val s = state(lastSuccess = null, nextRun = null)
        assertNull(s.lastSuccessLabel)
        assertNull(s.nextRunLabel)
    }

    @Test
    fun `零点整与午夜前一分钟都按 24 小时制`() {
        val s = state(
            lastSuccess = LocalDateTime.of(2026, 1, 1, 0, 0),
            nextRun = LocalDateTime.of(2026, 12, 31, 23, 59),
        )
        assertEquals("1-01 00:00", s.lastSuccessLabel)
        assertEquals("12-31 23:59", s.nextRunLabel)
    }

    // ------------------------------------------------------------ 透传

    @Test
    fun `开关 间隔 时刻原样透传`() {
        val s = state(
            enabled = true,
            modeValue = "intervalHours",
            intervalHours = 168,
            dailyMinuteOfDay = 23 * 60 + 59,
        )
        assertTrue(s.enabled)
        assertEquals(168, s.intervalHours)
        assertEquals(23 * 60 + 59, s.dailyMinuteOfDay)
        val off = state(enabled = false)
        assertEquals(false, off.enabled)
    }

    // ------------------------------------------------ 喂进 spec：整块真的出现

    @Test
    fun `喂了状态后整块按 Dart 顺序出现`() {
        // course_auto_refresh_settings.dart:100-165：分组标题 → 开关 → 档位下拉 →
        // （间隔模式才有滑杆）→ 定时行 → 立即试一次 → 底部灰字。
        val page = SettingsGeneralPage.spec(
            SettingsPageState(autoRefresh = state(modeValue = "dailyAt")),
        )
        assertEquals(
            listOf(
                "general.autoRefresh.switch",
                "general.autoRefresh.mode",
                "general.autoRefresh.dailyTime",
                "general.autoRefresh.tryNow",
            ),
            page.group("general.autoRefresh").childRowIds(),
        )
        assertEquals(
            "courseAutoRefreshSectionTitle",
            page.flatten().filterIsInstance<SettingsLabel>().single().textKey,
        )
    }

    @Test
    fun `灰字拼出上次与下次两段`() {
        val page = SettingsGeneralPage.spec(
            SettingsPageState(
                autoRefresh = state(
                    lastSuccess = LocalDateTime.of(2026, 9, 21, 7, 30),
                    nextRun = LocalDateTime.of(2026, 9, 22, 7, 30),
                ),
            ),
        )
        val summary = page.flatten().filterIsInstance<SettingsDescription>().single()
        assertEquals("上次 9-21 07:30 · 下次约 9-22 07:30", summary.text)
    }

    @Test
    fun `从没成功过时灰字只说还没成功`() {
        val page = SettingsGeneralPage.spec(
            SettingsPageState(autoRefresh = state(lastSuccess = null, nextRun = null)),
        )
        val summary = page.flatten().filterIsInstance<SettingsDescription>().single()
        assertEquals("还没成功更新过", summary.text)
        assertEquals("courseAutoRefreshSummaryNever", summary.textKey)
    }
}
