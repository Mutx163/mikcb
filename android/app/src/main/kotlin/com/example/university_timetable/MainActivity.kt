package com.example.university_timetable

import android.Manifest
import android.app.ActivityManager
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
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.text.TextPaint
import android.text.TextUtils
import android.util.Log
import android.util.TypedValue
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
        private const val UMENG_CHANNEL = "com.example.university_timetable/umeng_analytics"
        private const val HOME_WIDGET_CHANNEL = "com.example.university_timetable/home_widget"
        private const val CHANNEL_ID = "live_update_channel"
        private const val PERMISSION_REQUEST_CODE = 1001
        private const val PREFS_NAME = "native_runtime_prefs"
        private const val KEY_HIDE_FROM_RECENTS = "hide_from_recents"
        private const val POST_PROMOTED_NOTIFICATIONS_PERMISSION =
            "android.permission.POST_PROMOTED_NOTIFICATIONS"
    }

    private var notificationManager: NotificationManager? = null
    private var permissionResult: MethodChannel.Result? = null

    override fun onResume() {
        super.onResume()
        applyHideFromRecentsPreference()
    }

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
                    "setHideFromRecents" -> {
                        persistHideFromRecents(call.arguments as? Boolean ?: false)
                        applyHideFromRecentsPreference()
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UMENG_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initializeIfNeeded" -> {
                        val initialized = UmengApplication.initializeAnalyticsIfNeeded(applicationContext)
                        result.success(initialized)
                    }
                    "triggerTestCrash" -> {
                        UmengApplication.initializeAnalyticsIfNeeded(applicationContext)
                        Handler(Looper.getMainLooper()).post {
                            throw RuntimeException("Manual Umeng U-APM test crash")
                        }
                        result.success(true)
                    }
                    "triggerTestAnr" -> {
                        UmengApplication.initializeAnalyticsIfNeeded(applicationContext)
                        Handler(Looper.getMainLooper()).post {
                            try {
                                Thread.sleep(30000L)
                            } catch (_: InterruptedException) {
                            }
                        }
                        result.success(true)
                    }
                    "reportCustomLog" -> {
                        val data = call.arguments as? Map<*, *>
                        if (data == null) {
                            result.error("INVALID_ARGUMENTS", "Missing log payload", null)
                            return@setMethodCallHandler
                        }
                        UmengDiagnosticReporter.report(
                            context = applicationContext,
                            category = data["category"] as? String ?: "flutter_diagnostic",
                            message = data["message"] as? String ?: "",
                            stackTrace = data["stackTrace"] as? String,
                            dedupeKey = data["dedupeKey"] as? String
                                ?: (data["category"] as? String ?: "flutter_diagnostic"),
                            extras = buildMap {
                                put("error", data["error"])
                            }
                        )
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HOME_WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "syncSnapshot" -> {
                        val data = call.arguments as? Map<String, Any?>
                        if (data != null) {
                            HomeWidgetStorage.syncSnapshot(applicationContext, data)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENTS", "Missing widget snapshot", null)
                        }
                    }
                    "clearSnapshot" -> {
                        HomeWidgetStorage.clearSnapshot(applicationContext)
                        result.success(true)
                    }
                    "scheduleRefresh" -> {
                        val payload = call.arguments as? Map<String, Any?>
                        val triggerAtMillis = payload
                            ?.get("triggerAtMillis") as? List<*>
                        if (triggerAtMillis != null) {
                            HomeWidgetStorage.scheduleRefresh(
                                applicationContext,
                                triggerAtMillis.mapNotNull { (it as? Number)?.toLong() }
                            )
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENTS", "Missing widget refresh times", null)
                        }
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
        try {
            val intent = LiveUpdateScheduler.buildServiceIntentFromMethodPayload(this, data)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            UmengDiagnosticReporter.report(
                context = applicationContext,
                category = "live_update_start_failed",
                message = "Failed to start live update service from Flutter method channel",
                throwable = e,
                dedupeKey = "live_update_start_failed",
            )
            throw e
        }
    }

    private fun stopLiveUpdateService() {
        stopService(Intent(this, LiveUpdateService::class.java))
    }

    private fun persistHideFromRecents(hidden: Boolean) {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_HIDE_FROM_RECENTS, hidden)
            .apply()
    }

    private fun applyHideFromRecentsPreference() {
        val hidden = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_HIDE_FROM_RECENTS, false)
        setHideFromRecents(hidden)
    }

    private fun setHideFromRecents(hidden: Boolean) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return
        }
        try {
            val activityManager = getSystemService(ActivityManager::class.java)
            activityManager?.appTasks?.forEach { task ->
                task.setExcludeFromRecents(hidden)
            }
        } catch (e: Exception) {
            Log.w("MainActivity", "Failed to update recents visibility", e)
        }
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
    private var duringClassTimeDisplayMode = "nearest"
    private var enableMiuiIslandLabelImage = false
    private var miuiIslandLabelStyle = "text_only"
    private var miuiIslandLabelContent = "course_name"
    private var miuiIslandLabelFontColor = "#FFFFFF"
    private var miuiIslandLabelFontWeight = "bold"
    private var miuiIslandLabelRenderQuality = "standard"
    private var miuiIslandLabelFontSize = 14f
    private var miuiIslandExpandedIconMode = "app_icon"
    private var miuiIslandExpandedIconPath: String? = null
    private var startAtMillis = 0L
    private var endAtMillis = 0L
    private var endReminderLeadMillis = 600_000L
    private var liveClassReminderStartMinutes = 0
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
    private var cachedIslandBitmapKey: String? = null
    private var cachedIslandBitmap: Bitmap? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return try {
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
            duringClassTimeDisplayMode =
                intent?.getStringExtra("duringClassTimeDisplayMode") ?: "nearest"
            enableMiuiIslandLabelImage =
                intent?.getBooleanExtra("enableMiuiIslandLabelImage", false) ?: false
            miuiIslandLabelStyle = intent?.getStringExtra("miuiIslandLabelStyle") ?: "text_only"
            miuiIslandLabelContent =
                intent?.getStringExtra("miuiIslandLabelContent") ?: "course_name"
            miuiIslandLabelFontColor =
                intent?.getStringExtra("miuiIslandLabelFontColor") ?: "#FFFFFF"
            miuiIslandLabelFontWeight =
                intent?.getStringExtra("miuiIslandLabelFontWeight") ?: "bold"
            miuiIslandLabelRenderQuality =
                intent?.getStringExtra("miuiIslandLabelRenderQuality") ?: "standard"
            miuiIslandLabelFontSize =
                intent?.getFloatExtra("miuiIslandLabelFontSize", 14f) ?: 14f
            miuiIslandExpandedIconMode =
                intent?.getStringExtra("miuiIslandExpandedIconMode") ?: "app_icon"
            miuiIslandExpandedIconPath =
                intent?.getStringExtra("miuiIslandExpandedIconPath")?.takeIf { it.isNotBlank() }
            endReminderLeadMillis =
                intent?.getLongExtra("endReminderLeadMillis", 600_000L)
                    ?.coerceAtLeast(0L)
                    ?: 600_000L
            liveClassReminderStartMinutes =
                intent?.getIntExtra("liveClassReminderStartMinutes", 0)?.coerceAtLeast(0) ?: 0
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

            lastRemainingText = "-1"
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
                    "endReminderLeadMillis=$endReminderLeadMillis" +
                    ", liveClassReminderStartMinutes=$liveClassReminderStartMinutes"
            )

            val initialText = computeRemainingText(System.currentTimeMillis())
            lastRemainingText = initialText
            startForeground(NOTIFICATION_ID, buildNotification(initialText))
            startTicker()
            START_STICKY
        } catch (e: Exception) {
            UmengDiagnosticReporter.report(
                context = applicationContext,
                category = "live_update_service_start_failed",
                message = "Failed to initialize live update service payload or notification",
                throwable = e,
                dedupeKey = "live_update_service_start_failed",
                extras = mapOf(
                    "courseName" to courseName,
                    "stage" to activityStage,
                )
            )
            stopSelf()
            START_NOT_STICKY
        }
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

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "Task removed; stopping live update and relying on scheduler")
        getSharedPreferences("native_runtime_prefs", Context.MODE_PRIVATE)
            .edit()
            .putLong("last_task_removed_at", System.currentTimeMillis())
            .apply()
        stopAndRemoveNotification()
        super.onTaskRemoved(rootIntent)
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
        ticker?.let { runnable ->
            handler.removeCallbacks(runnable)
        }
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

        val reminderStart = if (liveClassReminderStartMinutes == 0) {
            startAtMillis
        } else {
            maxOf(startAtMillis, endAtMillis - liveClassReminderStartMinutes * 60_000L)
        }
        val endReminderStart = maxOf(startAtMillis, endAtMillis - endReminderLeadMillis)
        return when {
            now < startAtMillis -> if (enableBeforeClass) "beforeClass" else null
            now < reminderStart -> null
            liveClassReminderStartMinutes > 0 && enableBeforeEnd -> "beforeEnd"
            liveClassReminderStartMinutes > 0 && canDisplayDuringStage() -> "duringClass"
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

    private fun dp(value: Float): Float =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, resources.displayMetrics)

    private fun sp(value: Float): Float =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, value, resources.displayMetrics)

    private fun resolveIslandLabelBitmap(text: String): Bitmap? {
        if (!enableMiuiIslandLabelImage || !isXiaomiFamilyDevice() || text.isBlank()) {
            return null
        }

        val cacheKey = listOf(
            text,
            miuiIslandLabelStyle,
            miuiIslandLabelFontColor,
            miuiIslandLabelFontWeight,
            miuiIslandLabelRenderQuality,
            miuiIslandLabelFontSize.toString(),
        ).joinToString("|")
        if (cacheKey == cachedIslandBitmapKey && cachedIslandBitmap != null) {
            return cachedIslandBitmap
        }

        val bitmap = buildIslandLabelBitmap(
            text = text,
            includeAppIcon = miuiIslandLabelStyle == "icon_and_text",
            fontColorHex = miuiIslandLabelFontColor,
            fontWeight = miuiIslandLabelFontWeight,
            renderQuality = miuiIslandLabelRenderQuality,
            fontSizeSp = miuiIslandLabelFontSize,
        )
        cachedIslandBitmapKey = cacheKey
        cachedIslandBitmap = bitmap
        return bitmap
    }

    private fun buildIslandLabelBitmap(
        text: String,
        includeAppIcon: Boolean,
        fontColorHex: String,
        fontWeight: String,
        renderQuality: String,
        fontSizeSp: Float,
    ): Bitmap? {
        val resolvedFontSizeSp = fontSizeSp.coerceIn(1f, 32f)
        val renderScale = when (renderQuality) {
            "high" -> 3f
            "ultra" -> 4f
            else -> 2f
        }
        val textColor = parseColorHexOrDefault(fontColorHex, 0xFFFFFFFF.toInt())
        val typeface = resolveIslandLabelTypeface(fontWeight)
        val baseTextPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textColor
            textSize = sp(resolvedFontSizeSp)
            this.typeface = typeface
            isFakeBoldText = fontWeight == "bold"
            isSubpixelText = true
            isLinearText = true
        }
        val iconSizeDp = if (includeAppIcon) 24f else 0f
        val iconGapDp = if (includeAppIcon) 3f else 0f
        val horizontalPaddingDp = if (includeAppIcon) 3f else 2f
        val verticalPaddingDp = 0.5f
        val maxWidthDp = if (includeAppIcon) 132f else 112f
        val maxTextWidthPx = dp(
            maxWidthDp - horizontalPaddingDp * 2f - iconSizeDp - iconGapDp
        ).coerceAtLeast(dp(28f))

        var fittedSizeSp = resolvedFontSizeSp
        while (fittedSizeSp > 1f) {
            baseTextPaint.textSize = sp(fittedSizeSp)
            if (baseTextPaint.measureText(text) <= maxTextWidthPx) {
                break
            }
            fittedSizeSp -= 1f
        }

        val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textColor
            textSize = sp(fittedSizeSp) * renderScale
            this.typeface = typeface
            isFakeBoldText = fontWeight == "bold"
            isSubpixelText = true
            isLinearText = true
            setShadowLayer(dp(0.75f) * renderScale, 0f, dp(0.25f) * renderScale, 0x44000000)
        }

        val displayText = if (baseTextPaint.measureText(text) <= maxTextWidthPx) {
            text
        } else {
            TextUtils.ellipsize(
                text,
                baseTextPaint,
                maxTextWidthPx,
                TextUtils.TruncateAt.END
            ).toString()
        }

        val glyphBounds = Rect()
        textPaint.getTextBounds(displayText, 0, displayText.length, glyphBounds)
        val textWidthPx = textPaint.measureText(displayText)
        val textHeightPx = glyphBounds.height().toFloat().coerceAtLeast(sp(1f) * renderScale)
        val iconSizePx = (dp(iconSizeDp) * renderScale).toInt()
        val iconGapPx = dp(iconGapDp) * renderScale
        val horizontalPaddingPx = dp(horizontalPaddingDp) * renderScale
        val verticalPaddingPx = dp(verticalPaddingDp) * renderScale
        val textOnlyMinWidthPx = dp(54f) * renderScale
        val textOnlyMinHeightPx = dp(18f) * renderScale

        val contentWidth = (
            horizontalPaddingPx * 2f +
                textWidthPx +
                if (includeAppIcon) iconSizePx + iconGapPx else 0f
            )
        val width = maxOf(
            contentWidth,
            if (includeAppIcon) dp(20f) * renderScale else textOnlyMinWidthPx
        ).toInt()
        val contentHeight = (
            verticalPaddingPx * 2f + maxOf(textHeightPx, iconSizePx.toFloat())
            )
        val height = maxOf(
            contentHeight,
            if (includeAppIcon) sp(1f) * renderScale else textOnlyMinHeightPx
        ).toInt()
        if (width <= 0 || height <= 0) {
            return null
        }

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        var textStartX = horizontalPaddingPx
        val centerY = height / 2f

        if (includeAppIcon) {
            val appIcon = packageManager.getApplicationIcon(packageName)
            val iconTop = ((height - iconSizePx) / 2f).toInt()
            appIcon.setBounds(
                horizontalPaddingPx.toInt(),
                iconTop,
                horizontalPaddingPx.toInt() + iconSizePx,
                iconTop + iconSizePx
            )
            appIcon.draw(canvas)
            textStartX += iconSizePx + iconGapPx
        } else {
            textStartX = ((width - textWidthPx) / 2f).coerceAtLeast(horizontalPaddingPx)
        }
        val baseline = centerY - (glyphBounds.top + glyphBounds.bottom) / 2f
        canvas.drawText(displayText, textStartX, baseline, textPaint)
        return bitmap
    }

    private fun parseColorHexOrDefault(colorHex: String?, fallback: Int): Int {
        val normalized = colorHex?.trim()?.removePrefix("#")?.takeIf { it.isNotBlank() } ?: return fallback
        return try {
            when (normalized.length) {
                6 -> (0xFF000000 or normalized.toLong(16)).toInt()
                8 -> normalized.toLong(16).toInt()
                else -> fallback
            }
        } catch (_: Exception) {
            fallback
        }
    }

    private fun resolveIslandLabelTypeface(fontWeight: String): Typeface {
        return when (fontWeight) {
            "regular" -> Typeface.create(Typeface.SANS_SERIF, Typeface.NORMAL)
            "medium" -> Typeface.create("sans-serif-medium", Typeface.NORMAL)
            else -> Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
        }
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

    private fun resolveExpandedLargeIcon(): Icon? {
        return when (miuiIslandExpandedIconMode) {
            "hidden" -> null
            "custom_image" -> {
                val path = miuiIslandExpandedIconPath ?: return null
                decodeExpandedIconBitmap(path)?.let(Icon::createWithBitmap)
            }
            else -> Icon.createWithResource(this, R.mipmap.ic_launcher)
        }
    }

    private fun decodeExpandedIconBitmap(path: String): Bitmap? {
        val source = BitmapFactory.decodeFile(path) ?: return null
        val side = minOf(source.width, source.height)
        if (side <= 0) {
            source.recycle()
            return null
        }
        val offsetX = ((source.width - side) / 2).coerceAtLeast(0)
        val offsetY = ((source.height - side) / 2).coerceAtLeast(0)
        val cropped = Bitmap.createBitmap(source, offsetX, offsetY, side, side)
        if (cropped != source) {
            source.recycle()
        }
        val targetSize = dp(56f).toInt().coerceAtLeast(96)
        if (cropped.width == targetSize && cropped.height == targetSize) {
            return cropped
        }
        val scaled = Bitmap.createScaledBitmap(cropped, targetSize, targetSize, true)
        if (scaled != cropped) {
            cropped.recycle()
        }
        return scaled
    }

    private fun buildRoundedLauncherIcon(targetSizePx: Int, cornerRadiusPx: Float): Icon? {
        val size = targetSizePx.coerceAtLeast(1)
        return try {
            val drawable = packageManager.getApplicationIcon(packageName)
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val clipPath = Path().apply {
                addRoundRect(
                    RectF(0f, 0f, size.toFloat(), size.toFloat()),
                    cornerRadiusPx,
                    cornerRadiusPx,
                    Path.Direction.CW
                )
            }
            canvas.save()
            canvas.clipPath(clipPath)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
            canvas.restore()
            Icon.createWithBitmap(bitmap)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to build rounded launcher icon", e)
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
        val classProgress = if (!isUpcoming) buildDuringClassProgress(now) else null
        val usesProgressExpandedStyle = Build.VERSION.SDK_INT >= 36 && classProgress != null

        val shortCourseName = if (courseName.length > 8) courseName.substring(0, 8) + ".." else courseName
        val nameToUse = if (useShortNameInIsland && shortCourseNameRaw.isNotBlank()) shortCourseNameRaw else courseName
        val islandCourseName = if (showCourseNameInIsland) {
            if (nameToUse.length > 5) nameToUse.substring(0, 5) else nameToUse
        } else ""
        val islandLocation = if (showLocationInIsland) location else ""
        val miuiIslandLabelText = when (miuiIslandLabelContent) {
            "location" -> location
            "course_name_and_location" -> listOf(
                nameToUse.takeIf { it.isNotBlank() },
                location.takeIf { it.isNotBlank() }
            ).filterNotNull().joinToString(" ")
            else -> nameToUse
        }
        val miuiIslandLabelBitmap = resolveIslandLabelBitmap(miuiIslandLabelText)

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
        val summaryText = if ((isDuringClass || isEndingSoon) && classProgress != null) {
            listOf(
                classProgress.nextMilestoneDisplayText,
                classProgress.finalDismissDisplayText,
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
            (isDuringClass || isEndingSoon) && classProgress != null -> null
            remainingText.isNotBlank() && !shouldPromote -> remainingText
            else -> null
        }

        val expandedDetailText = buildString {
            append(stageTitle)
            append("\n课程: ").append(courseName)
            if (shortNameLabel != null) append("\n简称: ").append(shortNameLabel)
            if ((isDuringClass || isEndingSoon) && classProgress != null) {
                if (classProgress.nextMilestoneDisplayText != null) {
                    append("\n下一节点: ").append(classProgress.nextMilestoneDisplayText)
                }
                append("\n整节下课: ").append(classProgress.finalDismissDisplayText)
            } else if (detailStatusText != null) {
                append("\n状态: ").append(detailStatusText)
            }
            if (timeRangeText.isNotBlank()) append("\n时间: ").append(timeRangeText)
            if (location.isNotBlank()) append("\n地点: ").append(location)
            if (teacher.isNotBlank()) append("\n教师: ").append(teacher)
            if (nextName.isNotBlank()) append("\n下一节: ").append(nextName)
            if (note.isNotBlank()) append("\n备注: ").append(note)
        }

        val promotedContentText = if ((isDuringClass || isEndingSoon) && classProgress != null) {
            listOf(
                classProgress.compactDisplayText,
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
            if ((isDuringClass || isEndingSoon) && classProgress != null) {
                if (classProgress.nextMilestoneDisplayText != null) {
                    append("下一节点: ").append(classProgress.nextMilestoneDisplayText)
                    append("\n")
                }
                append("整节下课: ").append(classProgress.finalDismissDisplayText)
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
        } else if ((isDuringClass || isEndingSoon) && classProgress != null) {
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

        val islandCriticalStatusText = if ((isDuringClass || isEndingSoon) && classProgress != null) {
            classProgress.criticalTimeText
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
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && miuiIslandLabelBitmap != null) {
                setSmallIcon(Icon.createWithBitmap(miuiIslandLabelBitmap))
            } else {
                setSmallIcon(iconRes)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                resolveExpandedLargeIcon()?.let(::setLargeIcon)
            }
            setContentIntent(pendingIntent)
            setOngoing(true)
            setAutoCancel(false)
            setOnlyAlertOnce(true)
            setCategory(Notification.CATEGORY_PROGRESS)
            setColorized(false)
            setShowWhen(!shouldPromote)
            setWhen(if (isUpcoming) startAtMillis else endAtMillis)
            setUsesChronometer(false)
            if (usesProgressExpandedStyle && classProgress != null) {
                setProgress(classProgress.progressMax, classProgress.progressUnits, false)
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

        if (usesProgressExpandedStyle && classProgress != null) {
            builder.setStyle(
                Notification.ProgressStyle()
                    .setStyledByProgress(true)
                    .setProgress(classProgress.progressUnits)
                    .setProgressSegments(
                        listOf(
                            Notification.ProgressStyle.Segment(
                                classProgress.progressMax
                            )
                        )
                    )
                    .setProgressTrackerIcon(
                        buildRoundedLauncherIcon(dp(28f).toInt(), dp(9f))
                            ?: Icon.createWithResource(this, R.mipmap.ic_launcher)
                    )
                    .setProgressPoints(
                        classProgress.breakPointUnits.map { point ->
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
            if (shouldPromote && (!notification.hasPromotableCharacteristics() || !canPostPromoted)) {
                UmengDiagnosticReporter.report(
                    context = applicationContext,
                    category = "live_update_promoted_not_shown",
                    message = "Live update could not be promoted as expected",
                    dedupeKey = "live_update_promoted_not_shown:${courseName}:${activityStage}",
                    extras = mapOf(
                        "courseName" to courseName,
                        "stage" to stage,
                        "canPostPromoted" to canPostPromoted,
                        "hasPromotableCharacteristics" to notification.hasPromotableCharacteristics(),
                        "showStandardNotification" to showStandardNotification,
                        "remainingText" to remainingText,
                    )
                )
            }
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
                    "progress=${classProgress?.progressUnits}, " +
                    "progressPercent=${classProgress?.progressPercent}, " +
                    "progressPoints=${classProgress?.breakPointUnits}, " +
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
        val flooredMinutes = (totalSeconds / 60L).coerceAtLeast(1L)
        val roundedUpMinutes = ((totalSeconds + 59L) / 60L).coerceAtLeast(1L)

        return when {
            totalSeconds > 120L -> "${flooredMinutes}分钟"
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
        val compactDisplayText: String,
        val criticalTimeText: String,
        val breakPointUnits: List<Int>,
    )

    private fun buildDuringClassProgress(now: Long): DuringClassProgress? {
        val totalMillis = (endAtMillis - startAtMillis).coerceAtLeast(1L)
        val elapsedMillis = (now - startAtMillis).coerceIn(0L, totalMillis)
        val remainingMillis = (endAtMillis - now).coerceAtLeast(0L)
        val progressMax = 1000
        val progressUnits =
            ((elapsedMillis.toDouble() / totalMillis.toDouble()) * progressMax)
                .toInt()
                .coerceIn(0, progressMax)
        val progressPercent = ((progressUnits * 100L) / progressMax).toInt().coerceIn(0, 100)
        val breakPointUnits = progressBreakOffsetsMillis
            .map { offsetMillis ->
                ((offsetMillis.coerceIn(0L, totalMillis).toDouble() / totalMillis.toDouble()) * progressMax)
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
        val compactDisplayText = if (duringClassTimeDisplayMode == "total") {
            finalDismissDisplayText
        } else {
            nextMilestoneDisplayText ?: finalDismissDisplayText
        }
        val criticalTimeText = if (duringClassTimeDisplayMode == "total") {
            finalDismissRemainingText
        } else {
            nextMilestoneRemainingText ?: finalDismissRemainingText
        }
        return DuringClassProgress(
            progressMax = progressMax,
            progressUnits = progressUnits,
            progressPercent = progressPercent,
            nextMilestoneDisplayText = nextMilestoneDisplayText,
            finalDismissDisplayText = finalDismissDisplayText,
            compactDisplayText = compactDisplayText,
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
