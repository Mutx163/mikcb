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
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.pages.PagesShellActivity
import com.mutx163.qingyu.pages.schedule.ScheduleReminderFire
import com.mutx163.qingyu.pages.schedule.ScheduleReminderLogic
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId

/**
 * 日程提醒的原生调度器（AlarmManager + 通知）。
 *
 * ## 为什么单独一套，不复用 `ExamReminderScheduler`
 *
 * `ExamReminderScheduler.reconcile` 是**整表替换**：它先取消快照里的全部闹钟再排新的。
 * Flutter 侧把考试 / 单节课 / 日程三类提醒合在同一个快照里交上来；Compose 壳若用
 * 同一份 prefs 只交日程，就会把 Flutter 已经排好的考试与上课提醒整批取消。
 * 本调度器因此使用**独立的 prefs / 通知渠道 / PendingIntent 命名空间**，与考试提醒
 * 互不影响。两者唯一的交集是 POST_NOTIFICATIONS 权限本身。
 *
 * 各条语义逐条对齐 Dart（`lib/services/exam_reminder_service.dart`）与
 * `ExamReminderScheduler.kt`：
 * - 响点由 [ScheduleReminderLogic] 纯算，原生只负责调度；日程增删改后调用
 *   [reconcile] 整表重排。
 * - 只投递**快照里仍在的**响点：Intent extras 可被外部伪造，不能信。
 * - `notify()` 被系统丢弃（无权限 / 通知被关 / 渠道静默）时**保留**该条，
 *   下次对账在 24 小时内重试一次；投递成功才从快照删除。
 * - 重启 / 换时区后从快照重排，不依赖 App 进程活着。
 *
 * ## 接线现状（诚实）
 *
 * 本文件只是调度能力；**谁在日程增删改后调用 [reconcile] 仍需宿主接线**
 *（`TimetableRepository.syncExamReminders` 目前是空实现，壳在
 * `ScheduleItemService` 每次写完后确实会调它）。另外本接收器需要在
 * `AndroidManifest.xml` 注册（本批按纪律不修改 manifest，需要的几行见交付报告）。
 */
object ScheduleReminderScheduler {
    private const val TAG = "ScheduleReminder"
    private const val PREFS_NAME = "schedule_reminder_prefs"
    private const val KEY_SNAPSHOT_JSON = "snapshot_json"
    private const val SNAPSHOT_VERSION = 1
    private const val OVERDUE_DELIVERY_WINDOW_MILLIS = 24L * 60L * 60L * 1000L

    const val CHANNEL_ID = "schedule_reminder_channel"
    const val ACTION_FIRE = "com.mutx163.qingyu.ACTION_SCHEDULE_REMINDER_FIRE"

    private const val EXTRA_REQUEST_CODE = "requestCode"
    private const val EXTRA_SCHEDULE_ID = "scheduleId"
    private const val EXTRA_OFFSET_MINUTES = "offsetMinutes"

    /** 一条已排程的响点（快照条目；字段名是内部契约，不进用户数据）。 */
    private data class Fire(
        val scheduleId: String,
        val offsetMinutes: Int,
        val fireAtMillis: Long,
        val startMillis: Long,
        val title: String,
        val body: String,
        val requestCode: Int,
        val localDate: String,
        val localTimeMinutes: Int,
    ) {
        val fireKey: String get() = "$scheduleId#$offsetMinutes"
    }

    // ---------- 通知渠道 / 权限 ----------

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
            context.getString(R.string.notification_channel_schedule_reminder_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = context.getString(R.string.notification_channel_schedule_reminder_desc)
        }
        manager.createNotificationChannel(channel)
    }

    /**
     * 这条通知系统是否真的可能投递。三个条件缺一，`notify()` 都会被静默丢弃：
     * POST_NOTIFICATIONS 未授予、应用通知被关、渠道被调成「不显示」。
     *
     * 供界面在提醒卡片下显示 `scheduleReminderPermissionMissing`
     *（「通知权限未开启，日程仍会保存，但提醒可能无法送达」）——这正是本调度器的
     * 诚实降级：闹钟照排、日程照存，只是到点可能弹不出来，且不谎报已送达。
     */
    fun canPostNotifications(context: Context): Boolean {
        ensureChannel(context)
        val manager = context.getSystemService(NotificationManager::class.java) ?: return false
        val permissionGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
        val channelImportance = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.getNotificationChannel(CHANNEL_ID)?.importance
                ?: NotificationManager.IMPORTANCE_NONE
        } else {
            NotificationManager.IMPORTANCE_DEFAULT
        }
        return permissionGranted &&
            manager.areNotificationsEnabled() &&
            channelImportance > NotificationManager.IMPORTANCE_NONE
    }

    // ---------- 对账 ----------

    /**
     * 用当前日程列表整表重排日程提醒。
     *
     * 调用时机（与 Dart `reconcile` 一致）：日程增 / 删 / 改后、冷启动、恢复备份后。
     * 幂等：同一份数据重复调用不会重复投递。
     *
     * @param now 参考时刻，测试可注入；生产不传。
     */
    fun reconcile(
        context: Context,
        items: List<ScheduleItem>,
        now: LocalDateTime = LocalDateTime.now(),
        zone: ZoneId = ZoneId.systemDefault(),
    ) {
        ensureChannel(context)
        val appContext = context.applicationContext
        val oldFires = loadFires(appContext)
        cancelFires(appContext, oldFires)

        val plannedFires = ScheduleReminderLogic.buildFires(items, now = now, zone = zone)
        val newFires = plannedFires.map { it.toNativeFire() }
        val nowMillis = System.currentTimeMillis()
        val futureFires = newFires.filter { it.fireAtMillis > nowMillis - 30_000L }
        val futureRequestCodes = futureFires.mapTo(mutableSetOf()) { it.requestCode }
        val plannedKeys = ScheduleReminderLogic.buildPlannedFireKeys(items, now = now, zone = zone)

        // 逾期未投递重试：快照里遗留的条目 = 上次 notify 失败（无权限 / 通知被关）。
        // 只在「仍在计划里」且 24 小时内的才重排一次，避免删掉的旧日程反复弹。
        val failedOverdue = oldFires.mapNotNull { fire ->
            val originalFireAt = originalFireAtMillis(fire)
            val isRecentFailure = originalFireAt <= nowMillis &&
                originalFireAt > nowMillis - OVERDUE_DELIVERY_WINDOW_MILLIS
            if (!isRecentFailure ||
                fire.fireKey !in plannedKeys ||
                fire.requestCode in futureRequestCodes
            ) {
                null
            } else {
                fire.copy(fireAtMillis = nowMillis + 1_000L)
            }
        }

        val schedulable = futureFires + failedOverdue
        for (fire in schedulable) {
            scheduleAlarm(appContext, fire)
        }
        persistFires(appContext, schedulable)
        Log.d(
            TAG,
            "reconcile scheduled=${schedulable.size} cancelledOld=${oldFires.size} " +
                "canPost=${canPostNotifications(appContext)}",
        )
    }

    /** 清空全部日程提醒（例如用户删光日程 / 关闭功能）。 */
    fun clear(context: Context) {
        val appContext = context.applicationContext
        cancelFires(appContext, loadFires(appContext))
        appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_SNAPSHOT_JSON)
            .apply()
    }

    /** 开机 / 应用更新 / 系统时间变更：按快照原响点重排。 */
    fun handleBootReschedule(context: Context) {
        reschedulePersistedFires(context, preserveLocalWallClock = false)
    }

    /** 换时区：日程是「本地墙上时间」，按本地日期 + 钟点重新换算绝对时刻。 */
    fun handleTimezoneChanged(context: Context) {
        reschedulePersistedFires(context, preserveLocalWallClock = true)
    }

    fun handleFire(context: Context, intent: Intent) {
        ensureChannel(context)
        val appContext = context.applicationContext
        val requestCode = intent.getIntExtra(EXTRA_REQUEST_CODE, -1)
        val scheduleId = intent.getStringExtra(EXTRA_SCHEDULE_ID).orEmpty()
        val offsetMinutes = intent.getIntExtra(EXTRA_OFFSET_MINUTES, 0)

        // 只投递快照里仍存在的响点：接收器因开机广播而导出，不能信 Intent extras。
        val scheduled = loadFires(appContext)
        val matched = scheduled.firstOrNull {
            it.requestCode == requestCode ||
                (scheduleId.isNotBlank() &&
                    it.scheduleId == scheduleId &&
                    it.offsetMinutes == offsetMinutes)
        }
        if (matched == null) {
            Log.w(TAG, "drop fire: not scheduled requestCode=$requestCode id=$scheduleId")
            return
        }

        val title = matched.title.ifBlank {
            context.getString(R.string.notification_schedule_reminder_default_title)
        }
        val body = matched.body.ifBlank {
            context.getString(R.string.notification_schedule_reminder_default_body)
        }
        val posted = postNotification(
            context = appContext,
            notificationId = if (matched.requestCode != 0) {
                matched.requestCode
            } else {
                matched.scheduleId.hashCode()
            },
            title = title,
            body = body,
        )
        if (!posted) {
            // 投不出去要留着：用户之后开了通知权限 / 关了勿扰，下次对账还能重试一次。
            Log.w(TAG, "keep fire after notify failure requestCode=$requestCode")
            return
        }
        val remaining = scheduled.filterNot {
            it.requestCode == matched.requestCode ||
                (it.scheduleId == matched.scheduleId && it.offsetMinutes == matched.offsetMinutes)
        }
        persistFires(appContext, remaining)
    }

    // ---------- 内部：重排 / 通知 ----------

    private fun reschedulePersistedFires(
        context: Context,
        preserveLocalWallClock: Boolean,
    ) {
        ensureChannel(context)
        val appContext = context.applicationContext
        val fires = loadFires(appContext)
        if (fires.isEmpty()) {
            return
        }
        cancelFires(appContext, fires)
        val nowMillis = System.currentTimeMillis()
        val rearmed = fires.mapNotNull { fire ->
            val wallClockStart = if (preserveLocalWallClock) localStartMillis(fire) else null
            val originalFireAt = if (wallClockStart != null) {
                wallClockStart - fire.offsetMinutes.toLong() * 60_000L
            } else {
                originalFireAtMillis(fire)
            }
            val startMillis = wallClockStart ?: fire.startMillis
            when {
                originalFireAt <= nowMillis - OVERDUE_DELIVERY_WINDOW_MILLIS -> null
                originalFireAt <= nowMillis -> fire.copy(
                    fireAtMillis = nowMillis + 1_000L,
                    startMillis = startMillis,
                )
                else -> fire.copy(fireAtMillis = originalFireAt, startMillis = startMillis)
            }
        }
        for (fire in rearmed) {
            scheduleAlarm(appContext, fire)
        }
        persistFires(appContext, rearmed)
        Log.d(
            TAG,
            "${if (preserveLocalWallClock) "timezone" else "boot"} reschedule count=${rearmed.size}",
        )
    }

    private fun originalFireAtMillis(fire: Fire): Long =
        if (fire.startMillis > 0L && fire.offsetMinutes > 0) {
            fire.startMillis - fire.offsetMinutes.toLong() * 60_000L
        } else {
            fire.fireAtMillis
        }

    private fun localStartMillis(fire: Fire): Long? {
        val date = runCatching { LocalDate.parse(fire.localDate) }.getOrNull() ?: return null
        if (fire.localTimeMinutes !in 0..1439) {
            return null
        }
        val time = LocalTime.of(fire.localTimeMinutes / 60, fire.localTimeMinutes % 60)
        return LocalDateTime.of(date, time)
            .atZone(ZoneId.systemDefault())
            .toInstant()
            .toEpochMilli()
    }

    private fun postNotification(
        context: Context,
        notificationId: Int,
        title: String,
        body: String,
    ): Boolean {
        if (!canPostNotifications(context)) {
            Log.w(TAG, "skip notify: not deliverable")
            return false
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            notificationId,
            Intent(context, PagesShellActivity::class.java).apply {
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
            .setCategory(Notification.CATEGORY_REMINDER)
            .setPriority(Notification.PRIORITY_DEFAULT)
            .build()
        val manager = context.getSystemService(NotificationManager::class.java) ?: return false
        return try {
            manager.notify(notificationId, notification)
            true
        } catch (error: Exception) {
            // notify 抛异常既不能把接收器带崩，也不能当成投递成功（否则这条提醒永久丢失）。
            Log.w(TAG, "notify threw", error)
            false
        }
    }

    private fun scheduleAlarm(context: Context, fire: Fire) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
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
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, fire.fireAtMillis, pendingIntent)
            }
        } catch (error: SecurityException) {
            // 精确闹钟权限被收回时退化成不精确闹钟，提醒可能晚几分钟，但不能整个丢。
            Log.w(TAG, "exact alarm denied for ${fire.requestCode}", error)
            runCatching {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    fire.fireAtMillis,
                    pendingIntent,
                )
            }
        }
    }

    private fun cancelFires(context: Context, fires: List<Fire>) {
        if (fires.isEmpty()) {
            return
        }
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        for (fire in fires) {
            alarmManager.cancel(buildFirePendingIntent(context, fire))
        }
    }

    private fun buildFirePendingIntent(context: Context, fire: Fire): PendingIntent {
        val intent = Intent(context, ScheduleReminderReceiver::class.java).apply {
            action = ACTION_FIRE
            putExtra(EXTRA_REQUEST_CODE, fire.requestCode)
            putExtra(EXTRA_SCHEDULE_ID, fire.scheduleId)
            putExtra(EXTRA_OFFSET_MINUTES, fire.offsetMinutes)
        }
        return PendingIntent.getBroadcast(
            context,
            fire.requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    // ---------- 内部：快照 ----------

    private fun ScheduleReminderFire.toNativeFire(): Fire = Fire(
        scheduleId = scheduleId,
        offsetMinutes = offsetMinutes,
        fireAtMillis = fireAtEpochMillis,
        startMillis = startEpochMillis,
        title = title,
        body = body,
        requestCode = requestCode,
        localDate = localDate,
        localTimeMinutes = localTimeMinutes,
    )

    private fun loadFires(context: Context): List<Fire> {
        val json = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_SNAPSHOT_JSON, null)
            ?: return emptyList()
        return try {
            val array = JSONObject(json).optJSONArray("fires") ?: return emptyList()
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    add(
                        Fire(
                            scheduleId = item.optString("scheduleId"),
                            offsetMinutes = item.optInt("offsetMinutes"),
                            fireAtMillis = item.optLong("fireAtMillis"),
                            startMillis = item.optLong("startMillis"),
                            title = item.optString("title"),
                            body = item.optString("body"),
                            requestCode = item.optInt("requestCode"),
                            localDate = item.optString("localDate"),
                            localTimeMinutes = item.optInt("localTimeMinutes"),
                        ),
                    )
                }
            }.filter { it.scheduleId.isNotBlank() && it.requestCode != 0 }
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
                    put("scheduleId", fire.scheduleId)
                    put("offsetMinutes", fire.offsetMinutes)
                    put("fireAtMillis", fire.fireAtMillis)
                    put("startMillis", fire.startMillis)
                    put("title", fire.title)
                    put("body", fire.body)
                    put("requestCode", fire.requestCode)
                    put("localDate", fire.localDate)
                    put("localTimeMinutes", fire.localTimeMinutes)
                },
            )
        }
        val payload = JSONObject()
            .put("version", SNAPSHOT_VERSION)
            .put("updatedAtMillis", System.currentTimeMillis())
            .put("fires", array)
            .toString()
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SNAPSHOT_JSON, payload)
            .apply()
    }
}

/**
 * 日程提醒的广播接收器。
 *
 * **需要注册到 `AndroidManifest.xml`**（本批按纪律未改 manifest，见交付报告）：
 * 开机 / 换时区要重排，显式 PendingIntent 投递 `ACTION_FIRE`。
 */
class ScheduleReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            -> ScheduleReminderScheduler.handleBootReschedule(context)
            Intent.ACTION_TIMEZONE_CHANGED ->
                ScheduleReminderScheduler.handleTimezoneChanged(context)
            ScheduleReminderScheduler.ACTION_FIRE ->
                ScheduleReminderScheduler.handleFire(context, intent)
        }
    }
}
