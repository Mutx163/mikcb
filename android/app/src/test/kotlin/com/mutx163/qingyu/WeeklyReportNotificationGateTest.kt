package com.mutx163.qingyu

import android.app.NotificationManager
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 周报的通知投递门禁（第 27 轮审查）。
 *
 * `WeeklyReportScheduler.postNotification` 原先只检查 POST_NOTIFICATIONS 权限，
 * 而同仓的 `ExamReminderScheduler.kt:33-49` 与 `LiveUpdateService.kt:184-200`
 * 都写明「三个条件缺一，`notify()` 就会被系统静默丢弃」—— 只有周报这份副本没跟上。
 *
 * Android 13+ 上用户在系统设置里关掉本应用通知、或把「周报」渠道调成"不显示"时，
 * 权限依然是 granted：`notify()` 什么都没弹，函数却返回 true，
 * `onReceive` 于是按"投递成功"把 `KEY_FIRE_AT` 往后推一周并重排闹钟
 * （原 :163-170），这一周的周报永久消失 —— 用户重新打开通知也要等下周才收到。
 */
class WeeklyReportNotificationGateTest {
    @Test
    fun postsOnlyWhenAllThreeConditionsHold() {
        assertTrue(
            WeeklyReportScheduler.weeklyReportCanPostNotification(
                permissionGranted = true,
                appNotificationsEnabled = true,
                channelImportance = NotificationManager.IMPORTANCE_DEFAULT,
            ),
        )
    }

    @Test
    fun refusesWhenPermissionMissing() {
        assertFalse(
            WeeklyReportScheduler.weeklyReportCanPostNotification(
                permissionGranted = false,
                appNotificationsEnabled = true,
                channelImportance = NotificationManager.IMPORTANCE_HIGH,
            ),
        )
    }

    @Test
    fun refusesWhenAppNotificationsTurnedOff() {
        assertFalse(
            WeeklyReportScheduler.weeklyReportCanPostNotification(
                permissionGranted = true,
                appNotificationsEnabled = false,
                channelImportance = NotificationManager.IMPORTANCE_HIGH,
            ),
        )
    }

    @Test
    fun refusesWhenChannelSetToNone() {
        assertFalse(
            WeeklyReportScheduler.weeklyReportCanPostNotification(
                permissionGranted = true,
                appNotificationsEnabled = true,
                channelImportance = NotificationManager.IMPORTANCE_NONE,
            ),
        )
    }

    /** 静默渠道（IMPORTANCE_MIN/LOW）仍然会弹，只是不打扰 —— 不该按"投不出去"处理。 */
    @Test
    fun allowsQuietChannels() {
        assertTrue(
            WeeklyReportScheduler.weeklyReportCanPostNotification(
                permissionGranted = true,
                appNotificationsEnabled = true,
                channelImportance = NotificationManager.IMPORTANCE_MIN,
            ),
        )
    }
}
