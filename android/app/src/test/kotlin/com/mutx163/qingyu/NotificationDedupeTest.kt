package com.mutx163.qingyu

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [NotificationDedupe] 纯逻辑单测（JVM 直测）。
 *
 * 钉的是用户报的「2 小时 307 条通知、95.8% 内容没变」：
 * 内容签名逐字段比对，不变就不发；同时验证**不泄漏状态**——换课表后能发、
 * 换回旧内容仍能发（不会因为「以前见过」被永久挡掉）。
 */
class NotificationDedupeTest {

    private fun sig(
        text: String = "还有 3 分钟",
        critical: String = "08:00",
        quickAction: String = "none",
        progress: Int = -1,
    ) = NotificationContentSignature(text, critical, quickAction, progress)

    @Test
    fun `第一次没有上一次签名时必须发`() {
        assertTrue(NotificationDedupe.shouldPost(previous = null, next = sig()))
    }

    @Test
    fun `四个字段完全一致时不重发`() {
        assertFalse(NotificationDedupe.shouldPost(previous = sig(), next = sig()))
    }

    @Test
    fun `倒计时文本变化要发`() {
        assertTrue(
            NotificationDedupe.shouldPost(
                previous = sig(text = "还有 3 分钟"),
                next = sig(text = "还有 2 分钟"),
            ),
        )
    }

    @Test
    fun `关键时间文本变化要发`() {
        assertTrue(
            NotificationDedupe.shouldPost(
                previous = sig(critical = "08:00"),
                next = sig(critical = "08:00 - 09:40"),
            ),
        )
    }

    @Test
    fun `快捷按钮状态变化要发`() {
        assertTrue(
            NotificationDedupe.shouldPost(
                previous = sig(quickAction = "静音:未生效"),
                next = sig(quickAction = "静音:生效中"),
            ),
        )
    }

    @Test
    fun `进度单位变化要发`() {
        assertTrue(
            NotificationDedupe.shouldPost(
                previous = sig(progress = 500),
                next = sig(progress = 501),
            ),
        )
    }

    @Test
    fun `换课表后再换回旧内容仍会发（状态不泄漏）`() {
        val courseA = sig(text = "高等数学")
        val courseB = sig(text = "大学物理")
        // A -> B：变，要发
        assertTrue(NotificationDedupe.shouldPost(previous = courseA, next = courseB))
        // B -> A：又变回来，仍要发（不能因为“以前发过 A”被挡）
        assertTrue(NotificationDedupe.shouldPost(previous = courseB, next = courseA))
    }
}
