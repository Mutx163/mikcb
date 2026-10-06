package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * 用户刚授予通知权限后，周报该不该补投、按什么时间点补投（第 30 轮）。
 *
 * `handleFire` 在投不出去时**故意不推进** `KEY_FIRE_AT`（WeeklyReportScheduler.kt:158-162，
 * 注释写的是"next schedule pass retries"），但一次性闹钟已经被消耗掉，
 * 而 `MainActivity.onRequestPermissionsResult`（:1826-1832）授权成功后
 * 只重排考试提醒、没有周报 —— 于是首装时拒授权的用户，那一次的周报要等到
 * 下次改课表或重启手机才会再响。
 *
 * 补投不能直接调 `handleBootReschedule`：它 :135-143 一进来就把 `fireAt <= now`
 * 的待投时间点 `+N 周` 顺延掉，刚点"允许"反而错过这一份。本文件把这条差异钉住。
 */
class WeeklyReportPermissionGrantTest {
    @Test
    fun rearmsAtTheStoredFireTimeWithoutRollingForward() {
        val stored = 1_700_000_000_000L
        assertEquals(
            "补投必须按存量时间点重排（过期由 handleFire 的 24h 窗口决定）",
            stored,
            WeeklyReportScheduler.pendingFireMillisForGrant(
                enabled = true,
                fireAtMillis = stored,
            ),
        )
    }

    @Test
    fun refusesWhenReportDisabled() {
        assertNull(
            WeeklyReportScheduler.pendingFireMillisForGrant(
                enabled = false,
                fireAtMillis = 1_700_000_000_000L,
            ),
        )
    }

    /** 从未排过（prefs 里是默认 0）时不能重排：AlarmManager 会收到一个 1970 年的时刻。 */
    @Test
    fun refusesWhenNothingWasEverScheduled() {
        assertNull(
            WeeklyReportScheduler.pendingFireMillisForGrant(
                enabled = true,
                fireAtMillis = 0L,
            ),
        )
        assertNull(
            WeeklyReportScheduler.pendingFireMillisForGrant(
                enabled = true,
                fireAtMillis = -1L,
            ),
        )
    }

    /** 时间点**在过去**也必须照样返回 —— 这正是"刚授权要补投"的场景。 */
    @Test
    fun keepsPastFireTimeAsIs() {
        val past = System.currentTimeMillis() - 3 * 60 * 60 * 1000L
        assertEquals(
            past,
            WeeklyReportScheduler.pendingFireMillisForGrant(
                enabled = true,
                fireAtMillis = past,
            ),
        )
    }
}
