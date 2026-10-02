package com.mutx163.qingyu

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 自动课前动作的时间窗（回归钉，2026-10-02）。
 *
 * 服务侧原来只判下界 `now >= startAt - lead`，没有上界；调度侧
 * `liveSchedulerQuickActionIsDue` 却明确写着 `now >= startAt → false`（注释
 * "Window closed"）。两者相反的后果：08:00-09:40 的课、自动静音提前 20 分钟，
 * 用户 09:00 才把超级岛拉起来 → 服务当场把铃声设为静音，并把恢复点排到 09:40，
 * 用户正在上课却被静音半节课。
 */
class LiveUpdateAutoQuickActionTest {
    private val startAt = 1_000_000_000_000L
    private val lead = 20 * 60_000L

    @Test
    fun firesInsideTheBeforeClassWindow() {
        assertTrue(
            liveSchedulerAutoQuickActionIsDue(
                leadMillis = lead,
                action = BeforeClassQuickActionRestore.ACTION_SILENT,
                startAtMillis = startAt,
                nowMillis = startAt - lead,
            ),
        )
        assertTrue(
            liveSchedulerAutoQuickActionIsDue(
                leadMillis = lead,
                action = BeforeClassQuickActionRestore.ACTION_SILENT,
                startAtMillis = startAt,
                nowMillis = startAt - 1_000L,
            ),
        )
    }

    @Test
    fun doesNotFireTooEarly() {
        assertFalse(
            liveSchedulerAutoQuickActionIsDue(
                leadMillis = lead,
                action = BeforeClassQuickActionRestore.ACTION_SILENT,
                startAtMillis = startAt,
                nowMillis = startAt - lead - 1_000L,
            ),
        )
    }

    // 这条就是原来的缺陷：上课时点起岛，绝不能把手机静音。
    @Test
    fun doesNotFireOnceClassHasStarted() {
        assertFalse(
            liveSchedulerAutoQuickActionIsDue(
                leadMillis = lead,
                action = BeforeClassQuickActionRestore.ACTION_SILENT,
                startAtMillis = startAt,
                nowMillis = startAt,
            ),
        )
        assertFalse(
            liveSchedulerAutoQuickActionIsDue(
                leadMillis = lead,
                action = BeforeClassQuickActionRestore.ACTION_SILENT,
                startAtMillis = startAt,
                nowMillis = startAt + 60 * 60_000L,
            ),
        )
    }

    @Test
    fun respectsDisabledSwitches() {
        assertFalse(
            liveSchedulerAutoQuickActionIsDue(
                leadMillis = 0L,
                action = BeforeClassQuickActionRestore.ACTION_SILENT,
                startAtMillis = startAt,
                nowMillis = startAt - 1_000L,
            ),
        )
        assertFalse(
            liveSchedulerAutoQuickActionIsDue(
                leadMillis = lead,
                action = BeforeClassQuickActionRestore.ACTION_NONE,
                startAtMillis = startAt,
                nowMillis = startAt - 1_000L,
            ),
        )
    }
}
