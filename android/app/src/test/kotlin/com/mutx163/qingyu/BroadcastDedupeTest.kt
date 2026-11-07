package com.mutx163.qingyu

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [BroadcastDedupe] 的行为断言（JVM 直测）。
 *
 * 钉「一次 APPWIDGET_UPDATE 广播被 10 个 Provider 各收一遍时只处理一次」，
 * 防止 10 倍 rescheduleRefresh / updateAll 放大。
 *
 * **200ms 是经验值**（同批组件通常几十毫秒内到达）；窗口只用于合并同批，
 * 需要必达的加卡 / 首次启用来源走 `force` 绕过。
 */
class BroadcastDedupeTest {

    @Test
    fun `同一次广播的多个组件只放行第一个`() {
        val dedupe = BroadcastDedupe(windowMillis = 200)
        assertTrue("第一个组件放行", dedupe.shouldHandle(1_000))
        assertFalse("同批第二个组件必须跳过", dedupe.shouldHandle(1_001))
        assertFalse("窗口内继续跳过", dedupe.shouldHandle(1_150))
    }

    @Test
    fun `超过窗口后下一次广播再放行`() {
        val dedupe = BroadcastDedupe(windowMillis = 200)
        assertTrue(dedupe.shouldHandle(1_000))
        assertTrue("窗口外的下一次广播必须放行", dedupe.shouldHandle(1_300))
    }

    @Test
    fun `两次独立广播间隔小于窗口_第二次带新id_仍必须放行`() {
        val dedupe = BroadcastDedupe(windowMillis = 200)
        assertTrue(dedupe.shouldHandle(1_000, setOf(1)))
        assertFalse("同批重复跳过", dedupe.shouldHandle(1_001, setOf(1)))
        // 系统加卡时通常发**全量 ids**：靠「出现上次没有的新 id」判必达，而不是比数量。
        assertTrue("新 id 必然强制重排", dedupe.shouldHandle(1_100, setOf(1, 2)))
    }

    @Test
    fun `显式force仍可必达`() {
        val dedupe = BroadcastDedupe(windowMillis = 200)
        assertTrue(dedupe.shouldHandle(1_000))
        assertTrue("显式 force 必须放行", dedupe.shouldHandle(1_100, force = true))
    }
}
