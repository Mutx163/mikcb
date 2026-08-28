package com.mutx163.qingyu

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.AlarmClock
import android.util.Log

/**
 * Bridges Flutter to the public android.provider.AlarmClock contract.
 *
 * The system Clock app owns every alarm created here; this app intentionally
 * keeps no handle on them because there is no public API to read or delete
 * clock-app entries afterwards.
 */
object SystemAlarmHelper {
    private const val TAG = "SystemAlarm"

    data class Outcome(val launched: Boolean, val skipUiRequested: Boolean)

    fun fireSetAlarm(
        activity: Activity,
        hour: Int,
        minute: Int,
        label: String,
        skipUi: Boolean,
        days: List<Int>?,
    ): Outcome {
        val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
            putExtra(AlarmClock.EXTRA_HOUR, hour)
            putExtra(AlarmClock.EXTRA_MINUTES, minute)
            if (label.isNotBlank()) {
                putExtra(AlarmClock.EXTRA_MESSAGE, label)
            }
            if (!days.isNullOrEmpty()) {
                putIntegerArrayListExtra(
                    AlarmClock.EXTRA_DAYS,
                    ArrayList(days),
                )
            }
            if (skipUi) {
                putExtra(AlarmClock.EXTRA_SKIP_UI, true)
            }
        }
        return try {
            activity.startActivity(intent)
            Outcome(launched = true, skipUiRequested = skipUi)
        } catch (error: ActivityNotFoundException) {
            Log.w(TAG, "no activity handles ACTION_SET_ALARM", error)
            Outcome(launched = false, skipUiRequested = false)
        }
    }

    fun fireShowAlarms(activity: Activity): Boolean {
        return try {
            activity.startActivity(Intent(AlarmClock.ACTION_SHOW_ALARMS))
            true
        } catch (error: ActivityNotFoundException) {
            Log.w(TAG, "no activity handles ACTION_SHOW_ALARMS", error)
            false
        }
    }
}
