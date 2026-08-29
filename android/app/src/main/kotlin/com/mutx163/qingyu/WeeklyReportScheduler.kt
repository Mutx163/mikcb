package com.mutx163.qingyu

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Schedules a periodic weekly-report notification (default Sunday evening).
 *
 * Flutter owns the report content and pushes {enabled, fireAtMillis, title,
 * body} whenever the toggle or the timetable changes. Native persists the
 * next fire time so boot / time-zone changes can re-arm the alarm; after a
 * successful post the fire point automatically rolls forward one week.
 */
object WeeklyReportScheduler {
    private const val TAG = "WeeklyReport"
    private const val PREFS_NAME = "weekly_report_prefs"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_FIRE_AT = "fire_at_millis"
    private const val KEY_TITLE = "title"
    private const val KEY_BODY = "body"
    const val CHANNEL_ID = "weekly_report_channel"
    const val ACTION_FIRE = "com.mutx163.qingyu.ACTION_WEEKLY_REPORT_FIRE"
    private const val REQUEST_CODE = 0x5701
    private const val WEEK_MILLIS = 7L * 24L * 60L * 60L * 1000L

    private data class ScheduledReport(
        val enabled: Boolean,
        val fireAtMillis: Long,
        val title: String,
        val body: String,
    )

    private fun readPrefs(context: Context): ScheduledReport {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return ScheduledReport(
            enabled = prefs.getBoolean(KEY_ENABLED, false),
            fireAtMillis = prefs.getLong(KEY_FIRE_AT, 0L),
            title = prefs.getString(KEY_TITLE, "").orEmpty(),
            body = prefs.getString(KEY_BODY, "").orEmpty(),
        )
    }

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) {
            return
        }
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.notification_channel_weekly_report_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = context.getString(R.string.notification_channel_weekly_report_desc)
        }
        manager.createNotificationChannel(channel)
    }

    fun scheduleNext(
        context: Context,
        enabled: Boolean,
        fireAtMillis: Long,
        title: String,
        body: String,
    ) {
        ensureChannel(context)
        val appContext = context.applicationContext
        appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, enabled)
            .putLong(KEY_FIRE_AT, fireAtMillis)
            .putString(KEY_TITLE, title)
            .putString(KEY_BODY, body)
            .apply()
        if (enabled && fireAtMillis > 0L) {
            scheduleAlarm(appContext, fireAtMillis)
            Log.d(TAG, "scheduled next report at $fireAtMillis")
        } else {
            cancelAlarm(appContext)
            Log.d(TAG, "weekly report disabled")
        }
    }

    fun cancel(context: Context) {
        val appContext = context.applicationContext
        cancelAlarm(appContext)
        appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, false)
            .remove(KEY_FIRE_AT)
            .remove(KEY_TITLE)
            .remove(KEY_BODY)
            .apply()
    }

    /** Boot / time change: re-arm the persisted fire point, rolling past dates forward. */
    fun handleBootReschedule(context: Context) {
        ensureChannel(context)
        val appContext = context.applicationContext
        val report = readPrefs(appContext)
        if (!report.enabled || report.fireAtMillis <= 0L) {
            return
        }
        var fireAt = report.fireAtMillis
        val nowMillis = System.currentTimeMillis()
        // Missed while the app was closed: roll forward to the next occurrence.
        if (fireAt <= nowMillis) {
            val skipped = (nowMillis - fireAt) / WEEK_MILLIS + 1
            fireAt += skipped * WEEK_MILLIS
            appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putLong(KEY_FIRE_AT, fireAt)
                .apply()
        }
        scheduleAlarm(appContext, fireAt)
        Log.d(TAG, "boot reschedule fireAt=$fireAt")
    }

    fun handleFire(context: Context, intent: Intent) {
        ensureChannel(context)
        val appContext = context.applicationContext
        // Never trust Intent extras alone: exported receiver must verify state.
        val report = readPrefs(appContext)
        if (!report.enabled) {
            Log.w(TAG, "drop fire: weekly report disabled")
            return
        }
        val nowMillis = System.currentTimeMillis()
        val fireWindowStart = report.fireAtMillis - 30L * 60L * 1000L
        val fireWindowEnd = report.fireAtMillis + 24L * 60L * 60L * 1000L
        if (nowMillis < fireWindowStart || nowMillis > fireWindowEnd) {
            Log.w(TAG, "drop fire: outside window fireAt=${report.fireAtMillis} now=$nowMillis")
            handleBootReschedule(appContext)
            return
        }

        val title = report.title.takeIf { it.isNotBlank() }
            ?: appContext.getString(R.string.notification_weekly_report_default_title)
        val body = report.body.ifBlank {
            appContext.getString(R.string.notification_weekly_report_default_body)
        }
        val posted = postNotification(
            context = appContext,
            notificationId = REQUEST_CODE,
            title = title,
            body = body,
        )
        if (!posted) {
            // POST_NOTIFICATIONS denied: keep the entry; next schedule pass retries.
            Log.w(TAG, "keep report after notify failure")
            return
        }

        // Success: roll forward one week so the report repeats.
        val nextFireAt = report.fireAtMillis + WEEK_MILLIS
        appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putLong(KEY_FIRE_AT, nextFireAt)
            .apply()
        scheduleAlarm(appContext, nextFireAt)
        Log.d(TAG, "posted weekly report; next=$nextFireAt")
    }

    private fun scheduleAlarm(context: Context, fireAtMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = buildPendingIntent(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    fireAtMillis,
                    pendingIntent,
                )
            } else {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    fireAtMillis,
                    pendingIntent,
                )
            }
        } else {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                fireAtMillis,
                pendingIntent,
            )
        }
    }

    private fun cancelAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(buildPendingIntent(context))
    }

    private fun buildPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, WeeklyReportReceiver::class.java).apply {
            action = ACTION_FIRE
            component = android.content.ComponentName(context, WeeklyReportReceiver::class.java)
        }
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun postNotification(
        context: Context,
        notificationId: Int,
        title: String,
        body: String,
    ): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = context.checkSelfPermission(
                android.Manifest.permission.POST_NOTIFICATIONS,
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED
            if (!granted) {
                Log.w(TAG, "skip notify: POST_NOTIFICATIONS not granted")
                return false
            }
        }

        val contentIntent = PendingIntent.getActivity(
            context,
            notificationId,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .build()

        return try {
            manager.notify(notificationId, notification)
            true
        } catch (e: Exception) {
            Log.w(TAG, "notify failed: ${e.message}")
            false
        }
    }

}

// Manifest declares ".WeeklyReportReceiver": keep this a top-level class in this
// package. A nested class compiles to "WeeklyReportScheduler$WeeklyReportReceiver"
// and broadcast delivery crashes with ClassNotFoundException.
class WeeklyReportReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            WeeklyReportScheduler.ACTION_FIRE ->
                WeeklyReportScheduler.handleFire(context, intent)
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            -> WeeklyReportScheduler.handleBootReschedule(context)
        }
    }
}
