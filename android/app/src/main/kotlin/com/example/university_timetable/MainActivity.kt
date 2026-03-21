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
        val intent = Intent(this, LiveUpdateService::class.java)
        val current = data["currentCourse"] as? Map<String, Any>
        val next = data["nextCourse"] as? Map<String, Any>
        val autoDismissAfterStartMinutes =
            (data["autoDismissAfterStartMinutes"] as? Number)?.toInt() ?: 0
        val stage = data["stage"] as? String ?: ""
        val startAtMillis = (data["startAtMillis"] as? Number)?.toLong() ?: 0L
        val endAtMillis = (data["endAtMillis"] as? Number)?.toLong() ?: 0L
        val endReminderLeadMillis =
            (data["endReminderLeadMillis"] as? Number)?.toLong() ?: 600_000L
        val endSecondsCountdownThreshold =
            (data["endSecondsCountdownThreshold"] as? Number)?.toInt() ?: 60
        val enableBeforeClass = data["enableBeforeClass"] as? Boolean ?: true
        val enableDuringClass = data["enableDuringClass"] as? Boolean ?: true
        val enableBeforeEnd = data["enableBeforeEnd"] as? Boolean ?: true
        val promoteDuringClass = data["promoteDuringClass"] as? Boolean ?: true
        val showNotificationDuringClass =
            data["showNotificationDuringClass"] as? Boolean ?: true
        val showCountdown = data["showCountdown"] as? Boolean ?: true

        val islandConfig = data["islandConfig"] as? java.util.Map<String, Any>
        val showCourseName = islandConfig?.get("showCourseName") as? Boolean ?: true
        val showLocation = islandConfig?.get("showLocation") as? Boolean ?: true
        val useShortName = islandConfig?.get("useShortName") as? Boolean ?: false
        val hidePrefixText = islandConfig?.get("hidePrefixText") as? Boolean ?: false

        intent.putExtra("courseName", current?.get("name") as? String ?: "")
        intent.putExtra("shortName", current?.get("shortName") as? String ?: "")
        intent.putExtra("location", current?.get("location") as? String ?: "")
        intent.putExtra("teacher", current?.get("teacher") as? String ?: "")
        intent.putExtra("note", current?.get("note") as? String ?: "")
        intent.putExtra("startTime", current?.get("startTime") as? String ?: "")
        intent.putExtra("endTime", current?.get("endTime") as? String ?: "")
        intent.putExtra("nextName", next?.get("name") as? String ?: "")
        intent.putExtra("autoDismissAfterStartMinutes", autoDismissAfterStartMinutes)
        intent.putExtra("stage", stage)
        intent.putExtra("startAtMillis", startAtMillis)
        intent.putExtra("endAtMillis", endAtMillis)
        intent.putExtra("endReminderLeadMillis", endReminderLeadMillis)
        intent.putExtra("endSecondsCountdownThreshold", endSecondsCountdownThreshold)
        intent.putExtra("enableBeforeClass", enableBeforeClass)
        intent.putExtra("enableDuringClass", enableDuringClass)
        intent.putExtra("enableBeforeEnd", enableBeforeEnd)
        intent.putExtra("promoteDuringClass", promoteDuringClass)
        intent.putExtra("showNotificationDuringClass", showNotificationDuringClass)
        intent.putExtra("showCountdown", showCountdown)
        intent.putExtra("showCourseNameInIsland", showCourseName)
        intent.putExtra("showLocationInIsland", showLocation)
        intent.putExtra("useShortNameInIsland", useShortName)
        intent.putExtra("hidePrefixText", hidePrefixText)

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
    private var lastRemainingText = "-1"

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
        startAtMillis =
            intent?.getLongExtra("startAtMillis", 0L)?.takeIf { it > 0L }
                ?: buildCourseTimeMillis(startTimeText)
                ?: System.currentTimeMillis()
        endAtMillis =
            intent?.getLongExtra("endAtMillis", 0L)?.takeIf { it > 0L }
                ?: buildCourseTimeMillis(endTimeText)
                ?: startAtMillis
        
        lastRemainingText = "-1" // Ensure the first tick always refreshes the notification.

        // Publish once immediately so the foreground service becomes resident.
        val initialText = computeRemainingText(System.currentTimeMillis())
        lastRemainingText = initialText
        startForeground(NOTIFICATION_ID, buildNotification(initialText))
        startTicker()
        return START_STICKY
    }

    override fun onDestroy() {
        stopTicker()
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
                    stopAndRemoveNotification()
                    return
                }

                if (stage == null) {
                    stopAndRemoveNotification()
                    return
                }

                if (now >= endAtMillis + 30_000L) { // Auto-remove 30s after class end, especially for tests.
                    stopAndRemoveNotification()
                    return
                }

                val currentText = computeRemainingText(now)
                if (currentText != lastRemainingText) {
                    lastRemainingText = currentText
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
                "beforeClass" -> "${prefixTextStart}${formatCustomDuration(startAtMillis - now)}"
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
            now < endReminderStart && enableDuringClass -> "duringClass"
            now >= startAtMillis && enableBeforeEnd && endReminderStart <= startAtMillis -> "beforeEnd"
            else -> null
        }
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
            listOf(
                nextName.takeIf { it.isNotBlank() }?.let { "下一节: $it" },
                timeRangeText.takeIf { it.isNotBlank() }?.let { "本节时间: $it" }
            ).filterNotNull().joinToString("  ·  ")
        }
        val summaryText = listOf(
            location.takeIf { it.isNotBlank() },
            teacher.takeIf { it.isNotBlank() },
            remainingText.takeIf { it.isNotBlank() }
        ).filterNotNull().joinToString(" · ")

        val notificationIntent = Intent(this, MainActivity::class.java).apply {
            this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val expandedDetailText = buildString {
            append(stageTitle)
            append("\n课程: ").append(courseName)
            if (shortNameLabel != null) append("\n简称: ").append(shortNameLabel)
            append("\n状态: ").append(remainingText)
            if (timeRangeText.isNotBlank()) append("\n时间: ").append(timeRangeText)
            if (location.isNotBlank()) append("\n地点: ").append(location)
            if (teacher.isNotBlank()) append("\n教师: ").append(teacher)
            if (nextName.isNotBlank()) append("\n下一节: ").append(nextName)
            if (note.isNotBlank()) append("\n备注: ").append(note)
        }

        val promotedContentText = listOf(
            remainingText.takeIf { it.isNotBlank() },
            timeRangeText.takeIf { it.isNotBlank() },
            location.takeIf { it.isNotBlank() },
            teacher.takeIf { it.isNotBlank() }
).filterNotNull().joinToString(" · ")
        val promotedExpandedDetailText = buildString {
            append("状态: ").append(remainingText)
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

        val islandCriticalText = if (shouldPromote && !showCourseNameInIsland && !showLocationInIsland) {
            remainingText
        } else {
            listOf(islandCourseName, islandLocation, remainingText)
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
            setStyle(
                Notification.BigTextStyle()
                    .setBigContentTitle(notificationTitle)
                    .bigText(notificationExpandedText)
                    .setSummaryText(if (showStandardNotification) summaryText else "")
            )
            setCategory(Notification.CATEGORY_PROGRESS)
            setColorized(false)
            setShowWhen(!shouldPromote)
            setWhen(if (isUpcoming) startAtMillis else endAtMillis)
            setUsesChronometer(false)

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

        val notification = builder.build()
        miuiFocusParam?.let { notification.extras.putString("miui.focus.param", it) }

        if (Build.VERSION.SDK_INT >= 36) {
            val canPostPromoted =
                getSystemService(NotificationManager::class.java)?.canPostPromotedNotifications() == true
            Log.d(
                TAG,
                "requestPromoted=${notification.extras?.getBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, false) == true}, " +
                    "hasPromotableCharacteristics=${notification.hasPromotableCharacteristics()}, " +
                    "canPostPromoted=$canPostPromoted, " +
                    "remainingText=$remainingText"
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
}
