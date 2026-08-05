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
import org.json.JSONArray
import org.json.JSONObject

/**
 * Schedules one-shot exam reminder notifications via AlarmManager.
 *
 * Flutter owns the exam source of truth and pushes a full fire list on every
 * CRUD / profile / cold-start reconcile. Native persists that list so boot and
 * time-zone changes can re-arm alarms without Flutter.
 */
object ExamReminderScheduler {
    private const val TAG = "ExamReminder"
    private const val PREFS_NAME = "exam_reminder_prefs"
    private const val KEY_SNAPSHOT_JSON = "snapshot_json"
    const val CHANNEL_ID = "exam_reminder_channel"
    const val ACTION_FIRE = "com.mutx163.qingyu.ACTION_EXAM_REMINDER_FIRE"
    private const val EXTRA_REQUEST_CODE = "requestCode"
    private const val EXTRA_EXAM_ID = "examId"
    private const val EXTRA_OFFSET_MINUTES = "offsetMinutes"
    private const val EXTRA_TITLE = "title"
    private const val EXTRA_BODY = "body"
    private const val OVERDUE_DELIVERY_WINDOW_MILLIS = 24L * 60L * 60L * 1000L

    data class Fire(
        val examId: String,
        val offsetMinutes: Int,
        val fireAtMillis: Long,
        val examStartMillis: Long,
        val title: String,
        val body: String,
        val requestCode: Int,
    )

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) {
            return
        }
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.notification_channel_exam_reminder_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = context.getString(R.string.notification_channel_exam_reminder_desc)
        }
        manager.createNotificationChannel(channel)
    }

    fun reconcile(
        context: Context,
        firesPayload: List<*>,
        activeExamIds: Set<String> = emptySet(),
        activeFireKeys: Set<String>? = null,
    ) {
        ensureChannel(context)
        val appContext = context.applicationContext
        val newFires = parseFires(firesPayload)
        val oldFires = loadFires(appContext)
        cancelFires(appContext, oldFires)

        val nowMillis = System.currentTimeMillis()
        val futureFires = newFires.filter { it.fireAtMillis > nowMillis - 30_000L }
        val futureRequestCodes = futureFires.mapTo(mutableSetOf()) { it.requestCode }
        val failedOverdueFires = oldFires.mapNotNull { fire ->
            val originalFireAt = originalFireAtMillis(fire)
            val isRecentFailure = originalFireAt <= nowMillis &&
                originalFireAt > nowMillis - OVERDUE_DELIVERY_WINDOW_MILLIS
            val isActive = if (activeFireKeys != null) {
                fireKey(fire) in activeFireKeys
            } else {
                fire.examId in activeExamIds
            }
            if (
                !isActive ||
                fire.requestCode in futureRequestCodes ||
                !isRecentFailure
            ) {
                null
            } else {
                // Successful notifications remove themselves from oldFires.
                // Only a retained entry can represent a permission/posting
                // failure, so retry it once the app reconciles again.
                fire.copy(fireAtMillis = nowMillis + 1_000L)
            }
        }
        val schedulableFires = futureFires + failedOverdueFires
        for (fire in schedulableFires) {
            scheduleAlarm(appContext, fire)
        }
        persistFires(appContext, schedulableFires)
        Log.d(TAG, "reconcile scheduled=${schedulableFires.size} cancelledOld=${oldFires.size}")
    }

    fun clear(context: Context) {
        val appContext = context.applicationContext
        cancelFires(appContext, loadFires(appContext))
        appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_SNAPSHOT_JSON)
            .apply()
    }

    fun handleBootReschedule(context: Context) {
        ensureChannel(context)
        val appContext = context.applicationContext
        val fires = loadFires(appContext)
        if (fires.isEmpty()) {
            return
        }
        cancelFires(appContext, fires)
        val nowMillis = System.currentTimeMillis()
        val rearmed = fires.mapNotNull { fire ->
            val fireAt = originalFireAtMillis(fire)
            if (fireAt <= nowMillis - OVERDUE_DELIVERY_WINDOW_MILLIS) {
                null
            } else if (fireAt <= nowMillis) {
                fire.copy(fireAtMillis = nowMillis + 1_000L)
            } else {
                fire.copy(fireAtMillis = fireAt)
            }
        }
        for (fire in rearmed) {
            scheduleAlarm(appContext, fire)
        }
        persistFires(appContext, rearmed)
        Log.d(TAG, "boot reschedule count=${rearmed.size}")
    }

    private fun originalFireAtMillis(fire: Fire): Long {
        return if (fire.examStartMillis > 0L && fire.offsetMinutes > 0) {
            fire.examStartMillis - fire.offsetMinutes * 60_000L
        } else {
            fire.fireAtMillis
        }
    }

    private fun fireKey(fire: Fire): String {
        return "${fire.examId}#${fire.offsetMinutes}"
    }

    fun handleFire(context: Context, intent: Intent) {
        ensureChannel(context)
        val appContext = context.applicationContext
        val requestCode = intent.getIntExtra(EXTRA_REQUEST_CODE, -1)
        val examId = intent.getStringExtra(EXTRA_EXAM_ID).orEmpty()
        val offsetMinutes = intent.getIntExtra(EXTRA_OFFSET_MINUTES, 0)

        // Only deliver fires that are still in the persisted schedule. Receiver is
        // exported for BOOT_COMPLETED etc.; never trust Intent extras alone or an
        // external app can forge exam-reminder notifications.
        val scheduled = loadFires(appContext)
        val matched = scheduled.firstOrNull {
            it.requestCode == requestCode ||
                (examId.isNotBlank() && it.examId == examId && it.offsetMinutes == offsetMinutes)
        }
        if (matched == null) {
            Log.w(TAG, "drop fire: not scheduled requestCode=$requestCode examId=$examId")
            return
        }

        // Prefer persisted copy over Intent extras so spoofed payloads cannot override.
        val title = matched.title.takeIf { it.isNotBlank() }
            ?: appContext.getString(R.string.notification_exam_reminder_default_title)
        val body = matched.body.ifBlank {
            appContext.getString(R.string.notification_exam_reminder_default_body)
        }

        val posted = postNotification(
            context = appContext,
            notificationId = if (matched.requestCode != 0) matched.requestCode else matched.examId.hashCode(),
            title = title,
            body = body,
        )

        // Only drop the fire after a successful notify. If POST_NOTIFICATIONS is
        // denied (or NotificationManager is unavailable), keep the entry so the
        // user can still receive it after granting permission / reboot.
        if (!posted) {
            Log.w(TAG, "keep fire after notify failure requestCode=$requestCode examId=$examId")
            return
        }
        val remaining = scheduled.filterNot {
            it.requestCode == matched.requestCode ||
                (it.examId == matched.examId && it.offsetMinutes == matched.offsetMinutes)
        }
        persistFires(appContext, remaining)
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
                putExtra("open_route", "/exams")
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
            .setCategory(Notification.CATEGORY_REMINDER)
            .setPriority(Notification.PRIORITY_DEFAULT)
            .build()

        manager.notify(notificationId, notification)
        return true
    }

    private fun scheduleAlarm(context: Context, fire: Fire) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: return
        val pendingIntent = buildFirePendingIntent(context, fire)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        fire.fireAtMillis,
                        pendingIntent,
                    )
                } else {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        fire.fireAtMillis,
                        pendingIntent,
                    )
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    fire.fireAtMillis,
                    pendingIntent,
                )
            } else {
                @Suppress("DEPRECATION")
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    fire.fireAtMillis,
                    pendingIntent,
                )
            }
        } catch (error: SecurityException) {
            Log.w(TAG, "scheduleAlarm denied for ${fire.requestCode}", error)
            try {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    fire.fireAtMillis,
                    pendingIntent,
                )
            } catch (fallbackError: Exception) {
                Log.w(TAG, "fallback schedule failed", fallbackError)
            }
        }
    }

    private fun cancelFires(context: Context, fires: List<Fire>) {
        if (fires.isEmpty()) {
            return
        }
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: return
        for (fire in fires) {
            alarmManager.cancel(buildFirePendingIntent(context, fire))
        }
    }

    private fun buildFirePendingIntent(context: Context, fire: Fire): PendingIntent {
        val intent = Intent(context, ExamReminderReceiver::class.java).apply {
            action = ACTION_FIRE
            putExtra(EXTRA_REQUEST_CODE, fire.requestCode)
            putExtra(EXTRA_EXAM_ID, fire.examId)
            putExtra(EXTRA_OFFSET_MINUTES, fire.offsetMinutes)
            putExtra(EXTRA_TITLE, fire.title)
            putExtra(EXTRA_BODY, fire.body)
        }
        return PendingIntent.getBroadcast(
            context,
            fire.requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun parseFires(payload: List<*>): List<Fire> {
        return payload.mapNotNull { raw ->
            val map = raw as? Map<*, *> ?: return@mapNotNull null
            val examId = map["examId"] as? String ?: return@mapNotNull null
            val offsetMinutes = (map["offsetMinutes"] as? Number)?.toInt() ?: return@mapNotNull null
            val fireAtMillis = (map["fireAtMillis"] as? Number)?.toLong() ?: return@mapNotNull null
            val examStartMillis = (map["examStartMillis"] as? Number)?.toLong() ?: 0L
            val title = map["title"] as? String ?: ""
            val body = map["body"] as? String ?: ""
            val requestCode = (map["requestCode"] as? Number)?.toInt() ?: return@mapNotNull null
            Fire(
                examId = examId,
                offsetMinutes = offsetMinutes,
                fireAtMillis = fireAtMillis,
                examStartMillis = examStartMillis,
                title = title,
                body = body,
                requestCode = requestCode,
            )
        }
    }

    private fun loadFires(context: Context): List<Fire> {
        val json = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_SNAPSHOT_JSON, null)
            ?: return emptyList()
        return try {
            val root = JSONObject(json)
            val array = root.optJSONArray("fires") ?: return emptyList()
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    add(
                        Fire(
                            examId = item.optString("examId"),
                            offsetMinutes = item.optInt("offsetMinutes"),
                            fireAtMillis = item.optLong("fireAtMillis"),
                            examStartMillis = item.optLong("examStartMillis"),
                            title = item.optString("title"),
                            body = item.optString("body"),
                            requestCode = item.optInt("requestCode"),
                        ),
                    )
                }
            }.filter { it.examId.isNotBlank() && it.requestCode != 0 }
        } catch (error: Exception) {
            Log.w(TAG, "loadFires failed", error)
            emptyList()
        }
    }

    private fun persistFires(context: Context, fires: List<Fire>) {
        val array = JSONArray()
        for (fire in fires) {
            array.put(
                JSONObject().apply {
                    put("examId", fire.examId)
                    put("offsetMinutes", fire.offsetMinutes)
                    put("fireAtMillis", fire.fireAtMillis)
                    put("examStartMillis", fire.examStartMillis)
                    put("title", fire.title)
                    put("body", fire.body)
                    put("requestCode", fire.requestCode)
                },
            )
        }
        val payload = JSONObject()
            .put("version", 1)
            .put("updatedAtMillis", System.currentTimeMillis())
            .put("fires", array)
            .toString()
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SNAPSHOT_JSON, payload)
            .apply()
    }
}

class ExamReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            -> ExamReminderScheduler.handleBootReschedule(context)
            ExamReminderScheduler.ACTION_FIRE ->
                ExamReminderScheduler.handleFire(context, intent)
        }
    }
}
