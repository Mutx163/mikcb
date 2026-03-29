package com.mutx163.qingyu

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

object HomeWidgetStorage {
    private const val PREFS_NAME = "home_widget_prefs"
    private const val KEY_SNAPSHOT_JSON = "snapshot_json"
    private const val KEY_REFRESH_TIMES_JSON = "refresh_times_json"
    private const val REQUEST_CODE_REFRESH = 4201

    fun syncSnapshot(context: Context, snapshot: Map<String, Any?>) {
        val payload = JSONObject(snapshot).toString()
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SNAPSHOT_JSON, payload)
            .apply()
        TodayWidgetSupport.updateAll(context)
        rescheduleRefresh(context)
    }

    fun clearSnapshot(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_SNAPSHOT_JSON)
            .remove(KEY_REFRESH_TIMES_JSON)
            .apply()
        cancelRefreshAlarm(context)
        TodayWidgetSupport.updateAll(context)
    }

    fun scheduleRefresh(context: Context, triggerAtMillis: List<Long>) {
        val payload = JSONArray(triggerAtMillis).toString()
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_REFRESH_TIMES_JSON, payload)
            .apply()
        rescheduleRefresh(context)
    }

    fun getSnapshotJson(context: Context): String? {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_SNAPSHOT_JSON, null)
    }

    fun getRefreshTimesJson(context: Context): String? {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_REFRESH_TIMES_JSON, null)
    }

    fun rescheduleRefresh(context: Context) {
        cancelRefreshAlarm(context)
        val nextTriggerAtMillis = loadRefreshTimes(context)
            .filter { it > System.currentTimeMillis() }
            .minOrNull() ?: return

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = buildRefreshPendingIntent(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    nextTriggerAtMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    nextTriggerAtMillis,
                    pendingIntent
                )
            }
        } else {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                nextTriggerAtMillis,
                pendingIntent
            )
        }
    }

    private fun cancelRefreshAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(buildRefreshPendingIntent(context))
    }

    private fun buildRefreshPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, HomeWidgetRefreshReceiver::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            component = ComponentName(context, HomeWidgetRefreshReceiver::class.java)
        }
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE_REFRESH,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun loadRefreshTimes(context: Context): List<Long> {
        val payload = getRefreshTimesJson(context) ?: return emptyList()
        return try {
            val json = JSONArray(payload)
            buildList {
                for (index in 0 until json.length()) {
                    add(json.optLong(index))
                }
            }.filter { it > 0L }
        } catch (_: Exception) {
            emptyList()
        }
    }
}

