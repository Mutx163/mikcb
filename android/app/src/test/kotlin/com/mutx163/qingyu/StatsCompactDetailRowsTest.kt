package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 统计方卡（2×2）明细行「显示几行」的预算判据守卫。
 *
 * 学期进度百分比已并入进度条同一行，不再按整行参与高度预算。这里只验证
 * 「核心四行 vs 核心四行 + 必修·选修」能否装进格位可用高度。
 *
 * 期望值全部按 adaptiveVerticalPaddingValue 的公式手工推算
 * （width=120、heightAdjustment=-11 时根边距 = 25 + min((h−120)/4, 18)），
 * 再额外预留大字体超支 12dp；不是从实现抄的。
 */
class StatsCompactDetailRowsTest {

    private fun profile(widthDp: Int, heightDp: Int) =
        TodayWidgetSizeProfile(widthDp = widthDp, heightDp = heightDp)

    @Test
    fun standardSquareGetsZeroDetailRows() {
        // 2×2 常见格位（h≈150–216）：根边距 32–43dp + 卡片 14dp ×2 之后，
        // 再减大字体预留 12dp，可用 46–90dp；五行估高 95dp 装不下 → 明细收起，
        // 换来核心四行完整不被裁（用户截图里「已上 N%」半截就是这一档漏网）。
        assertEquals(0, TodayWidgetSupport.statsCompactDetailRowCount(profile(120, 150), -11))
        assertEquals(0, TodayWidgetSupport.statsCompactDetailRowCount(profile(120, 190), -11))
        assertEquals(0, TodayWidgetSupport.statsCompactDetailRowCount(profile(120, 216), -11))
    }

    @Test
    fun tallerSquareGrowsBackNatureRow() {
        // 可用 = h − 114 − 12（h ≥ 192 后根边距到顶 43dp）：
        // h=230 → 104 → 五行（95dp）装得下 → 必修·选修回来。
        assertEquals(1, TodayWidgetSupport.statsCompactDetailRowCount(profile(120, 230), -11))
        assertEquals(1, TodayWidgetSupport.statsCompactDetailRowCount(profile(120, 250), -11))
        assertEquals(1, TodayWidgetSupport.statsCompactDetailRowCount(profile(120, 300), -11))
    }

    @Test
    fun userHeightAdjustmentParticipatesInBudget() {
        // 同一块 220dp 格位：默认微调（-11 → 根边距 43dp）可用 94 → 0 行；
        // 用户调到 +29（根边距收到 3dp）可用 192 → 1 行。微调旋钮必须参与预算。
        assertEquals(0, TodayWidgetSupport.statsCompactDetailRowCount(profile(120, 220), -11))
        assertEquals(1, TodayWidgetSupport.statsCompactDetailRowCount(profile(120, 220), 29))
    }

    @Test
    fun wideShortStripGetsZero() {
        // 4×1 横条：矮格位判据本身就该给 0（Provider 还有 isShort 的直收兜底）。
        assertEquals(0, TodayWidgetSupport.statsCompactDetailRowCount(profile(250, 60), -11))
    }
}
