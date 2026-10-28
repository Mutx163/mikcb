package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 小组件刷新判据的 JVM 单测。期望值全部**人推**，与实现无关：
 *
 * - 去重 = 内容签名是否与上次相等；
 * - 跨天 = epoch day 是否变化（null 视为首刷）；
 * - 今天有课 = 今日课程数是否 > 0；
 * - 定时 tick = 跨天 或 今天有课。
 *
 * 三条关键判据各自被独立钉住，咬合探针（改坏任一条 → 对应用例翻红）见交付报告。
 */
class WidgetRefreshDecisionLogicTest {

    // ---------- 连续两次变更去重 ----------

    @Test
    fun changeDedupedOnlyWhenSignatureIdentical() {
        // 首刷（无基线）→ 刷
        assertTrue(WidgetRefreshDecisionLogic.shouldRefreshOnChange(null, "A"))
        // 连续两次相同签名 → 不刷（去重的核心诉求）
        assertFalse(WidgetRefreshDecisionLogic.shouldRefreshOnChange("A", "A"))
        // 签名变了 → 刷
        assertTrue(WidgetRefreshDecisionLogic.shouldRefreshOnChange("A", "B"))
    }

    @Test
    fun blankNewSignatureNeverRefreshes() {
        // 读不到内容（空签名）不能当成「内容变了」
        assertFalse(WidgetRefreshDecisionLogic.shouldRefreshOnChange("A", ""))
        assertFalse(WidgetRefreshDecisionLogic.shouldRefreshOnChange("A", "   "))
        assertFalse(WidgetRefreshDecisionLogic.shouldRefreshOnChange(null, ""))
    }

    // ---------- 跨天才刷新 ----------

    @Test
    fun dayChangeDetectedByEpochDay() {
        // 首刷（无基线）→ 视为跨天，必须刷一次
        assertTrue(WidgetRefreshDecisionLogic.isDayChanged(null, 100L))
        // 同一天 → 没跨天
        assertFalse(WidgetRefreshDecisionLogic.isDayChanged(100L, 100L))
        // 往后一天 / 往回一天（时区回拨）→ 都算跨天
        assertTrue(WidgetRefreshDecisionLogic.isDayChanged(100L, 101L))
        assertTrue(WidgetRefreshDecisionLogic.isDayChanged(101L, 100L))
    }

    // ---------- 今天有课才刷新 ----------

    @Test
    fun classTodayOnlyWhenCountPositive() {
        assertFalse(WidgetRefreshDecisionLogic.hasClassToday(0))
        assertFalse(WidgetRefreshDecisionLogic.hasClassToday(-3)) // 异常负值按无课
        assertTrue(WidgetRefreshDecisionLogic.hasClassToday(1))
        assertTrue(WidgetRefreshDecisionLogic.hasClassToday(5))
    }

    // ---------- 定时 tick 合成判据：跨天 或 今天有课 ----------

    @Test
    fun timeTickSkipsOnlyWhenSameDayAndNoClass() {
        // 同日无课 → 唯一跳过的情况（省电）
        assertFalse(WidgetRefreshDecisionLogic.shouldWakeOnTimeTick(0, 100L, 100L))
        // 同日有课 → 刷（课程状态会翻转）
        assertTrue(WidgetRefreshDecisionLogic.shouldWakeOnTimeTick(3, 100L, 100L))
        // 跨天无课 → 刷（换日，卡片要离开昨日态）
        assertTrue(WidgetRefreshDecisionLogic.shouldWakeOnTimeTick(0, 100L, 101L))
        // 跨天有课 → 刷
        assertTrue(WidgetRefreshDecisionLogic.shouldWakeOnTimeTick(2, 100L, 101L))
        // 首刷（无基线）即便无课也刷一次
        assertTrue(WidgetRefreshDecisionLogic.shouldWakeOnTimeTick(0, null, 100L))
    }

    // ---------- 内容签名拼接 ----------

    @Test
    fun signatureStableAndTrimmed() {
        // 相同内容 → 相同签名
        assertEquals(
            WidgetRefreshDecisionLogic.buildChangeSignature(listOf("p1", "3", "c1")),
            WidgetRefreshDecisionLogic.buildChangeSignature(listOf("p1", "3", "c1")),
        )
        // 首尾空白被 trim 掉 → 不算变更
        assertEquals(
            WidgetRefreshDecisionLogic.buildChangeSignature(listOf("p1", "3")),
            WidgetRefreshDecisionLogic.buildChangeSignature(listOf(" p1 ", "3 ")),
        )
        // 顺序不同 → 不同签名（字段顺序固定，换序就是不同内容）
        assertTrue(
            WidgetRefreshDecisionLogic.buildChangeSignature(listOf("a", "b")) !=
                WidgetRefreshDecisionLogic.buildChangeSignature(listOf("b", "a")),
        )
        // 分隔符不可与字段内字符混淆：["a,b"] 与 ["a","b"] 必须不同
        assertTrue(
            WidgetRefreshDecisionLogic.buildChangeSignature(listOf("a,b")) !=
                WidgetRefreshDecisionLogic.buildChangeSignature(listOf("a", "b")),
        )
        // 空清单 → 空串
        assertEquals("", WidgetRefreshDecisionLogic.buildChangeSignature(emptyList()))
    }
}
