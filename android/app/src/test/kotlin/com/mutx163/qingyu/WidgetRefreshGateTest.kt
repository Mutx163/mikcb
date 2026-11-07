package com.mutx163.qingyu

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [WidgetRefreshGate] 纯逻辑单测（JVM 直测，不需要 Android）。
 *
 * 钉的是用户报的耗电问题里最直接的一条判据：
 * 「桌面上还有没有小部件实例，决定要不要继续调度刷新」。
 */
class WidgetRefreshGateTest {

    @Test
    fun `全部 Provider 无实例时不调度`() {
        assertFalse(WidgetRefreshGate.shouldSchedule(listOf(0, 0, 0, 0)))
    }

    @Test
    fun `只要有一个 Provider 有实例就继续调度`() {
        assertTrue(WidgetRefreshGate.shouldSchedule(listOf(0, 0, 3, 0)))
        assertTrue(WidgetRefreshGate.shouldSchedule(listOf(1)))
    }

    @Test
    fun `空列表（没有注册任何 Provider）不调度`() {
        assertFalse(WidgetRefreshGate.shouldSchedule(emptyList()))
    }
}
