package com.example.university_timetable

import android.app.ActivityManager
import android.app.NotificationManager
import android.content.Context
import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import org.json.JSONObject
import java.io.File
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
    private const val KEY_LIVE_DIAGNOSTICS_ENABLED = "live_diagnostics_enabled"
    private const val POST_PROMOTED_NOTIFICATIONS_PERMISSION =
        "android.permission.POST_PROMOTED_NOTIFICATIONS"
    private const val MAX_LOG_BYTES = 256 * 1024L

    private val lastReportedAt = ConcurrentHashMap<String, Long>()

    fun record(
        context: Context,
        category: String,
        message: String,
        extras: Map<String, Any?> = emptyMap(),
    ) {
        if (!isLiveDiagnosticsEnabled(context) || !hasPrivacyConsent(context)) {
            return
        }
        try {
            val payload = buildString {
                appendLine("category=$category")
                appendLine("message=$message")
                if (extras.isNotEmpty()) {
                    appendLine("extras=")
                    extras.forEach { (key, value) ->
                        appendLine("  $key=${value ?: "null"}")
                    }
                }
            }.trim()
            appendToLocalFile(context, payload)
        } catch (error: Exception) {
            Log.w(TAG, "Failed to persist local diagnostic event", error)
        }
    }

    fun report(
        context: Context,
        category: String,
        message: String,
        throwable: Throwable? = null,
        stackTrace: String? = null,
        dedupeKey: String = category,
        extras: Map<String, Any?> = emptyMap(),
    ) {
        if (!isLiveDiagnosticsEnabled(context) || !hasPrivacyConsent(context)) {
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

            appendToLocalFile(context, payload)
        } catch (error: Exception) {
            Log.w(TAG, "Failed to persist local diagnostic log", error)
        }
    }

    fun setLiveDiagnosticsEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(NATIVE_PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_LIVE_DIAGNOSTICS_ENABLED, enabled)
            .apply()
        if (enabled) {
            appendToLocalFile(
                context = context,
                payload = buildString {
                    appendLine("category=diagnostics_enabled")
                    appendLine("message=Live diagnostics logging enabled")
                }.trim()
            )
        }
    }

    fun exportLiveDiagnosticsFile(context: Context): String? {
        if (!isLiveDiagnosticsEnabled(context)) {
            return null
        }
        return runCatching {
            val source = diagnosticLogFile(context)
            if (!source.exists()) {
                appendToLocalFile(
                    context = context,
                    payload = buildString {
                        appendLine("category=diagnostics_bootstrap")
                        appendLine("message=Export requested before any explicit diagnostic events were recorded")
                    }.trim()
                )
            }
            val exportDir = File(context.cacheDir, "exports").apply { mkdirs() }
            val exportFile = File(
                exportDir,
                "mikcb-live-diagnostics-${System.currentTimeMillis()}.log"
            )
            val header = buildString {
                appendLine("轻屿课表 - 超级岛诊断日志")
                appendLine("exportedAt=${System.currentTimeMillis()}")
                buildDiagnosticContext(context).forEach { (key, value) ->
                    appendLine("$key=${value ?: "null"}")
                }
                appendLine("----")
            }
            exportFile.writeText(header + diagnosticLogFile(context).readText())
            exportFile.absolutePath
        }.getOrNull()
    }

    fun clearLiveDiagnostics(context: Context): Boolean {
        if (!isLiveDiagnosticsEnabled(context)) {
            return false
        }
        return runCatching {
            val file = diagnosticLogFile(context)
            if (file.exists()) {
                file.delete()
            }
            appendToLocalFile(
                context = context,
                payload = buildString {
                    appendLine("category=diagnostics_cleared")
                    appendLine("message=Live diagnostics log cleared and restarted")
                }.trim()
            )
            true
        }.getOrDefault(false)
    }

    fun isLiveDiagnosticsEnabled(context: Context): Boolean {
        return context.getSharedPreferences(NATIVE_PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_LIVE_DIAGNOSTICS_ENABLED, false)
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

    private fun appendToLocalFile(context: Context, payload: String) {
        val file = diagnosticLogFile(context)
        file.parentFile?.mkdirs()
        if (file.exists() && file.length() > MAX_LOG_BYTES) {
            val existing = file.readText()
            val retained = existing.takeLast((MAX_LOG_BYTES / 2).toInt())
            file.writeText(retained)
        }
        file.appendText(
            buildString {
                appendLine("time=${System.currentTimeMillis()}")
                appendLine(payload)
                appendLine()
            }
        )
    }

    private fun diagnosticLogFile(context: Context): File {
        return File(context.filesDir, "logs/live_update_diagnostics.log")
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
            "keepAliveAccessibilityEnabled" to isKeepAliveAccessibilityEnabled(context),
            "hideFromRecentsEnabled" to nativePrefs.getBoolean("hide_from_recents", false),
            "taskRemovedRecently" to (
                lastTaskRemovedAt > 0L &&
                    System.currentTimeMillis() - lastTaskRemovedAt < 10 * 60 * 1000L
                ),
            "lastTaskRemovedAt" to lastTaskRemovedAt.takeIf { it > 0L },
            "processImportance" to resolveProcessImportance(context),
            "autoStartStatus" to "unknown",
            "liveEnableBeforeClass" to settings?.optBoolean("liveEnableBeforeClass"),
            "liveEnableDuringClass" to settings?.optBoolean("liveEnableDuringClass"),
            "liveEnableBeforeEnd" to settings?.optBoolean("liveEnableBeforeEnd"),
            "livePromoteDuringClass" to settings?.optBoolean("livePromoteDuringClass"),
            "liveShowDuringClassNotification" to settings?.optBoolean("liveShowDuringClassNotification"),
            "liveShowCountdown" to settings?.optBoolean("liveShowCountdown"),
            "liveShowStageText" to settings?.optBoolean("liveShowStageText"),
            "liveShowCourseName" to settings?.optBoolean("liveShowCourseName"),
            "liveShowLocation" to settings?.optBoolean("liveShowLocation"),
            "liveUseShortName" to settings?.optBoolean("liveUseShortName"),
            "liveHidePrefixText" to settings?.optBoolean("liveHidePrefixText"),
            "liveDuringClassTimeDisplayMode" to settings?.optString("liveDuringClassTimeDisplayMode"),
            "liveEnableMiuiIslandLabelImage" to settings?.optBoolean("liveEnableMiuiIslandLabelImage"),
            "liveMiuiIslandLabelStyle" to settings?.optString("liveMiuiIslandLabelStyle"),
            "liveMiuiIslandLabelContent" to settings?.optString("liveMiuiIslandLabelContent"),
            "liveMiuiIslandLabelFontColor" to settings?.optString("liveMiuiIslandLabelFontColor"),
            "liveMiuiIslandLabelFontWeight" to settings?.optString("liveMiuiIslandLabelFontWeight"),
            "liveMiuiIslandLabelRenderQuality" to settings?.optString("liveMiuiIslandLabelRenderQuality"),
            "liveMiuiIslandLabelFontSize" to settings?.optDouble("liveMiuiIslandLabelFontSize"),
            "liveMiuiIslandLabelOffsetX" to settings?.optDouble("liveMiuiIslandLabelOffsetX"),
            "liveMiuiIslandLabelOffsetY" to settings?.optDouble("liveMiuiIslandLabelOffsetY"),
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

    private fun isKeepAliveAccessibilityEnabled(context: Context): Boolean {
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val expectedComponent = ComponentName(
            context,
            KeepAliveAccessibilityService::class.java
        ).flattenToString()
        return enabledServices
            .split(':')
            .any { it.equals(expectedComponent, ignoreCase = true) }
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
