package com.mutx163.qingyu

import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.HapticFeedbackConstants
import android.Manifest
import android.app.ActivityManager
import android.app.AlarmManager
import android.app.DownloadManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.appwidget.AppWidgetManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.provider.OpenableColumns
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import android.webkit.URLUtil
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "com.mutx163.qingyu/miui_live"
        private const val SYSTEM_UI_CHANNEL = "com.mutx163.qingyu/system_ui"
        private const val UMENG_CHANNEL = "com.mutx163.qingyu/umeng_analytics"
        private const val HOME_WIDGET_CHANNEL = "com.mutx163.qingyu/home_widget"
        private const val EXAM_REMINDER_CHANNEL = "com.mutx163.qingyu/exam_reminder"
        private const val WEEKLY_REPORT_CHANNEL = "com.mutx163.qingyu/weekly_report"
        private const val SUPPORT_CHANNEL = "com.mutx163.qingyu/support"
        private const val MIGRATION_CHANNEL = "com.mutx163.qingyu/migration"
        private const val CHANNEL_ID = "live_update_channel"
        private const val PERMISSION_REQUEST_CODE = 1001
        private const val PREFS_NAME = "native_runtime_prefs"
        private const val KEY_HIDE_FROM_RECENTS = "hide_from_recents"
        private const val KEY_MANAGED_UPDATE_DOWNLOAD_IDS = "managed_update_download_ids"
        private const val POST_PROMOTED_NOTIFICATIONS_PERMISSION =
            "android.permission.POST_PROMOTED_NOTIFICATIONS"
        private const val ICS_CHANNEL = "com.mutx163.qingyu/ics_import"
        private const val LAN_EDIT_CHANNEL = "com.mutx163.qingyu/lan_edit"
        private const val FROSTED_BLUR_CHANNEL = "com.mutx163.qingyu/frosted_blur"
        private const val LAUNCH_URL_CHANNEL = "com.mutx163.qingyu/launch_url"
        private const val HAPTIC_CHANNEL = "com.mutx163.qingyu/haptic"
        private const val SYSTEM_ALARM_CHANNEL = "com.mutx163.qingyu/system_alarm"

        /** Schemes allowed for the `launch_url` channel (feedback deep links). */
        private val ALLOWED_LAUNCH_SCHEMES = setOf(
            "https", "http", "coolmarket", "xhsdiscover", "mqqopensdkapi", "mqqapi", "weixin"
        )
    }

    private var notificationManager: NotificationManager? = null
    private var permissionResult: MethodChannel.Result? = null
    private data class PendingExternalImport(
        val kind: String,
        val fileName: String,
        val textContent: String? = null,
        val filePath: String? = null,
    )

    private var pendingExternalImport: PendingExternalImport? = null

    /** 外部导入读取请求序号：仅主线程读写；后台读取回填时校验仍是最新请求，
     *  防止前一个慢读取（如网盘 provider）回来覆盖更新的导入意图。 */
    private var externalImportRequestSeq = 0
    private var pendingOpenLanEdit = false
    private var pendingDebugRoute: Map<String, Any?>? = null

    /** 桌面卡片点击带进的 appWidgetId，Flutter 侧按绑定档案分流后消费。 */
    private var pendingWidgetLaunchAppWidgetId: Int? = null
    private var flutterChannel: MethodChannel? = null
    private var lanEditChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Fix: when launched via ACTION_SEND / ACTION_VIEW from another app (e.g.
        // a file manager), the caller may NOT set FLAG_ACTIVITY_NEW_TASK, which
        // causes our Activity to run inside the caller's task.  The Recents
        // screen then shows the caller's label & icon instead of ours.
        // Detect this situation (not task root + external intent) and redirect
        // into our own task before proceeding.
        if (!isTaskRoot && intent != null &&
            (intent.action == Intent.ACTION_SEND ||
             intent.action == Intent.ACTION_SEND_MULTIPLE ||
             intent.action == Intent.ACTION_VIEW)) {
            val relaunch = Intent(this, MainActivity::class.java).apply {
                action = intent.action
                type = intent.type
                intent.clipData?.let { clipData = it }
                putExtras(intent)
                intent.data?.let { data = it }
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
                )
            }
            // super.onCreate() must run before onCreate returns on EVERY path:
            // finish() does not exempt this branch, and skipping it throws
            // SuperNotCalledException — crashing "open with" launches from
            // apps like QQ (VIEW intent without FLAG_ACTIVITY_NEW_TASK).
            super.onCreate(savedInstanceState)
            startActivity(relaunch)
            finish()
            return
        }

        // Install the Android/AndroidX splash before super.onCreate. Do not
        // install a second custom window background here: the system splash is
        // the only launch branding, and the first Flutter frame is the app UI.
        installSplashScreen()
        super.onCreate(savedInstanceState)
        // Debug deep links first so automation routes never fall into import.
        handleDebugDeepLinkIntent(intent)
        handleExternalImportIntent(intent)
        handleLanEditIntent(intent)
        handleWidgetLaunchIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleDebugDeepLinkIntent(intent)
        handleExternalImportIntent(intent)
        handleLanEditIntent(intent)
        handleWidgetLaunchIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        applyPersistedHideFromRecents()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannels()

        // 公平运行内存：绑定 Flutter 通道（原生广播本身不依赖引擎）。
        FairMemoryAdapter.attachFlutterEngine(flutterEngine.dartExecutor.binaryMessenger)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MemoryStatsCollector.methodChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getMemorySnapshot" -> {
                    try {
                        result.success(MemoryStatsCollector.buildSnapshot(applicationContext))
                    } catch (error: Exception) {
                        result.error(
                            "MEMORY_SNAPSHOT_FAILED",
                            error.message,
                            null,
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_UI_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getTransitionAnimationScale" -> {
                        val scale = Settings.Global.getFloat(
                            contentResolver,
                            Settings.Global.TRANSITION_ANIMATION_SCALE,
                            1.0f,
                        )
                        result.success(scale.toDouble())
                    }
                    "getDisplayCornerRadiusDp" -> {
                        result.success(readDisplayCornerRadiusDp())
                    }
                    "getFontWeightAdjustment" -> {
                        // Android 12+ (API 31) 暴露系统字体粗细增量；未设置为
                        // FONT_WEIGHT_ADJUSTMENT_UNDEFINED(Int.MAX_VALUE)。低版本/未定义
                        // 时返回 null，交由 Dart 侧回退到 MediaQuery.boldText。
                        val value: Int? =
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                val adj = resources.configuration.fontWeightAdjustment
                                if (adj ==
                                    android.content.res.Configuration
                                        .FONT_WEIGHT_ADJUSTMENT_UNDEFINED
                                ) {
                                    null
                                } else {
                                    adj
                                }
                            } else {
                                null
                            }
                        result.success(value)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HAPTIC_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "edgeTick" -> {
                        try {
                            result.success(performEdgeHapticTick())
                        } catch (error: Exception) {
                            Log.w("EdgeHaptic", "edgeTick failed", error)
                            result.error("HAPTIC_FAILED", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FROSTED_BLUR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(FrostedBlur.isSupported())
                    "blurPng" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val radius = (call.argument<Double>("radius") ?: 16.0).toFloat()
                        if (bytes == null) {
                            result.error("INVALID_ARGUMENTS", "Missing PNG bytes", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                val blurred = FrostedBlur.blurPng(bytes, radius)
                                runOnUiThread {
                                    if (blurred == null) {
                                        result.error(
                                            "BLUR_FAILED",
                                            "Native blur returned null",
                                            null,
                                        )
                                    } else {
                                        result.success(blurred)
                                    }
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("BLUR_FAILED", e.message, null)
                                }
                            }
                        }.start()
                    }
                    "blurRgba" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val width = call.argument<Int>("width") ?: 0
                        val height = call.argument<Int>("height") ?: 0
                        val radius = (call.argument<Double>("radius") ?: 16.0).toFloat()
                        if (bytes == null || width <= 0 || height <= 0) {
                            result.error("INVALID_ARGUMENTS", "Missing RGBA payload", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                val blurred = FrostedBlur.blurRgba(bytes, width, height, radius)
                                runOnUiThread {
                                    if (blurred == null) {
                                        result.error(
                                            "BLUR_FAILED",
                                            "Native RGBA blur returned null",
                                            null,
                                        )
                                    } else {
                                        result.success(blurred)
                                    }
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("BLUR_FAILED", e.message, null)
                                }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }


        // ── 这节课闹钟：调用系统时钟 AlarmClock ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_ALARM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setAlarm" -> {
                        try {
                            val hour = call.argument<Int>("hour")
                            val minute = call.argument<Int>("minute")
                            if (hour == null || minute == null ||
                                hour !in 0..23 || minute !in 0..59
                            ) {
                                result.error(
                                    "INVALID_ARGUMENTS",
                                    "hour/minute missing or out of range",
                                    null,
                                )
                                return@setMethodCallHandler
                            }
                            val label = call.argument<String>("label") ?: ""
                            val skipUi = call.argument<Boolean>("skipUi") ?: false
                            @Suppress("UNCHECKED_CAST")
                            val days = call.argument<List<Int>>("days")
                            val outcome = SystemAlarmHelper.fireSetAlarm(
                                this,
                                hour,
                                minute,
                                label,
                                skipUi,
                                days,
                            )
                            result.success(
                                mapOf(
                                    "launched" to outcome.launched,
                                    "skipUi" to outcome.skipUiRequested,
                                ),
                            )
                        } catch (e: ClassCastException) {
                            result.error(
                                "INVALID_ARGUMENTS",
                                "malformed argument type: ${e.message}",
                                null,
                            )
                        } catch (e: Exception) {
                            Log.e("MainActivity", "system_alarm: setAlarm failed", e)
                            result.error("SET_ALARM_FAILED", e.message, null)
                        }
                    }
                    "showAlarms" -> {
                        try {
                            result.success(SystemAlarmHelper.fireShowAlarms(this))
                        } catch (e: Exception) {
                            Log.e("MainActivity", "system_alarm: showAlarms failed", e)
                            result.error("SHOW_ALARMS_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Feedback: direct Intent launch (bypasses url_launcher on MIUI) ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LAUNCH_URL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "launch" -> {
                        val urlString = call.argument<String>("url")
                        if (urlString.isNullOrEmpty()) {
                            result.error("INVALID_URL", "url is null or empty", null)
                            return@setMethodCallHandler
                        }
                        val parsed = Uri.parse(urlString)
                        val scheme = parsed.scheme?.lowercase()
                        if (scheme == null || scheme !in ALLOWED_LAUNCH_SCHEMES) {
                            Log.w("MainActivity", "launch_url: blocked scheme '$scheme' for $urlString")
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, parsed).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: ActivityNotFoundException) {
                            Log.w("MainActivity", "launch_url: no activity for $urlString", e)
                            result.success(false)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "launch_url: failed for $urlString", e)
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .also { flutterChannel = it }
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
                    "isAutoStartEnabled" -> {
                        result.success(isAutoStartEnabled())
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
                    "getLiveUpdateDebugStatus" -> {
                        result.success(LiveUpdateService.buildDebugStatus(this))
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
                    "suspendScheduleTriggers" -> {
                        val untilMillis = (call.arguments as? Number)?.toLong()
                        if (untilMillis != null) {
                            LiveUpdateScheduler.suspendScheduleTriggers(this, untilMillis)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENTS", "Missing suspend deadline", null)
                        }
                    }

                    "getPendingExternalImport" -> {
                        val pending = pendingExternalImport
                        pendingExternalImport = null
                        result.success(
                            pending?.let {
                                mapOf(
                                    "kind" to it.kind,
                                    "fileName" to it.fileName,
                                    "textContent" to it.textContent,
                                    "filePath" to it.filePath,
                                )
                            },
                        )
                    }

                    "getPendingDebugRoute" -> {
                        val pending = pendingDebugRoute
                        pendingDebugRoute = null
                        result.success(pending)
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
                            level = data["level"] as? String,
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
                            level = data["level"] as? String,
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
                    "readLiveDiagnosticsText" -> {
                        result.success(
                            UmengDiagnosticReporter.readLiveDiagnosticsText(applicationContext)
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
                    "canRequestPinWidget" -> {
                        result.success(canRequestPinWidget())
                    }
                    "canScheduleExactAlarms" -> {
                        result.success(canScheduleExactAlarms())
                    }
                    "requestScheduleExactAlarm" -> {
                        result.success(requestScheduleExactAlarm())
                    }
                    "requestPinWidget" -> {
                        val arguments = call.arguments as? Map<*, *>
                        val widgetType = arguments?.get("widgetType") as? String
                        if (widgetType.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENTS", "Missing widget type", null)
                        } else {
                            result.success(requestPinWidget(widgetType))
                        }
                    }
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
                    "syncStatsSnapshot" -> {
                        val data = call.arguments as? Map<String, Any?>
                        if (data != null) {
                            StatsWidgetSupport.syncSnapshot(applicationContext, data)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENTS", "Missing stats widget snapshot", null)
                        }
                    }
                    "clearStatsSnapshot" -> {
                        StatsWidgetSupport.clearSnapshot(applicationContext)
                        result.success(true)
                    }
                    "listTodayWidgetInstances" -> {
                        result.success(listTodayWidgetInstances())
                    }
                    "getWidgetBinding" -> {
                        val appWidgetId = (call.arguments as? Map<*, *>)
                            ?.get("appWidgetId") as? Int
                        if (appWidgetId == null) {
                            result.error("INVALID_ARGUMENTS", "Missing appWidgetId", null)
                        } else {
                            result.success(
                                WidgetBindingStore.getBoundProfileId(applicationContext, appWidgetId)
                            )
                        }
                    }
                    "setWidgetBinding" -> {
                        val payload = call.arguments as? Map<*, *>
                        val appWidgetId = payload?.get("appWidgetId") as? Int
                        val profileId = payload?.get("profileId") as? String
                        if (appWidgetId == null) {
                            result.error("INVALID_ARGUMENTS", "Missing appWidgetId", null)
                        } else {
                            WidgetBindingStore.setBoundProfileId(applicationContext, appWidgetId, profileId)
                            TodayWidgetSupport.updateAll(applicationContext)
                            HomeWidgetStorage.rescheduleRefresh(applicationContext)
                            result.success(true)
                        }
                    }
                    "syncWidgetSnapshot" -> {
                        val payload = call.arguments as? Map<*, *>
                        val appWidgetId = payload?.get("appWidgetId") as? Int
                        val snapshot = payload?.get("snapshot") as? Map<String, Any?>
                        if (appWidgetId == null || snapshot == null) {
                            result.error("INVALID_ARGUMENTS", "Missing appWidgetId/snapshot", null)
                        } else {
                            HomeWidgetStorage.syncWidgetSnapshot(applicationContext, appWidgetId, snapshot)
                            result.success(true)
                        }
                    }
                    "clearWidgetSnapshot" -> {
                        val appWidgetId = (call.arguments as? Map<*, *>)
                            ?.get("appWidgetId") as? Int
                        if (appWidgetId == null) {
                            result.error("INVALID_ARGUMENTS", "Missing appWidgetId", null)
                        } else {
                            HomeWidgetStorage.clearWidgetSnapshot(applicationContext, appWidgetId)
                            result.success(true)
                        }
                    }
                    "getPendingWidgetLaunch" -> {
                        val appWidgetId = pendingWidgetLaunchAppWidgetId
                        pendingWidgetLaunchAppWidgetId = null
                        result.success(appWidgetId)
                    }
                    "rescheduleRefresh" -> {
                        // 授权状态变化后按最新权限档位重排小组件刷新闹钟。
                        HomeWidgetStorage.rescheduleRefresh(applicationContext)
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EXAM_REMINDER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "reconcile" -> {
                        val payload = call.arguments as? Map<*, *>
                        val fires = payload?.get("fires") as? List<*>
                        val activeExamIds = (payload?.get("activeExamIds") as? List<*>)
                            ?.mapNotNull { it as? String }
                            ?.toSet()
                            ?: emptySet()
                        val activeFireKeys = if (payload?.containsKey("activeFireKeys") == true) {
                            (payload["activeFireKeys"] as? List<*>)
                                ?.mapNotNull { it as? String }
                                ?.toSet()
                                ?: emptySet()
                        } else {
                            null
                        }
                        if (fires != null) {
                            ExamReminderScheduler.reconcile(
                                applicationContext,
                                fires,
                                activeExamIds,
                                activeFireKeys,
                            )
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENTS", "Missing exam reminder fires", null)
                        }
                    }
                    "clear" -> {
                        ExamReminderScheduler.clear(applicationContext)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WEEKLY_REPORT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleNext" -> {
                        val payload = call.arguments as? Map<*, *>
                        val enabled = payload?.get("enabled") as? Boolean ?: false
                        val fireAtMillis = (payload?.get("fireAtMillis") as? Number)?.toLong() ?: 0L
                        val title = payload?.get("title") as? String ?: ""
                        val body = payload?.get("body") as? String ?: ""
                        WeeklyReportScheduler.scheduleNext(
                            applicationContext,
                            enabled,
                            fireAtMillis,
                            title,
                            body,
                        )
                        result.success(true)
                    }
                    "cancel" -> {
                        WeeklyReportScheduler.cancel(applicationContext)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SUPPORT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enqueueSystemDownload" -> {
                        val arguments = call.arguments as? Map<*, *>
                        val url = arguments?.get("url") as? String
                        val fileName = arguments?.get("fileName") as? String
                        val title = arguments?.get("title") as? String
                        val description = arguments?.get("description") as? String
                        if (url.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENTS", "Missing download url", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val downloadId = enqueueSystemDownload(
                                url = url,
                                fileName = fileName,
                                title = title,
                                description = description,
                            )
                            result.success(downloadId)
                        } catch (e: Exception) {
                            result.error("DOWNLOAD_ENQUEUE_FAILED", e.message, null)
                        }
                    }
                    "getSystemDownloadProgress" -> {
                        val arguments = call.arguments as? Map<*, *>
                        val downloadId = (arguments?.get("downloadId") as? Number)?.toLong()
                        if (downloadId == null) {
                            result.error("INVALID_ARGUMENTS", "Missing download id", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(querySystemDownloadProgress(downloadId))
                        } catch (e: Exception) {
                            result.error("DOWNLOAD_QUERY_FAILED", e.message, null)
                        }
                    }
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LAN_EDIT_CHANNEL)
            .also { lanEditChannel = it }
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startLanEditForeground" -> {
                        try {
                            startLanEditForegroundService()
                            result.success(true)
                        } catch (e: Exception) {
                            val tag = when (e) {
                                is SecurityException -> DiagnosticLogMessages.LOG_LAN_FOREGROUND_START_DENIED
                                else -> DiagnosticLogMessages.LOG_LAN_FOREGROUND_START_FAILED
                            }
                            Log.e("MainActivity", tag, e)
                            result.error(
                                "START_FOREGROUND_FAILED",
                                e.message,
                                e.javaClass.simpleName,
                            )
                        }
                    }
                    "stopLanEditForeground" -> {
                        stopLanEditForegroundService()
                        result.success(true)
                    }
                    "getPendingLanEditOpen" -> {
                        val pending = pendingOpenLanEdit
                        pendingOpenLanEdit = false
                        result.success(pending)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Debug-only deep links for adb / Android CLI automation.
     * Scheme: mikcb-debug://path?query=value
     * Only honored on non-release package ids (*.debug / *.profile).
     */
    private fun handleDebugDeepLinkIntent(intent: Intent) {
        if (!isDebugAutomationPackage()) {
            return
        }
        val action = intent.action ?: return
        if (action != Intent.ACTION_VIEW) {
            return
        }
        val data = intent.data ?: return
        if (data.scheme != "mikcb-debug") {
            return
        }
        // Prefer path-absolute form: mikcb-debug:///settings/live
        // (empty host). Host-based form mikcb-debug://settings/live is also
        // accepted for convenience.
        val host = data.host?.trim().orEmpty()
        val pathSegment = data.path
            ?.trim()
            .orEmpty()
            .removePrefix("/")
        val path = when {
            host.isEmpty() && pathSegment.isEmpty() -> "home"
            host.isEmpty() -> pathSegment
            pathSegment.isEmpty() -> host
            else -> "$host/$pathSegment"
        }.trim().removePrefix("/")
        if (path.isEmpty()) {
            return
        }
        val query = mutableMapOf<String, String>()
        for (name in data.queryParameterNames) {
            val value = data.getQueryParameter(name) ?: continue
            query[name] = value
        }
        pendingDebugRoute = mapOf(
            "path" to path,
            "query" to query,
        )
        notifyDebugRouteReceived()
    }

    private fun isDebugAutomationPackage(): Boolean {
        val packageName = applicationContext.packageName
        return packageName.endsWith(".debug") || packageName.endsWith(".profile")
    }

    private fun notifyDebugRouteReceived() {
        try {
            flutterChannel?.invokeMethod("onDebugRouteReceived", null)
        } catch (error: Exception) {
            Log.w("MainActivity", "notifyDebugRouteReceived failed", error)
        }
    }

    private fun handleExternalImportIntent(intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_VIEW && action != Intent.ACTION_SEND) return

        // Debug automation deep links share ACTION_VIEW with file imports.
        // Never open them as content URIs — that floods logcat with
        // FileNotFoundException: No content provider: mikcb-debug://...
        val dataScheme = intent.data?.scheme
        if (dataScheme == "mikcb-debug") {
            return
        }

        val uri = resolveImportUri(intent) ?: return
        if (uri.scheme == "mikcb-debug") {
            return
        }
        // 跨进程 ContentResolver I/O（getType/query/全量读文件）不能在主线程做：
        // 外部「打开方式」导入会先走重定向重建 Activity 并新建 FlutterEngine，
        // 同一主线程还要跑引擎冷启动，这里同步读大文件/慢 provider 必然 ANR。
        // 全部阻塞调用挪到后台线程，完成后回主线程落 pending 并通知 Dart。
        val requestSeq = ++externalImportRequestSeq
        val sharedType = intent.type
        Thread {
            val pending = try {
                loadExternalImportFromUri(uri, sharedType)
            } catch (e: Exception) {
                Log.w(
                    "MainActivity",
                    "${DiagnosticLogMessages.LOG_LOAD_EXTERNAL_IMPORT_FAILED}：$uri",
                    e,
                )
                null
            } ?: return@Thread
            runOnUiThread {
                if (requestSeq == externalImportRequestSeq) {
                    pendingExternalImport = pending
                    notifyExternalImportReceived()
                }
            }
        }.start()
    }

    /** [handleExternalImportIntent] 的后台线程部分：所有阻塞调用集中在这里，
     *  返回 null 表示该 URI 不是可导入内容（原有判定逻辑原样搬移）。 */
    private fun loadExternalImportFromUri(
        uri: Uri,
        sharedType: String?,
    ): PendingExternalImport? {
        val mimeType = sharedType?.takeIf { it.isNotBlank() }
            ?: contentResolver.getType(uri)
        val fileName = resolveImportDisplayName(uri)
        val bytes = readImportBytes(uri) ?: return null
        val kind = detectImportKind(fileName, mimeType, bytes) ?: return null

        return when (kind) {
            "ics", "backup" -> {
                val text = bytes.toString(Charsets.UTF_8)
                if (kind == "ics" && !text.contains("VCALENDAR", ignoreCase = true)) {
                    return null
                }
                if (kind == "backup" && !text.contains("\"mikcb\"")) {
                    return null
                }
                PendingExternalImport(kind = kind, fileName = fileName, textContent = text)
            }
            "spreadsheet" -> {
                val cachedFile = copyBytesToImportCache(bytes, fileName) ?: return null
                PendingExternalImport(
                    kind = kind,
                    fileName = fileName,
                    filePath = cachedFile.absolutePath,
                )
            }
            else -> null
        }
    }

    private fun resolveImportUri(intent: Intent): Uri? {
        return when (intent.action) {
            Intent.ACTION_SEND -> extractSendStreamUri(intent)
            else -> intent.data
        }
    }

    private fun extractSendStreamUri(intent: Intent): Uri? {
        // Plain-text shares use EXTRA_TEXT and have no stream URI. File shares (CSV, ICS,
        // JSON, XLSX, etc.) always attach EXTRA_STREAM regardless of MIME type.
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
    }

    private fun resolveImportDisplayName(uri: Uri): String {
        if (uri.scheme == ContentResolver.SCHEME_CONTENT) {
            try {
                contentResolver.query(
                    uri,
                    arrayOf(OpenableColumns.DISPLAY_NAME),
                    null,
                    null,
                    null,
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (index >= 0) {
                            val name = cursor.getString(index)?.trim().orEmpty()
                            if (name.isNotEmpty()) {
                                return name
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w("MainActivity", "${DiagnosticLogMessages.LOG_RESOLVE_IMPORT_DISPLAY_NAME_FAILED}：$uri", e)
            }
        }
        return uri.lastPathSegment?.substringAfterLast('/').orEmpty().ifBlank { "import" }
    }

    private fun readImportBytes(uri: Uri): ByteArray? {
        if (uri.scheme == "mikcb-debug") {
            return null
        }
        return try {
            contentResolver.openInputStream(uri)?.use { stream -> stream.readBytes() }
        } catch (e: Exception) {
            Log.e("MainActivity", "${DiagnosticLogMessages.LOG_READ_IMPORT_BYTES_FAILED}：$uri", e)
            null
        }
    }

    private fun detectImportKind(
        fileName: String,
        mimeType: String?,
        bytes: ByteArray,
    ): String? {
        val extension = fileName.substringAfterLast('.', "").lowercase(Locale.US)
        val normalizedMime = mimeType?.lowercase(Locale.US)
        val textPreview = if (bytes.size <= 65536) {
            bytes.toString(Charsets.UTF_8)
        } else {
            bytes.copyOf(65536).toString(Charsets.UTF_8)
        }

        when {
            extension == "ics" || normalizedMime?.startsWith("text/calendar") == true -> {
                return "ics"
            }
            extension == "mikcb" -> return "backup"
            extension == "json" || normalizedMime == "application/json" -> return "backup"
            extension == "csv" ||
                normalizedMime == "text/csv" ||
                normalizedMime == "text/comma-separated-values" -> {
                return "spreadsheet"
            }
            extension == "xlsx" ||
                normalizedMime ==
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" -> {
                return "spreadsheet"
            }
        }

        if (normalizedMime == "application/octet-stream" || normalizedMime == "*/*") {
            when (extension) {
                "ics" -> return "ics"
                "mikcb", "json" -> return "backup"
                "csv", "xlsx" -> return "spreadsheet"
            }
        }

        if (textPreview.contains("VCALENDAR", ignoreCase = true)) {
            return "ics"
        }
        if (textPreview.trimStart().startsWith("{") && textPreview.contains("\"mikcb\"")) {
            return "backup"
        }
        if (bytes.size >= 4 &&
            bytes[0] == 0x50.toByte() &&
            bytes[1] == 0x4B.toByte() &&
            (extension == "xlsx" || extension.isEmpty())
        ) {
            return "spreadsheet"
        }

        return null
    }

    private fun copyBytesToImportCache(bytes: ByteArray, fileName: String): File? {
        return try {
            val safeName = fileName.replace(Regex("[^a-zA-Z0-9._-]"), "_")
            val cacheRoot = File(cacheDir, "external_imports").apply { mkdirs() }
            val target = File(cacheRoot, "${System.currentTimeMillis()}_$safeName")
            target.outputStream().use { output -> output.write(bytes) }
            target
        } catch (e: Exception) {
            Log.e("MainActivity", DiagnosticLogMessages.LOG_CACHE_EXTERNAL_IMPORT_FAILED, e)
            null
        }
    }

    private fun notifyExternalImportReceived() {
        try {
            flutterChannel?.invokeMethod("onExternalImportReceived", null)
        } catch (_: Exception) {
        }
    }

    private fun handleWidgetLaunchIntent(intent: Intent?) {
        if (intent == null) return
        if (!intent.getBooleanExtra(TodayWidgetSupport.EXTRA_WIDGET_LAUNCH, false)) return
        val appWidgetId = intent.getIntExtra(
            TodayWidgetSupport.EXTRA_WIDGET_LAUNCH_APP_WIDGET_ID,
            Integer.MIN_VALUE,
        )
        if (appWidgetId == Integer.MIN_VALUE) return
        pendingWidgetLaunchAppWidgetId = appWidgetId
        notifyWidgetLaunchReceived()
    }

    private fun notifyWidgetLaunchReceived() {
        try {
            flutterChannel?.invokeMethod("onWidgetLaunchReceived", null)
        } catch (_: Exception) {
            // 冷启动时 Flutter 侧监听器尚未就绪：pending 已存，
            // 启动流程稍后会主动 drain getPendingWidgetLaunch。
        }
    }

    /** 今日课程类卡型的 widgetType → Provider 映射（与 resolveWidgetProvider 对齐）。 */
    private fun todayWidgetProviders(): List<Pair<String, Class<*>>> = listOf(
        "compact" to TodayCompactWidgetProvider::class.java,
        "mini_list" to TodayMiniListWidgetProvider::class.java,
        "medium" to TodayMediumWidgetProvider::class.java,
        "large" to TodayLargeWidgetProvider::class.java,
        "today_strip" to TodayStripWidgetProvider::class.java,
        "today_wide" to TodayWideWidgetProvider::class.java,
    )

    private fun listTodayWidgetInstances(): List<Map<String, Any?>> {
        val appWidgetManager = getSystemService(AppWidgetManager::class.java)
            ?: return emptyList()
        val bindings = WidgetBindingStore.allBindings(this)
        val instances = mutableListOf<Map<String, Any?>>()
        for ((widgetType, providerClass) in todayWidgetProviders()) {
            val ids = appWidgetManager.getAppWidgetIds(ComponentName(this, providerClass))
            for (appWidgetId in ids) {
                instances.add(
                    mapOf(
                        "appWidgetId" to appWidgetId,
                        "widgetType" to widgetType,
                        "boundProfileId" to bindings[appWidgetId],
                    )
                )
            }
        }
        return instances
    }

    private fun canRequestPinWidget(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return false
        }
        val appWidgetManager = getSystemService(AppWidgetManager::class.java)
        return appWidgetManager?.isRequestPinAppWidgetSupported == true
    }

    private fun requestPinWidget(widgetType: String): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return "unsupported"
        }
        val appWidgetManager = getSystemService(AppWidgetManager::class.java)
            ?: return "unsupported"
        if (!appWidgetManager.isRequestPinAppWidgetSupported) {
            return "unsupported"
        }
        val provider = resolveWidgetProvider(widgetType) ?: return "invalid_widget_type"
        return if (appWidgetManager.requestPinAppWidget(provider, null, null)) {
            "requested"
        } else {
            "failed"
        }
    }

    /** Android 12+ 需要用户在系统里授予「闹钟和提醒」权限才能精确闹钟。 */
    private fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return true
        }
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: return true
        return alarmManager.canScheduleExactAlarms()
    }

    /**
     * 跳转系统「闹钟和提醒」授权页。
     *
     * 返回状态字符串：launched 已跳授权页；fallback ROM 未处理该 action，
     * 已回退应用详情页（含闹钟和提醒开关）；not_required S 以下无需授权。
     */
    private fun requestScheduleExactAlarm(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return "not_required"
        }
        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            startActivity(intent)
            "launched"
        } catch (_: ActivityNotFoundException) {
            // 个别 ROM 未处理该 action 时退回应用详情页（含闹钟和提醒开关）。
            openAppDetailsSettings()
            "fallback"
        }
    }

    private fun resolveWidgetProvider(widgetType: String): ComponentName? {
        val providerClass = when (widgetType) {
            "compact" -> TodayCompactWidgetProvider::class.java
            "mini_list" -> TodayMiniListWidgetProvider::class.java
            "medium" -> TodayMediumWidgetProvider::class.java
            "large" -> TodayLargeWidgetProvider::class.java
            "stats_compact" -> StatsCompactWidgetProvider::class.java
            "stats_medium" -> StatsMediumWidgetProvider::class.java
            "today_strip" -> TodayStripWidgetProvider::class.java
            "stats_strip" -> StatsStripWidgetProvider::class.java
            "exam_card" -> ExamCountdownWidgetProvider::class.java
            "today_wide" -> TodayWideWidgetProvider::class.java
            else -> null
        } ?: return null
        return ComponentName(this, providerClass)
    }

    private fun enqueueSystemDownload(
        url: String,
        fileName: String?,
        title: String?,
        description: String?,
    ): Long {
        val downloadManager =
            getSystemService(Context.DOWNLOAD_SERVICE) as? DownloadManager
                ?: throw IllegalStateException("DownloadManager unavailable")
        val resolvedFileName = sanitizeDownloadFileName(
            fileName?.takeIf { it.isNotBlank() }
                ?: URLUtil.guessFileName(url, null, "application/vnd.android.package-archive")
        )
        cleanupManagedUpdateDownloads(downloadManager)
        val request = DownloadManager.Request(Uri.parse(url)).apply {
            setMimeType("application/vnd.android.package-archive")
            setTitle(title?.takeIf { it.isNotBlank() } ?: resolvedFileName)
            if (!description.isNullOrBlank()) {
                setDescription(description)
            }
            setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
            )
            setVisibleInDownloadsUi(true)
            setAllowedOverMetered(true)
            setAllowedOverRoaming(true)
            setDestinationInExternalPublicDir(
                Environment.DIRECTORY_DOWNLOADS,
                resolvedFileName
            )
        }
        val downloadId = downloadManager.enqueue(request)
        rememberManagedUpdateDownload(downloadId)
        return downloadId
    }

    private fun querySystemDownloadProgress(downloadId: Long): Map<String, Any?> {
        val downloadManager =
            getSystemService(Context.DOWNLOAD_SERVICE) as? DownloadManager
                ?: throw IllegalStateException("DownloadManager unavailable")
        val query = DownloadManager.Query().setFilterById(downloadId)
        downloadManager.query(query).use { cursor ->
            if (!cursor.moveToFirst()) {
                return mapOf(
                    "status" to "unknown",
                    "downloadedBytes" to 0L,
                    "totalBytes" to -1L,
                    "reason" to null,
                )
            }

            val status = when (
                cursor.getInt(
                    cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS),
                )
            ) {
                DownloadManager.STATUS_PENDING -> "pending"
                DownloadManager.STATUS_RUNNING -> "running"
                DownloadManager.STATUS_PAUSED -> "paused"
                DownloadManager.STATUS_SUCCESSFUL -> "successful"
                DownloadManager.STATUS_FAILED -> "failed"
                else -> "unknown"
            }
            val downloadedBytes = cursor.getLong(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR),
            )
            val totalBytes = cursor.getLong(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES),
            )
            val reasonIndex = cursor.getColumnIndex(DownloadManager.COLUMN_REASON)
            val reason = if (reasonIndex >= 0) cursor.getInt(reasonIndex) else null
            return mapOf(
                "status" to status,
                "downloadedBytes" to downloadedBytes,
                "totalBytes" to totalBytes,
                "reason" to reason,
            )
        }
    }

    private fun sanitizeDownloadFileName(fileName: String): String {
        val trimmed = fileName.trim().ifEmpty { "mikcb_update.apk" }
        val normalized = trimmed.replace(Regex("[\\\\/:*?\"<>|]"), "_")
        return if (normalized.lowercase().endsWith(".apk")) {
            normalized
        } else {
            "$normalized.apk"
        }
    }

    private fun cleanupManagedUpdateDownloads(downloadManager: DownloadManager) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val trackedIds = prefs.getStringSet(KEY_MANAGED_UPDATE_DOWNLOAD_IDS, emptySet()).orEmpty()
        val ids = trackedIds.mapNotNull { it.toLongOrNull() }.toLongArray()
        if (ids.isNotEmpty()) {
            runCatching {
                downloadManager.remove(*ids)
            }
        }
        prefs.edit().remove(KEY_MANAGED_UPDATE_DOWNLOAD_IDS).apply()
    }

    private fun rememberManagedUpdateDownload(downloadId: Long) {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putStringSet(KEY_MANAGED_UPDATE_DOWNLOAD_IDS, setOf(downloadId.toString()))
            .apply()
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
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            if (granted) {
                // Retry any reminder whose alarm fired while notification
                // permission was denied, without rebuilding past fires in
                // Flutter (which could duplicate successful notifications).
                ExamReminderScheduler.handleBootReschedule(applicationContext)
            }
            permissionResult?.success(granted)
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
            Log.w("MainActivity", DiagnosticLogMessages.LOG_OPEN_NOTIFICATION_SETTINGS_FAILED, e)
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
        val brand = Build.BRAND.lowercase(Locale.ROOT)
        val intents = mutableListOf<Intent>()

        when (brand) {
            "xiaomi", "poco", "redmi" -> {
                intents += Intent().apply {
                    component = ComponentName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.autostart.AutoStartManagementActivity"
                    )
                }
                intents += Intent("miui.intent.action.APP_PERM_EDITOR").apply {
                    component = ComponentName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.permissions.PermissionsEditorActivity"
                    )
                    putExtra("extra_pkgname", packageName)
                    putExtra("package_name", packageName)
                }
            }
            "oppo", "realme", "oneplus" -> {
                intents += Intent().apply {
                    component = ComponentName(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                    )
                }
                intents += Intent().apply {
                    component = ComponentName(
                        "com.oppo.safe",
                        "com.oppo.safe.permission.startup.StartupAppListActivity"
                    )
                }
                intents += Intent().apply {
                    component = ComponentName(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.startupapp.StartupAppListActivity"
                    )
                }
                if (brand == "oneplus") {
                    intents += Intent().apply {
                        component = ComponentName(
                            "com.oneplus.security",
                            "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"
                        )
                    }
                }
            }
            "vivo" -> {
                intents += Intent().apply {
                    component = ComponentName(
                        "com.iqoo.secure",
                        "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"
                    )
                }
                intents += Intent().apply {
                    component = ComponentName(
                        "com.vivo.permissionmanager",
                        "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
                    )
                }
            }
            "huawei", "honor" -> {
                intents += Intent().apply {
                    component = ComponentName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                    )
                }
                intents += Intent().apply {
                    component = ComponentName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.optimize.process.ProtectActivity"
                    )
                }
            }
            "samsung" -> {
                intents += Intent().apply {
                    component = ComponentName(
                        "com.samsung.android.lool",
                        "com.samsung.android.sm.ui.battery.BatteryActivity"
                    )
                }
                intents += Intent().apply {
                    component = ComponentName(
                        "com.samsung.android.lool",
                        "com.samsung.android.sm.battery.ui.BatteryActivity"
                    )
                }
            }
            "asus" -> {
                intents += Intent().apply {
                    component = ComponentName(
                        "com.asus.mobilemanager",
                        "com.asus.mobilemanager.autostart.AutoStartActivity"
                    )
                }
                intents += Intent().apply {
                    component = ComponentName(
                        "com.asus.mobilemanager",
                        "com.asus.mobilemanager.powersaver.PowerSaverSettings"
                    )
                }
            }
        }

        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return
            } catch (_: Exception) {
                // Try the next screen.
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
            Log.w("MainActivity", DiagnosticLogMessages.LOG_OPEN_APP_DETAILS_FAILED, e)
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
                    "${Environment.DIRECTORY_PICTURES}/${getString(R.string.pictures_folder_name)}"
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
            getString(R.string.payment_qr_description)
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
            Log.w("MainActivity", DiagnosticLogMessages.LOG_INSPECT_PROMOTED_PERMISSION_FAILED, e)
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
                getString(R.string.notification_channel_live_update_name),
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = getString(R.string.notification_channel_live_update_desc)
            }
            notificationManager?.createNotificationChannel(channel)
            ExamReminderScheduler.ensureChannel(this)
        }
    }

    private fun startLiveUpdateService(data: Map<String, Any>) {
        try {
            UmengDiagnosticReporter.record(
                context = applicationContext,
                category = "live_update_start_requested",
                message = DiagnosticLogMessages.LIVE_UPDATE_START_REQUESTED,
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
                message = DiagnosticLogMessages.LIVE_UPDATE_START_FAILED_CHANNEL,
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
            message = DiagnosticLogMessages.LIVE_UPDATE_STOP_REQUESTED,
        )
        stopService(Intent(this, LiveUpdateService::class.java))
        // Re-arm the next future trigger instead of cancelling it outright.
        // Flutter calls stopLiveUpdate on every refresh without an active
        // course; dropping the exact alarm here would leave only the 15-min
        // WorkManager backup, delaying the next before-class reminder.
        // (reschedule cancels the old alarm itself and honors holiday /
        // suspension state; with a cleared snapshot it is a no-op.)
        LiveUpdateScheduler.reschedule(applicationContext, allowImmediateStart = false)
    }

    private fun startLanEditForegroundService() {
        val intent = LanEditForegroundService.buildStartIntent(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopLanEditForegroundService() {
        stopService(
            Intent(this, LanEditForegroundService::class.java).apply {
                action = LanEditForegroundService.ACTION_STOP
            },
        )
    }

    private fun handleLanEditIntent(intent: Intent?) {
        if (intent?.getBooleanExtra(LanEditForegroundService.EXTRA_OPEN_LAN_EDIT, false) != true) {
            return
        }
        pendingOpenLanEdit = true
        intent.removeExtra(LanEditForegroundService.EXTRA_OPEN_LAN_EDIT)
        try {
            lanEditChannel?.invokeMethod("onLanEditNotificationTapped", null)
        } catch (_: Exception) {
        }
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
            Log.w("MainActivity", DiagnosticLogMessages.LOG_UPDATE_RECENTS_VISIBILITY_FAILED, e)
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

    private fun isAutoStartEnabled(): Boolean {
        // 检测逻辑统一下沉到 UmengDiagnosticReporter.resolveAutoStartStatus：
        // 引导页与诊断上下文共用同一实现，unknown（无法确定）仍乐观视为开启。
        return UmengDiagnosticReporter.resolveAutoStartStatus(this) != "denied"
    }

    private fun isKeepAliveAccessibilityEnabled(): Boolean {
        return KeepAliveAccessibilityStatus.isEnabled(this)
    }

    private fun readDisplayCornerRadiusDp(): Double {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val insets = window.decorView.rootWindowInsets
            val corner = insets?.getRoundedCorner(android.view.RoundedCorner.POSITION_TOP_LEFT)
            val radiusPx = corner?.radius ?: 0
            if (radiusPx > 0) {
                return radiusPx.toDouble() / resources.displayMetrics.density.toDouble()
            }
        }
        return 28.0
    }

    /**
     * Soft edge-arrival tick (CLOCK_TICK). Kept for optional native callers;
     * Dart currently uses Flutter [HapticFeedback.selectionClick] for intensity.
     */
    private fun performEdgeHapticTick(): String {
        val decorView = window?.decorView
        if (decorView != null) {
            @Suppress("DEPRECATION")
            val feedbackFlags =
                HapticFeedbackConstants.FLAG_IGNORE_VIEW_SETTING or
                    HapticFeedbackConstants.FLAG_IGNORE_GLOBAL_SETTING
            if (decorView.performHapticFeedback(
                    HapticFeedbackConstants.CLOCK_TICK,
                    feedbackFlags,
                )
            ) {
                return "view_clock_tick"
            }
            if (decorView.performHapticFeedback(
                    HapticFeedbackConstants.CONTEXT_CLICK,
                    feedbackFlags,
                )
            ) {
                return "view_context_click"
            }
        }

        val vibrator = resolveDefaultVibrator()
        if (vibrator != null && vibrator.hasVibrator()) {
            // Soft tick only — avoid long/high-amplitude oneshots.
            val durationMs = 8L
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val amplitude =
                    if (vibrator.hasAmplitudeControl()) {
                        48
                    } else {
                        VibrationEffect.DEFAULT_AMPLITUDE
                    }
                vibrator.vibrate(VibrationEffect.createOneShot(durationMs, amplitude))
                return "vibrator_oneshot_${durationMs}ms"
            }
            @Suppress("DEPRECATION")
            vibrator.vibrate(durationMs)
            return "vibrator_legacy_${durationMs}ms"
        }

        return "no_haptic"
    }

    private fun resolveDefaultVibrator(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager =
                getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            manager?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        FairMemoryAdapter.detachFlutterEngine()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}

internal fun liveShouldMirrorStatusIntoMiuiFocusHint(
    sdkInt: Int,
    shouldPromote: Boolean,
): Boolean {
    return !(sdkInt >= 36 && shouldPromote)
}
