package com.mutx163.qingyu

import android.Manifest
import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.ContentValues
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
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.MediaStore
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
        private const val METHOD_CHANNEL = "com.mutx163.qingyu/miui_live"
        private const val UMENG_CHANNEL = "com.mutx163.qingyu/umeng_analytics"
        private const val HOME_WIDGET_CHANNEL = "com.mutx163.qingyu/home_widget"
        private const val SUPPORT_CHANNEL = "com.mutx163.qingyu/support"
        private const val MIGRATION_CHANNEL = "com.mutx163.qingyu/migration"
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
        applyPersistedHideFromRecents()
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
                    "openAccessibilitySettings" -> {
                        openAccessibilitySettings()
                        result.success(true)
                    }
                    "isKeepAliveAccessibilityEnabled" -> {
                        result.success(isKeepAliveAccessibilityEnabled())
                    }
                    "setHideFromRecents" -> {
                        val hidden = call.arguments as? Boolean ?: false
                        persistHideFromRecents(hidden)
                        setHideFromRecents(hidden)
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
                    "recordDiagnosticEvent" -> {
                        val data = call.arguments as? Map<*, *>
                        if (data == null) {
                            result.error("INVALID_ARGUMENTS", "Missing log payload", null)
                            return@setMethodCallHandler
                        }
                        @Suppress("UNCHECKED_CAST")
                        val extras = (data["extras"] as? Map<String, Any?>) ?: emptyMap()
                        UmengDiagnosticReporter.record(
                            context = applicationContext,
                            category = data["category"] as? String ?: "flutter_diagnostic_event",
                            message = data["message"] as? String ?: "",
                            extras = extras,
                        )
                        result.success(true)
                    }
                    "setLiveDiagnosticsEnabled" -> {
                        val enabled = call.arguments as? Boolean ?: false
                        UmengDiagnosticReporter.setLiveDiagnosticsEnabled(
                            applicationContext,
                            enabled
                        )
                        result.success(true)
                    }
                    "exportLiveDiagnosticsFile" -> {
                        result.success(
                            UmengDiagnosticReporter.exportLiveDiagnosticsFile(applicationContext)
                        )
                    }
                    "clearLiveDiagnostics" -> {
                        result.success(
                            UmengDiagnosticReporter.clearLiveDiagnostics(applicationContext)
                        )
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SUPPORT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveImageToGallery" -> {
                        val arguments = call.arguments as? Map<*, *>
                        val bytes = arguments?.get("bytes") as? ByteArray
                        val fileName = arguments?.get("fileName") as? String ?: "qingyu_kebiao.png"
                        val mimeType = arguments?.get("mimeType") as? String ?: "image/png"
                        if (bytes == null || bytes.isEmpty()) {
                            result.error("INVALID_ARGUMENTS", "Missing image bytes", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val savedUri = saveImageToGallery(bytes, fileName, mimeType)
                            if (savedUri == null) {
                                result.error("SAVE_FAILED", "Failed to save image to gallery", null)
                            } else {
                                result.success(savedUri)
                            }
                        } catch (e: Exception) {
                            result.error("SAVE_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MIGRATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "findInstalledPackage" -> {
                        val packageNames = (call.arguments as? List<*>)?.mapNotNull {
                            it as? String
                        } ?: emptyList()
                        result.success(findInstalledPackage(packageNames))
                    }
                    "openPackage" -> {
                        val packageName = call.arguments as? String
                        if (packageName.isNullOrBlank()) {
                            result.success(false)
                        } else {
                            result.success(openPackage(packageName))
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
            Intent("miui.intent.action.APP_PERM_EDITOR").apply {
                setClassName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.permissions.PermissionsEditorActivity"
                )
                putExtra("extra_pkgname", packageName)
                putExtra("package_name", packageName)
                putExtra("android.intent.extra.PACKAGE_NAME", packageName)
            },
            Intent().apply {
                component = ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.permissions.AppPermissionsEditorActivity"
                )
                putExtra("extra_pkgname", packageName)
                putExtra("package_name", packageName)
                putExtra("android.intent.extra.PACKAGE_NAME", packageName)
            },
            Intent().apply {
                component = ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.permissions.PermissionsEditorActivity"
                )
                putExtra("extra_pkgname", packageName)
                putExtra("package_name", packageName)
                putExtra("android.intent.extra.PACKAGE_NAME", packageName)
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

    private fun findInstalledPackage(packageNames: List<String>): String? {
        for (packageName in packageNames) {
            try {
                packageManager.getPackageInfo(packageName, 0)
                return packageName
            } catch (_: Exception) {
            }
        }
        return null
    }

    private fun openPackage(packageName: String): Boolean {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: return false
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            startActivity(launchIntent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun saveImageToGallery(
        bytes: ByteArray,
        fileName: String,
        mimeType: String,
    ): String? {
        val safeFileName = if (fileName.contains(".")) fileName else "$fileName.png"
        val resolver = applicationContext.contentResolver

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, safeFileName)
                put(MediaStore.Images.Media.MIME_TYPE, mimeType)
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_PICTURES}/轻屿课表"
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: return null
            return try {
                resolver.openOutputStream(uri)?.use { output ->
                    output.write(bytes)
                    output.flush()
                } ?: return null
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                uri.toString()
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
        }

        @Suppress("DEPRECATION")
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
        @Suppress("DEPRECATION")
        val inserted = MediaStore.Images.Media.insertImage(
            resolver,
            bitmap,
            safeFileName,
            "轻屿课表收款码"
        )
        return inserted?.takeIf { it.isNotBlank() }
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
            UmengDiagnosticReporter.record(
                context = applicationContext,
                category = "live_update_start_requested",
                message = "Flutter requested live update start",
                extras = mapOf(
                    "stage" to data["stage"],
                    "hasCurrentCourse" to (data["currentCourse"] != null),
                    "hasNextCourse" to (data["nextCourse"] != null),
                )
            )
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
        UmengDiagnosticReporter.record(
            context = applicationContext,
            category = "live_update_stop_requested",
            message = "Flutter requested live update stop",
        )
        stopService(Intent(this, LiveUpdateService::class.java))
    }

    private fun persistHideFromRecents(hidden: Boolean) {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_HIDE_FROM_RECENTS, hidden)
            .apply()
    }

    private fun isHideFromRecentsEnabled(): Boolean {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_HIDE_FROM_RECENTS, false)
    }

    private fun applyPersistedHideFromRecents() {
        setHideFromRecents(isHideFromRecentsEnabled())
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

    private fun openAccessibilitySettings() {
        try {
            startActivity(
                Intent("android.settings.ACCESSIBILITY_DETAILS_SETTINGS").apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    putExtra("package_name", packageName)
                    putExtra("android.intent.extra.PACKAGE_NAME", packageName)
                    putExtra(
                        "android.intent.extra.COMPONENT_NAME",
                        ComponentName(
                            this@MainActivity,
                            KeepAliveAccessibilityService::class.java
                        ).flattenToString()
                    )
                }
            )
            return
        } catch (e: ActivityNotFoundException) {
            // Fall through to the general accessibility settings page.
        } catch (_: Exception) {
            // Fall through to the general accessibility settings page.
        }

        try {
            startActivity(
                Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
        } catch (_: ActivityNotFoundException) {
            val fallbackIntent = Intent(Settings.ACTION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(fallbackIntent)
        }
    }

    private fun isKeepAliveAccessibilityEnabled(): Boolean {
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val expectedComponent = ComponentName(
            this,
            KeepAliveAccessibilityService::class.java
        ).flattenToString()
        return enabledServices
            .split(':')
            .any { it.equals(expectedComponent, ignoreCase = true) }
    }
}

class LiveUpdateService : Service() {
    companion object {
        private const val TAG = "LiveUpdateService"
        private const val CHANNEL_ID = "live_update_channel"
        private const val NOTIFICATION_ID = 2001
        private const val EXTRA_REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"
        private const val PREFS_NAME = "native_runtime_prefs"
        private const val KEY_HIDE_FROM_RECENTS = "hide_from_recents"
        private const val ACTION_ENABLE_SILENT_MODE =
            "com.mutx163.qingyu.action.ENABLE_SILENT_MODE"
        private const val ACTION_ENABLE_DO_NOT_DISTURB =
            "com.mutx163.qingyu.action.ENABLE_DO_NOT_DISTURB"
        private const val ACTION_DISMISS_STATUS_BAR_STAGE =
            "com.mutx163.qingyu.action.DISMISS_STATUS_BAR_STAGE"
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
    private var countdownTextStyle = "smart"
    private var showStageText = true
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
    private var miuiIslandLabelOffsetX = 0f
    private var miuiIslandLabelOffsetY = 0f
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
    private var beforeClassQuickAction = "none"
    private var progressBreakOffsetsMillis = longArrayOf()
    private var progressMilestoneLabels = emptyList<String>()
    private var progressMilestoneTimeTexts = emptyList<String>()
    private var lastRemainingText = "-1"
    private var lastProgressUnits = -1
    private var lastCriticalTimeText = ""
    private var cachedIslandBitmapKey: String? = null
    private var cachedIslandBitmap: Bitmap? = null
    private var hasStartedForeground = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return try {
            val quickActionResult = when (intent?.action) {
                ACTION_ENABLE_SILENT_MODE -> {
                    handleBeforeClassQuickAction(enableDoNotDisturb = false)
                    START_NOT_STICKY
                }
                ACTION_ENABLE_DO_NOT_DISTURB -> {
                    handleBeforeClassQuickAction(enableDoNotDisturb = true)
                    START_NOT_STICKY
                }
                ACTION_DISMISS_STATUS_BAR_STAGE -> {
                    dismissStatusBarStage()
                    START_NOT_STICKY
                }
                else -> null
            }
            if (quickActionResult != null) {
                return quickActionResult
            }

            startForegroundSafely(intent)

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
            countdownTextStyle = intent?.getStringExtra("countdownTextStyle") ?: "smart"
            showStageText = intent?.getBooleanExtra("showStageText", true) ?: true
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
            miuiIslandLabelOffsetX =
                intent?.getFloatExtra("miuiIslandLabelOffsetX", 0f) ?: 0f
            miuiIslandLabelOffsetY =
                intent?.getFloatExtra("miuiIslandLabelOffsetY", 0f) ?: 0f
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
            beforeClassQuickAction =
                intent?.getStringExtra("beforeClassQuickAction") ?: "none"
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

            UmengDiagnosticReporter.record(
                context = applicationContext,
                category = "live_update_service_started",
                message = "Live update service started",
                extras = mapOf(
                    "courseName" to courseName,
                    "stage" to activityStage,
                    "startAtMillis" to startAtMillis,
                    "endAtMillis" to endAtMillis,
                    "enableBeforeClass" to enableBeforeClass,
                    "enableDuringClass" to enableDuringClass,
                    "enableBeforeEnd" to enableBeforeEnd,
                )
            )

            val initialText = computeRemainingText(System.currentTimeMillis())
            lastRemainingText = initialText
            updateForegroundNotification(buildNotification(initialText))
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
            if (hasStartedForeground) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                hasStartedForeground = false
            }
            stopSelf()
            START_NOT_STICKY
        }
    }

    override fun onDestroy() {
        stopTicker()
        if (hasStartedForeground) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            hasStartedForeground = false
        }
        LiveUpdateScheduler.onLiveUpdateStopped(applicationContext)
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        val keepAliveExperimentEnabled = isTaskRemovalKeepAliveEnabled()
        getSharedPreferences("native_runtime_prefs", Context.MODE_PRIVATE)
            .edit()
            .putLong("last_task_removed_at", System.currentTimeMillis())
            .apply()
        UmengDiagnosticReporter.record(
            context = applicationContext,
            category = "live_update_task_removed",
            message = "Task removed while live update service was active",
            extras = mapOf(
                "courseName" to courseName,
                "stage" to activityStage,
                "keepAliveExperimentEnabled" to keepAliveExperimentEnabled,
                "hideFromRecentsEnabled" to isHideFromRecentsEnabled(),
                "keepAliveAccessibilityEnabled" to isKeepAliveAccessibilityEnabled(),
            )
        )
        if (!keepAliveExperimentEnabled) {
            stopAndRemoveNotification()
        }
        super.onTaskRemoved(rootIntent)
    }

    private fun isTaskRemovalKeepAliveEnabled(): Boolean {
        return isHideFromRecentsEnabled() || isKeepAliveAccessibilityEnabled()
    }

    private fun startForegroundSafely(intent: Intent?) {
        ensureNotificationChannel()
        if (hasStartedForeground) {
            return
        }

        val bootstrapTitle = intent?.getStringExtra("courseName")
            ?.takeIf { it.isNotBlank() }
            ?.let { "课程提醒: $it" }
            ?: "轻屿课表"
        startForeground(
            NOTIFICATION_ID,
            buildBootstrapNotification(bootstrapTitle)
        )
        hasStartedForeground = true
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "课程表实时更新",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "显示当前课程进度"
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildBootstrapNotification(title: String): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }

        return builder
            .setContentTitle(title)
            .setContentText("正在准备课程提醒")
            .setSmallIcon(R.drawable.ic_course)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }

    private fun updateForegroundNotification(notification: Notification) {
        if (!hasStartedForeground) {
            startForeground(NOTIFICATION_ID, notification)
            hasStartedForeground = true
            return
        }

        getSystemService(NotificationManager::class.java)
            ?.notify(NOTIFICATION_ID, notification)
            ?: startForeground(NOTIFICATION_ID, notification)
    }

    private fun buildBeforeClassQuickAction(): Notification.Action? {
        val (action, label) = when (beforeClassQuickAction) {
            "silent" -> ACTION_ENABLE_SILENT_MODE to "打开静音"
            "do_not_disturb" -> ACTION_ENABLE_DO_NOT_DISTURB to "打开免打扰"
            else -> return null
        }
        val pendingIntent = PendingIntent.getService(
            this,
            action.hashCode(),
            Intent(this, LiveUpdateService::class.java).apply {
                this.action = action
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return Notification.Action.Builder(
            Icon.createWithResource(this, R.drawable.ic_notification),
            label,
            pendingIntent,
        ).build()
    }

    private fun buildDismissStatusBarAction(): Notification.Action {
        val pendingIntent = PendingIntent.getService(
            this,
            ACTION_DISMISS_STATUS_BAR_STAGE.hashCode(),
            Intent(this, LiveUpdateService::class.java).apply {
                action = ACTION_DISMISS_STATUS_BAR_STAGE
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return Notification.Action.Builder(
            Icon.createWithResource(this, android.R.drawable.ic_menu_close_clear_cancel),
            "关闭",
            pendingIntent,
        ).build()
    }

    private fun handleBeforeClassQuickAction(enableDoNotDisturb: Boolean) {
        val applied = if (enableDoNotDisturb) {
            enableDoNotDisturbMode()
        } else {
            enableSilentMode()
        }
        UmengDiagnosticReporter.record(
            context = applicationContext,
            category = "live_update_before_class_quick_action",
            message = "Before-class quick action invoked",
            extras = mapOf(
                "action" to if (enableDoNotDisturb) "do_not_disturb" else "silent",
                "applied" to applied,
                "courseName" to courseName,
                "stage" to activityStage,
            )
        )
        if (hasStartedForeground) {
            updateForegroundNotification(buildNotification(computeRemainingText(System.currentTimeMillis())))
        }
    }

    private fun dismissStatusBarStage() {
        UmengDiagnosticReporter.record(
            context = applicationContext,
            category = "live_update_status_bar_dismissed",
            message = "User dismissed during-class status bar notification",
            extras = mapOf(
                "courseName" to courseName,
                "stage" to activityStage,
            )
        )
        stopTicker()
        if (hasStartedForeground) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            hasStartedForeground = false
        }
        stopSelf()
    }

    private fun enableSilentMode(): Boolean {
        val audioManager = getSystemService(AudioManager::class.java) ?: return false
        return try {
            audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
            true
        } catch (e: SecurityException) {
            Log.w(TAG, "Failed to enable silent mode directly", e)
            openSoundSettings()
            false
        } catch (e: Exception) {
            Log.w(TAG, "Failed to enable silent mode", e)
            openSoundSettings()
            false
        }
    }

    private fun enableDoNotDisturbMode(): Boolean {
        val manager = getSystemService(NotificationManager::class.java) ?: return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !manager.isNotificationPolicyAccessGranted
        ) {
            openNotificationPolicyAccessSettings()
            return false
        }
        return try {
            manager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
            true
        } catch (e: SecurityException) {
            Log.w(TAG, "Failed to enable do-not-disturb directly", e)
            openNotificationPolicyAccessSettings()
            false
        } catch (e: Exception) {
            Log.w(TAG, "Failed to enable do-not-disturb", e)
            openNotificationPolicyAccessSettings()
            false
        }
    }

    private fun openNotificationPolicyAccessSettings() {
        openSettingsIntent(
            Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
        )
    }

    private fun openSoundSettings() {
        openSettingsIntent(Intent(Settings.ACTION_SOUND_SETTINGS))
    }

    private fun openSettingsIntent(intent: Intent) {
        try {
            startActivity(intent.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) })
        } catch (e: Exception) {
            Log.w(TAG, "Failed to open settings intent", e)
            try {
                startActivity(
                    Intent(Settings.ACTION_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                )
            } catch (fallbackError: Exception) {
                Log.w(TAG, "Failed to open fallback settings", fallbackError)
            }
        }
    }

    private fun isHideFromRecentsEnabled(): Boolean {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_HIDE_FROM_RECENTS, false)
    }

    private fun isKeepAliveAccessibilityEnabled(): Boolean {
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val expectedComponent = ComponentName(
            this,
            KeepAliveAccessibilityService::class.java
        ).flattenToString()
        return enabledServices
            .split(':')
            .any { it.equals(expectedComponent, ignoreCase = true) }
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
                val currentCriticalTimeText = currentDuringClassProgress?.criticalTimeText ?: currentText
                val shouldRefreshProgressThisTick =
                    currentDuringClassProgress?.updatesEverySecond == true
                val currentProgress =
                    if (shouldRefreshProgressThisTick) {
                        currentDuringClassProgress.progressUnits
                    } else {
                        -1
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

                handler.postDelayed(this, computeNextTickDelayMillis(now, stage, currentDuringClassProgress))
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
                    "${prefixTextStart}${formatCountdownDuration(
                        durationMillis = timeUntilStart,
                        secondsThresholdMillis = 60_000L,
                    )}"
                }
                "beforeEnd" -> {
                    "${prefixTextEnd}${formatCountdownDuration(
                        durationMillis = timeUntilEnd,
                        secondsThresholdMillis = endSecondsCountdownThreshold * 1000L,
                    )}"
                }
                "duringClass",
                "duringClassStatusBar" -> "上课中"
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
            liveClassReminderStartMinutes > 0 && now < reminderStart ->
                if (enableDuringClass && showNotificationDuringClass && !promoteDuringClass) {
                    "duringClass"
                } else {
                    null
                }
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
            miuiIslandLabelOffsetX.toString(),
            miuiIslandLabelOffsetY.toString(),
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
            offsetXDp = miuiIslandLabelOffsetX,
            offsetYDp = miuiIslandLabelOffsetY,
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
        offsetXDp: Float,
        offsetYDp: Float,
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
        val clampedOffsetXDp = offsetXDp.coerceIn(-2f, 2f)
        val clampedOffsetYDp = offsetYDp.coerceIn(-2f, 2f)
        val horizontalOffsetPx = dp(clampedOffsetXDp) * renderScale
        val verticalOffsetPx = dp(clampedOffsetYDp) * renderScale

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
            textStartX = (
                (width - textWidthPx) / 2f + horizontalOffsetPx
            ).coerceIn(horizontalPaddingPx, width - horizontalPaddingPx - textWidthPx)
        }
        if (includeAppIcon) {
            textStartX = (
                textStartX + horizontalOffsetPx
            ).coerceIn(horizontalPaddingPx, width - horizontalPaddingPx - textWidthPx)
        }
        val baseline = centerY - (glyphBounds.top + glyphBounds.bottom) / 2f + verticalOffsetPx
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
        val isDuringClassStatusBar = stage == "duringClassStatusBar"
        val isEndingSoon = stage == "beforeEnd"
        val isDuringClass = stage == "duringClass" || isDuringClassStatusBar
        val shouldPromote = when {
            isDuringClassStatusBar -> false
            isDuringClass -> promoteDuringClass
            else -> true
        }
        val showStandardNotification = when {
            isDuringClassStatusBar -> true
            isDuringClass -> showNotificationDuringClass
            else -> true
        }
        val classProgress = if (stage == "duringClass") buildDuringClassProgress(now) else null
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
        val visibleStatusText = when {
            !showCountdown && showStageText -> stageTitle
            !showCountdown -> ""
            else -> remainingText.ifBlank { stageTitle }
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
        val summaryText = if ((isDuringClass || isEndingSoon) && classProgress != null && showCountdown) {
            listOf(
                classProgress.nextMilestoneDisplayText,
                classProgress.finalDismissDisplayText,
                location.takeIf { it.isNotBlank() }
            ).filterNotNull().joinToString(" · ")
        } else {
            listOf(
                location.takeIf { it.isNotBlank() },
                teacher.takeIf { it.isNotBlank() },
                visibleStatusText.takeIf { it.isNotBlank() }
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
            (isDuringClass || isEndingSoon) && classProgress != null && showCountdown -> null
            visibleStatusText.isNotBlank() && !shouldPromote -> visibleStatusText
            else -> null
        }

        val expandedDetailText = buildString {
            append(stageTitle)
            append("\n课程: ").append(courseName)
            if (shortNameLabel != null) append("\n简称: ").append(shortNameLabel)
            if ((isDuringClass || isEndingSoon) && classProgress != null && showCountdown) {
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

        val promotedContentText = if ((isDuringClass || isEndingSoon) && classProgress != null && showCountdown) {
            listOf(
                classProgress.compactDisplayText,
                location.takeIf { it.isNotBlank() }
            ).filterNotNull().joinToString(" · ")
        } else {
            listOf(
                visibleStatusText.takeIf { it.isNotBlank() },
                timeRangeText.takeIf { it.isNotBlank() },
                location.takeIf { it.isNotBlank() },
                teacher.takeIf { it.isNotBlank() }
            ).filterNotNull().joinToString(" · ")
        }
        val promotedExpandedDetailText = buildString {
            if ((isDuringClass || isEndingSoon) && classProgress != null && showCountdown) {
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
            visibleStatusText
        } else {
            listOf(islandCourseName, islandLocation, teacher, visibleStatusText)
                .filter { it.isNotBlank() }
                .joinToString(" · ")
        }
            
        val miuiFocusParam = if (!shouldPromote || isDuringClassStatusBar) {
            null
        } else {
            buildMiuiFocusParam(
                title = title,
                remainingText = visibleStatusText,
                timeRangeText = timeRangeText,
                bodyContent = if (shouldPromote) promotedContentText else contentText,
            )
        }

        val islandCriticalStatusText = if ((isDuringClass || isEndingSoon) && classProgress != null && showCountdown) {
            classProgress.criticalTimeText
        } else {
            visibleStatusText
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
            setCategory(
                if (isDuringClassStatusBar) {
                    Notification.CATEGORY_REMINDER
                } else {
                    Notification.CATEGORY_PROGRESS
                }
            )
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
                if (isDuringClassStatusBar) {
                    setShortCriticalText("")
                    setExtras(Bundle())
                } else if (shouldPromote) {
                    setShortCriticalText(islandCriticalText)
                    setExtras(
                        Bundle().apply {
                            putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true)
                        }
                    )
                } else {
                    setShortCriticalText("")
                    setExtras(Bundle())
                }
            }
        }

        if (isUpcoming) {
            buildBeforeClassQuickAction()?.let(builder::addAction)
        }
        if (isDuringClassStatusBar) {
            builder.addAction(buildDismissStatusBarAction())
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
                UmengDiagnosticReporter.record(
                    context = applicationContext,
                    category = "live_update_not_promoted",
                    message = "Live update notification was built but not promoted",
                    extras = mapOf(
                        "courseName" to courseName,
                        "stage" to stage,
                        "canPostPromoted" to canPostPromoted,
                        "hasPromotableCharacteristics" to notification.hasPromotableCharacteristics(),
                    )
                )
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
        }

        return notification
    }

    private fun stopAndRemoveNotification() {
        UmengDiagnosticReporter.record(
            context = applicationContext,
            category = "live_update_service_stopped",
            message = "Live update service stopped and notification removed",
            extras = mapOf(
                "courseName" to courseName,
                "stage" to activityStage,
            )
        )
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

    private fun formatCountdownDuration(
        durationMillis: Long,
        secondsThresholdMillis: Long = 60_000L,
    ): String {
        return when (countdownTextStyle) {
            "smart_min_s" -> formatSmartDuration(
                durationMillis = durationMillis,
                secondsThresholdMillis = secondsThresholdMillis,
                minuteSuffix = "min",
                secondSuffix = "s",
            )
            "minute_second_cn" -> formatMinuteSecondCn(durationMillis)
            "minute_second_min_s" -> formatMinuteSecond(durationMillis, minuteSuffix = "min", secondSuffix = "s")
            "minute_second_min_slash_s" -> formatMinuteSecond(durationMillis, minuteSuffix = "min/", secondSuffix = "s")
            "minute_only_cn" -> formatMinuteOnly(durationMillis, "分钟")
            "minute_only_min" -> formatMinuteOnly(durationMillis, "min")
            "minute_only_slash" -> formatMinuteOnly(durationMillis, "/min")
            "second_only_cn" -> formatSecondOnly(durationMillis, "秒")
            "second_only_short" -> formatSecondOnly(durationMillis, "s")
            "second_only_slash" -> formatSecondOnly(durationMillis, "/s")
            else -> formatSmartDuration(durationMillis, secondsThresholdMillis)
        }
    }

    private fun formatSmartDuration(
        durationMillis: Long,
        secondsThresholdMillis: Long,
        minuteSuffix: String = "分钟",
        secondSuffix: String = "秒",
    ): String {
        val totalSeconds = (durationMillis / 1000L).coerceAtLeast(0L)
        val flooredMinutes = (totalSeconds / 60L).coerceAtLeast(1L)
        val roundedUpMinutes = ((totalSeconds + 59L) / 60L).coerceAtLeast(1L)

        return when {
            durationMillis <= secondsThresholdMillis -> "${totalSeconds}${secondSuffix}"
            totalSeconds > 120L -> "${flooredMinutes}${minuteSuffix}"
            totalSeconds > 60L -> "${roundedUpMinutes}${minuteSuffix}"
            else -> "${totalSeconds}${secondSuffix}"
        }
    }

    private fun formatMinuteSecondCn(durationMillis: Long): String {
        val totalSeconds = (durationMillis / 1000L).coerceAtLeast(0L)
        val minutes = totalSeconds / 60L
        val seconds = totalSeconds % 60L
        return when {
            minutes > 0L && seconds > 0L -> "${minutes}分钟${seconds}秒"
            minutes > 0L -> "${minutes}分钟"
            else -> "${seconds}秒"
        }
    }

    private fun formatMinuteSecond(
        durationMillis: Long,
        minuteSuffix: String,
        secondSuffix: String,
    ): String {
        val totalSeconds = (durationMillis / 1000L).coerceAtLeast(0L)
        val minutes = totalSeconds / 60L
        val seconds = totalSeconds % 60L
        return when {
            minutes > 0L && seconds > 0L -> "${minutes}${minuteSuffix}${seconds}${secondSuffix}"
            minutes > 0L -> "${minutes}${minuteSuffix.trimEnd('/')}"
            else -> "${seconds}${secondSuffix}"
        }
    }

    private fun formatMinuteOnly(durationMillis: Long, suffix: String): String {
        val totalSeconds = (durationMillis / 1000L).coerceAtLeast(0L)
        val minutes = (totalSeconds / 60L).coerceAtLeast(1L)
        return "$minutes$suffix"
    }

    private fun formatSecondOnly(durationMillis: Long, suffix: String): String {
        val totalSeconds = (durationMillis / 1000L).coerceAtLeast(0L)
        return "$totalSeconds$suffix"
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
        val updatesEverySecond: Boolean,
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
            nextMilestoneIndex?.let { formatCountdownDuration(progressBreakOffsetsMillis[it] - elapsedMillis) }
        val finalDismissRemainingText = formatCountdownDuration(remainingMillis)
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
            updatesEverySecond = shouldRefreshEverySecond(
                durationMillis = nextMilestoneIndex?.let { progressBreakOffsetsMillis[it] - elapsedMillis }
                    ?: remainingMillis,
                secondsThresholdMillis = 60_000L,
            ),
        )
    }

    private fun shouldRefreshEverySecond(
        durationMillis: Long,
        secondsThresholdMillis: Long,
    ): Boolean {
        if (!showCountdown) {
            return false
        }
        return when (countdownTextStyle) {
            "minute_second_cn",
            "minute_second_min_s",
            "minute_second_min_slash_s",
            "second_only_cn",
            "second_only_short",
            "second_only_slash" -> true
            "smart",
            "smart_min_s" -> durationMillis <= secondsThresholdMillis
            else -> false
        }
    }

    private fun nextCountdownTextChangeDelayMillis(
        durationMillis: Long,
        secondsThresholdMillis: Long,
    ): Long {
        if (!showCountdown) {
            return 60_000L
        }
        val safeDurationMillis = durationMillis.coerceAtLeast(0L)
        val totalSeconds = (safeDurationMillis / 1000L).coerceAtLeast(0L)
        return when (countdownTextStyle) {
            "minute_second_cn",
            "minute_second_min_s",
            "minute_second_min_slash_s",
            "second_only_cn",
            "second_only_short",
            "second_only_slash" -> 1_000L
            "minute_only_cn",
            "minute_only_min",
            "minute_only_slash" -> {
                val currentMinutes = (totalSeconds / 60L).coerceAtLeast(1L)
                if (currentMinutes <= 1L) {
                    safeDurationMillis.coerceAtLeast(1_000L)
                } else {
                    (safeDurationMillis - currentMinutes * 60_000L + 1L).coerceAtLeast(1_000L)
                }
            }
            else -> {
                when {
                    safeDurationMillis <= secondsThresholdMillis -> 1_000L
                    totalSeconds > 120L -> {
                        val currentMinutes = (totalSeconds / 60L).coerceAtLeast(1L)
                        (safeDurationMillis - currentMinutes * 60_000L + 1L).coerceAtLeast(1_000L)
                    }
                    totalSeconds > 60L -> {
                        (safeDurationMillis - secondsThresholdMillis + 1L).coerceAtLeast(1_000L)
                    }
                    else -> 1_000L
                }
            }
        }
    }

    private fun computeNextTickDelayMillis(
        now: Long,
        stage: String?,
        duringClassProgress: DuringClassProgress?,
    ): Long {
        val refreshEverySecond = when (stage) {
            "beforeClass" -> shouldRefreshEverySecond(
                durationMillis = (startAtMillis - now).coerceAtLeast(0L),
                secondsThresholdMillis = 60_000L,
            )
            "beforeEnd" -> shouldRefreshEverySecond(
                durationMillis = (endAtMillis - now).coerceAtLeast(0L),
                secondsThresholdMillis = endSecondsCountdownThreshold * 1000L,
            )
            "duringClass" -> duringClassProgress?.updatesEverySecond == true
            else -> false
        }
        if (refreshEverySecond) {
            return 1000L
        }
        val stageDelay = when (stage) {
            "beforeClass" -> minOf(
                (startAtMillis - now).coerceAtLeast(1_000L),
                nextCountdownTextChangeDelayMillis(
                    durationMillis = (startAtMillis - now).coerceAtLeast(0L),
                    secondsThresholdMillis = 60_000L,
                ),
            )
            "beforeEnd" -> minOf(
                (endAtMillis - now).coerceAtLeast(1_000L),
                nextCountdownTextChangeDelayMillis(
                    durationMillis = (endAtMillis - now).coerceAtLeast(0L),
                    secondsThresholdMillis = endSecondsCountdownThreshold * 1000L,
                ),
            )
            "duringClass" -> {
                val elapsedMillis = (now - startAtMillis).coerceAtLeast(0L)
                val nextMilestoneDelay = progressBreakOffsetsMillis
                    .firstOrNull { it > elapsedMillis }
                    ?.minus(elapsedMillis)
                listOfNotNull(
                    nextMilestoneDelay?.takeIf { it > 0L },
                    (endAtMillis - now).takeIf { it > 0L },
                    nextCountdownTextChangeDelayMillis(
                        durationMillis = nextMilestoneDelay ?: (endAtMillis - now).coerceAtLeast(0L),
                        secondsThresholdMillis = 60_000L,
                    ),
                ).minOrNull() ?: 60_000L
            }
            "duringClassStatusBar" -> {
                val beforeEndStartMillis = maxOf(
                    startAtMillis,
                    endAtMillis - liveClassReminderStartMinutes * 60_000L,
                )
                listOfNotNull(
                    (beforeEndStartMillis - now).takeIf { it > 0L },
                    (endAtMillis - now).takeIf { it > 0L },
                ).minOrNull() ?: 60_000L
            }
            else -> 60_000L
        }
        return stageDelay.coerceIn(1_000L, 60_000L)
    }
}

