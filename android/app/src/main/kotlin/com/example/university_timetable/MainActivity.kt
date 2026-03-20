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

        intent.putExtra("courseName", current?.get("name") as? String ?: "")
        intent.putExtra("location", current?.get("location") as? String ?: "")
        intent.putExtra("teacher", current?.get("teacher") as? String ?: "")
        intent.putExtra("startTime", current?.get("startTime") as? String ?: "")
        intent.putExtra("endTime", current?.get("endTime") as? String ?: "")
        intent.putExtra("nextName", next?.get("name") as? String ?: "")
        intent.putExtra("autoDismissAfterStartMinutes", autoDismissAfterStartMinutes)

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
    private var location = ""
    private var teacher = ""
    private var startTimeText = ""
    private var endTimeText = ""
    private var nextName = ""
    private var autoDismissAfterStartMinutes = 0
    private var startAtMillis = 0L
    private var endAtMillis = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        courseName = intent?.getStringExtra("courseName").orEmpty().ifBlank { "暂无课程" }
        location = intent?.getStringExtra("location").orEmpty()
        teacher = intent?.getStringExtra("teacher").orEmpty()
        startTimeText = intent?.getStringExtra("startTime").orEmpty()
        endTimeText = intent?.getStringExtra("endTime").orEmpty()
        nextName = intent?.getStringExtra("nextName").orEmpty()
        autoDismissAfterStartMinutes = intent?.getIntExtra("autoDismissAfterStartMinutes", 0) ?: 0
        startAtMillis = buildCourseTimeMillis(startTimeText) ?: System.currentTimeMillis()
        endAtMillis = buildCourseTimeMillis(endTimeText) ?: startAtMillis

        startForeground(NOTIFICATION_ID, buildNotification())
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

                getSystemService(NotificationManager::class.java)
                    ?.notify(NOTIFICATION_ID, buildNotification())
                handler.postDelayed(this, 1000L)
            }
        }
        handler.post(ticker!!)
    }

    private fun stopTicker() {
        ticker?.let(handler::removeCallbacks)
        ticker = null
    }

    private fun buildNotification(): Notification {
        val now = System.currentTimeMillis()
        val isUpcoming = now < startAtMillis
        val remainingText = if (isUpcoming) {
            "距上课 ${formatDuration(startAtMillis - now)}"
        } else {
            "距下课 ${formatDuration((endAtMillis - now).coerceAtLeast(0L))}"
        }
        val title = if (isUpcoming) {
            "即将上课: $courseName"
        } else {
            "正在上课: $courseName"
        }

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
            append("\n").append(remainingText)
            if (location.isNotBlank()) append("\n地点: ").append(location)
            if (teacher.isNotBlank()) append("\n教师: ").append(teacher)
            if (startTimeText.isNotBlank() || endTimeText.isNotBlank()) {
                append("\n时间: ").append(startTimeText).append(" - ").append(endTimeText)
            }
        }

        val contentText = listOf(location, remainingText)
            .filter { it.isNotBlank() }
            .joinToString(" · ")

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }

        builder.apply {
            setContentTitle(title)
            setContentText(contentText)
            setSmallIcon(R.drawable.ic_course)
            setContentIntent(pendingIntent)
            setOngoing(true)
            setAutoCancel(false)
            setOnlyAlertOnce(true)
            setStyle(Notification.BigTextStyle().bigText(detailText))
            setCategory(Notification.CATEGORY_PROGRESS)
            setColorized(false)
            setShowWhen(true)
            setWhen(if (isUpcoming) startAtMillis else endAtMillis)
            setUsesChronometer(false)

            if (!isUpcoming && nextName.isNotBlank()) {
                setSubText("下一节: $nextName")
            }

            if (Build.VERSION.SDK_INT >= 36) {
                setShortCriticalText(remainingText)
                setExtras(
                    Bundle().apply {
                        putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true)
                    }
                )
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

    private fun formatDuration(durationMillis: Long): String {
        val totalSeconds = (durationMillis / 1000L).coerceAtLeast(0L)
        val hours = totalSeconds / 3600L
        val minutes = (totalSeconds % 3600L) / 60L
        val seconds = totalSeconds % 60L

        return if (hours > 0) {
            String.format("%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            String.format("%02d:%02d", minutes, seconds)
        }
    }
}
