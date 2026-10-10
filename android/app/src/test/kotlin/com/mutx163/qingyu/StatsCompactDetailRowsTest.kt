package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 统计方卡（2×2）明细行「显示几行」的预算判据守卫。
 *
 * 背景：原先只按 profile.isShort（高度 <150dp）拍阈值，用户的 2×2 格位报高
 * 落在阈值之上但内容+双层内边距装不下，最后一行「已上 N%」被垂直居中布局
 * 裁出卡外（用户真机截图）。改为按「格位高 − 双层内边距 vs 内容估高」分档：
 * 装得下全量六行 → 2 行明细；只装得下五行 → 1 行；再小 → 0 行。
 *
 * 期望值全部按 adaptiveVerticalPaddingValue 的公式手工推算
 * （width=120、heightAdjustment=-11 时根边距 = 25 + min((h−120)/4, 18)），
 * 不是从实现抄的。
 */
class StatsCompactDetailRowsTest {

    private fun profile(widthDp: Int, heightDp: Int) =
        TodayWidgetSizeProfile(widthDp = widthDp, heightDp = heightDp)

    @Test
    fun standardSquareGetsZeroDetailRows() {
        // 2×2 常见格位（h≈150–216）：根边距 32–43dp + 卡片 14dp ×2 之后，
        // 可用 58–102dp，连五行内容（108dp）都装不下 → 明细全收，
        // 换来核心四行完整不被裁（用户截图里「已上 N%」半截就是这一档漏网）。
        assertEquals(0, TodayWidgetSupport.statsCompactDetailRowCount(profile(120, 150), -11))
        assertEquals(0, TodayWidgetSupport.statsCompactDetailRowCount(profile(120, 190), -11))
        assertEquals(0, TodayWidgetSupport.statsCompactDetailRowCount(profile(120, 216), -11))
    }

    @Test
    fun tallerSquareGrowsBackDetailRows() {
        // 可用 = h − 114（h ≥ 192 后根边距到顶 43dp）：
        // h=230 → 116 → 只装得下五行（108）→ 1 行；h=250 → 136 → 六行（130）→ 2 行。
        assertEquals(1, TodayWidgetSupport.statsCompactDetailRowCount(profile(120, 230), -11))
        assertEquals(2, TodayWidgetSupport.statsCompactDetailRowCount(profile(120, 250), -11))
        assertEquals(2, TodayWidgetSupport.statsCompactDetailRowCount(profile(120, 300), -11))
    }

    @Test
    fun userHeightAdjustmentParticipatesInBudget() {
        // 同一块 220dp 格位：默认微调（-11 → 根边距 43dp）可用 106 → 0 行；
        // 用户调到 +29（根边距收到 3dp）可用 186 → 2 行。微调旋钮必须参与预算。
        assertEquals(0, TodayWidgetSupport.statsCompactDetailRowCount(profile(120, 220), -11))
        assertEquals(2, TodayWidgetSupport.statsCompactDetailRowCount(profile(120, 220), 29))
    }

    @Test
    fun wideShortStripGetsZero() {
        // 4×1 横条：矮格位判据本身就该给 0（Provider 还有 isShort 的直收兜底）。
        assertEquals(0, TodayWidgetSupport.statsCompactDetailRowCount(profile(250, 60), -11))
    }
}
