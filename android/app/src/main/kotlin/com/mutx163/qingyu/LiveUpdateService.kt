package com.mutx163.qingyu

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.graphics.drawable.Icon
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
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.util.Calendar
import kotlin.math.ceil

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
        private const val ACTION_CANCEL_SILENT_MODE =
            "com.mutx163.qingyu.action.CANCEL_SILENT_MODE"
        private const val ACTION_CANCEL_DO_NOT_DISTURB =
            "com.mutx163.qingyu.action.CANCEL_DO_NOT_DISTURB"
        private const val ACTION_DISMISS_STATUS_BAR_STAGE =
            "com.mutx163.qingyu.action.DISMISS_STATUS_BAR_STAGE"
        private const val POST_PROMOTED_NOTIFICATIONS_PERMISSION =
            "android.permission.POST_PROMOTED_NOTIFICATIONS"

        @Volatile
        private var isServiceRunning = false

        @Volatile
        private var lastDebugSnapshot: Map<String, Any?> = emptyMap()

        @Volatile
        private var lastDebugUpdatedAtMillis = 0L

        @Volatile
        private var lastStopReason: String? = null

        fun buildDebugStatus(context: Context): Map<String, Any?> {
            val snapshot = lastDebugSnapshot
            val summary = copyStringKeyMap(snapshot["summary"]).apply {
                this["serviceRunning"] = isServiceRunning
                this["statusText"] = when {
                    isServiceRunning -> this["statusText"] ?: context.getString(R.string.debug_status_running)
                    else -> context.getString(R.string.debug_status_not_running)
                }
                this["isExpectedToShowIsland"] =
                    (this["isExpectedToShowIsland"] as? Boolean == true) && isServiceRunning
                this["isActuallyPromotable"] =
                    (this["isActuallyPromotable"] as? Boolean == true) && isServiceRunning
                this["notIslandReason"] =
                    if (isServiceRunning) {
                        this["notIslandReason"] ?: ""
                    } else {
                        lastStopReason ?: context.getString(R.string.debug_service_not_running)
                    }
            }

            val service = copyStringKeyMap(snapshot["service"]).apply {
                this["serviceRunning"] = isServiceRunning
                this["lastDebugUpdatedAtMillis"] = lastDebugUpdatedAtMillis
                this["lastStopReason"] = lastStopReason
            }
            val recentDiagnostics = linkedMapOf<String, Any?>(
                "enabled" to UmengDiagnosticReporter.isLiveDiagnosticsEnabled(context),
                "tail" to UmengDiagnosticReporter.readLiveDiagnosticsTail(context),
            )

            return linkedMapOf(
                "generatedAtMillis" to System.currentTimeMillis(),
                "summary" to summary,
                "environment" to buildEnvironmentSnapshot(context),
                "service" to service,
                "course" to copyStringKeyMap(snapshot["course"]),
                "timing" to copyStringKeyMap(snapshot["timing"]),
                "switches" to copyStringKeyMap(snapshot["switches"]),
                "display" to copyStringKeyMap(snapshot["display"]),
                "notification" to copyStringKeyMap(snapshot["notification"]),
                "recentDiagnostics" to recentDiagnostics,
            )
        }

        private fun copyStringKeyMap(value: Any?): LinkedHashMap<String, Any?> {
            val source = value as? Map<*, *> ?: return linkedMapOf()
            val result = linkedMapOf<String, Any?>()
            source.forEach { (key, item) ->
                if (key is String) {
                    result[key] = item
                }
            }
            return result
        }

        private fun buildEnvironmentSnapshot(context: Context): Map<String, Any?> {
            return linkedMapOf(
                "androidVersion" to Build.VERSION.SDK_INT,
                "brand" to Build.BRAND,
                "manufacturer" to Build.MANUFACTURER,
                "device" to Build.DEVICE,
                "model" to Build.MODEL,
                "isXiaomiFamilyDevice" to isXiaomiFamilyDeviceCompat(),
                "hasNotificationPermission" to hasNotificationPermissionCompat(context),
                "hasPromotedPermissionDeclared" to isPromotedPermissionDeclaredCompat(context),
                "canPostPromotedNotifications" to canPostPromotedNotificationsCompat(context),
                "ignoringBatteryOptimizations" to isIgnoringBatteryOptimizationsCompat(context),
                "keepAliveAccessibilityEnabled" to KeepAliveAccessibilityStatus.isEnabled(context),
                "hideFromRecentsEnabled" to context
                    .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    .getBoolean(KEY_HIDE_FROM_RECENTS, false),
            )
        }

        private fun updateDebugSnapshot(snapshot: Map<String, Any?>) {
            lastDebugSnapshot = snapshot
            lastDebugUpdatedAtMillis = System.currentTimeMillis()
            lastStopReason = null
        }

        private fun markServiceRunning() {
            isServiceRunning = true
            lastStopReason = null
            lastDebugUpdatedAtMillis = System.currentTimeMillis()
        }

        private fun markServiceStopped(reason: String) {
            isServiceRunning = false
            lastStopReason = reason
            lastDebugUpdatedAtMillis = System.currentTimeMillis()
        }

        private fun hasNotificationPermissionCompat(context: Context): Boolean {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.POST_NOTIFICATIONS
                ) == PackageManager.PERMISSION_GRANTED
            } else {
                true
            }
        }

        // 应用级通知总开关：Android 13+ 与运行时通知权限联动，13 以下反映系统设置里的
        // 「显示通知」开关。两种状态为关时 notify() 都会被系统静默丢弃。
        private fun areNotificationsEnabledCompat(context: Context): Boolean {
            return context.getSystemService(NotificationManager::class.java)
                ?.areNotificationsEnabled() == true
        }

        // 渠道级开关：live_update_channel 被单独关闭（importance = NONE）时同样无法出通知。
        // 渠道尚未创建时视为开启，由 ensureNotificationChannel 在服务启动阶段兜底创建。
        private fun isLiveUpdateChannelEnabledCompat(context: Context): Boolean {
            val channel = context.getSystemService(NotificationManager::class.java)
                ?.getNotificationChannel(CHANNEL_ID) ?: return true
            return channel.importance != NotificationManager.IMPORTANCE_NONE
        }

        private fun isPromotedPermissionDeclaredCompat(context: Context): Boolean {
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
                packageInfo.requestedPermissions
                    ?.contains(POST_PROMOTED_NOTIFICATIONS_PERMISSION) == true
            } catch (e: Exception) {
                Log.w(TAG, DiagnosticLogMessages.LOG_INSPECT_PROMOTED_PERMISSION_FAILED, e)
                false
            }
        }

        private fun canPostPromotedNotificationsCompat(context: Context): Boolean {
            return Build.VERSION.SDK_INT >= 36 &&
                context.getSystemService(NotificationManager::class.java)
                    ?.canPostPromotedNotifications() == true
        }

        private fun isIgnoringBatteryOptimizationsCompat(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                return true
            }
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            return powerManager?.isIgnoringBatteryOptimizations(context.packageName) == true
        }

        private fun isXiaomiFamilyDeviceCompat(): Boolean {
            val brand = Build.BRAND.lowercase()
            val manufacturer = Build.MANUFACTURER.lowercase()
            return manufacturer.contains("xiaomi") ||
                brand.contains("xiaomi") ||
                brand.contains("redmi") ||
                brand.contains("poco")
        }
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
    private var miuiIslandLabelLogoPath: String? = null
    private var miuiIslandLabelLogoCornerRadius = 8f
    private var miuiIslandExpandedIconMode = "app_icon"
    private var miuiIslandExpandedIconPath: String? = null
    private var startAtMillis = 0L
    private var endAtMillis = 0L
    private var beforeClassLeadMillis = 0L
    private var endReminderLeadMillis = 600_000L
    private var liveClassReminderStartMinutes = 0
    private var enableBeforeClass = true
    private var enableDuringClass = true
    private var enableBeforeEnd = true
    private var promoteDuringClass = true
    private var showNotificationDuringClass = true
    private var beforeClassQuickAction = "none"
    private var quickActionAutoLeadMillis = 0L
    private var lastQuickActionState = ""
    private var progressBreakOffsetsMillis = longArrayOf()
    private var progressMilestoneLabels = emptyList<String>()
    private var progressMilestoneTimeTexts = emptyList<String>()
    private var lastRemainingText = "-1"
    private var lastProgressUnits = -1
    private var lastCriticalTimeText = ""
    private var cachedIslandBitmapKey: String? = null
    private var cachedIslandBitmap: Bitmap? = null
    private var hasStartedForeground = false
    private var lastTickerStage: String? = null
    private var validateAgainstSchedule = true

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return try {
            val quickActionResult = when (intent?.action) {
                ACTION_ENABLE_SILENT_MODE -> {
                    readQuickActionTimingExtra(intent)
                    handleBeforeClassQuickAction(BeforeClassQuickActionRestore.ACTION_SILENT)
                    START_NOT_STICKY
                }
                ACTION_ENABLE_DO_NOT_DISTURB -> {
                    readQuickActionTimingExtra(intent)
                    handleBeforeClassQuickAction(
                        BeforeClassQuickActionRestore.ACTION_DO_NOT_DISTURB
                    )
                    START_NOT_STICKY
                }
                ACTION_CANCEL_SILENT_MODE -> {
                    handleCancelQuickAction(BeforeClassQuickActionRestore.ACTION_SILENT)
                    START_NOT_STICKY
                }
                ACTION_CANCEL_DO_NOT_DISTURB -> {
                    handleCancelQuickAction(BeforeClassQuickActionRestore.ACTION_DO_NOT_DISTURB)
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

            if (!hasCompleteLivePayload(intent)) {
                UmengDiagnosticReporter.record(
                    context = applicationContext,
                    category = "live_update_service_missing_payload",
                    message = DiagnosticLogMessages.LIVE_UPDATE_SERVICE_MISSING_PAYLOAD,
                    extras = mapOf(
                        "intentIsNull" to (intent == null),
                        "hasCourseName" to (!intent?.getStringExtra("courseName").isNullOrBlank()),
                        "hasStage" to (!intent?.getStringExtra("stage").isNullOrBlank()),
                        "hasStartAtMillis" to ((intent?.getLongExtra("startAtMillis", 0L) ?: 0L) > 0L),
                        "hasEndAtMillis" to ((intent?.getLongExtra("endAtMillis", 0L) ?: 0L) > 0L),
                    )
                )
                val resumed = LiveUpdateScheduler.reschedule(
                    applicationContext,
                    allowImmediateStart = true,
                    stopStaleSessions = true,
                )
                if (!resumed) {
                    stopAndRemoveNotification()
                    return START_NOT_STICKY
                }
                return START_STICKY
            }

            courseName = sanitizeTextExtra(intent?.getStringExtra("courseName"))
            shortCourseNameRaw = sanitizeTextExtra(intent?.getStringExtra("shortName"))
            location = sanitizeTextExtra(intent?.getStringExtra("location"))
            teacher = sanitizeTextExtra(intent?.getStringExtra("teacher"))
            note = sanitizeTextExtra(intent?.getStringExtra("note"))
            startTimeText = sanitizeTextExtra(intent?.getStringExtra("startTime"))
            endTimeText = sanitizeTextExtra(intent?.getStringExtra("endTime"))
            nextName = sanitizeTextExtra(intent?.getStringExtra("nextName"))
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
            miuiIslandLabelLogoPath =
                intent?.getStringExtra("miuiIslandLabelLogoPath")?.takeIf { it.isNotBlank() }
            miuiIslandLabelLogoCornerRadius =
                intent?.getFloatExtra("miuiIslandLabelLogoCornerRadius", 8f) ?: 8f
            miuiIslandExpandedIconMode =
                intent?.getStringExtra("miuiIslandExpandedIconMode") ?: "app_icon"
            miuiIslandExpandedIconPath =
                intent?.getStringExtra("miuiIslandExpandedIconPath")?.takeIf { it.isNotBlank() }
            beforeClassLeadMillis =
                intent?.getLongExtra("beforeClassLeadMillis", 0L)
                    ?.coerceAtLeast(0L)
                    ?: 0L
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
            quickActionAutoLeadMillis =
                intent?.getLongExtra("quickActionAutoLeadMillis", 0L) ?: 0L
            validateAgainstSchedule =
                intent?.getBooleanExtra("validateAgainstSchedule", true) ?: true
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
            markServiceRunning()

            UmengDiagnosticReporter.record(
                context = applicationContext,
                category = "live_update_service_started",
                message = DiagnosticLogMessages.LIVE_UPDATE_SERVICE_STARTED,
                extras = mapOf(
                    "courseName" to courseName,
                    "stage" to activityStage,
                    "startAtMillis" to startAtMillis,
                    "endAtMillis" to endAtMillis,
                    "enableBeforeClass" to enableBeforeClass,
                    "enableDuringClass" to enableDuringClass,
                    "enableBeforeEnd" to enableBeforeEnd,
                    "promoteDuringClass" to promoteDuringClass,
                    "showNotificationDuringClass" to showNotificationDuringClass,
                    "showCourseNameInIsland" to showCourseNameInIsland,
                    "showLocationInIsland" to showLocationInIsland,
                    "enableMiuiIslandLabelImage" to enableMiuiIslandLabelImage,
                    "miuiIslandLabelFontSize" to miuiIslandLabelFontSize,
                    "miuiIslandLabelOffsetX" to miuiIslandLabelOffsetX,
                    "miuiIslandLabelOffsetY" to miuiIslandLabelOffsetY,
                    "hasMiuiIslandLabelLogoPath" to (!miuiIslandLabelLogoPath.isNullOrBlank()),
                    "miuiIslandLabelLogoCornerRadius" to miuiIslandLabelLogoCornerRadius,
                    "miuiIslandExpandedIconMode" to miuiIslandExpandedIconMode,
                )
            )

            val initialText = computeRemainingText(System.currentTimeMillis())
            lastRemainingText = initialText
            updateForegroundNotification(buildNotification(initialText))
            startTicker()
            START_STICKY
        } catch (e: Exception) {
            markServiceStopped(getString(R.string.stop_service_start_failed))
            UmengDiagnosticReporter.report(
                context = applicationContext,
                category = "live_update_service_start_failed",
                message = DiagnosticLogMessages.LIVE_UPDATE_SERVICE_START_FAILED,
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
        if (isServiceRunning) {
            markServiceStopped(getString(R.string.stop_service_destroyed))
        }
        if (hasStartedForeground) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            hasStartedForeground = false
        }
        if (validateAgainstSchedule) {
            LiveUpdateScheduler.onLiveUpdateStopped(applicationContext)
        }
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        val keepAliveExperimentEnabled = isTaskRemovalKeepAliveEnabled()
        val keepAliveAccessibilityEnabled = isKeepAliveAccessibilityEnabled()
        getSharedPreferences("native_runtime_prefs", Context.MODE_PRIVATE)
            .edit()
            .putLong("last_task_removed_at", System.currentTimeMillis())
            .apply()
        UmengDiagnosticReporter.record(
            context = applicationContext,
            category = "live_update_task_removed",
            message = DiagnosticLogMessages.LIVE_UPDATE_TASK_REMOVED,
            extras = mapOf(
                "courseName" to courseName,
                "stage" to activityStage,
                "keepAliveExperimentEnabled" to keepAliveExperimentEnabled,
                "hideFromRecentsEnabled" to isHideFromRecentsEnabled(),
                "keepAliveAccessibilityEnabled" to keepAliveAccessibilityEnabled,
            )
        )
        val resumed = LiveUpdateScheduler.reschedule(
            applicationContext,
            allowImmediateStart = true,
            stopStaleSessions = validateAgainstSchedule,
        )
        if (!resumed) {
            stopAndRemoveNotification()
        } else {
            UmengDiagnosticReporter.record(
                context = applicationContext,
                category = "live_update_task_removed_resumed",
                message = DiagnosticLogMessages.LIVE_UPDATE_TASK_REMOVED_RESUMED,
                extras = mapOf(
                    "courseName" to courseName,
                    "stage" to activityStage,
                    "keepAliveExperimentEnabled" to keepAliveExperimentEnabled,
                    "keepAliveAccessibilityEnabled" to keepAliveAccessibilityEnabled,
                )
            )
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
            ?.let { getString(R.string.notification_course_reminder_title, it) }
            ?: getString(R.string.app_display_name)
        val notification = buildBootstrapNotification(bootstrapTitle)
        // FOREGROUND_SERVICE_TYPE_SPECIAL_USE is API 34+.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        hasStartedForeground = true
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.notification_channel_live_update_name),
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = getString(R.string.notification_channel_live_update_desc)
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
            .setContentText(getString(R.string.notification_preparing_reminder))
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

    private fun buildBeforeClassQuickActions(): List<Notification.Action> {
        val buttons = currentQuickActionButtons()
        val actions = mutableListOf<Notification.Action>()
        if (buttons.silentEnable) {
            actions += buildQuickActionNotificationAction(
                ACTION_ENABLE_SILENT_MODE,
                getString(R.string.action_enable_silent),
            )
        }
        if (buttons.silentCancel) {
            actions += buildQuickActionNotificationAction(
                ACTION_CANCEL_SILENT_MODE,
                getString(R.string.action_cancel_silent),
            )
        }
        if (buttons.dndEnable) {
            actions += buildQuickActionNotificationAction(
                ACTION_ENABLE_DO_NOT_DISTURB,
                getString(R.string.action_enable_dnd),
            )
        }
        if (buttons.dndCancel) {
            actions += buildQuickActionNotificationAction(
                ACTION_CANCEL_DO_NOT_DISTURB,
                getString(R.string.action_cancel_dnd),
            )
        }
        return actions
    }

    private fun buildQuickActionNotificationAction(
        intentAction: String,
        label: String,
    ): Notification.Action {
        val pendingIntent = PendingIntent.getService(
            this,
            intentAction.hashCode(),
            Intent(this, LiveUpdateService::class.java).apply {
                this.action = intentAction
                putExtra("endAtMillis", endAtMillis)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return Notification.Action.Builder(
            Icon.createWithResource(this, R.drawable.ic_notification),
            label,
            pendingIntent,
        ).build()
    }

    private fun currentQuickActionButtons(): BeforeClassQuickActionButtons {
        if (beforeClassQuickAction == BeforeClassQuickActionRestore.ACTION_NONE) {
            return BeforeClassQuickActionButtons()
        }
        return beforeClassQuickActionButtons(
            action = beforeClassQuickAction,
            silentCurrentlyActive =
                BeforeClassQuickActionRestore.isSilentModeActive(applicationContext),
            dndCurrentlyActive =
                BeforeClassQuickActionRestore.isDoNotDisturbModeActive(applicationContext),
        )
    }

    private fun handleCancelQuickAction(quickAction: String) {
        val applied = if (quickAction == BeforeClassQuickActionRestore.ACTION_SILENT) {
            BeforeClassQuickActionRestore.cancelSilentMode(applicationContext)
        } else {
            BeforeClassQuickActionRestore.cancelDoNotDisturbMode(applicationContext)
        }
        if (!applied) {
            if (quickAction == BeforeClassQuickActionRestore.ACTION_DO_NOT_DISTURB) {
                openNotificationPolicyAccessSettings()
            } else {
                openSoundSettings()
            }
        }
        // 与手动打开一致：一次手动取消即代表本节课不再自动执行
        BeforeClassQuickActionRestore.markTriggerHandled(applicationContext, startAtMillis)
        UmengDiagnosticReporter.record(
            context = applicationContext,
            category = "live_update_before_class_quick_action",
            message = DiagnosticLogMessages.LIVE_UPDATE_BEFORE_CLASS_QUICK_ACTION,
            extras = mapOf(
                "action" to "cancel_$quickAction",
                "applied" to applied,
                "courseName" to courseName,
                "stage" to activityStage,
            )
        )
        refreshQuickActionNotification()
    }

    /** 通知按钮跟随真实铃声/勿扰状态；状态翻转后立即重建通知并更新缓存签名。 */
    private fun refreshQuickActionNotification() {
        if (hasStartedForeground) {
            updateForegroundNotification(
                buildNotification(computeRemainingText(System.currentTimeMillis()))
            )
        }
        lastQuickActionState = currentQuickActionButtons().toString()
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
            getString(R.string.action_close),
            pendingIntent,
        ).build()
    }

    private fun handleBeforeClassQuickAction(action: String) {
        val restoreAtMillis = endAtMillis.takeIf { it > 0L }
            ?: (System.currentTimeMillis() + 2 * 60 * 60_000L)
        val applied = when (action) {
            BeforeClassQuickActionRestore.ACTION_SILENT ->
                applyQuickActionMode(enableDoNotDisturb = false, restoreAtMillis)
            BeforeClassQuickActionRestore.ACTION_DO_NOT_DISTURB ->
                applyQuickActionMode(enableDoNotDisturb = true, restoreAtMillis)
            BeforeClassQuickActionRestore.ACTION_BOTH -> {
                val silentApplied =
                    applyQuickActionMode(enableDoNotDisturb = false, restoreAtMillis)
                val dndApplied =
                    applyQuickActionMode(enableDoNotDisturb = true, restoreAtMillis)
                silentApplied || dndApplied
            }
            else -> false
        }
        // A manual tap settles the whole quick action for this course session,
        // so the scheduled auto run must not re-apply it mid-session.
        BeforeClassQuickActionRestore.markTriggerHandled(
            applicationContext,
            startAtMillis,
        )
        UmengDiagnosticReporter.record(
            context = applicationContext,
            category = "live_update_before_class_quick_action",
            message = DiagnosticLogMessages.LIVE_UPDATE_BEFORE_CLASS_QUICK_ACTION,
            extras = mapOf(
                "action" to action,
                "applied" to applied,
                "courseName" to courseName,
                "stage" to activityStage,
            )
        )
        refreshQuickActionNotification()
    }

    private fun applyQuickActionMode(
        enableDoNotDisturb: Boolean,
        restoreAtMillis: Long,
    ): Boolean {
        return if (enableDoNotDisturb) {
            val enabled = BeforeClassQuickActionRestore.enableDoNotDisturbMode(
                this,
                restoreAtMillis,
            )
            if (!enabled) {
                openNotificationPolicyAccessSettings()
            }
            enabled
        } else {
            val enabled = BeforeClassQuickActionRestore.enableSilentMode(
                this,
                restoreAtMillis,
            )
            if (!enabled) {
                openSoundSettings()
            }
            enabled
        }
    }

    private fun maybeApplyAutoQuickAction(nowMillis: Long) {
        if (quickActionAutoLeadMillis <= 0L ||
            beforeClassQuickAction == BeforeClassQuickActionRestore.ACTION_NONE
        ) {
            return
        }
        val dueAtMillis = startAtMillis - quickActionAutoLeadMillis
        if (nowMillis < dueAtMillis) {
            return
        }
        BeforeClassQuickActionRestore.applyAutoQuickAction(
            context = applicationContext,
            action = beforeClassQuickAction,
            triggerKeyMillis = startAtMillis,
            restoreAtMillis = endAtMillis,
        )
    }

    private fun dismissStatusBarStage() {
        markServiceStopped(getString(R.string.stop_status_bar_dismissed))
        UmengDiagnosticReporter.record(
            context = applicationContext,
            category = "live_update_status_bar_dismissed",
            message = DiagnosticLogMessages.LIVE_UPDATE_STATUS_BAR_DISMISSED,
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

    private fun readQuickActionTimingExtra(intent: Intent?) {
        val restoreAtMillis = intent?.getLongExtra("endAtMillis", 0L) ?: 0L
        if (restoreAtMillis > 0L) {
            endAtMillis = restoreAtMillis
        }
    }

    private fun restoreBeforeClassQuickActionIfClassEnded() {
        BeforeClassQuickActionRestore.restoreIfClassEnded(applicationContext)
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
            Log.w(TAG, DiagnosticLogMessages.LOG_OPEN_SETTINGS_INTENT_FAILED, e)
            try {
                startActivity(
                    Intent(Settings.ACTION_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                )
            } catch (fallbackError: Exception) {
                Log.w(TAG, DiagnosticLogMessages.LOG_OPEN_FALLBACK_SETTINGS_FAILED, fallbackError)
            }
        }
    }

    private fun isHideFromRecentsEnabled(): Boolean {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_HIDE_FROM_RECENTS, false)
    }

    private fun hasCompleteLivePayload(intent: Intent?): Boolean {
        if (intent == null) {
            return false
        }
        val courseName = intent.getStringExtra("courseName")
        val stage = intent.getStringExtra("stage")
        val startAtMillis = intent.getLongExtra("startAtMillis", 0L)
        val endAtMillis = intent.getLongExtra("endAtMillis", 0L)
        return !courseName.isNullOrBlank() &&
            !stage.isNullOrBlank() &&
            startAtMillis > 0L &&
            endAtMillis > 0L &&
            endAtMillis >= startAtMillis
    }

    private fun isKeepAliveAccessibilityEnabled(): Boolean {
        return KeepAliveAccessibilityStatus.isEnabled(this)
    }

    private fun startTicker() {
        stopTicker()
        ticker = object : Runnable {
            override fun run() {
                val now = System.currentTimeMillis()
                BeforeClassQuickActionRestore.restoreIfClassEnded(applicationContext, now)
                maybeApplyAutoQuickAction(now)
                if (validateAgainstSchedule &&
                    !LiveUpdateScheduler.hasActiveLiveSelection(applicationContext, now)
                ) {
                    if (!LiveUpdateScheduler.reschedule(
                            applicationContext,
                            allowImmediateStart = true,
                            stopStaleSessions = true,
                        )
                    ) {
                        stopAndRemoveNotification()
                    }
                    return
                }
                val stage = resolveStage(now)
                if (autoDismissAfterStartMinutes > 0 &&
                    now >= startAtMillis + autoDismissAfterStartMinutes * 60_000L
                ) {
                    if (!LiveUpdateScheduler.reschedule(
                            applicationContext,
                            allowImmediateStart = true,
                            stopStaleSessions = validateAgainstSchedule,
                        )
                    ) {
                        stopAndRemoveNotification()
                    }
                    return
                }

                if (stage == null) {
                    if (!LiveUpdateScheduler.reschedule(
                            applicationContext,
                            allowImmediateStart = true,
                            stopStaleSessions = validateAgainstSchedule,
                        )
                    ) {
                        stopAndRemoveNotification()
                    }
                    return
                }

                // When stage transitions, reschedule so onStartCommand re-reads
                // the correct displaySettings for the new stage.
                if (lastTickerStage != null && stage != lastTickerStage) {
                    lastTickerStage = stage
                    if (!LiveUpdateScheduler.reschedule(
                            applicationContext,
                            allowImmediateStart = true,
                            stopStaleSessions = validateAgainstSchedule,
                        )
                    ) {
                        stopAndRemoveNotification()
                    }
                    return
                }
                lastTickerStage = stage

                if (now >= endAtMillis + 30_000L) { // Auto-remove 30s after class end, especially for tests.
                    if (!LiveUpdateScheduler.reschedule(
                            applicationContext,
                            allowImmediateStart = true,
                            stopStaleSessions = validateAgainstSchedule,
                        )
                    ) {
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
                val currentQuickActionState = currentQuickActionButtons().toString()
                if (currentText != lastRemainingText ||
                    currentProgress != lastProgressUnits ||
                    currentCriticalTimeText != lastCriticalTimeText ||
                    currentQuickActionState != lastQuickActionState
                ) {
                    lastRemainingText = currentText
                    lastProgressUnits = currentProgress
                    lastCriticalTimeText = currentCriticalTimeText
                    lastQuickActionState = currentQuickActionState
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

        val prefixTextStart = if (hidePrefixText) "" else getString(R.string.prefix_until_class_start)
        val prefixTextEnd = if (hidePrefixText) "" else getString(R.string.prefix_until_class_end)

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
                "duringClassStatusBar" -> getString(R.string.stage_in_class)
                else -> ""
            }
        }
    }

    private fun resolveStage(now: Long): String? {
        if (now >= endAtMillis) {
            return null
        }
        // Do not show the before-class stage earlier than its window start.
        // (leadMillis == 0 means the caller did not supply a window; keep the
        // legacy behavior of trusting the start intent in that case.)
        if (beforeClassLeadMillis > 0L && now < startAtMillis - beforeClassLeadMillis) {
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
                if (enableDuringClass && showNotificationDuringClass) {
                    "duringClassStatusBar"
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
            miuiIslandLabelLogoPath.orEmpty(),
            miuiIslandLabelLogoCornerRadius.toString(),
        ).joinToString("|")
        if (cacheKey == cachedIslandBitmapKey && cachedIslandBitmap != null) {
            return cachedIslandBitmap
        }

        val bitmap = buildIslandLabelBitmap(
            text = text,
            includeAppIcon = miuiIslandLabelStyle == "icon_and_text",
            customIconPath = miuiIslandLabelLogoPath,
            customIconCornerRadiusDp = miuiIslandLabelLogoCornerRadius,
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
        customIconPath: String?,
        customIconCornerRadiusDp: Float,
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
            // 粗细档位说明：真实 Typeface 的 BOLD 样式对拉丁字形有效，
            // 但中文字形走系统回退字体（MiSans 等），样式请求常不生效，
            // 可见的加粗主要依赖 isFakeBoldText 描边实现，故 bold 档必须保留。
            isFakeBoldText = fontWeight == "bold"
            isSubpixelText = true
            isLinearText = true
        }
        val iconSizeDp = if (includeAppIcon) 24f else 0f
        val iconGapDp = if (includeAppIcon) 3f else 0f
        val horizontalPaddingDp = if (includeAppIcon) 3f else 0.75f
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

        // 清晰度修正（在保留字重档位可见性的前提下）：
        // 1) bold 档保留 isFakeBoldText——中文字形走系统回退字体，
        //    真实 Bold 样式请求常不生效，假粗体是“粗”的唯一可靠来源；
        // 2) 去掉 setShadowLayer 文字投影——半透明阴影经系统缩小后
        //    晕成灰色光晕包住笔画，是小字观感“完全模糊”的主要来源；
        // 3) 字号取整到整数物理像素，避免轮廓被分数像素缩放软化。
        val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textColor
            textSize = Math.round(sp(fittedSizeSp) * renderScale).toFloat()
            this.typeface = typeface
            isFakeBoldText = fontWeight == "bold"
            isSubpixelText = true
            isLinearText = true
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
            ceil(contentWidth).toInt(),
            if (includeAppIcon) (dp(20f) * renderScale).toInt() else 1
        )
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
            val iconTop = ((height - iconSizePx) / 2f).toInt()
            val customBitmap = customIconPath?.let {
                decodeSquareBitmap(it, iconSizePx.coerceAtLeast(1))
            }
            if (customBitmap != null) {
                drawRoundedBitmap(
                    canvas = canvas,
                    bitmap = customBitmap,
                    left = horizontalPaddingPx,
                    top = iconTop.toFloat(),
                    sizePx = iconSizePx.toFloat(),
                    cornerRadiusPx = (dp(customIconCornerRadiusDp.coerceIn(0f, 12f)) * renderScale)
                        .coerceAtMost(iconSizePx / 2f),
                )
            } else {
                val appIcon = packageManager.getApplicationIcon(packageName)
                appIcon.setBounds(
                    horizontalPaddingPx.toInt(),
                    iconTop,
                    horizontalPaddingPx.toInt() + iconSizePx,
                    iconTop + iconSizePx
                )
                appIcon.draw(canvas)
            }
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
        // 绘制坐标取整到整数物理像素，消除子像素抗锯齿造成的整体发蒙。
        canvas.drawText(
            displayText,
            Math.round(textStartX).toFloat(),
            Math.round(baseline).toFloat(),
            textPaint,
        )
        return bitmap
    }

    private fun drawRoundedBitmap(
        canvas: Canvas,
        bitmap: Bitmap,
        left: Float,
        top: Float,
        sizePx: Float,
        cornerRadiusPx: Float,
    ) {
        if (cornerRadiusPx <= 0f) {
            canvas.drawBitmap(bitmap, left, top, null)
            return
        }
        val rect = RectF(left, top, left + sizePx, top + sizePx)
        val shader = BitmapShader(bitmap, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.shader = shader
            isFilterBitmap = true
        }
        canvas.drawRoundRect(rect, cornerRadiusPx, cornerRadiusPx, paint)
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
        visibleLocation: String,
        stage: String?,
        classProgress: DuringClassProgress?,
        startAtMillis: Long,
        endAtMillis: Long,
        islandName: String,
        progressBreakOffsetsMillis: LongArray,
        progressMilestoneLabels: List<String>,
        progressMilestoneTimeTexts: List<String>,
    ): String? {
        if (!isXiaomiFamilyDevice()) {
            return null
        }

        return try {
            val extraInfo = JSONObject().apply {
                if (visibleLocation.isNotBlank()) put("location", visibleLocation)
                if (teacher.isNotBlank()) put("teacher", teacher)
                if (timeRangeText.isNotBlank()) put("time", timeRangeText)
                if (nextName.isNotBlank()) put("nextCourse", nextName)
            }

            // 摘要态：岛内容
            val paramIsland = buildIslandSummary(
                stage = stage,
                classProgress = classProgress,
                islandName = islandName,
                visibleLocation = visibleLocation,
                startAtMillis = startAtMillis,
                endAtMillis = endAtMillis,
                progressBreakOffsetsMillis = progressBreakOffsetsMillis,
                progressMilestoneLabels = progressMilestoneLabels,
                progressMilestoneTimeTexts = progressMilestoneTimeTexts,
            )

            val paramV2 = JSONObject().apply {
                put("protocol", 1)
                put("business", "class_schedule")
                put("updatable", true)
                put("enableFloat", true)
                put("ticker", title)
                // 展开态：焦点通知卡片
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
                put("param_island", paramIsland)
            }

            JSONObject().apply {
                put("param_v2", paramV2)
            }.toString()
        } catch (e: Exception) {
            Log.w(TAG, DiagnosticLogMessages.LOG_BUILD_MIUI_FOCUS_PARAM_FAILED, e)
            null
        }
    }

    private fun buildIslandSummary(
        stage: String?,
        classProgress: DuringClassProgress?,
        islandName: String,
        visibleLocation: String,
        startAtMillis: Long,
        endAtMillis: Long,
        progressBreakOffsetsMillis: LongArray,
        progressMilestoneLabels: List<String>,
        progressMilestoneTimeTexts: List<String>,
    ): JSONObject {
        val totalMillis = (endAtMillis - startAtMillis).coerceAtLeast(1L)
        val now = System.currentTimeMillis()
        val elapsedMillis = (now - startAtMillis).coerceIn(0L, totalMillis)
        val progressPercent = classProgress?.progressPercent
            ?: ((elapsedMillis.toDouble() / totalMillis.toDouble()) * 100).toInt().coerceIn(0, 100)

        val islandContentText = when (stage) {
            "beforeClass" -> remainingTextForIsland(stage, startAtMillis, endAtMillis)
            "beforeEnd" -> remainingTextForIsland(stage, startAtMillis, endAtMillis)
            else -> classProgress?.compactDisplayText ?: getString(R.string.stage_in_class)
        }

        val bigIslandArea = JSONObject().apply {
            // A 区：图文组件1
            val imageTextInfoLeft = JSONObject().apply {
                put("type", 1)
                put(
                    "textInfo",
                    JSONObject().apply {
                        put("title", islandName)
                        put("content", islandContentText)
                    }
                )
                // 上课中阶段显示环形进度
                if (stage == "duringClass" && classProgress != null) {
                    put(
                        "progressInfo",
                        JSONObject().apply {
                            put("progress", progressPercent)
                            put("colorReach", "#4CAF50")
                            put("colorUnReach", "#33FFFFFF")
                        }
                    )
                }
            }
            put("imageTextInfoLeft", imageTextInfoLeft)

            // B 区：仅上课中阶段显示线性进度+节点
            if (stage == "duringClass" && classProgress != null) {
                val milestonePoints = buildMilestonePoints(
                    progressBreakOffsetsMillis,
                    progressMilestoneLabels,
                    progressMilestoneTimeTexts,
                    totalMillis,
                )
                val progressTextInfo = JSONObject().apply {
                    put(
                        "progressInfo",
                        JSONObject().apply {
                            put("progress", progressPercent)
                            put("colorReach", "#4CAF50")
                            put("colorUnReach", "#33FFFFFF")
                            if (milestonePoints.isNotEmpty()) {
                                put("picMiddle", milestonePoints.first().picKey)
                            }
                        }
                    )
                    put(
                        "textInfo",
                        JSONObject().apply {
                            val nextMilestone = classProgress.nextMilestoneDisplayText
                            if (nextMilestone != null) {
                                put("title", nextMilestone)
                            } else {
                                put("title", classProgress.finalDismissDisplayText)
                            }
                        }
                    )
                }
                put("progressTextInfo", progressTextInfo)
            }
        }

        val smallIslandArea = JSONObject()

        return JSONObject().apply {
            put("islandProperty", 1)
            put("islandTimeout", 3600)
            put("bigIslandArea", bigIslandArea)
            put("smallIslandArea", smallIslandArea)
        }
    }

    private fun remainingTextForIsland(
        stage: String?,
        startAtMillis: Long,
        endAtMillis: Long,
    ): String {
        val now = System.currentTimeMillis()
        return when (stage) {
            "beforeClass" -> {
                val remaining = startAtMillis - now
                if (remaining > 0) {
                    getString(R.string.remaining_until_class_start, formatCountdownDuration(remaining))
                } else {
                    getString(R.string.stage_before_class)
                }
            }
            "beforeEnd" -> {
                val remaining = endAtMillis - now
                if (remaining > 0) {
                    getString(R.string.remaining_until_class_end, formatCountdownDuration(remaining))
                } else {
                    getString(R.string.stage_before_end)
                }
            }
            else -> getString(R.string.stage_in_class)
        }
    }

    private data class MilestonePoint(
        val position: Int,
        val picKey: String,
    )

    private fun buildMilestonePoints(
        progressBreakOffsetsMillis: LongArray,
        progressMilestoneLabels: List<String>,
        progressMilestoneTimeTexts: List<String>,
        totalMillis: Long,
    ): List<MilestonePoint> {
        if (progressBreakOffsetsMillis.isEmpty() || totalMillis <= 0) return emptyList()
        val points = mutableListOf<MilestonePoint>()
        for (index in progressBreakOffsetsMillis.indices) {
            val offsetMillis = progressBreakOffsetsMillis[index]
            val position = ((offsetMillis.toDouble() / totalMillis.toDouble()) * 100)
                .toInt().coerceIn(1, 99)
            val label = progressMilestoneLabels.getOrNull(index) ?: continue
            points.add(MilestonePoint(position = position, picKey = "miui.focus.pic_milestone_$index"))
        }
        return points.distinctBy { it.position }.sortedBy { it.position }
    }

    private fun decodeSquareBitmap(path: String, targetSize: Int): Bitmap? {
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
        val resolvedTargetSize = targetSize.coerceAtLeast(1)
        if (cropped.width == resolvedTargetSize && cropped.height == resolvedTargetSize) {
            return cropped
        }
        val scaled = Bitmap.createScaledBitmap(cropped, resolvedTargetSize, resolvedTargetSize, true)
        if (scaled != cropped) {
            cropped.recycle()
        }
        return scaled
    }

    private fun decodeExpandedIconBitmap(path: String): Bitmap? {
        val targetSize = dp(56f).toInt().coerceAtLeast(96)
        return decodeSquareBitmap(path, targetSize)
    }

    private fun applyExpandedLargeIcon(builder: Notification.Builder) {
        when (miuiIslandExpandedIconMode) {
            "hidden" -> return
            "custom_image" -> {
                val path = miuiIslandExpandedIconPath ?: return
                decodeExpandedIconBitmap(path)?.let(builder::setLargeIcon)
            }
            else -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    builder.setLargeIcon(Icon.createWithResource(this, R.mipmap.ic_launcher))
                }
            }
        }
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
            Log.w(TAG, DiagnosticLogMessages.LOG_BUILD_ROUNDED_LAUNCHER_ICON_FAILED, e)
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
        val visibleLocation = if (showLocationInIsland) location else ""
        val islandLocation = visibleLocation
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
            "beforeClass" -> getString(R.string.stage_before_class)
            "beforeEnd" -> getString(R.string.stage_before_end)
            else -> getString(R.string.stage_in_class)
        }
        val visibleStatusText = when {
            !showCountdown && showStageText -> stageTitle
            !showCountdown -> ""
            else -> remainingText.ifBlank { stageTitle }
        }
        val title = when (stage) {
            "beforeClass" -> getString(R.string.title_before_class, shortCourseName)
            "beforeEnd" -> getString(R.string.title_before_end, shortCourseName)
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
                timeRangeText.takeIf { it.isNotBlank() }?.let { getString(R.string.label_class_start_time, it) },
                visibleLocation.takeIf { it.isNotBlank() }?.let { getString(R.string.label_location, it) }
            ).filterNotNull().joinToString("  ·  ")
        } else if (isEndingSoon) {
            listOf(
                timeRangeText.takeIf { it.isNotBlank() }?.let { getString(R.string.label_class_end_time, it) },
                visibleLocation.takeIf { it.isNotBlank() }?.let { getString(R.string.label_location, it) }
            ).filterNotNull().joinToString("  ·  ")
        } else {
            ""
        }
        val summaryText = if ((isDuringClass || isEndingSoon) && classProgress != null && showCountdown) {
            listOf(
                classProgress.nextMilestoneDisplayText,
                classProgress.finalDismissDisplayText,
                visibleLocation.takeIf { it.isNotBlank() }
            ).filterNotNull().joinToString(" · ")
        } else {
            listOf(
                visibleLocation.takeIf { it.isNotBlank() },
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
            if (shortNameLabel != null) {
                append("\n").append(getString(R.string.detail_short_name, shortNameLabel))
            }
            if ((isDuringClass || isEndingSoon) && classProgress != null && showCountdown) {
                if (classProgress.nextMilestoneDisplayText != null) {
                    append("\n").append(
                        getString(R.string.detail_next_milestone, classProgress.nextMilestoneDisplayText)
                    )
                }
                append("\n").append(
                    getString(R.string.detail_final_dismiss, classProgress.finalDismissDisplayText)
                )
            } else if (detailStatusText != null) {
                append("\n").append(getString(R.string.detail_status, detailStatusText))
            }
            if (timeRangeText.isNotBlank()) append("\n").append(getString(R.string.detail_time, timeRangeText))
            if (location.isNotBlank()) append("\n").append(getString(R.string.label_location, location))
            if (teacher.isNotBlank()) append("\n").append(getString(R.string.detail_teacher, teacher))
            if (nextName.isNotBlank()) append("\n").append(getString(R.string.detail_next_course, nextName))
            if (note.isNotBlank()) append("\n").append(getString(R.string.detail_note, note))
        }

        val promotedContentText = if ((isDuringClass || isEndingSoon) && classProgress != null && showCountdown) {
            listOf(
                classProgress.compactDisplayText,
                visibleLocation.takeIf { it.isNotBlank() }
            ).filterNotNull().joinToString(" · ")
        } else {
            listOf(
                visibleStatusText.takeIf { it.isNotBlank() },
                timeRangeText.takeIf { it.isNotBlank() },
                visibleLocation.takeIf { it.isNotBlank() },
                teacher.takeIf { it.isNotBlank() }
            ).filterNotNull().joinToString(" · ")
        }
        val promotedExpandedDetailText = buildString {
            if ((isDuringClass || isEndingSoon) && classProgress != null && showCountdown) {
                if (classProgress.nextMilestoneDisplayText != null) {
                    append(getString(R.string.detail_next_milestone, classProgress.nextMilestoneDisplayText))
                    append("\n")
                }
                append(getString(R.string.detail_final_dismiss, classProgress.finalDismissDisplayText))
            } else if (detailStatusText != null) {
                append(getString(R.string.detail_status, detailStatusText))
            }
            if (timeRangeText.isNotBlank()) append("\n").append(getString(R.string.detail_time, timeRangeText))
            if (location.isNotBlank()) append("\n").append(getString(R.string.label_location, location))
            if (teacher.isNotBlank()) append("\n").append(getString(R.string.detail_teacher, teacher))
            if (shortNameLabel != null) append("\n").append(getString(R.string.detail_short_name, shortNameLabel))
            if (nextName.isNotBlank()) append("\n").append(getString(R.string.detail_next_course, nextName))
            if (note.isNotBlank()) append("\n").append(getString(R.string.detail_note, note))
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
            
        val miuiFocusHintText = if (
            liveShouldMirrorStatusIntoMiuiFocusHint(
                sdkInt = Build.VERSION.SDK_INT,
                shouldPromote = shouldPromote,
            )
        ) {
            visibleStatusText
        } else {
            ""
        }

        val miuiFocusParam = if (!shouldPromote || isDuringClassStatusBar) {
            null
        } else {
            buildMiuiFocusParam(
                title = title,
                remainingText = miuiFocusHintText,
                timeRangeText = timeRangeText,
                bodyContent = promotedContentText,
                visibleLocation = visibleLocation,
                stage = stage,
                classProgress = classProgress,
                startAtMillis = startAtMillis,
                endAtMillis = endAtMillis,
                islandName = nameToUse,
                progressBreakOffsetsMillis = progressBreakOffsetsMillis,
                progressMilestoneLabels = progressMilestoneLabels,
                progressMilestoneTimeTexts = progressMilestoneTimeTexts,
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

        val notificationTitle = if (shouldPromote || showStandardNotification) {
            title
        } else {
            ""
        }
        val notificationContentText = if (shouldPromote) {
            promotedContentText
        } else if (!showStandardNotification) {
            ""
        } else {
            contentText
        }
        val notificationExpandedText = if (shouldPromote) {
            promotedExpandedDetailText
        } else if (!showStandardNotification) {
            ""
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
            applyExpandedLargeIcon(this)
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
            if (usesProgressExpandedStyle) {
                val progress = requireNotNull(classProgress)
                setProgress(progress.progressMax, progress.progressUnits, false)
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
            buildBeforeClassQuickActions().forEach(builder::addAction)
        }
        if (isDuringClassStatusBar) {
            builder.addAction(buildDismissStatusBarAction())
        }

        if (usesProgressExpandedStyle) {
            val progress = requireNotNull(classProgress)
            builder.setStyle(
                Notification.ProgressStyle()
                    .setStyledByProgress(true)
                    .setProgress(progress.progressUnits)
                    .setProgressSegments(
                        listOf(
                            Notification.ProgressStyle.Segment(
                                progress.progressMax
                            )
                        )
                    )
                    .setProgressTrackerIcon(
                        buildRoundedLauncherIcon(dp(28f).toInt(), dp(9f))
                            ?: Icon.createWithResource(this, R.mipmap.ic_launcher)
                    )
                    .setProgressPoints(
                        progress.breakPointUnits.map { point ->
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

        val canPostPromoted = if (Build.VERSION.SDK_INT >= 36) {
            getSystemService(NotificationManager::class.java)?.canPostPromotedNotifications() == true
        } else {
            false
        }
        val hasPromotableCharacteristics = if (Build.VERSION.SDK_INT >= 36) {
            notification.hasPromotableCharacteristics()
        } else {
            null
        }
        val isMiuiFocusIslandReady =
            isXiaomiFamilyDevice() &&
                miuiFocusParam != null &&
                shouldPromote &&
                !isDuringClassStatusBar
        // 应用级或渠道级通知任一被关时 notify() 都会被系统静默丢弃，
        // 必须先于两条就绪路径拦截，否则自检页会误报「已满足上岛条件」而实际无法上岛。
        val notificationsAllowed = areNotificationsEnabledCompat(this)
        val liveChannelEnabled = isLiveUpdateChannelEnabledCompat(this)
        val isActuallyPromotable = when {
            isDuringClassStatusBar || !shouldPromote -> false
            !notificationsAllowed || !liveChannelEnabled -> false
            Build.VERSION.SDK_INT >= 36 &&
                canPostPromoted &&
                hasPromotableCharacteristics == true -> true
            isMiuiFocusIslandReady -> true
            else -> false
        }
        val notIslandReason = when {
            !hasStartedForeground -> getString(R.string.debug_foreground_not_started)
            stage == null -> getString(R.string.debug_stage_not_displayable)
            isDuringClassStatusBar -> getString(R.string.debug_status_bar_only)
            !shouldPromote && isDuringClass && !promoteDuringClass ->
                getString(R.string.debug_during_class_normal_notification)
            !shouldPromote -> getString(R.string.debug_promote_not_requested)
            !notificationsAllowed -> getString(R.string.debug_notification_permission_off)
            !liveChannelEnabled -> getString(R.string.debug_notification_channel_disabled)
            isActuallyPromotable -> ""
            Build.VERSION.SDK_INT >= 36 && !isPromotedPermissionDeclaredCompat(this) ->
                getString(R.string.debug_promoted_permission_not_declared)
            Build.VERSION.SDK_INT >= 36 && !canPostPromoted && !isMiuiFocusIslandReady ->
                getString(R.string.debug_system_denied_promoted)
            Build.VERSION.SDK_INT >= 36 && hasPromotableCharacteristics == false && !isMiuiFocusIslandReady ->
                getString(R.string.debug_notification_not_promotable)
            isXiaomiFamilyDevice() && miuiFocusParam == null ->
                getString(R.string.debug_miui_focus_param_missing)
            Build.VERSION.SDK_INT < 36 && !isXiaomiFamilyDevice() ->
                getString(R.string.debug_os_not_supported)
            else -> getString(R.string.debug_try_return_home)
        }

        updateDebugSnapshot(
            linkedMapOf(
                "summary" to linkedMapOf(
                    "serviceRunning" to true,
                    "currentStage" to activityStage,
                    "resolvedStage" to stage,
                    "isExpectedToShowIsland" to shouldPromote,
                    "isActuallyPromotable" to isActuallyPromotable,
                    "statusText" to if (isActuallyPromotable) {
                        getString(R.string.debug_island_ready)
                    } else {
                        getString(R.string.debug_island_not_ready)
                    },
                    "notIslandReason" to notIslandReason,
                ),
                "service" to linkedMapOf(
                    "serviceRunning" to true,
                    "hasStartedForeground" to hasStartedForeground,
                    "activityStage" to activityStage,
                    "resolvedStage" to stage,
                    "lastRemainingText" to remainingText,
                    "lastProgressUnits" to lastProgressUnits,
                    "lastCriticalTimeText" to lastCriticalTimeText,
                ),
                "course" to linkedMapOf(
                    "courseName" to courseName,
                    "shortCourseNameRaw" to shortCourseNameRaw,
                    "nextCourseName" to nextName,
                    "location" to location,
                    "teacher" to teacher,
                    "note" to note,
                    "startTimeText" to startTimeText,
                    "endTimeText" to endTimeText,
                ),
                "timing" to linkedMapOf(
                    "nowMillis" to now,
                    "startAtMillis" to startAtMillis,
                    "endAtMillis" to endAtMillis,
                    "remainingToStartMillis" to (startAtMillis - now).coerceAtLeast(0L),
                    "remainingToEndMillis" to (endAtMillis - now).coerceAtLeast(0L),
                    "endReminderLeadMillis" to endReminderLeadMillis,
                    "liveClassReminderStartMinutes" to liveClassReminderStartMinutes,
                    "endSecondsCountdownThreshold" to endSecondsCountdownThreshold,
                    "autoDismissAfterStartMinutes" to autoDismissAfterStartMinutes,
                ),
                "switches" to linkedMapOf(
                    "enableBeforeClass" to enableBeforeClass,
                    "enableDuringClass" to enableDuringClass,
                    "enableBeforeEnd" to enableBeforeEnd,
                    "promoteDuringClass" to promoteDuringClass,
                    "showNotificationDuringClass" to showNotificationDuringClass,
                ),
                "display" to linkedMapOf(
                    "showCountdown" to showCountdown,
                    "countdownTextStyle" to countdownTextStyle,
                    "showStageText" to showStageText,
                    "showCourseNameInIsland" to showCourseNameInIsland,
                    "showLocationInIsland" to showLocationInIsland,
                    "useShortNameInIsland" to useShortNameInIsland,
                    "hidePrefixText" to hidePrefixText,
                    "duringClassTimeDisplayMode" to duringClassTimeDisplayMode,
                    "enableMiuiIslandLabelImage" to enableMiuiIslandLabelImage,
                    "miuiIslandLabelStyle" to miuiIslandLabelStyle,
                    "miuiIslandLabelContent" to miuiIslandLabelContent,
                    "miuiIslandLabelFontColor" to miuiIslandLabelFontColor,
                    "miuiIslandLabelFontWeight" to miuiIslandLabelFontWeight,
                    "miuiIslandLabelRenderQuality" to miuiIslandLabelRenderQuality,
                    "miuiIslandLabelFontSize" to miuiIslandLabelFontSize,
                    "miuiIslandLabelOffsetX" to miuiIslandLabelOffsetX,
                    "miuiIslandLabelOffsetY" to miuiIslandLabelOffsetY,
                    "miuiIslandLabelLogoPath" to miuiIslandLabelLogoPath,
                    "miuiIslandLabelLogoCornerRadius" to miuiIslandLabelLogoCornerRadius,
                    "miuiIslandExpandedIconMode" to miuiIslandExpandedIconMode,
                    "miuiIslandExpandedIconPath" to miuiIslandExpandedIconPath,
                    "beforeClassQuickAction" to beforeClassQuickAction,
                    "quickActionAutoLeadMillis" to quickActionAutoLeadMillis,
                ),
                "notification" to linkedMapOf(
                    "shouldPromote" to shouldPromote,
                    "showStandardNotification" to showStandardNotification,
                    "isDuringClassStatusBar" to isDuringClassStatusBar,
                    "notificationsAllowed" to notificationsAllowed,
                    "liveUpdateChannelEnabled" to liveChannelEnabled,
                    "canPostPromotedNotifications" to canPostPromoted,
                    "hasPromotableCharacteristics" to hasPromotableCharacteristics,
                    "miuiFocusParamPresent" to (miuiFocusParam != null),
                    "notificationTitle" to notificationTitle,
                    "notificationContentText" to notificationContentText,
                    "notificationExpandedText" to notificationExpandedText,
                    "visibleStatusText" to visibleStatusText,
                    "islandCriticalText" to islandCriticalText,
                    "promotedContentText" to promotedContentText,
                ),
            )
        )

        if (Build.VERSION.SDK_INT >= 36) {
            if (shouldPromote && (hasPromotableCharacteristics != true || !canPostPromoted)) {
                UmengDiagnosticReporter.record(
                    context = applicationContext,
                    category = "live_update_not_promoted",
                    message = DiagnosticLogMessages.LIVE_UPDATE_NOT_PROMOTED,
                    extras = mapOf(
                        "courseName" to courseName,
                        "stage" to stage,
                        "canPostPromoted" to canPostPromoted,
                        "hasPromotableCharacteristics" to hasPromotableCharacteristics,
                        "notificationsAllowed" to notificationsAllowed,
                        "liveChannelEnabled" to liveChannelEnabled,
                        "miuiIslandExpandedIconMode" to miuiIslandExpandedIconMode,
                    )
                )
                UmengDiagnosticReporter.report(
                    context = applicationContext,
                    category = "live_update_promoted_not_shown",
                    message = DiagnosticLogMessages.LIVE_UPDATE_PROMOTED_NOT_SHOWN,
                    dedupeKey = "live_update_promoted_not_shown:${courseName}:${activityStage}",
                    extras = mapOf(
                        "courseName" to courseName,
                        "stage" to stage,
                        "canPostPromoted" to canPostPromoted,
                        "hasPromotableCharacteristics" to hasPromotableCharacteristics,
                        "notificationsAllowed" to notificationsAllowed,
                        "liveChannelEnabled" to liveChannelEnabled,
                        "showStandardNotification" to showStandardNotification,
                        "remainingText" to remainingText,
                        "miuiIslandExpandedIconMode" to miuiIslandExpandedIconMode,
                    )
                )
            }
        }

        return notification
    }

    private fun sanitizeTextExtra(value: String?): String {
        val normalized = value?.trim().orEmpty()
        return if (normalized.equals("null", ignoreCase = true)) "" else normalized
    }

    private fun stopAndRemoveNotification() {
        restoreBeforeClassQuickActionIfClassEnded()
        markServiceStopped(getString(R.string.stop_reminder_ended))
        UmengDiagnosticReporter.record(
            context = applicationContext,
            category = "live_update_service_stopped",
            message = DiagnosticLogMessages.LIVE_UPDATE_SERVICE_STOPPED,
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
    ): String = CountdownFormat.formatDuration(durationMillis, countdownTextStyle, secondsThresholdMillis)

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
        val finalDismissDisplayText = getString(R.string.final_dismiss_with_time, finalDismissRemainingText)
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
            "minute_second_colon",
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
            "minute_second_colon",
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
