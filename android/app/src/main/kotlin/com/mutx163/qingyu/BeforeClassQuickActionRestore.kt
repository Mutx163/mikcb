package com.mutx163.qingyu

import android.app.NotificationManager
import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.util.Log

internal object BeforeClassQuickActionRestore {
    private const val TAG = "BeforeClassQuickActionRestore"
    private const val PREFS_NAME = "before_class_quick_action_prefs"
    private const val KEY_PENDING = "pending"
    private const val KEY_SAVED_RINGER_MODE = "saved_ringer_mode"
    private const val KEY_SAVED_DND_FILTER = "saved_dnd_filter"
    private const val KEY_RESTORE_AT_MILLIS = "restore_at_millis"
    private const val KEY_APPLIED_ACTION = "applied_action"

    const val ACTION_SILENT = "silent"
    const val ACTION_DO_NOT_DISTURB = "do_not_disturb"

    fun enableSilentMode(context: Context, restoreAtMillis: Long): Boolean {
        val audioManager = context.getSystemService(AudioManager::class.java) ?: return false
        return try {
            markPending(
                context = context,
                restoreAtMillis = restoreAtMillis,
                appliedAction = ACTION_SILENT,
            ) {
                val prefs = prefs(context)
                if (!prefs.getBoolean(KEY_PENDING, false)) {
                    prefs.edit()
                        .putInt(KEY_SAVED_RINGER_MODE, audioManager.ringerMode)
                        .apply()
                }
            }
            audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
            true
        } catch (e: SecurityException) {
            Log.w(TAG, DiagnosticLogMessages.LOG_ENABLE_SILENT_MODE_DIRECT_FAILED, e)
            false
        } catch (e: Exception) {
            Log.w(TAG, DiagnosticLogMessages.LOG_ENABLE_SILENT_MODE_FAILED, e)
            false
        }
    }

    fun enableDoNotDisturbMode(context: Context, restoreAtMillis: Long): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !manager.isNotificationPolicyAccessGranted
        ) {
            return false
        }
        return try {
            markPending(
                context = context,
                restoreAtMillis = restoreAtMillis,
                appliedAction = ACTION_DO_NOT_DISTURB,
            ) {
                val prefs = prefs(context)
                if (!prefs.getBoolean(KEY_PENDING, false)) {
                    prefs.edit()
                        .putInt(KEY_SAVED_DND_FILTER, manager.currentInterruptionFilter)
                        .apply()
                }
            }
            manager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
            true
        } catch (e: SecurityException) {
            Log.w(TAG, DiagnosticLogMessages.LOG_ENABLE_DND_DIRECT_FAILED, e)
            false
        } catch (e: Exception) {
            Log.w(TAG, DiagnosticLogMessages.LOG_ENABLE_DND_FAILED, e)
            false
        }
    }

    fun restoreOnBoot(context: Context): Boolean {
        if (!isPending(context)) {
            return false
        }
        return restoreIfPending(context, reason = "boot")
    }

    fun restoreIfClassEnded(context: Context, nowMillis: Long = System.currentTimeMillis()): Boolean {
        if (!isPending(context)) {
            return false
        }
        val restoreAtMillis = prefs(context).getLong(KEY_RESTORE_AT_MILLIS, 0L)
        if (!beforeClassQuickActionShouldRestoreAfterClassEnd(nowMillis, restoreAtMillis)) {
            return false
        }
        return restoreIfPending(context, reason = "class_end")
    }

    fun restoreIfPending(context: Context, reason: String): Boolean {
        val prefs = prefs(context)
        if (!prefs.getBoolean(KEY_PENDING, false)) {
            return false
        }

        val appliedAction = prefs.getString(KEY_APPLIED_ACTION, "").orEmpty()
        val restored = when (appliedAction) {
            ACTION_SILENT -> restoreSilentMode(context, prefs)
            ACTION_DO_NOT_DISTURB -> restoreDoNotDisturbMode(context, prefs)
            else -> false
        }
        if (restored) {
            clearPending(context)
            UmengDiagnosticReporter.record(
                context = context.applicationContext,
                category = "live_update_before_class_quick_action_restored",
                message = DiagnosticLogMessages.LIVE_UPDATE_BEFORE_CLASS_QUICK_ACTION_RESTORED,
                extras = mapOf(
                    "reason" to reason,
                    "appliedAction" to appliedAction,
                ),
            )
        }
        return restored
    }

    private fun restoreSilentMode(context: Context, prefs: android.content.SharedPreferences): Boolean {
        val audioManager = context.getSystemService(AudioManager::class.java) ?: return false
        val savedMode = prefs.getInt(
            KEY_SAVED_RINGER_MODE,
            AudioManager.RINGER_MODE_NORMAL,
        )
        return try {
            audioManager.ringerMode = savedMode
            true
        } catch (e: SecurityException) {
            Log.w(TAG, DiagnosticLogMessages.LOG_RESTORE_SILENT_MODE_FAILED, e)
            false
        } catch (e: Exception) {
            Log.w(TAG, DiagnosticLogMessages.LOG_RESTORE_SILENT_MODE_FAILED, e)
            false
        }
    }

    private fun restoreDoNotDisturbMode(
        context: Context,
        prefs: android.content.SharedPreferences,
    ): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !manager.isNotificationPolicyAccessGranted
        ) {
            return false
        }
        val savedFilter = prefs.getInt(
            KEY_SAVED_DND_FILTER,
            NotificationManager.INTERRUPTION_FILTER_ALL,
        )
        return try {
            manager.setInterruptionFilter(savedFilter)
            true
        } catch (e: SecurityException) {
            Log.w(TAG, DiagnosticLogMessages.LOG_RESTORE_DND_FAILED, e)
            false
        } catch (e: Exception) {
            Log.w(TAG, DiagnosticLogMessages.LOG_RESTORE_DND_FAILED, e)
            false
        }
    }

    private fun markPending(
        context: Context,
        restoreAtMillis: Long,
        appliedAction: String,
        saveOriginalState: () -> Unit,
    ) {
        val prefs = prefs(context)
        val alreadyPending = prefs.getBoolean(KEY_PENDING, false)
        if (!alreadyPending) {
            saveOriginalState()
            prefs.edit()
                .putBoolean(KEY_PENDING, true)
                .putString(KEY_APPLIED_ACTION, appliedAction)
                .apply()
        }
        val effectiveRestoreAt = maxOf(
            prefs.getLong(KEY_RESTORE_AT_MILLIS, 0L),
            restoreAtMillis.coerceAtLeast(0L),
        )
        prefs.edit()
            .putLong(KEY_RESTORE_AT_MILLIS, effectiveRestoreAt)
            .apply()
    }

    private fun isPending(context: Context): Boolean {
        return prefs(context).getBoolean(KEY_PENDING, false)
    }

    private fun clearPending(context: Context) {
        prefs(context).edit().clear().apply()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}

internal fun beforeClassQuickActionShouldRestoreAfterClassEnd(
    nowMillis: Long,
    restoreAtMillis: Long,
): Boolean {
    return restoreAtMillis > 0L && nowMillis >= restoreAtMillis
}
