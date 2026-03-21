package com.example.university_timetable

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
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
                    "openPromotedSettings" -> {
                        openPromotedSettings()
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

        try {
            startActivity(
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                }
            )
        } catch (e: Exception) {
            Log.w("MainActivity", "Failed to open notification settings", e)
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
                "课程实时更新",
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
    private var showCountdown = true
    private var showCourseNameInIsland = true
    private var showLocationInIsland = true
    private var useShortNameInIsland = false
    private var hidePrefixText = false
    private var startAtMillis = 0L
    private var endAtMillis = 0L
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
        showCountdown = intent?.getBooleanExtra("showCountdown", true) ?: true
        showCourseNameInIsland = intent?.getBooleanExtra("showCourseNameInIsland", true) ?: true
        showLocationInIsland = intent?.getBooleanExtra("showLocationInIsland", true) ?: true
        useShortNameInIsland = intent?.getBooleanExtra("useShortNameInIsland", false) ?: false
        hidePrefixText = intent?.getBooleanExtra("hidePrefixText", false) ?: false
        startAtMillis = buildCourseTimeMillis(startTimeText) ?: System.currentTimeMillis()
        endAtMillis = buildCourseTimeMillis(endTimeText) ?: startAtMillis
        
        lastRemainingText = "-1" // 确保第一刷通过

        // 在这里进行一次初始推送，使服务启动为常驻
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
                if (autoDismissAfterStartMinutes > 0 &&
                    now >= startAtMillis + autoDismissAfterStartMinutes * 60_000L
                ) {
                    stopAndRemoveNotification()
                    return
                }

                if (now >= endAtMillis + 30_000L) { // 下课后 30 秒自动退场（特别是对无后续或者测试课的安全回收）
                    stopAndRemoveNotification()
                    return
                }

                val currentText = computeRemainingText(now)
                if (currentText != lastRemainingText) {
                    lastRemainingText = currentText
                    getSystemService(NotificationManager::class.java)
                        ?.notify(NOTIFICATION_ID, buildNotification(currentText))
                }
                
                // 心跳频率视乎倒数是否只变了分钟还是在 60秒内，但为稳妥都留有1秒钟来捕捉下一分钟跳变的时刻，而不会发生通知风暴。
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
        val isUpcoming = now < startAtMillis
        val timeUntilEnd = endAtMillis - now

        val prefixTextStart = if (hidePrefixText) "" else "距上课 "
        val prefixTextEnd = if (hidePrefixText) "" else "距下课 "

        return if (!showCountdown) {
            ""
        } else if (isUpcoming) {
            "${prefixTextStart}${formatCustomDuration(startAtMillis - now)}"
        } else if (timeUntilEnd in 1..600_000L) {
            "${prefixTextEnd}${formatCustomDuration(timeUntilEnd)}"
        } else {
            "上课中"
        }
    }

    private fun buildNotification(remainingText: String): Notification {
        val now = System.currentTimeMillis()
        val isUpcoming = now < startAtMillis
        val timeUntilEnd = endAtMillis - now
        val isEndingSoon = !isUpcoming && timeUntilEnd in 1..600_000L
        val shouldPromote = isUpcoming || isEndingSoon

        val shortCourseName = if (courseName.length > 8) courseName.substring(0, 8) + ".." else courseName
        val nameToUse = if (useShortNameInIsland && shortCourseNameRaw.isNotBlank()) shortCourseNameRaw else courseName
        val islandCourseName = if (showCourseNameInIsland) {
            if (nameToUse.length > 5) nameToUse.substring(0, 5) else nameToUse
        } else ""
        val islandLocation = if (showLocationInIsland) location else ""

        val titlePrefix = if (isUpcoming) "即将上课" else "正在上课"
        val title = if (isUpcoming) "即将上课: $shortCourseName" else shortCourseName
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

        val detailText = buildString {
            append("课程: ").append(courseName)
            append("\n状态: ").append(remainingText)
            if (location.isNotBlank()) append("\n地点: ").append(location)
            if (teacher.isNotBlank()) append("\n教师: ").append(teacher)
            if (note.isNotBlank()) append("\n备注: ").append(note)
            if (startTimeText.isNotBlank() || endTimeText.isNotBlank()) {
                append("\n时间: ").append(startTimeText).append(" - ").append(endTimeText)
            }
        }

        val expandedDetailText = buildString {
            append(if (isUpcoming) "即将上课" else "正在上课")
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

        val contentText = if (shouldPromote && !showCourseNameInIsland && !showLocationInIsland) {
            remainingText
        } else {
            listOf(islandCourseName, islandLocation, teacher, remainingText)
                .filter { it.isNotBlank() }
                .joinToString(" · ")
        }
            
        val islandCriticalText = if (shouldPromote && !showCourseNameInIsland && !showLocationInIsland) {
            remainingText
        } else {
            listOf(islandCourseName, islandLocation, remainingText)
                .filter { it.isNotBlank() }
                .joinToString(" ")
        }

        val iconRes = if (isUpcoming) R.drawable.ic_upcoming else if (shouldPromote) R.drawable.ic_countdown else R.drawable.ic_course

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }

        builder.apply {
            setContentTitle(title)
            setContentText(if (shouldPromote) promotedContentText else contentText)
            setSmallIcon(iconRes)
            setContentIntent(pendingIntent)
            setOngoing(true)
            setAutoCancel(false)
            setOnlyAlertOnce(true)
            setStyle(
                Notification.BigTextStyle()
                    .setBigContentTitle(title)
                    .bigText(if (shouldPromote) promotedExpandedDetailText else expandedDetailText)
                    .setSummaryText(summaryText)
            )
            setCategory(Notification.CATEGORY_PROGRESS)
            setColorized(false)
            setShowWhen(!shouldPromote)
            setWhen(if (isUpcoming) startAtMillis else endAtMillis)
            setUsesChronometer(false)

            if (!shouldPromote && subText.isNotBlank()) {
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
        return if (totalSeconds >= 60) {
            val minutes = totalSeconds / 60L
            "${minutes}分钟"
        } else {
            "${totalSeconds}秒"
        }
    }
}
