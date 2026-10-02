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
    private const val KEY_LAST_AUTO_TRIGGER_MILLIS = "last_auto_trigger_millis"
    private const val KEY_APPLIED_SILENT = "applied_silent"
    private const val KEY_APPLIED_DND = "applied_dnd"

    /** 已按课上报过失败的 triggerKey（进程内存）：自动执行失败会随 ticker
     *  每拍重试，上报必须去重，避免诊断日志被同一节课刷爆。 */
    private val autoFailureReportedKeys = mutableSetOf<Long>()

    /** 静音铃声在 Android 13+/HyperOS 并入勿扰体系：无策略访问权限时每次
     *  setRingerMode(SILENT) 都抛 SecurityException，而自动执行随 ticker 每拍
     *  重试，异常日志只在进程内告警一次（带栈保留可诊断性）。 */
    private var silentAccessDeniedWarnedOnce = false

    const val ACTION_NONE = "none"
    const val ACTION_SILENT = "silent"
    const val ACTION_DO_NOT_DISTURB = "do_not_disturb"
    const val ACTION_BOTH = "both"

    fun enableSilentMode(context: Context, restoreAtMillis: Long): Boolean {
        val audioManager = context.getSystemService(AudioManager::class.java) ?: return false
        return try {
            // Capture pre-change ringer mode before applying silent, otherwise
            // restore would write back SILENT forever.
            markPending(context, restoreAtMillis, ACTION_SILENT)
            audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
            // setRingerMode 在缺 MODIFY_AUDIO_SETTINGS 权限时会被框架静默丢弃（不抛
            // 异常、不生效），必须回读校验，否则「静音」按钮点了毫无反应却当成功。
            val applied = audioManager.ringerMode == AudioManager.RINGER_MODE_SILENT
            if (!applied) {
                // 没真的静音就不能把 pending 留在盘上：pending 还挂着时下一次
                // markPending 会跳过 saveOriginalStates（:347），于是这节课恢复用的是
                // 好几节课之前那次的原始模式 —— 用户中途自己改成的振动被静默覆盖。
                abandonAppliedFlag(context, KEY_APPLIED_SILENT)
            }
            applied
        } catch (e: SecurityException) {
            if (!silentAccessDeniedWarnedOnce) {
                silentAccessDeniedWarnedOnce = true
                Log.w(TAG, DiagnosticLogMessages.LOG_ENABLE_SILENT_MODE_DIRECT_FAILED, e)
            }
            abandonAppliedFlag(context, KEY_APPLIED_SILENT)
            false
        } catch (e: Exception) {
            Log.w(TAG, DiagnosticLogMessages.LOG_ENABLE_SILENT_MODE_FAILED, e)
            abandonAppliedFlag(context, KEY_APPLIED_SILENT)
            false
        }
    }

    /**
     * 应用失败时回收刚写下的"已生效"标记：另一个动作若仍生效，pending 与它保存的
     * 原始状态必须留着（下课还得恢复它）；两个标记都撤掉了才整份清 pending。
     */
    private fun abandonAppliedFlag(context: Context, key: String) {
        clearAppliedFlagAndMaybeClearPending(context, key)
    }

    fun enableDoNotDisturbMode(context: Context, restoreAtMillis: Long): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !manager.isNotificationPolicyAccessGranted
        ) {
            return false
        }
        return try {
            // Capture pre-change DND filter before applying NONE.
            markPending(context, restoreAtMillis, ACTION_DO_NOT_DISTURB)
            manager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
            true
        } catch (e: SecurityException) {
            Log.w(TAG, DiagnosticLogMessages.LOG_ENABLE_DND_DIRECT_FAILED, e)
            abandonAppliedFlag(context, KEY_APPLIED_DND)
            false
        } catch (e: Exception) {
            Log.w(TAG, DiagnosticLogMessages.LOG_ENABLE_DND_FAILED, e)
            abandonAppliedFlag(context, KEY_APPLIED_DND)
            false
        }
    }

    /**
     * Scheduler-driven auto apply, deduped per course session via
     * [triggerKeyMillis] (the course start time). Runs entirely in the
     * background: unlike the manual notification button it never opens
     * system settings pages when a permission is missing.
     */
    fun applyAutoQuickAction(
        context: Context,
        action: String,
        triggerKeyMillis: Long,
        restoreAtMillis: Long,
    ): Boolean {
        val prefs = prefs(context)
        if (prefs.getLong(KEY_LAST_AUTO_TRIGGER_MILLIS, 0L) == triggerKeyMillis) {
            return false
        }
        val applied = when (action) {
            ACTION_SILENT -> enableSilentMode(context, restoreAtMillis)
            ACTION_DO_NOT_DISTURB -> enableDoNotDisturbMode(context, restoreAtMillis)
            ACTION_BOTH -> {
                val silentApplied = enableSilentMode(context, restoreAtMillis)
                val dndApplied = enableDoNotDisturbMode(context, restoreAtMillis)
                silentApplied || dndApplied
            }
            else -> false
        }
        // 去重键只在成功后落盘：瞬时失败（如 AudioManager 暂不可用）下一拍自动
        // 重试，而不是让整节课错过自动执行。持久失败（如未授权 DND）会随 ticker
        // 每拍重试，故诊断上报按课去重（进程内存），避免刷爆诊断日志。
        if (applied) {
            prefs.edit()
                .putLong(KEY_LAST_AUTO_TRIGGER_MILLIS, triggerKeyMillis)
                .apply()
        }
        if (applied || autoFailureReportedKeys.add(triggerKeyMillis)) {
            UmengDiagnosticReporter.record(
                context = context.applicationContext,
                category = "live_update_before_class_quick_action",
                message = DiagnosticLogMessages.LIVE_UPDATE_BEFORE_CLASS_QUICK_ACTION,
                extras = mapOf(
                    "action" to action,
                    "applied" to applied,
                    "source" to "auto",
                ),
            )
        }
        return applied
    }

    /** Record that a manual tap already handled the given course session. */
    fun markTriggerHandled(context: Context, triggerKeyMillis: Long) {
        prefs(context).edit()
            .putLong(KEY_LAST_AUTO_TRIGGER_MILLIS, triggerKeyMillis)
            .apply()
    }

    /** Whether the ringer is currently silent (regardless of who set it). */
    fun isSilentModeActive(context: Context): Boolean {
        val audioManager = context.getSystemService(AudioManager::class.java) ?: return false
        return audioManager.ringerMode == AudioManager.RINGER_MODE_SILENT
    }

    /** 当前勿扰档位是否会把铃声模式强制压成静音（完全静音 / 仅允许闹钟）。 */
    private fun dndCurrentlySuppressesRinger(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return false
        }
        val manager = context.getSystemService(NotificationManager::class.java) ?: return false
        return dndFilterSuppressesRinger(manager.currentInterruptionFilter)
    }

    /** Whether Do Not Disturb is currently on at any level (regardless of who set it). */
    fun isDoNotDisturbModeActive(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return false
        }
        val manager = context.getSystemService(NotificationManager::class.java) ?: return false
        val filter = manager.currentInterruptionFilter
        return filter != NotificationManager.INTERRUPTION_FILTER_ALL &&
            filter != NotificationManager.INTERRUPTION_FILTER_UNKNOWN
    }

    /**
     * Turn the ringer back off silent: restore the state captured before the
     * app applied it when a pending restore exists, otherwise fall back to
     * NORMAL (the user toggled it themselves outside the app). One cancel tap
     * must not lose the restore window of the other applied mode, so the
     * pending state survives while any applied flag remains.
     */
    fun cancelSilentMode(context: Context): Boolean {
        val audioManager = context.getSystemService(AudioManager::class.java) ?: return false
        val prefs = prefs(context)
        val target = if (prefs.getBoolean(KEY_PENDING, false) &&
            prefs.contains(KEY_SAVED_RINGER_MODE)
        ) {
            prefs.getInt(KEY_SAVED_RINGER_MODE, AudioManager.RINGER_MODE_NORMAL)
        } else {
            AudioManager.RINGER_MODE_NORMAL
        }
        return try {
            // 完全静音/仅允许闹钟这两个勿扰档位会把铃声模式强制压成静音：只要勿扰
            // 还在，写入 NORMAL 会被 ZenModeHelper 立刻覆盖回静音，用户点「取消静音」
            // 便毫无反应。勿扰是本应用开的就先一并解除，再恢复铃声。
            if (dndCurrentlySuppressesRinger(context) &&
                prefs.getBoolean(KEY_APPLIED_DND, false)
            ) {
                cancelDoNotDisturbMode(context)
            }
            audioManager.ringerMode = target
            val applied = audioManager.ringerMode == target
            if (applied) {
                clearAppliedFlagAndMaybeClearPending(context, KEY_APPLIED_SILENT)
            } else {
                Log.w(TAG, DiagnosticLogMessages.LOG_RESTORE_SILENT_MODE_FAILED)
            }
            applied
        } catch (e: SecurityException) {
            Log.w(TAG, DiagnosticLogMessages.LOG_RESTORE_SILENT_MODE_FAILED, e)
            false
        } catch (e: Exception) {
            Log.w(TAG, DiagnosticLogMessages.LOG_RESTORE_SILENT_MODE_FAILED, e)
            false
        }
    }

    /** Turn Do Not Disturb back off; mirror of [cancelSilentMode]. */
    fun cancelDoNotDisturbMode(context: Context): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !manager.isNotificationPolicyAccessGranted
        ) {
            return false
        }
        val prefs = prefs(context)
        val target = if (prefs.getBoolean(KEY_PENDING, false) &&
            prefs.contains(KEY_SAVED_DND_FILTER)
        ) {
            prefs.getInt(KEY_SAVED_DND_FILTER, NotificationManager.INTERRUPTION_FILTER_ALL)
        } else {
            NotificationManager.INTERRUPTION_FILTER_ALL
        }
        return try {
            manager.setInterruptionFilter(target)
            clearAppliedFlagAndMaybeClearPending(context, KEY_APPLIED_DND)
            true
        } catch (e: SecurityException) {
            Log.w(TAG, DiagnosticLogMessages.LOG_RESTORE_DND_FAILED, e)
            false
        } catch (e: Exception) {
            Log.w(TAG, DiagnosticLogMessages.LOG_RESTORE_DND_FAILED, e)
            false
        }
    }

    private fun clearAppliedFlagAndMaybeClearPending(context: Context, key: String) {
        val prefs = prefs(context)
        if (!prefs.getBoolean(KEY_PENDING, false)) {
            return
        }
        prefs.edit().putBoolean(key, false).apply()
        if (!prefs.getBoolean(KEY_APPLIED_SILENT, false) &&
            !prefs.getBoolean(KEY_APPLIED_DND, false)
        ) {
            clearPending(context)
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
        // 顺序必须是「先解勿扰，再恢复铃声」，与本文件 cancelSilentMode:178-185 的
        // 处理同口径：勿扰档位（NONE / SILENCE_INTERUPTIONS）会把铃声模式强制压成
        // 静音，这是本仓已经钉住的结论（LiveUpdateServiceLogicTest.kt:117-126 的
        // dndFilterSuppressesRinger）。restoreSilentMode 还带写后回读校验（:298，
        // 注释写明"写入被框架静默丢弃时不能当成功"），所以在 ACTION_BOTH 下
        // 先恢复铃声必然回读失败 → silentRestored=false → restored=false →
        // 不 clearPending。表现是下课铃后手机一直静音：ticker 随后就
        // stopAndRemoveNotification（LiveUpdateService.kt:1022-1029），通知栏连可点的
        // 按钮都没了，重试走的也是同一对顺序，只能等下次打开 App 才恢复。
        val dndRestored = restoreDoNotDisturbMode(context, prefs)
        val silentRestored = restoreSilentMode(context, prefs)
        val restored = silentRestored && dndRestored
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
            // 同 enableSilentMode：写入被框架静默丢弃时不能当成功，否则 pending
            // 状态会被清掉，下课后手机永远停在静音。
            audioManager.ringerMode == savedMode
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
        if (!prefs.contains(KEY_SAVED_DND_FILTER)) {
            return true
        }
        val manager = context.getSystemService(NotificationManager::class.java) ?: return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !manager.isNotificationPolicyAccessGranted
        ) {
            // Permission was revoked; retry will never succeed — treat as handled
            // so pending restore state can clear instead of blocking forever.
            return true
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
    ) {
        val prefs = prefs(context)
        val alreadyPending = prefs.getBoolean(KEY_PENDING, false)
        val editor = prefs.edit()
        if (!alreadyPending) {
            saveOriginalStates(context, editor)
        }
        val effectiveRestoreAt = maxOf(
            prefs.getLong(KEY_RESTORE_AT_MILLIS, 0L),
            restoreAtMillis.coerceAtLeast(0L),
        )
        editor
            .putBoolean(KEY_PENDING, true)
            .putString(KEY_APPLIED_ACTION, appliedAction)
            .putLong(KEY_RESTORE_AT_MILLIS, effectiveRestoreAt)
            .let { editor ->
                when (appliedAction) {
                    ACTION_SILENT -> editor.putBoolean(KEY_APPLIED_SILENT, true)
                    ACTION_DO_NOT_DISTURB -> editor.putBoolean(KEY_APPLIED_DND, true)
                    ACTION_BOTH -> editor
                        .putBoolean(KEY_APPLIED_SILENT, true)
                        .putBoolean(KEY_APPLIED_DND, true)
                    else -> editor
                }
            }
            .apply()
    }

    private fun saveOriginalStates(
        context: Context,
        editor: android.content.SharedPreferences.Editor,
    ) {
        context.getSystemService(AudioManager::class.java)?.let { audioManager ->
            editor.putInt(KEY_SAVED_RINGER_MODE, audioManager.ringerMode)
        }
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !manager.isNotificationPolicyAccessGranted
        ) {
            return
        }
        editor.putInt(KEY_SAVED_DND_FILTER, manager.currentInterruptionFilter)
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

/** Which quick-action buttons the before-class notification should show,
 *  derived from the configured action and the live ringer/DND state: a mode
 *  that is already on gets a cancel button so one tap toggles it back off. */
/** 完全静音与「仅允许闹钟」两档勿扰会把铃声模式强制压成静音（ZenModeHelper
 *  .applyZenToRingerMode），其余档位（如仅优先）不影响铃声模式。 */
internal fun dndFilterSuppressesRinger(interruptionFilter: Int): Boolean {
    return interruptionFilter == NotificationManager.INTERRUPTION_FILTER_NONE ||
        interruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALARMS
}

internal data class BeforeClassQuickActionButtons(
    val silentEnable: Boolean = false,
    val silentCancel: Boolean = false,
    val dndEnable: Boolean = false,
    val dndCancel: Boolean = false,
) {
    override fun toString(): String {
        return "${if (silentEnable) 1 else 0}${if (silentCancel) 1 else 0}" +
            "${if (dndEnable) 1 else 0}${if (dndCancel) 1 else 0}"
    }
}

internal fun beforeClassQuickActionButtons(
    action: String,
    silentCurrentlyActive: Boolean,
    dndCurrentlyActive: Boolean,
): BeforeClassQuickActionButtons {
    if (action == BeforeClassQuickActionRestore.ACTION_NONE) {
        return BeforeClassQuickActionButtons()
    }
    val showSilent = action == BeforeClassQuickActionRestore.ACTION_SILENT ||
        action == BeforeClassQuickActionRestore.ACTION_BOTH
    val showDnd = action == BeforeClassQuickActionRestore.ACTION_DO_NOT_DISTURB ||
        action == BeforeClassQuickActionRestore.ACTION_BOTH
    return BeforeClassQuickActionButtons(
        silentEnable = showSilent && !silentCurrentlyActive,
        silentCancel = showSilent && silentCurrentlyActive,
        dndEnable = showDnd && !dndCurrentlyActive,
        dndCancel = showDnd && dndCurrentlyActive,
    )
}
