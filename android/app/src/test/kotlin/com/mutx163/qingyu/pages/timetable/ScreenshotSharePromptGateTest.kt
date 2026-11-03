package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 截屏提示三道门的纯判定（Dart `_onScreenshotDetected`，`timetable_screen.dart:939-963`）。
 *
 * 人推期望值，不从实现倒推：
 * - 开关关 / 页面不在最上层 → 永远不弹；
 * - 第一次截屏（没记过账）→ 弹；
 * - 冷却期内（< 6s）的下一张 → 不弹，**同一张之后的连拍也不叠**；
 * - 冷却一过（>= 6s）→ 再弹；
 * - 弹与不弹只差边界一毫秒也要分得清（== 6000 放行，5999 拦下）。
 */
class ScreenshotSharePromptGateTest {

    @Test
    fun `设置开关关闭时永远不弹`() {
        assertFalse(
            ScreenshotSharePromptGate.shouldShow(
                enabled = false,
                topMost = true,
                lastPromptAtMillis = null,
                nowMillis = 1_000L,
            ),
        )
    }

    @Test
    fun `页面不在最上层时不弹`() {
        // 被推入页覆盖（miuix-nav 条目级生命周期 = STARTED）：就算第一次截屏也不弹。
        assertFalse(
            ScreenshotSharePromptGate.shouldShow(
                enabled = true,
                topMost = false,
                lastPromptAtMillis = null,
                nowMillis = 1_000L,
            ),
        )
    }

    @Test
    fun `第一次截屏直接弹`() {
        assertTrue(
            ScreenshotSharePromptGate.shouldShow(
                enabled = true,
                topMost = true,
                lastPromptAtMillis = null,
                nowMillis = 50_000L,
            ),
        )
    }

    @Test
    fun `冷却期内的下一张不弹`() {
        // 3 秒前刚弹过：连拍截屏不叠提示（Dart :948-951）。
        assertFalse(
            ScreenshotSharePromptGate.shouldShow(
                enabled = true,
                topMost = true,
                lastPromptAtMillis = 10_000L,
                nowMillis = 10_000L + ScreenshotSharePromptGate.COOLDOWN_MILLIS - 1,
            ),
        )
    }

    @Test
    fun `冷却期一过再弹`() {
        assertTrue(
            ScreenshotSharePromptGate.shouldShow(
                enabled = true,
                topMost = true,
                lastPromptAtMillis = 10_000L,
                nowMillis = 10_000L + ScreenshotSharePromptGate.COOLDOWN_MILLIS,
            ),
        )
    }

    @Test
    fun `冷却边界逐毫秒对拍`() {
        val last = 100_000L
        // 5999ms：拦；6000ms 整：放行（Dart `difference < cooldown` 的开区间口径）。
        assertEquals(
            false,
            ScreenshotSharePromptGate.shouldShow(
                enabled = true,
                topMost = true,
                lastPromptAtMillis = last,
                nowMillis = last + 5_999L,
            ),
        )
        assertEquals(
            true,
            ScreenshotSharePromptGate.shouldShow(
                enabled = true,
                topMost = true,
                lastPromptAtMillis = last,
                nowMillis = last + 6_000L,
            ),
        )
    }

    @Test
    fun `提示时长与冷却期取 Dart 原值`() {
        // 提示 5 秒 < 冷却 6 秒：可见期间冷却必然没过，天然不会叠两条（Dart 同一组值）。
        assertEquals(5_000L, ScreenshotSharePromptGate.PROMPT_DURATION_MILLIS)
        assertEquals(6_000L, ScreenshotSharePromptGate.COOLDOWN_MILLIS)
    }
}
