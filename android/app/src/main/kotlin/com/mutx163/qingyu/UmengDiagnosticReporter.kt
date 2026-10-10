package com.mutx163.qingyu

import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.util.Log
import org.json.JSONObject
import java.io.File
import java.util.concurrent.ConcurrentHashMap

object UmengDiagnosticReporter {
    private const val TAG = "UmengDiagnostic"
    private const val LEVEL_ERROR = "error"
    private const val LEVEL_WARN = "warn"
    private const val LEVEL_INFO = "info"
    private const val LEVEL_DEBUG = "debug"
    private const val LEVEL_VERBOSE = "verbose"
    private val SUPPORTED_LEVELS = setOf(
        LEVEL_ERROR,
        LEVEL_WARN,
        LEVEL_INFO,
        LEVEL_DEBUG,
        LEVEL_VERBOSE,
    )
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
        level: String? = null,
        extras: Map<String, Any?> = emptyMap(),
    ) {
        if (!isLiveDiagnosticsEnabled(context) || !hasPrivacyConsent(context)) {
            return
        }
        try {
            val payload = buildString {
                appendLine(
                    "level=${normalizeLevel(level, category = category, message = message, defaultLevel = LEVEL_INFO)}"
                )
                appendLine("category=$category")
                // message 是调用方拼的自由文本（可能带 `course=…` 形态的课名），
                // 与 extras 同口径过一遍字段表 —— 审查确认这条出口原先零防线。
                appendLine("message=${redactPersonalFields(message)}")
                if (extras.isNotEmpty()) {
                    appendLine("extras=")
                    extras.forEach { (key, value) ->
                        appendLine("  $key=${redactExtrasValue(key, value)}")
                    }
                }
            }.trim()
            appendToLocalFile(context, payload)
        } catch (error: Exception) {
            Log.w(TAG, DiagnosticLogMessages.LOG_PERSIST_DIAGNOSTIC_EVENT_FAILED, error)
        }
    }

    fun report(
        context: Context,
        category: String,
        message: String,
        level: String? = null,
        throwable: Throwable? = null,
        stackTrace: String? = null,
        dedupeKey: String = category,
        // FGS 启动被拒这类低频高危事件必须全程留痕（退避重试的每次失败都要可见），
        // 不受 2 分钟节流窗口约束；常规高频事件仍走节流。
        bypassThrottle: Boolean = false,
        extras: Map<String, Any?> = emptyMap(),
    ) {
        if (!isLiveDiagnosticsEnabled(context) || !hasPrivacyConsent(context)) {
            return
        }
        if (!bypassThrottle && shouldThrottle(dedupeKey)) {
            return
        }

        try {
            val payload = buildString {
                appendLine(
                    "level=${normalizeLevel(
                        level,
                        category = category,
                        message = message,
                        defaultLevel = if (throwable != null || !stackTrace.isNullOrBlank() || extras["error"] != null) LEVEL_ERROR else LEVEL_WARN,
                        hasThrowable = throwable != null,
                        hasStackTrace = !stackTrace.isNullOrBlank(),
                        hasExplicitError = extras["error"] != null,
                    )}"
                )
                appendLine("category=$category")
                appendLine("message=${redactPersonalFields(message)}")
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
                        appendLine("  $key=${redactExtrasValue(key, value)}")
                    }
                }
                if (!stackTrace.isNullOrBlank()) {
                    appendLine("stackTrace=")
                    // 栈文本里常带异常消息原文（schoolName / 课名 / URL 都进过栈），
                    // 紧挨着的 `message=` 洗过而这行原样 = 白洗。同口径过字段表。
                    appendLine(redactPersonalFields(stackTrace))
                }
                if (throwable != null) {
                    appendLine("throwable=")
                    appendLine(redactPersonalFields(Log.getStackTraceString(throwable)))
                }
            }.trim()

            appendToLocalFile(context, payload)
        } catch (error: Exception) {
            Log.w(TAG, DiagnosticLogMessages.LOG_PERSIST_DIAGNOSTIC_LOG_FAILED, error)
        }
    }

    fun setLiveDiagnosticsEnabled(context: Context, enabled: Boolean) {
        val prefs = context.getSharedPreferences(NATIVE_PREFS_NAME, Context.MODE_PRIVATE)
        // 状态未变化不记录（每次冷启动会收到重复的开启调用，
        // 2026-09 日志卫生审计：同一秒内 ×2）。
        val changed = prefs.getBoolean(KEY_LIVE_DIAGNOSTICS_ENABLED, false) != enabled
        prefs.edit()
            .putBoolean(KEY_LIVE_DIAGNOSTICS_ENABLED, enabled)
            .apply()
        if (!changed) {
            return
        }
        if (enabled) {
            appendToLocalFile(
                context = context,
                payload = buildString {
                    appendLine("level=$LEVEL_INFO")
                    appendLine("category=diagnostics_enabled")
                    appendLine("message=${DiagnosticLogMessages.LIVE_DIAGNOSTICS_ENABLED}")
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
                        appendLine("level=$LEVEL_INFO")
                        appendLine("category=diagnostics_bootstrap")
                        appendLine("message=${DiagnosticLogMessages.EXPORT_BEFORE_EVENTS}")
                    }.trim()
                )
            }
            val exportDir = File(context.cacheDir, "exports").apply { mkdirs() }
            val exportFile = File(
                exportDir,
                "mikcb-live-diagnostics-${System.currentTimeMillis()}.log"
            )
            val header = buildString {
                appendLine("轻屿课表 - 应用日志")
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

    fun readLiveDiagnosticsText(
        context: Context,
        maxChars: Int = 120_000,
    ): String? {
        if (!isLiveDiagnosticsEnabled(context)) {
            return null
        }
        return runCatching {
            val file = diagnosticLogFile(context)
            if (!file.exists()) {
                return@runCatching null
            }
            val header = buildString {
                appendLine("轻屿课表 - 应用日志")
                appendLine("exportedAt=${System.currentTimeMillis()}")
                buildDiagnosticContext(context).forEach { (key, value) ->
                    appendLine("$key=${value ?: "null"}")
                }
                appendLine("----")
            }
            val body = file.readText().trim()
            if (body.isEmpty()) {
                return@runCatching null
            }
            val combined = (header + body).trim()
            if (combined.length <= maxChars) {
                combined
            } else {
                val truncatedBody = body.takeLast((maxChars - header.length).coerceAtLeast(0))
                buildString {
                    append(header)
                    appendLine("truncated=true")
                    appendLine("truncatedHint=日志过长，当前仅显示最新一部分内容")
                    appendLine("----")
                    append(truncatedBody.trimStart())
                }.trim()
            }
        }.getOrNull()
    }

    fun clearLiveDiagnostics(context: Context): Boolean {
        return runCatching {
            val file = diagnosticLogFile(context)
            if (file.exists()) {
                file.delete()
            }
            if (isLiveDiagnosticsEnabled(context) && hasPrivacyConsent(context)) {
                appendToLocalFile(
                    context = context,
                    payload = buildString {
                        appendLine("level=$LEVEL_INFO")
                        appendLine("category=diagnostics_cleared")
                        appendLine("message=${DiagnosticLogMessages.DIAGNOSTICS_CLEARED}")
                    }.trim()
                )
            }
            true
        }.getOrDefault(false)
    }

    fun readLiveDiagnosticsTail(
        context: Context,
        maxChars: Int = 6000,
    ): String? {
        if (!isLiveDiagnosticsEnabled(context)) {
            return null
        }
        return runCatching {
            val file = diagnosticLogFile(context)
            if (!file.exists()) {
                return@runCatching null
            }
            val text = file.readText()
            if (text.length <= maxChars) {
                text.trim().ifEmpty { null }
            } else {
                text.takeLast(maxChars).trim().ifEmpty { null }
            }
        }.getOrNull()
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

    /**
     * 会认到人的字段（值要盖成 `**`），与 Dart 侧
     * `lib/logging/app_debug_log.dart` 的 `personalLogFieldKeys` 对齐。
     *
     * ⚠️ 两边各维护一份、无法共享代码：改这份表时**必须同步** Dart 那份，
     * 否则又变成「改了这份、漏了那份」。2026-10-08 审核实测的泄漏正是这么来的 ——
     * Dart 侧 fd4aa078 只把 `recordDiagnosticEvent` 送出前脱敏了，而 Kotlin 自己调
     * `record()` / `report()` 的这些点（例如实时活动启动失败打 `courseName=高等数学`）
     * 整份原样进了用户导出的 `live_update_diagnostics.log`。查表大小写不敏感，
     * 与 Dart 侧 `isPersonalLogFieldKey` 同口径。
     */
    private val personalLogFieldKeysLower: Set<String> = setOf(
        "course", "coursename", "name", "shortname", "teacher", "loc", "location",
        "groupname", "group", "keyword", "keywords", "classname", "studentname",
        "overflownames", "changesamples", "sampleoverrides",
        // 2026-10-10 补（10-09 隐私审查发现 2），与 Dart 侧同步：
        // 用户可见的课表名 / 改名前的课程名 / 局域网客户端 IP。
        "profilename", "originalname", "clientip",
    )

    internal fun isPersonalLogFieldKey(key: String): Boolean =
        personalLogFieldKeysLower.contains(key.lowercase())

    /** extras 里命中敏感键的值盖成 `**`，其余原样。 */
    internal fun redactExtrasValue(key: String, value: Any?): String =
        if (isPersonalLogFieldKey(key)) "**" else "${value ?: "null"}"

    /**
     * 自由文本行（`message=` / `stackTrace=` / `throwable=`）的 `key=value` 脱敏。
     *
     * 为什么必须要有它：extras 那条出口（[redactExtrasValue]）只管**结构化**的
     * `Map` 入参，而 2026-10-09 审查确认这三行**至今没有任何防线** ——
     * 任何人在原生侧写一句 `record(..., "起岛失败：course=$courseName")`，
     * 课程名就整份进了用户导出的 `live_update_diagnostics.log`，Dart 侧那份
     * 洗过的代码完全拦不住。与 Dart 侧 `redactPersonalFields` 同口径：
     * `key` 大小写不敏感、允许 `=` 前后空格、行首可命中、值吃到下一个
     * 空白 / `&` / `|` 为止（id / 计数 / 钟点这些取证量原样保留）。
     */
    internal fun redactPersonalFields(message: String): String {
        // 前置边界比 Dart 侧多认 `(` / `[` / `,`：Kotlin 这条出口大头是
        // stackTrace / throwable，栈帧形态 `at Course.from(name=高等数学)` 里
        // key 紧贴 `(`，按 Dart 的 `(^|[\s&|])` 边界一条都命中不了
        // （10-09 审查发现 4 记过这条机制缺口，Dart 侧暂未放宽）。
        val pattern = Regex("(^|[\\s&|(,])([A-Za-z_][A-Za-z0-9_]*)\\s*=\\s*([^\\s&|]*)", setOf(RegexOption.MULTILINE, RegexOption.IGNORE_CASE))
        val out = StringBuilder()
        var cursor = 0
        for (match in pattern.findAll(message)) {
            val key = match.groupValues[2]
            if (!isPersonalLogFieldKey(key)) continue
            if (match.range.first < cursor) continue
            out.append(message, cursor, match.range.first)
            out.append(match.groupValues[1]).append(key).append("=**")
            cursor = match.range.last + 1
        }
        out.append(message, cursor, message.length)
        return out.toString()
    }

    private fun normalizeLevel(
        level: String?,
        category: String,
        message: String,
        defaultLevel: String,
        hasThrowable: Boolean = false,
        hasStackTrace: Boolean = false,
        hasExplicitError: Boolean = false,
    ): String {
        val normalized = level
            ?.trim()
            ?.lowercase()
            ?.takeIf { it in SUPPORTED_LEVELS }
        if (normalized != null) {
            return normalized
        }
        if (hasThrowable || hasStackTrace || hasExplicitError) {
            return LEVEL_ERROR
        }
        val source = "$category $message".lowercase()
        return when {
            "error" in source || "exception" in source || "fatal" in source || "crash" in source -> LEVEL_ERROR
            "warn" in source || "warning" in source -> LEVEL_WARN
            "verbose" in source || "trace" in source -> LEVEL_VERBOSE
            "debug" in source -> LEVEL_DEBUG
            "info" in source -> LEVEL_INFO
            else -> defaultLevel
        }
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
            // 复用引导页的 AppOps 反射检测（OP_AUTO_START）；仅当厂商接口与
            // 电池优化推断都无法给出确定值时才报 unknown。
            "autoStartStatus" to resolveAutoStartStatus(context),
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
        return KeepAliveAccessibilityStatus.isEnabled(context)
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

    /// 自启动状态三态：allowed / denied / unknown。
    /// 检测链与引导页（MainActivity.isAutoStartEnabled）同源：先 AppOps 反射
    /// （小米/OPPO/Vivo/一加 OP_AUTO_START=10008），再电池优化间接推断；
    /// 两者都无法给确定值时返回 unknown（引导页对 unknown 乐观视为开启）。
    fun resolveAutoStartStatus(context: Context): String {
        val appOpsResult = checkAutoStartViaAppOps(context)
        if (appOpsResult != null) return if (appOpsResult) "allowed" else "denied"
        val batteryResult = checkAutoStartViaBattery(context)
        if (batteryResult != null) return if (batteryResult) "allowed" else "denied"
        return "unknown"
    }

    /** 通过 AppOps 反射检测自启动状态；不适用时返回 null。 */
    private fun checkAutoStartViaAppOps(context: Context): Boolean? {
        return try {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val method = AppOpsManager::class.java.getMethod(
                "checkOpNoThrow",
                Int::class.javaPrimitiveType,
                Int::class.javaPrimitiveType,
                String::class.java,
            )
            // OP_AUTO_START = 10008 (小米/OPPO/Vivo 等厂商通用)
            val result = method.invoke(
                appOps,
                10008,
                android.os.Process.myUid(),
                context.packageName,
            ) as Int
            when (result) {
                AppOpsManager.MODE_ALLOWED -> true
                AppOpsManager.MODE_IGNORED,
                AppOpsManager.MODE_ERRORED,
                -> false
                else -> null // MODE_DEFAULT 等，说明此 OP 不适用于当前设备
            }
        } catch (_: Exception) {
            null
        }
    }

    /** 通过电池优化状态间接推断；无法推断时返回 null。 */
    private fun checkAutoStartViaBattery(context: Context): Boolean? {
        return try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            powerManager?.isIgnoringBatteryOptimizations(context.packageName)
        } catch (_: Exception) {
            null
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
                // 230 = IMPORTANCE_TOP_SLEEPING：设备息屏前的 top 进程（UI 曾在前台、
                // 设备休眠后系统保留的中间态），是 FGS 后台启动被拒的高危态。
                // 用数字字面量映射，规避弃用符号在各 compileSdk 下的可用性差异。
                230 -> "top_sleeping"
                null -> "unknown"
                else -> currentProcess.importance.toString()
            }
        } catch (_: Exception) {
            "unknown"
        }
    }
}
