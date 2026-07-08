package com.mutx163.qingyu

import android.Manifest
import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.DownloadManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.appwidget.AppWidgetManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.provider.OpenableColumns
import android.content.pm.PackageManager
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
import android.webkit.URLUtil
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.Locale
import java.io.File
import java.util.Calendar
import kotlin.math.ceil

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "com.mutx163.qingyu/miui_live"
        private const val SYSTEM_UI_CHANNEL = "com.mutx163.qingyu/system_ui"
        private const val UMENG_CHANNEL = "com.mutx163.qingyu/umeng_analytics"
        private const val HOME_WIDGET_CHANNEL = "com.mutx163.qingyu/home_widget"
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
    private var pendingOpenLanEdit = false
    private var flutterChannel: MethodChannel? = null
    private var lanEditChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        window.setBackgroundDrawable(
            SplashLayerDrawable(
                this,
                applicationInfo.loadLabel(packageManager),
            ),
        )
        installSplashScreen()
        super.onCreate(savedInstanceState)
        handleExternalImportIntent(intent)
        handleLanEditIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleExternalImportIntent(intent)
        handleLanEditIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        applyPersistedHideFromRecents()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannels()

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

    private fun handleExternalImportIntent(intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_VIEW && action != Intent.ACTION_SEND) return

        val uri = resolveImportUri(intent) ?: return
        val mimeType = intent.type?.takeIf { it.isNotBlank() }
            ?: contentResolver.getType(uri)
        val fileName = resolveImportDisplayName(uri)
        val bytes = readImportBytes(uri) ?: return
        val kind = detectImportKind(fileName, mimeType, bytes) ?: return

        val pending = when (kind) {
            "ics", "backup" -> {
                val text = bytes.toString(Charsets.UTF_8)
                if (kind == "ics" && !text.contains("VCALENDAR", ignoreCase = true)) {
                    return
                }
                if (kind == "backup" && !text.contains("\"mikcb\"")) {
                    return
                }
                PendingExternalImport(kind = kind, fileName = fileName, textContent = text)
            }
            "spreadsheet" -> {
                val cachedFile = copyBytesToImportCache(bytes, fileName) ?: return
                PendingExternalImport(
                    kind = kind,
                    fileName = fileName,
                    filePath = cachedFile.absolutePath,
                )
            }
            else -> return
        }

        pendingExternalImport = pending
        Log.d(
            "MainActivity",
            "${DiagnosticLogMessages.LOG_EXTERNAL_IMPORT_QUEUED} kind=$kind file=$fileName bytes=${bytes.size}",
        )
        notifyExternalImportReceived()
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

    private fun resolveWidgetProvider(widgetType: String): ComponentName? {
        val providerClass = when (widgetType) {
            "compact" -> TodayCompactWidgetProvider::class.java
            "mini_list" -> TodayMiniListWidgetProvider::class.java
            "medium" -> TodayMediumWidgetProvider::class.java
            "large" -> TodayLargeWidgetProvider::class.java
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
        LiveUpdateScheduler.cancelPendingTriggers(applicationContext)
        stopService(Intent(this, LiveUpdateService::class.java))
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
        // 1. 尝试 AppOps 反射检测（小米/OPPO/Vivo/一加 等）
        val appOpsResult = checkAutoStartViaAppOps()
        if (appOpsResult != null) return appOpsResult

        // 2. 回退到电池优化检测（三星/华为/荣耀/通用）
        val batteryResult = checkAutoStartViaBattery()
        if (batteryResult != null) return batteryResult

        // 3. 兜底：乐观默认
        return true
    }

    /**
     * 通过 AppOps 反射检测自启动状态。
     * 适用：小米 (MIUI)、OPPO (ColorOS)、Vivo、一加 (OxygenOS) 等。
     * 不适用时返回 null（如 Pixel 等原生 Android）。
     */
    private fun checkAutoStartViaAppOps(): Boolean? {
        return try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val method = AppOpsManager::class.java.getMethod(
                "checkOpNoThrow",
                Int::class.javaPrimitiveType,
                Int::class.javaPrimitiveType,
                String::class.java
            )
            // OP_AUTO_START = 10008 (小米/OPPO/Vivo 等厂商通用)
            val result = method.invoke(
                appOps, 10008, android.os.Process.myUid(), packageName
            ) as Int
            when (result) {
                AppOpsManager.MODE_ALLOWED -> true
                AppOpsManager.MODE_IGNORED,
                AppOpsManager.MODE_ERRORED -> false
                else -> null // MODE_DEFAULT 等，说明此 OP 不适用于当前设备
            }
        } catch (_: Exception) {
            null
        }
    }

    /**
     * 通过电池优化状态间接推断。
     * 适用：三星（sleeping apps）、华为/荣耀（EMUI）等使用电池策略限制后台的厂商。
     * 对于 Pixel 等原生设备也适用（但通常不需要自启动权限）。
     */
    private fun checkAutoStartViaBattery(): Boolean? {
        return try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            powerManager?.isIgnoringBatteryOptimizations(packageName)
        } catch (_: Exception) {
            null
        }
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
}

internal fun liveShouldMirrorStatusIntoMiuiFocusHint(
    sdkInt: Int,
    shouldPromote: Boolean,
): Boolean {
    return !(sdkInt >= 36 && shouldPromote)
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
    private var lastTickerStage: String? = null
    private var validateAgainstSchedule = true

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return try {
            val quickActionResult = when (intent?.action) {
                ACTION_ENABLE_SILENT_MODE -> {
                    readQuickActionTimingExtra(intent)
                    handleBeforeClassQuickAction(enableDoNotDisturb = false)
                    START_NOT_STICKY
                }
                ACTION_ENABLE_DO_NOT_DISTURB -> {
                    readQuickActionTimingExtra(intent)
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

    private fun buildBeforeClassQuickAction(): Notification.Action? {
        val (action, label) = when (beforeClassQuickAction) {
            "silent" -> ACTION_ENABLE_SILENT_MODE to getString(R.string.action_enable_silent)
            "do_not_disturb" -> ACTION_ENABLE_DO_NOT_DISTURB to getString(R.string.action_enable_dnd)
            else -> return null
        }
        val pendingIntent = PendingIntent.getService(
            this,
            action.hashCode(),
            Intent(this, LiveUpdateService::class.java).apply {
                this.action = action
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

    private fun handleBeforeClassQuickAction(enableDoNotDisturb: Boolean) {
        val restoreAtMillis = endAtMillis.takeIf { it > 0L }
            ?: (System.currentTimeMillis() + 2 * 60 * 60_000L)
        val applied = if (enableDoNotDisturb) {
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
        UmengDiagnosticReporter.record(
            context = applicationContext,
            category = "live_update_before_class_quick_action",
            message = DiagnosticLogMessages.LIVE_UPDATE_BEFORE_CLASS_QUICK_ACTION,
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
        canvas.drawText(displayText, textStartX, baseline, textPaint)
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
            buildBeforeClassQuickAction()?.let(builder::addAction)
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
        val isActuallyPromotable = when {
            isDuringClassStatusBar || !shouldPromote -> false
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
            !hasNotificationPermissionCompat(this) -> getString(R.string.debug_notification_permission_off)
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
                ),
                "notification" to linkedMapOf(
                    "shouldPromote" to shouldPromote,
                    "showStandardNotification" to showStandardNotification,
                    "isDuringClassStatusBar" to isDuringClassStatusBar,
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
