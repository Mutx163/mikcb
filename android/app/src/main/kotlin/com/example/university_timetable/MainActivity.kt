package com.example.university_timetable

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.Calendar

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "com.example.university_timetable/miui_live"
        private const val CHANNEL_ID = "live_update_channel"
        private const val PERMISSION_REQUEST_CODE = 1001
        private const val POST_PROMOTED_NOTIFICATIONS_PERMISSION =
            "android.permission.POST_PROMOTED_NOTIFICATIONS"
    }

    private var notificationManager: NotificationManager? = null
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannels()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> result.success(true)
                    "checkNotificationPermission" -> result.success(hasNotificationPermission())
                    "requestNotificationPermission" -> {
                        if (hasNotificationPermission()) {
                            result.success(true)
                        } else {
                            permissionResult = result
                            requestNotificationPermission()
                        }
                    }

                    "checkPromotedSupport" -> result.success(checkPromotedSupport())
                    "isIgnoringBatteryOptimizations" ->
                        result.success(isIgnoringBatteryOptimizations())
                    "openNotificationSettings" -> {
                        openNotificationSettings()
                        result.success(true)
                    }
                    "openPromotedSettings" -> {
                        openPromotedSettings()
                        result.success(true)
                    }
                    "openAutoStartSettings" -> {
                        openAutoStartSettings()
                        result.success(true)
                    }
                    "openBatteryOptimizationSettings" -> {
                        openBatteryOptimizationSettings()
                        result.success(true)
                    }

                    "startLiveUpdate" -> {
                        val data = call.arguments as? Map<String, Any>
                        if (data != null) {
                            startLiveUpdateService(data)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENTS", "Missing live update payload", null)
                        }
                    }

                    "stopLiveUpdate" -> {
                        stopLiveUpdateService()
                        result.success(true)
                    }
                    "syncScheduleSnapshot" -> {
                        val snapshotJson = call.arguments as? String
                        if (snapshotJson != null) {
                            LiveUpdateScheduler.syncSnapshot(this, snapshotJson)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENTS", "Missing schedule snapshot", null)
                        }
                    }
                    "clearScheduleSnapshot" -> {
                        LiveUpdateScheduler.clearSnapshot(this)
                        stopLiveUpdateService()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun hasNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                PERMISSION_REQUEST_CODE
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            permissionResult?.success(
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            )
            permissionResult = null
        }
    }

    private fun checkPromotedSupport(): Map<String, Any> {
        return mapOf(
            "androidVersion" to Build.VERSION.SDK_INT,
            "hasNotificationPermission" to hasNotificationPermission(),
            "hasPromotedPermission" to isPromotedPermissionDeclared(),
            "canPostPromoted" to canPostPromotedNotifications(),
        )
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }
        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
        return powerManager?.isIgnoringBatteryOptimizations(packageName) == true
    }

    private fun openNotificationSettings() {
        try {
            startActivity(
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                }
            )
        } catch (e: Exception) {
            Log.w("MainActivity", "Failed to open notification settings", e)
            openAppDetailsSettings()
        }
    }

    private fun openPromotedSettings() {
        if (Build.VERSION.SDK_INT >= 36) {
            try {
                startActivity(
                    Intent(Settings.ACTION_APP_NOTIFICATION_PROMOTION_SETTINGS).apply {
                        putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    }
                )
                return
            } catch (_: ActivityNotFoundException) {
                // Fallback below.
            }
        }

        openNotificationSettings()
    }

    private fun openAutoStartSettings() {
        val intents = listOf(
            Intent().apply {
                component = ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.permissions.PermissionsEditorActivity"
                )
                putExtra("extra_pkgname", packageName)
            }
        )

        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return
            } catch (_: Exception) {
                // Try the next Xiaomi-specific screen.
            }
        }

        openAppDetailsSettings()
    }

    private fun openBatteryOptimizationSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                startActivity(
                    Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                )
                return
            } catch (_: Exception) {
                // Fallback below.
            }

            try {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                return
            } catch (_: Exception) {
                // Fallback below.
            }
        }

        openAppDetailsSettings()
    }

    private fun openAppDetailsSettings() {
        try {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                }
            )
        } catch (e: Exception) {
            Log.w("MainActivity", "Failed to open app details settings", e)
        }
    }

    private fun isPromotedPermissionDeclared(): Boolean {
        return try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong())
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, PackageManager.GET_PERMISSIONS)
            }

            packageInfo.requestedPermissions
                ?.contains(POST_PROMOTED_NOTIFICATIONS_PERMISSION) == true
        } catch (e: Exception) {
            Log.w("MainActivity", "Failed to inspect promoted notification permission", e)
            false
        }
    }

    private fun canPostPromotedNotifications(): Boolean {
        return Build.VERSION.SDK_INT >= 36 &&
            notificationManager?.canPostPromotedNotifications() == true
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "课程表实时更新",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "显示当前课程进度"
            }
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private fun startLiveUpdateService(data: Map<String, Any>) {
        val intent = LiveUpdateScheduler.buildServiceIntentFromMethodPayload(this, data)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopLiveUpdateService() {
        stopService(Intent(this, LiveUpdateService::class.java))
    }
}

class LiveUpdateService : Service() {
    companion object {
        private const val TAG = "LiveUpdateService"
        private const val CHANNEL_ID = "live_update_channel"
        private const val NOTIFICATION_ID = 2001
        private const val EXTRA_REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"
    }

    private val handler = Handler(Looper.getMainLooper())
    private var ticker: Runnable? = null
    private var courseName = ""
    private var shortCourseNameRaw = ""
    private var location = ""
    private var teacher = ""
    private var note = ""
    private var startTimeText = ""
    private var endTimeText = ""
    private var nextName = ""
    private var autoDismissAfterStartMinutes = 0
    private var activityStage = ""
    private var endSecondsCountdownThreshold = 60
    private var showCountdown = true
    private var showCourseNameInIsland = true
    private var showLocationInIsland = true
    private var useShortNameInIsland = false
    private var hidePrefixText = false
    private var startAtMillis = 0L
    private var endAtMillis = 0L
    private var endReminderLeadMillis = 600_000L
    private var enableBeforeClass = true
    private var enableDuringClass = true
    private var enableBeforeEnd = true
    private var promoteDuringClass = true
    private var showNotificationDuringClass = true
    private var progressBreakOffsetsMillis = longArrayOf()
    private var progressMilestoneLabels = emptyList<String>()
    private var progressMilestoneTimeTexts = emptyList<String>()
    private var lastRemainingText = "-1"
    private var lastProgressUnits = -1
    private var lastCriticalTimeText = ""

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        courseName = intent?.getStringExtra("courseName").orEmpty()
        shortCourseNameRaw = intent?.getStringExtra("shortName").orEmpty()
        location = intent?.getStringExtra("location").orEmpty()
        teacher = intent?.getStringExtra("teacher").orEmpty()
        note = intent?.getStringExtra("note").orEmpty()
        startTimeText = intent?.getStringExtra("startTime").orEmpty()
        endTimeText = intent?.getStringExtra("endTime").orEmpty()
        nextName = intent?.getStringExtra("nextName").orEmpty()
        autoDismissAfterStartMinutes = intent?.getIntExtra("autoDismissAfterStartMinutes", 0) ?: 0
        activityStage = intent?.getStringExtra("stage").orEmpty()
        endSecondsCountdownThreshold =
            intent?.getIntExtra("endSecondsCountdownThreshold", 60) ?: 60
        showCountdown = intent?.getBooleanExtra("showCountdown", true) ?: true
        showCourseNameInIsland = intent?.getBooleanExtra("showCourseNameInIsland", true) ?: true
        showLocationInIsland = intent?.getBooleanExtra("showLocationInIsland", true) ?: true
        useShortNameInIsland = intent?.getBooleanExtra("useShortNameInIsland", false) ?: false
        hidePrefixText = intent?.getBooleanExtra("hidePrefixText", false) ?: false
        endReminderLeadMillis =
            intent?.getLongExtra("endReminderLeadMillis", 600_000L)
                ?.coerceAtLeast(0L)
                ?: 600_000L
        enableBeforeClass = intent?.getBooleanExtra("enableBeforeClass", true) ?: true
        enableDuringClass = intent?.getBooleanExtra("enableDuringClass", true) ?: true
        enableBeforeEnd = intent?.getBooleanExtra("enableBeforeEnd", true) ?: true
        promoteDuringClass = intent?.getBooleanExtra("promoteDuringClass", true) ?: true
        showNotificationDuringClass =
            intent?.getBooleanExtra("showNotificationDuringClass", true) ?: true
        progressBreakOffsetsMillis =
            intent?.getLongArrayExtra("progressBreakOffsetsMillis") ?: longArrayOf()
        progressMilestoneLabels =
            intent?.getStringArrayListExtra("progressMilestoneLabels") ?: emptyList()
        progressMilestoneTimeTexts =
            intent?.getStringArrayListExtra("progressMilestoneTimeTexts") ?: emptyList()
        startAtMillis =
            intent?.getLongExtra("startAtMillis", 0L)?.takeIf { it > 0L }
                ?: buildCourseTimeMillis(startTimeText)
                ?: System.currentTimeMillis()
        endAtMillis =
            intent?.getLongExtra("endAtMillis", 0L)?.takeIf { it > 0L }
                ?: buildCourseTimeMillis(endTimeText)
                ?: startAtMillis
        
        lastRemainingText = "-1" // Ensure the first tick always refreshes the notification.
        lastProgressUnits = -1
        lastCriticalTimeText = ""

        Log.d(
            TAG,
            "startLiveUpdate " +
                "courseName=$courseName, " +
                "stage=$activityStage, " +
                "enableBeforeClass=$enableBeforeClass, " +
                "enableDuringClass=$enableDuringClass, " +
                "enableBeforeEnd=$enableBeforeEnd, " +
                "promoteDuringClass=$promoteDuringClass, " +
                "showNotificationDuringClass=$showNotificationDuringClass, " +
                "progressBreakOffsetsMillis=${progressBreakOffsetsMillis.joinToString(prefix = "[", postfix = "]")}, " +
                "progressMilestoneLabels=$progressMilestoneLabels, " +
                "progressMilestoneTimeTexts=$progressMilestoneTimeTexts, " +
                "startAtMillis=$startAtMillis, " +
                "endAtMillis=$endAtMillis, " +
                "endReminderLeadMillis=$endReminderLeadMillis"
        )

        // Publish once immediately so the foreground service becomes resident.
        val initialText = computeRemainingText(System.currentTimeMillis())
        lastRemainingText = initialText
        startForeground(NOTIFICATION_ID, buildNotification(initialText))
        startTicker()
        return START_STICKY
    }

    override fun onDestroy() {
        stopTicker()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        LiveUpdateScheduler.onLiveUpdateStopped(applicationContext)
        super.onDestroy()
    }

    private fun startTicker() {
        stopTicker()
        ticker = object : Runnable {
            override fun run() {
                val now = System.currentTimeMillis()
                val stage = resolveStage(now)
                if (autoDismissAfterStartMinutes > 0 &&
                    now >= startAtMillis + autoDismissAfterStartMinutes * 60_000L
                ) {
                    if (!LiveUpdateScheduler.reschedule(applicationContext, allowImmediateStart = true)) {
                        stopAndRemoveNotification()
                    }
                    return
                }

                if (stage == null) {
                    if (!LiveUpdateScheduler.reschedule(applicationContext, allowImmediateStart = true)) {
                        stopAndRemoveNotification()
                    }
                    return
                }

                if (now >= endAtMillis + 30_000L) { // Auto-remove 30s after class end, especially for tests.
                    if (!LiveUpdateScheduler.reschedule(applicationContext, allowImmediateStart = true)) {
                        stopAndRemoveNotification()
                    }
                    return
                }

                val currentText = computeRemainingText(now)
                val currentDuringClassProgress = if (stage == "duringClass") {
                    buildDuringClassProgress(now)
                } else {
                    null
                }
                val currentProgress = currentDuringClassProgress?.progressUnits ?: -1
                val currentCriticalTimeText = currentDuringClassProgress?.criticalTimeText ?: currentText
                if (stage == "duringClass") {
                    Log.d(
                        TAG,
                        "tick stage=$stage, currentText=$currentText, " +
                            "progress=$currentProgress, " +
                            "criticalTimeText=$currentCriticalTimeText, " +
                            "elapsedMillis=${(now - startAtMillis).coerceAtLeast(0L)}, " +
                            "remainingMillis=${(endAtMillis - now).coerceAtLeast(0L)}"
                    )
                }
                if (currentText != lastRemainingText ||
                    currentProgress != lastProgressUnits ||
                    currentCriticalTimeText != lastCriticalTimeText
                ) {
                    lastRemainingText = currentText
                    lastProgressUnits = currentProgress
                    lastCriticalTimeText = currentCriticalTimeText
                    getSystemService(NotificationManager::class.java)
                        ?.notify(NOTIFICATION_ID, buildNotification(currentText))
                }
                
                // Keep a 1s heartbeat so countdowns and stage transitions update on time.
                handler.postDelayed(this, 1000L)
            }
        }
        handler.post(ticker!!)
    }

    private fun stopTicker() {
        ticker?.let(handler::removeCallbacks)
        ticker = null
    }

    private fun computeRemainingText(now: Long): String {
        val stage = resolveStage(now)
        val timeUntilEnd = endAtMillis - now

        val prefixTextStart = if (hidePrefixText) "" else "距上课"
        val prefixTextEnd = if (hidePrefixText) "" else "距下课"

        return if (!showCountdown) {
            ""
        } else {
            when (stage) {
                "beforeClass" -> {
                    val timeUntilStart = (startAtMillis - now).coerceAtLeast(0L)
                    if (timeUntilStart <= 60_000L) {
                        "${prefixTextStart}${(timeUntilStart / 1000L).coerceAtLeast(0L)}秒"
                    } else {
                        "${prefixTextStart}${formatCustomDuration(timeUntilStart)}"
                    }
                }
                "beforeEnd" -> {
                    if (timeUntilEnd <= endSecondsCountdownThreshold * 1000L) {
                        "${prefixTextEnd}${(timeUntilEnd / 1000L).coerceAtLeast(0L)}秒"
                    } else {
                        "${prefixTextEnd}${formatCustomDuration(timeUntilEnd)}"
                    }
                }
                "duringClass" -> "上课中"
                else -> ""
            }
        }
    }

    private fun resolveStage(now: Long): String? {
        if (now >= endAtMillis) {
            return null
        }

        val endReminderStart = maxOf(startAtMillis, endAtMillis - endReminderLeadMillis)
        return when {
            now < startAtMillis -> if (enableBeforeClass) "beforeClass" else null
            now >= endReminderStart && enableBeforeEnd -> "beforeEnd"
            now < endReminderStart && canDisplayDuringStage() -> "duringClass"
            now >= endReminderStart && canDisplayDuringStage() -> "duringClass"
            else -> null
        }
    }

    private fun canDisplayDuringStage(): Boolean {
        return enableDuringClass && (promoteDuringClass || showNotificationDuringClass)
    }

    private fun isXiaomiFamilyDevice(): Boolean {
        val brand = Build.BRAND.lowercase()
        val manufacturer = Build.MANUFACTURER.lowercase()
        return manufacturer.contains("xiaomi") ||
            brand.contains("xiaomi") ||
            brand.contains("redmi") ||
            brand.contains("poco")
    }

    private fun buildMiuiFocusParam(
        title: String,
        remainingText: String,
        timeRangeText: String,
        bodyContent: String,
    ): String? {
        if (!isXiaomiFamilyDevice()) {
            return null
        }

        return try {
            val extraInfo = JSONObject().apply {
                if (location.isNotBlank()) put("location", location)
                if (teacher.isNotBlank()) put("teacher", teacher)
                if (timeRangeText.isNotBlank()) put("time", timeRangeText)
                if (nextName.isNotBlank()) put("nextCourse", nextName)
            }

            val paramV2 = JSONObject().apply {
                put("protocol", 1)
                put("updatable", true)
                put("enableFloat", true)
                put("ticker", title)
                put(
                    "baseInfo",
                    JSONObject().apply {
                        put("title", title)
                        put("content", bodyContent.ifBlank { remainingText })
                        put("type", 2)
                    }
                )
                if (remainingText.isNotBlank()) {
                    put(
                        "hintInfo",
                        JSONObject().apply {
                            put("type", 1)
                            put("title", remainingText)
                        }
                    )
                }
                if (extraInfo.length() > 0) {
                    put("extraInfo", extraInfo)
                }
            }

            JSONObject().apply {
                put("param_v2", paramV2)
            }.toString()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to build miui.focus.param", e)
            null
        }
    }

    private fun buildNotification(remainingText: String): Notification {
        val now = System.currentTimeMillis()
        val stage = resolveStage(now)
        val isUpcoming = stage == "beforeClass"
        val isEndingSoon = stage == "beforeEnd"
        val isDuringClass = stage == "duringClass"
        val shouldPromote = !isDuringClass || promoteDuringClass
        val showStandardNotification = !isDuringClass || showNotificationDuringClass
        val duringClassProgress = if (isDuringClass) buildDuringClassProgress(now) else null

        val shortCourseName = if (courseName.length > 8) courseName.substring(0, 8) + ".." else courseName
        val nameToUse = if (useShortNameInIsland && shortCourseNameRaw.isNotBlank()) shortCourseNameRaw else courseName
        val islandCourseName = if (showCourseNameInIsland) {
            if (nameToUse.length > 5) nameToUse.substring(0, 5) else nameToUse
        } else ""
        val islandLocation = if (showLocationInIsland) location else ""

        val stageTitle = when (stage) {
            "beforeClass" -> "即将上课"
            "beforeEnd" -> "下课提醒"
            else -> "上课中"
        }
        val title = when (stage) {
            "beforeClass" -> "即将上课: $shortCourseName"
            "beforeEnd" -> "下课提醒: $shortCourseName"
            else -> shortCourseName
        }
        val shortNameLabel = shortCourseNameRaw.takeIf { it.isNotBlank() && it != courseName }
        val timeRangeText = if (startTimeText.isNotBlank() || endTimeText.isNotBlank()) {
            "$startTimeText - $endTimeText".trim()
        } else {
            ""
        }
        val subText = if (isUpcoming) {
            listOf(
                timeRangeText.takeIf { it.isNotBlank() }?.let { "上课时间: $it" },
                location.takeIf { it.isNotBlank() }?.let { "地点: $it" }
            ).filterNotNull().joinToString("  ·  ")
        } else if (isEndingSoon) {
            listOf(
                timeRangeText.takeIf { it.isNotBlank() }?.let { "下课时间: $it" },
                location.takeIf { it.isNotBlank() }?.let { "地点: $it" }
            ).filterNotNull().joinToString("  ·  ")
        } else {
            ""
        }
        val summaryText = if (isDuringClass && duringClassProgress != null) {
            listOf(
                duringClassProgress.nextMilestoneDisplayText,
                duringClassProgress.finalDismissDisplayText,
                location.takeIf { it.isNotBlank() }
            ).filterNotNull().joinToString(" · ")
        } else {
            listOf(
                location.takeIf { it.isNotBlank() },
                teacher.takeIf { it.isNotBlank() },
                remainingText.takeIf { it.isNotBlank() }
            ).filterNotNull().joinToString(" · ")
        }

        val notificationIntent = Intent(this, MainActivity::class.java).apply {
            this.action = Intent.ACTION_MAIN
            this.addCategory(Intent.CATEGORY_LAUNCHER)
            this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val detailStatusText = when {
            isDuringClass && duringClassProgress != null -> null
            remainingText.isNotBlank() && !shouldPromote -> remainingText
            else -> null
        }

        val expandedDetailText = buildString {
            append(stageTitle)
            append("\n课程: ").append(courseName)
            if (shortNameLabel != null) append("\n简称: ").append(shortNameLabel)
            if (isDuringClass && duringClassProgress != null) {
                if (duringClassProgress.nextMilestoneDisplayText != null) {
                    append("\n下一节点: ").append(duringClassProgress.nextMilestoneDisplayText)
                }
                append("\n整节下课: ").append(duringClassProgress.finalDismissDisplayText)
            } else if (detailStatusText != null) {
                append("\n状态: ").append(detailStatusText)
            }
            if (timeRangeText.isNotBlank()) append("\n时间: ").append(timeRangeText)
            if (location.isNotBlank()) append("\n地点: ").append(location)
            if (teacher.isNotBlank()) append("\n教师: ").append(teacher)
            if (nextName.isNotBlank()) append("\n下一节: ").append(nextName)
            if (note.isNotBlank()) append("\n备注: ").append(note)
        }

        val promotedContentText = if (isDuringClass && duringClassProgress != null) {
            listOf(
                duringClassProgress.nextMilestoneDisplayText,
                duringClassProgress.finalDismissDisplayText,
                location.takeIf { it.isNotBlank() }
            ).filterNotNull().joinToString(" · ")
        } else {
            listOf(
                remainingText.takeIf { it.isNotBlank() },
                timeRangeText.takeIf { it.isNotBlank() },
                location.takeIf { it.isNotBlank() },
                teacher.takeIf { it.isNotBlank() }
            ).filterNotNull().joinToString(" · ")
        }
        val promotedExpandedDetailText = buildString {
            if (isDuringClass && duringClassProgress != null) {
                if (duringClassProgress.nextMilestoneDisplayText != null) {
                    append("下一节点: ").append(duringClassProgress.nextMilestoneDisplayText)
                    append("\n")
                }
                append("整节下课: ").append(duringClassProgress.finalDismissDisplayText)
            } else if (detailStatusText != null) {
                append("状态: ").append(detailStatusText)
            }
            if (timeRangeText.isNotBlank()) append("\n时间: ").append(timeRangeText)
            if (location.isNotBlank()) append("\n地点: ").append(location)
            if (teacher.isNotBlank()) append("\n教师: ").append(teacher)
            append("\n课程: ").append(courseName)
            if (shortNameLabel != null) append("\n简称: ").append(shortNameLabel)
            if (nextName.isNotBlank()) append("\n下一节: ").append(nextName)
            if (note.isNotBlank()) append("\n备注: ").append(note)
        }

        val contentText = if (!showStandardNotification) {
            ""
        } else if (isDuringClass && duringClassProgress != null) {
            promotedContentText
        } else if (shouldPromote && !showCourseNameInIsland && !showLocationInIsland) {
            remainingText
        } else {
            listOf(islandCourseName, islandLocation, teacher, remainingText)
                .filter { it.isNotBlank() }
                .joinToString(" · ")
        }
            
        val miuiFocusParam = buildMiuiFocusParam(
            title = title,
            remainingText = remainingText,
            timeRangeText = timeRangeText,
            bodyContent = if (shouldPromote) promotedContentText else contentText,
        )

        val islandCriticalStatusText = if (isDuringClass && duringClassProgress != null) {
            duringClassProgress.criticalTimeText
        } else {
            remainingText
        }

        val islandCriticalText = if (shouldPromote && !showCourseNameInIsland && !showLocationInIsland) {
            islandCriticalStatusText
        } else {
            listOf(islandCourseName, islandLocation, islandCriticalStatusText)
                .filter { it.isNotBlank() }
                .joinToString(" ")
        }

        val iconRes = when (stage) {
            "beforeClass" -> R.drawable.ic_upcoming
            "beforeEnd" -> R.drawable.ic_countdown
            else -> R.drawable.ic_course
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }

        val notificationTitle = if (showStandardNotification) title else ""
        val notificationContentText = if (!showStandardNotification) {
            ""
        } else if (shouldPromote) {
            promotedContentText
        } else {
            contentText
        }
        val notificationExpandedText = if (!showStandardNotification) {
            ""
        } else if (shouldPromote) {
            promotedExpandedDetailText
        } else {
            expandedDetailText
        }

        builder.apply {
            setContentTitle(notificationTitle)
            setContentText(notificationContentText)
            setSmallIcon(iconRes)
            setContentIntent(pendingIntent)
            setOngoing(true)
            setAutoCancel(false)
            setOnlyAlertOnce(true)
            setCategory(Notification.CATEGORY_PROGRESS)
            setColorized(false)
            setShowWhen(!shouldPromote)
            setWhen(if (isUpcoming) startAtMillis else endAtMillis)
            setUsesChronometer(false)
            if (isDuringClass && duringClassProgress != null) {
                setProgress(duringClassProgress.progressMax, duringClassProgress.progressUnits, false)
            } else {
                setProgress(0, 0, false)
            }

            if (showStandardNotification && !shouldPromote && subText.isNotBlank()) {
                setSubText(subText)
            }

            if (Build.VERSION.SDK_INT >= 36) {
                if (shouldPromote) {
                    setShortCriticalText(islandCriticalText)
                    setExtras(
                        Bundle().apply {
                            putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true)
                        }
                    )
                } else {
                    setShortCriticalText("")
                    setExtras(
                        Bundle().apply {
                            putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, false)
                        }
                    )
                }
            }
        }

        if (Build.VERSION.SDK_INT >= 36 && isDuringClass && duringClassProgress != null) {
            builder.setStyle(
                Notification.ProgressStyle()
                    .setStyledByProgress(true)
                    .setProgress(duringClassProgress.progressUnits)
                    .setProgressSegments(
                        listOf(
                            Notification.ProgressStyle.Segment(
                                duringClassProgress.progressMax
                            )
                        )
                    )
                    .setProgressTrackerIcon(Icon.createWithResource(this, R.drawable.ic_course))
                    .setProgressPoints(
                        duringClassProgress.breakPointUnits.map { point ->
                            Notification.ProgressStyle.Point(point)
                        }
                    )
            )
        } else {
            builder.setStyle(
                Notification.BigTextStyle()
                    .setBigContentTitle(notificationTitle)
                    .bigText(notificationExpandedText)
                    .setSummaryText(if (showStandardNotification) summaryText else "")
            )
        }

        val notification = builder.build()
        miuiFocusParam?.let { notification.extras.putString("miui.focus.param", it) }

        if (Build.VERSION.SDK_INT >= 36) {
            val canPostPromoted =
                getSystemService(NotificationManager::class.java)?.canPostPromotedNotifications() == true
            Log.d(
                TAG,
                "buildNotification " +
                    "stage=$stage, " +
                    "isUpcoming=$isUpcoming, " +
                    "isDuringClass=$isDuringClass, " +
                    "isEndingSoon=$isEndingSoon, " +
                    "shouldPromote=$shouldPromote, " +
                    "showStandardNotification=$showStandardNotification, " +
                    "requestPromoted=${notification.extras?.getBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, false) == true}, " +
                    "hasPromotableCharacteristics=${notification.hasPromotableCharacteristics()}, " +
                    "canPostPromoted=$canPostPromoted, " +
                    "remainingText=$remainingText, " +
                    "progress=${duringClassProgress?.progressUnits}, " +
                    "progressPercent=${duringClassProgress?.progressPercent}, " +
                    "progressPoints=${duringClassProgress?.breakPointUnits}, " +
                    "startAtMillis=$startAtMillis, " +
                    "endAtMillis=$endAtMillis"
            )
        }

        return notification
    }

    private fun stopAndRemoveNotification() {
        stopTicker()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        LiveUpdateScheduler.onLiveUpdateStopped(applicationContext)
        stopSelf()
    }

    private fun buildCourseTimeMillis(timeText: String): Long? {
        val parts = timeText.split(":")
        if (parts.size != 2) {
            return null
        }

        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null

        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    private fun formatCustomDuration(durationMillis: Long): String {
        val totalSeconds = (durationMillis / 1000L).coerceAtLeast(0L)
        val roundedUpMinutes = (totalSeconds + 59L) / 60L

        return when {
            totalSeconds > 60L -> "${roundedUpMinutes}分钟"
            else -> "${totalSeconds}秒"
        }
    }

    private data class DuringClassProgress(
        val progressMax: Int,
        val progressUnits: Int,
        val progressPercent: Int,
        val nextMilestoneDisplayText: String?,
        val finalDismissDisplayText: String,
        val criticalTimeText: String,
        val breakPointUnits: List<Int>,
    )

    private fun buildDuringClassProgress(now: Long): DuringClassProgress? {
        val totalMillis = (endAtMillis - startAtMillis).coerceAtLeast(1L)
        val elapsedMillis = (now - startAtMillis).coerceIn(0L, totalMillis)
        val remainingMillis = (endAtMillis - now).coerceAtLeast(0L)
        val progressMax = 1000
        val progressUnits = ((elapsedMillis * progressMax) / totalMillis).toInt().coerceIn(0, progressMax)
        val progressPercent = ((elapsedMillis * 100L) / totalMillis).toInt().coerceIn(0, 100)
        val breakPointUnits = progressBreakOffsetsMillis
            .map { offsetMillis ->
                ((offsetMillis.coerceIn(0L, totalMillis) * progressMax) / totalMillis)
                    .toInt()
                    .coerceIn(1, progressMax - 1)
            }
            .distinct()
            .sorted()
        val nextMilestoneIndex =
            progressBreakOffsetsMillis.indexOfFirst { it > elapsedMillis }.takeIf { it >= 0 }
        val nextMilestoneLabel =
            nextMilestoneIndex?.let { progressMilestoneLabels.getOrNull(it)?.takeIf { label -> label.isNotBlank() } }
        val nextMilestoneRemainingText =
            nextMilestoneIndex?.let { formatCustomDuration(progressBreakOffsetsMillis[it] - elapsedMillis) }
        val finalDismissRemainingText = formatCustomDuration(remainingMillis)
        val nextMilestoneDisplayText =
            if (nextMilestoneLabel != null && nextMilestoneRemainingText != null) {
                "$nextMilestoneLabel $nextMilestoneRemainingText"
            } else if (nextMilestoneRemainingText != null) {
                nextMilestoneRemainingText
            } else {
                null
            }
        val finalDismissDisplayText = "整节下课 $finalDismissRemainingText"
        val criticalTimeText =
            if (nextMilestoneRemainingText != null &&
                nextMilestoneRemainingText != finalDismissRemainingText
            ) {
                "$nextMilestoneRemainingText / $finalDismissRemainingText"
            } else {
                finalDismissRemainingText
            }
        return DuringClassProgress(
            progressMax = progressMax,
            progressUnits = progressUnits,
            progressPercent = progressPercent,
            nextMilestoneDisplayText = nextMilestoneDisplayText,
            finalDismissDisplayText = finalDismissDisplayText,
            criticalTimeText = criticalTimeText,
            breakPointUnits = breakPointUnits,
        )
    }

    private fun formatProgressDuration(durationMillis: Long): String {
        val totalSeconds = (durationMillis / 1000L).coerceAtLeast(0L)
        val minutes = totalSeconds / 60L
        val seconds = totalSeconds % 60L

        return when {
            minutes > 0L && seconds > 0L -> "${minutes}分${seconds}秒"
            minutes > 0L -> "${minutes}分钟"
            else -> "${seconds}秒"
        }
    }
}
