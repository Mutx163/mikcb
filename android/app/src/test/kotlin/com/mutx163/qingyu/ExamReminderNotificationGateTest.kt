package com.mutx163.qingyu

import android.app.NotificationManager
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 考试/上课提醒的通知投递门禁（2026-10-02 审查）。
 *
 * `ExamReminderScheduler.postNotification` 原先只检查 POST_NOTIFICATIONS 权限。
 * Android 13+ 上用户在系统设置里关掉本应用通知、或把「考试提醒」渠道调成
 * "不显示"时，这个权限依然是 granted：`notify()` 被系统静默丢弃，
 * 函数却 `return true`，`onReceive` 便按"投递成功"把那条 fire 从快照里删掉 ——
 * 那次提醒永久消失，开机重排也救不回来（而同文件 :277-279 的注释写的
 * 恰恰是"投不出去要留着，等用户授权或开机后再收"）。
 */
class ExamReminderNotificationGateTest {
    @Test
    fun postsOnlyWhenAllThreeConditionsHold() {
        assertTrue(
            ExamReminderScheduler.examReminderCanPostNotification(
                permissionGranted = true,
                appNotificationsEnabled = true,
                channelImportance = NotificationManager.IMPORTANCE_DEFAULT,
            ),
        )
    }

    @Test
    fun refusesWhenPermissionMissing() {
        assertFalse(
            ExamReminderScheduler.examReminderCanPostNotification(
                permissionGranted = false,
                appNotificationsEnabled = true,
                channelImportance = NotificationManager.IMPORTANCE_HIGH,
            ),
        )
    }

    @Test
    fun refusesWhenAppNotificationsTurnedOff() {
        // 权限 granted 但总开关关了：33+ 上这是最常见的组合。
        assertFalse(
            ExamReminderScheduler.examReminderCanPostNotification(
                permissionGranted = true,
                appNotificationsEnabled = false,
                channelImportance = NotificationManager.IMPORTANCE_DEFAULT,
            ),
        )
    }

    @Test
    fun refusesWhenChannelSilenced() {
        assertFalse(
            ExamReminderScheduler.examReminderCanPostNotification(
                permissionGranted = true,
                appNotificationsEnabled = true,
                channelImportance = NotificationManager.IMPORTANCE_NONE,
            ),
        )
    }

    @Test
    fun acceptsQuietButVisibleChannel() {
        // 静默但不隐藏（IMPORTANCE_MIN/LOW）仍会投递，不该被误判为不可用。
        assertTrue(
            ExamReminderScheduler.examReminderCanPostNotification(
                permissionGranted = true,
                appNotificationsEnabled = true,
                channelImportance = NotificationManager.IMPORTANCE_LOW,
            ),
        )
    }
}
