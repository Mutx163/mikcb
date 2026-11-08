package com.mutx163.qingyu

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 钉住「刷新档位由设置页的倒计时开关决定」这一条：
 *
 * - 默认 / 关闭倒计时 ⇒ **不排**每分钟心跳（省电档，与同类开源课表 App 同档）；
 * - 用户显式打开倒计时 ⇒ 上课中、快上课两个状态才排心跳。
 *
 * 这不是纯样式偏好：心跳就是那条 `RTC_WAKEUP` 精确闹钟（用户实测约 700 次/天），
 * 谁把它从开关上摘掉，谁就把「用户没要、电照耗」放回来了。
 */
class WidgetRefreshPolicyTest {

    @Test
    fun `关闭倒计时时任何状态都不排心跳`() {
        listOf("ongoing", "upcoming", "no_course", "completed", "").forEach { state ->
            assertFalse(
                "showCountdown=false、state=$state 时不该排每分钟心跳",
                WidgetRefreshPolicy.shouldScheduleMinuteHeartbeat(showCountdown = false, state = state),
            )
        }
    }

    @Test
    fun `打开倒计时只有上课中与快上课排心跳`() {
        assertTrue(
            WidgetRefreshPolicy.shouldScheduleMinuteHeartbeat(showCountdown = true, state = "ongoing"),
        )
        assertTrue(
            WidgetRefreshPolicy.shouldScheduleMinuteHeartbeat(showCountdown = true, state = "upcoming"),
        )
        listOf("no_course", "completed", "").forEach { state ->
            assertFalse(
                "state=$state 不该排心跳（没有倒计时可走字）",
                WidgetRefreshPolicy.shouldScheduleMinuteHeartbeat(showCountdown = true, state = state),
            )
        }
    }
}
