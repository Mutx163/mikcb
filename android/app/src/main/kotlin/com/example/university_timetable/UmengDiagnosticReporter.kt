package com.example.university_timetable

import android.app.ActivityManager
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.util.Log
import com.umeng.umcrash.UMCrash
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap

object UmengDiagnosticReporter {
    private const val TAG = "UmengDiagnostic"
    private const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
    private const val KEY_ACCEPTED_PRIVACY_POLICY = "flutter.accepted_privacy_policy"
    private const val KEY_TIMETABLE_SETTINGS = "flutter.timetable_settings"
    private const val THROTTLE_WINDOW_MILLIS = 2 * 60 * 1000L
    private const val NATIVE_PREFS_NAME = "native_runtime_prefs"
    private const val KEY_HIDE_FROM_RECENTS = "hide_from_recents"
    private const val KEY_LAST_TASK_REMOVED_AT = "last_task_removed_at"
    private const val POST_PROMOTED_NOTIFICATIONS_PERMISSION =
        "android.permission.POST_PROMOTED_NOTIFICATIONS"

    private val lastReportedAt = ConcurrentHashMap<String, Long>()

    fun report(
        context: Context,
        category: String,
        message: String,
        throwable: Throwable? = null,
        stackTrace: String? = null,
        dedupeKey: String = category,
        extras: Map<String, Any?> = emptyMap(),
    ) {
        if (!hasPrivacyConsent(context)) {
            return
        }
        UmengApplication.initializeAnalyticsIfNeeded(context.applicationContext)
        if (!UmengApplication.isAnalyticsInitialized()) {
            return
        }
        if (shouldThrottle(dedupeKey)) {
            return
        }

        try {
            val payload = buildString {
                appendLine("category=$category")
                appendLine("message=$message")
                val diagnosticContext = buildDiagnosticContext(context)
                if (diagnosticContext.isNotEmpty()) {
                    appendLine("context=")
                    diagnosticContext.forEach { (key, value) ->
                        appendLine("  $key=${value ?: "null"}")
                    }
                }
                if (extras.isNotEmpty()) {
                    appendLine("extras=")
                    extras.forEach { (key, value) ->
                        appendLine("  $key=${value ?: "null"}")
                    }
                }
                if (!stackTrace.isNullOrBlank()) {
                    appendLine("stackTrace=")
                    appendLine(stackTrace)
                }
                if (throwable != null) {
                    appendLine("throwable=")
                    appendLine(Log.getStackTraceString(throwable))
                }
            }.trim()

            UMCrash.generateCustomLog(payload, category.take(64))
        } catch (error: Exception) {
            Log.w(TAG, "Failed to upload Umeng diagnostic log", error)
        }
    }

    private fun hasPrivacyConsent(context: Context): Boolean {
        return context.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_ACCEPTED_PRIVACY_POLICY, false)
    }

    private fun shouldThrottle(dedupeKey: String): Boolean {
        val now = System.currentTimeMillis()
        val last = lastReportedAt[dedupeKey]
        if (last != null && now - last < THROTTLE_WINDOW_MILLIS) {
            return true
        }
        lastReportedAt[dedupeKey] = now
        return false
    }

    private fun buildDiagnosticContext(context: Context): Map<String, Any?> {
        val flutterPrefs = context.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
        val nativePrefs = context.getSharedPreferences(NATIVE_PREFS_NAME, Context.MODE_PRIVATE)
        val lastTaskRemovedAt = nativePrefs.getLong(KEY_LAST_TASK_REMOVED_AT, 0L)
        val settingsJson = flutterPrefs.getString(KEY_TIMETABLE_SETTINGS, null)
        val settings = settingsJson?.let {
            runCatching { JSONObject(it) }.getOrNull()
        }

        return linkedMapOf(
            "brand" to Build.BRAND,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "sdkInt" to Build.VERSION.SDK_INT,
            "versionName" to resolveVersionName(context),
            "channel" to BuildConfig.UMENG_CHANNEL,
            "hasNotificationPermission" to hasNotificationPermission(context),
            "hasPromotedPermissionDeclared" to isPromotedPermissionDeclared(context),
            "canPostPromotedNotifications" to canPostPromotedNotifications(context),
            "ignoringBatteryOptimizations" to isIgnoringBatteryOptimizations(context),
            "hideFromRecentsEnabled" to nativePrefs.getBoolean(KEY_HIDE_FROM_RECENTS, false),
            "taskRemovedRecently" to lastTaskRemovedAt > 0L &&
                System.currentTimeMillis() - lastTaskRemovedAt < 10 * 60 * 1000L,
            "lastTaskRemovedAt" to lastTaskRemovedAt.takeIf { it > 0L },
            "processImportance" to resolveProcessImportance(context),
            "autoStartStatus" to "unknown",
            "liveEnableBeforeClass" to settings?.optBoolean("liveEnableBeforeClass"),
            "liveEnableDuringClass" to settings?.optBoolean("liveEnableDuringClass"),
            "liveEnableBeforeEnd" to settings?.optBoolean("liveEnableBeforeEnd"),
            "livePromoteDuringClass" to settings?.optBoolean("livePromoteDuringClass"),
            "liveShowDuringClassNotification" to settings?.optBoolean("liveShowDuringClassNotification"),
            "liveShowCountdown" to settings?.optBoolean("liveShowCountdown"),
            "liveShowCourseName" to settings?.optBoolean("liveShowCourseName"),
            "liveShowLocation" to settings?.optBoolean("liveShowLocation"),
            "liveUseShortName" to settings?.optBoolean("liveUseShortName"),
            "liveHidePrefixText" to settings?.optBoolean("liveHidePrefixText"),
            "liveDuringClassTimeDisplayMode" to settings?.optString("liveDuringClassTimeDisplayMode"),
            "liveEnableMiuiIslandLabelImage" to settings?.optBoolean("liveEnableMiuiIslandLabelImage"),
            "liveHideFromRecents" to settings?.optBoolean("liveHideFromRecents"),
            "liveMiuiIslandLabelStyle" to settings?.optString("liveMiuiIslandLabelStyle"),
            "liveMiuiIslandLabelContent" to settings?.optString("liveMiuiIslandLabelContent"),
            "liveMiuiIslandLabelFontColor" to settings?.optString("liveMiuiIslandLabelFontColor"),
            "liveMiuiIslandLabelFontWeight" to settings?.optString("liveMiuiIslandLabelFontWeight"),
            "liveMiuiIslandLabelRenderQuality" to settings?.optString("liveMiuiIslandLabelRenderQuality"),
            "liveMiuiIslandLabelFontSize" to settings?.optDouble("liveMiuiIslandLabelFontSize"),
            "liveMiuiIslandExpandedIconMode" to settings?.optString("liveMiuiIslandExpandedIconMode"),
            "liveShowBeforeClassMinutes" to settings?.optInt("liveShowBeforeClassMinutes"),
            "liveClassReminderStartMinutes" to settings?.optInt("liveClassReminderStartMinutes"),
            "liveEndSecondsCountdownThreshold" to settings?.optInt("liveEndSecondsCountdownThreshold"),
        )
    }

    private fun resolveVersionName(context: Context): String? {
        return try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.PackageInfoFlags.of(0)
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(context.packageName, 0)
            }
            packageInfo.versionName
        } catch (_: Exception) {
            null
        }
    }

    private fun hasNotificationPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun isPromotedPermissionDeclared(context: Context): Boolean {
        return try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong())
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.GET_PERMISSIONS
                )
            }
            packageInfo.requestedPermissions?.contains(POST_PROMOTED_NOTIFICATIONS_PERMISSION) == true
        } catch (_: Exception) {
            false
        }
    }

    private fun canPostPromotedNotifications(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 36) {
            return false
        }
        return try {
            context.getSystemService(NotificationManager::class.java)
                ?.canPostPromotedNotifications() == true
        } catch (_: Exception) {
            false
        }
    }

    private fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }
        return try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            powerManager?.isIgnoringBatteryOptimizations(context.packageName) == true
        } catch (_: Exception) {
            false
        }
    }

    private fun resolveProcessImportance(context: Context): String {
        return try {
            val activityManager = context.getSystemService(ActivityManager::class.java)
            val currentProcess = activityManager?.runningAppProcesses
                ?.firstOrNull { it.processName == context.packageName }
            when (currentProcess?.importance) {
                ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND -> "foreground"
                ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE -> "visible"
                ActivityManager.RunningAppProcessInfo.IMPORTANCE_SERVICE -> "service"
                ActivityManager.RunningAppProcessInfo.IMPORTANCE_CACHED -> "cached"
                null -> "unknown"
                else -> currentProcess.importance.toString()
            }
        } catch (_: Exception) {
            "unknown"
        }
    }
}
