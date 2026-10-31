package com.mutx163.qingyu.pages.about

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.DiagnosticLogMessages
import com.mutx163.qingyu.app.DiagnosticsLogHost
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.infra.AppLogStore
import com.mutx163.qingyu.infra.AppUpdateCheckResult
import com.mutx163.qingyu.infra.buildDownloadUrl
import com.mutx163.qingyu.infra.recordingEnabledFromPrefs
import com.mutx163.qingyu.infra.releasesApiUrl
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import com.mutx163.qingyu.isTrustedSystemDownloadUrl
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL

/**
 * 版本更新页的**宿主装配层**：把 [AboutUpdatePage] / [AdvancedOptionsPage] 接到真实的
 * 检查更新（GitHub releases API）、系统下载（DownloadManager）、设置读写与镜像测速上。
 *
 * ## 分工
 *
 * - 纯逻辑（判据 / 解析 / 格式化）：见 main 层同类文件与 `AboutUpdateLogic`；
 * - 本文件只做「副作用接线」：网络、文件系统、DownloadManager、Intent、prefs。
 *
 * ## 诚实边界（真机验收前别当成全链路）
 *
 * - **应用内下载 + 安装**：传输交给系统 `DownloadManager`，下载完成后**本层自己**
 *   用 `ApkDigest` 校验 SHA-256，再把 `DownloadManager` 返回的 content Uri 交给系统安装器
 *   （`FILE_PROVIDER` 白名单与 scoped storage 都不参与，故不再依赖任何额外 manifest 声明）。
 *   `AndroidManifest.xml:143-151` 的 FileProvider 是给「日志导出 / ICS / 传输包」用的，与本页无关。
 *   仍与 Dart 有差异：Dart 用 `AppUpdateDownloadController` 在应用内自带进度条与换源重试，
 *   这里复用系统下载器的进度与通知；`fallbackUrl` 换源重试未移植。
 * - GitHub releases API 匿名请求有速率限制；失败按「检查更新失败」画（可重试）。
 * - 镜像测速用 HEAD 请求测耗时；结果只用于推荐，不改变下载地址信任根。
 * - 检查失败 / 下载入队失败 / 摘要不符等关键事件会按「记录应用日志」开关落盘（见 `appendLog`）。
 */
@Composable
fun AboutUpdateHostPage(
    onBack: () -> Unit,
    /**
     * 壳内推页出口（可选）。壳里传的应当是 `{ onOpenPage(it) }`，
     * 这样「打开日志页」走到真正的 `h.log` 分支（同一个页面实例栈，返回键行为与 Dart 一致）。
     *
     * 不传时降级为**页内嵌日志查看器**（同一份真数据、真交互），而不是留一个死行。
     */
    onOpenPage: ((String) -> Unit)? = null,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val store = remember(context) { TimetableStore(PrefsKeyValueStore(context)) }
    val packageInfo = remember(context) { readHostPackageInfo(context) }

    var settings by remember { mutableStateOf(AppUpdateSettings.fromJson(store.loadSettingsJson())) }
    var result by remember { mutableStateOf<AppUpdateCheckResult?>(null) }
    var checking by remember { mutableStateOf(packageInfo != null) }
    var download by remember { mutableStateOf<AboutUpdateDownloadUi?>(null) }
    var showAdvanced by remember { mutableStateOf(false) }
    var probing by remember { mutableStateOf(false) }
    var probeStates by remember { mutableStateOf<Map<MirrorPreset, DownloadProbeResult>>(emptyMap()) }
    var cancelPolling by remember { mutableStateOf(false) }
    // 正在轮询的系统下载任务（取消时要 remove 它，不然「取消」只停了 UI、APK 继续下）。
    var activeDownload by remember { mutableStateOf<Pair<DownloadManager, Long>?>(null) }
    // 没有壳出口时的页内日志查看器（真实 DiagnosticsLogHost，MERGED 源）。
    var showLogs by remember { mutableStateOf(false) }
    // 「记录应用日志」开关的真值（IO 线程读一次；见 [appendLog]）。
    var loggingEnabled by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        loggingEnabled = withContext(Dispatchers.IO) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            recordingEnabledFromPrefs(
                settingsJson = prefs.getString("flutter.timetable_settings", null),
                profilesJson = prefs.getString("flutter.timetable_profiles", null),
                activeProfileId = prefs.getString("flutter.active_timetable_profile_id", null),
            )
        }
    }

    fun persist(updated: AppUpdateSettings) {
        settings = updated
        runCatching { store.saveSettingsPatch(updated.toPatch()) }
    }

    /**
     * 更新链路的关键事件落盘（Dart `update_check_controller.dart:56 AppLogService.instance.warn`
     * / 下载失败分支同样会写）。**门控与 Dart 一致**：只有用户打开「记录应用日志」才写，
     * 关闭时一条都不落——隐私口径不能因为换了个壳就松掉。
     *
     * 门控值在 IO 线程算一次缓存住（见上面的 `LaunchedEffect`），
     * 避免每个事件都在主线程解析两份设置 JSON。
     */
    fun appendLog(level: String, category: String, message: String) {
        if (!loggingEnabled) return
        AppLogStore.append(level = level, category = category, message = message)
    }

    fun runCheck() {
        val info = packageInfo ?: run { checking = false; return }
        checking = true
        scope.launch {
            val text = withContext(Dispatchers.IO) { fetchReleasesJson() }
            val outcome = parseGithubResponses(info.version, text, settings.includePrerelease)
            result = outcome
            checking = false
            if (outcome == null) {
                appendLog("warn", UPDATE_LOG_CATEGORY_CHECK, UPDATE_LOG_CHECK_FAILED)
            }
        }
    }

    LaunchedEffect(packageInfo != null, settings.includePrerelease) {
        if (packageInfo != null) runCheck() else checking = false
    }

    fun toast(msg: String) = Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()

    fun openUrl(url: String?) {
        val trimmed = url?.trim().orEmpty()
        if (trimmed.isEmpty()) return
        runCatching {
            context.startActivity(
                Intent(Intent.ACTION_VIEW, Uri.parse(trimmed))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    /**
     * 下载完成后的**校验 + 装包**（Dart `app_update_service.downloadAndInstallUpdate` 的等价段）。
     *
     * 三个分支必须分开：摘要不符 / 算出不来 / 安装器打不开，各自的用户提示不同，
     * 不能都糊成一句「下载失败」。
     *
     * **suspend**：摘要要读完整个 APK（上百 MB），必须在 IO 线程算，
     * 不能挂在主线程（否则装包前的十几秒会卡住整个 UI）。调用方在 `scope.launch` 里。
     */
    suspend fun finishDownload(manager: DownloadManager, id: Long, expectedApkSha256: String?) {
        val uri = runCatching { manager.getUriForDownloadedFile(id) }.getOrNull()
        val actual = uri?.let { downloadUri ->
            withContext(Dispatchers.IO) {
                runCatching {
                    context.contentResolver.openInputStream(downloadUri)?.use { sha256Hex(it) }
                }.getOrNull()
            }
        }
        when (apkDigestVerdict(expectedApkSha256, actual)) {
            ApkDigestVerdict.MATCH, ApkDigestVerdict.NOT_DECLARED -> Unit
            ApkDigestVerdict.MISMATCH -> {
                runCatching { manager.remove(id) }
                toast(AboutUpdatePageStrings.hashMismatch)
                appendLog("error", UPDATE_LOG_CATEGORY_DOWNLOAD, UPDATE_LOG_HASH_MISMATCH)
                return
            }
            ApkDigestVerdict.UNVERIFIABLE -> {
                runCatching { manager.remove(id) }
                toast(AboutUpdatePageStrings.sha256Unverified)
                appendLog("error", UPDATE_LOG_CATEGORY_DOWNLOAD, UPDATE_LOG_SHA_UNVERIFIED)
                return
            }
        }
        if (uri == null) {
            toast(AboutUpdatePageStrings.openInstallerFailed("no-uri"))
            return
        }
        // 用系统下载器给的 content Uri 直接拉起安装器：不需要 FileProvider 白名单，
        // 也不会因为「下载到的文件在 Downloads 里」而被 scoped storage 卡住。
        val install = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val launched = runCatching { context.startActivity(install) }.isSuccess
        if (launched) {
            toast(AboutUpdatePageStrings.installReady)
        } else {
            toast(AboutUpdatePageStrings.openInstallerFailed("no-activity"))
            appendLog("warn", UPDATE_LOG_CATEGORY_DOWNLOAD, UPDATE_LOG_INSTALLER_FAILED)
        }
    }

    /** 真取消：先把系统下载任务 remove 掉，再停 UI 轮询（Dart `_cancelDownload` 等价物）。 */
    fun cancelDownload() {
        cancelPolling = true
        val active = activeDownload
        if (active != null) {
            runCatching { active.first.remove(active.second) }
        }
        activeDownload = null
        download = null
    }

    /**
     * 下载更新包并**校验后**拉起安装器。
     *
     * 与 Dart 的分工差异（诚实登记，见报告 P1-3）：
     * 传输仍交给系统 `DownloadManager`（它负责断点续传/通知/免流量策略），
     * 但**下载完成后由本函数自己算 SHA-256**：元数据声明了摘要就必须一致，
     * 不一致或算不出来一律拒绝安装（Dart `update_download_hash_mismatch` /
     * `update_sha256_unverified_install_refused` 两个错误码的等价物）。
     * 装包用 `DownloadManager` 返回的 content Uri 直接拉起安装器，不再需要 FileProvider 白名单。
     *
     * @param url 直连地址（不可信地址会被转到浏览器，与 Dart「不信任就不下」同义）
     * @param expectedApkSha256 发布元数据里的 sha256；null = 没声明
     */
    fun startDownload(url: String?, expectedApkSha256: String? = null) {
        val trimmed = url?.trim().orEmpty()
        if (trimmed.isEmpty()) return
        if (!isTrustedSystemDownloadUrl(trimmed)) {
            openUrl(trimmed)
            return
        }
        val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as? DownloadManager
        if (manager == null) {
            toast(AboutUpdatePageStrings.systemDownloaderFailed)
            return
        }
        val fileName = "mikcb_update_${System.currentTimeMillis()}.apk"
        val request = DownloadManager.Request(Uri.parse(trimmed)).apply {
            setMimeType("application/vnd.android.package-archive")
            setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName)
        }
        val id = runCatching { manager.enqueue(request) }.getOrNull()
        if (id == null) {
            toast(AboutUpdatePageStrings.systemDownloaderFailed)
            appendLog("warn", UPDATE_LOG_CATEGORY_DOWNLOAD, UPDATE_LOG_DOWNLOAD_ENQUEUE_FAILED)
            return
        }
        toast(AboutUpdatePageStrings.systemDownloaderQueued)
        cancelPolling = false
        activeDownload = manager to id
        scope.launch {
            download = AboutUpdateDownloadUi(downloadedBytes = 0, totalBytes = null)
            while (true) {
                if (cancelPolling) {
                    download = null
                    return@launch
                }
                val progress = withContext(Dispatchers.IO) { queryDownload(manager, id) }
                if (progress == null) {
                    download = null
                    break
                }
                download = AboutUpdateDownloadUi(
                    downloadedBytes = progress.downloadedBytes,
                    totalBytes = progress.totalBytes.takeIf { it > 0 },
                )
                if (progress.status == DownloadManager.STATUS_SUCCESSFUL) {
                    download = null
                    finishDownload(manager, id, expectedApkSha256)
                    break
                }
                if (progress.status == DownloadManager.STATUS_FAILED) {
                    download = null
                    toast(AboutUpdatePageStrings.systemDownloaderFailed)
                    appendLog("warn", UPDATE_LOG_CATEGORY_DOWNLOAD, UPDATE_LOG_DOWNLOAD_FAILED)
                    break
                }
                delay(500)
            }
            activeDownload = null
        }
    }

    fun probeMirrors() {
        val release = result?.latestRelease ?: return
        val original = release.downloadUrl ?: return
        probing = true
        scope.launch {
            val candidates = buildMirrorPresetCandidates(settings.mirrorUrlPrefix)
            val collected = LinkedHashMap<MirrorPreset, DownloadProbeResult>()
            for ((preset, prefix) in candidates) {
                val probeUrl = buildDownloadUrl(original, com.mutx163.qingyu.infra.AppUpdateDownloadSource.MIRROR, prefix)
                collected[preset] = withContext(Dispatchers.IO) { probeUrlHead(probeUrl) }
            }
            probeStates = collected
            probing = false
            resolveRecommendedMirrorPreset(collected)?.let { recommended ->
                if (recommended != settings.mirrorPreset) persist(settings.copy(mirrorPreset = recommended))
            }
        }
    }

    // 页内日志查看器优先：从「高级选项 → 打开日志页」进来时，高级选项的状态要留着，
    // 返回时还在原位（Dart 是 push 一层路由，语义一致）。
    if (showLogs) {
        DiagnosticsLogHost(onBack = { showLogs = false })
    } else if (showAdvanced) {
        AdvancedOptionsPage(
            onBack = { showAdvanced = false },
            settings = settings,
            result = result,
            probeStates = probeStates,
            probing = probing,
            onPromptEnabledChange = { persist(settings.copy(promptEnabled = it)) },
            onIncludePrereleaseChange = { persist(settings.copy(includePrerelease = it)) },
            onDownloadChannelChange = { persist(settings.copy(downloadChannel = it)) },
            onUseSystemDownloaderChange = { persist(settings.copy(useSystemDownloader = it)) },
            onMirrorPresetChange = { persist(settings.copy(mirrorPreset = it)) },
            onProbeMirrors = { probeMirrors() },
            // 自定义镜像地址：归一化后写设置（Dart `_editMirrorUrlPrefix`，:2259-2288）。
            onMirrorPrefixSubmit = { raw ->
                val normalized = normalizeMirrorUrlPrefix(raw)
                if (raw.isNotEmpty() && normalized == null) {
                    // 渲染层已经拦过一次；这里兜住「万一」——不写非法值。
                    toast(AboutUpdatePageStrings.mirrorPrefixInvalid)
                } else {
                    persist(settings.copy(mirrorUrlPrefix = normalized ?: ""))
                    toast(AboutUpdatePageStrings.mirrorSaved)
                }
            },
            // 「打开日志页」：Dart 是真 push 日志查看器（about_screen.dart:1246）。
            // 壳给了出口就走壳（h.log，与其它入口同一个实例栈），没给就页内嵌同一个真宿主。
            onOpenDiagnostics = {
                val openPage = onOpenPage
                if (openPage != null) openPage("h.log") else showLogs = true
            },
        )
    } else {
        AboutUpdatePage(
            onBack = onBack,
            packageInfoAvailable = packageInfo != null,
            checking = checking,
            result = result,
            settings = settings,
            appName = packageInfo?.appName.orEmpty(),
            download = download,
            onRefresh = { runCheck() },
            onOpenAdvancedOptions = { showAdvanced = true },
            onOpenUrl = { openUrl(it) },
            // 应用内下载 = 系统下载器传输 + 本函数自算 SHA-256 + 拉起安装器（见 [startDownload] KDoc）。
            // 绝不丢弃 expectedApkSha256：Dart 那条「摘要不符就拒绝安装」的判据必须跟着搬过来。
            onInAppDownload = { url, expectedApkSha256, _ /* fallbackUrl */ ->
                startDownload(url, expectedApkSha256)
            },
            onSystemDownload = { startDownload(it) },
            onSystemDownloadUnavailable = { toast(AboutUpdatePageStrings.systemDownloaderFailed) },
            onCancelDownload = { cancelDownload() },
        )
    }
}

/**
 * 更新链路落盘用的分类与消息（Dart `home_update_check_failed` 等事件的等价物）。
 *
 * 消息正文（中文）集中登记在 `com.mutx163.qingyu.DiagnosticLogMessages`：这些字串只进
 * logcat 与本地诊断日志、不上屏，属于「内部日志」而不是界面文案；放在渲染层源集里
 * 会被 i18n 棘轮当作待翻译的中文字面量计入（2026-10-29 质量审核发现并搬走）。
 */
private const val UPDATE_LOG_CATEGORY_CHECK = "update_check"
private const val UPDATE_LOG_CATEGORY_DOWNLOAD = "update_download"
private const val UPDATE_LOG_CHECK_FAILED = DiagnosticLogMessages.LOG_UPDATE_CHECK_FAILED
private const val UPDATE_LOG_DOWNLOAD_ENQUEUE_FAILED = DiagnosticLogMessages.LOG_UPDATE_DOWNLOAD_ENQUEUE_FAILED
private const val UPDATE_LOG_DOWNLOAD_FAILED = DiagnosticLogMessages.LOG_UPDATE_DOWNLOAD_FAILED
private const val UPDATE_LOG_HASH_MISMATCH = DiagnosticLogMessages.LOG_UPDATE_HASH_MISMATCH
private const val UPDATE_LOG_SHA_UNVERIFIED = DiagnosticLogMessages.LOG_UPDATE_SHA_UNVERIFIED
private const val UPDATE_LOG_INSTALLER_FAILED = DiagnosticLogMessages.LOG_UPDATE_INSTALLER_FAILED

private data class HostPackageInfo(val appName: String, val version: String)

private fun readHostPackageInfo(context: Context): HostPackageInfo? = runCatching {
    @Suppress("DEPRECATION")
    val info = context.packageManager.getPackageInfo(context.packageName, 0)
    val name = context.applicationInfo.loadLabel(context.packageManager).toString()
    val version = info.versionName.orEmpty()
    HostPackageInfo(appName = name, version = version)
}.getOrNull()

/** GitHub releases API（匿名）→ 响应体；失败返回 null（页面按检查失败画）。 */
private fun fetchReleasesJson(): String? = runCatching {
    val conn = (URL(releasesApiUrl).openConnection() as HttpURLConnection).apply {
        requestMethod = "GET"
        connectTimeout = 4000
        readTimeout = 6000
        setRequestProperty("User-Agent", "mikcb-android")
        setRequestProperty("Accept", "application/vnd.github+json")
    }
    try {
        if (conn.responseCode !in 200..299) return null
        conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
    } finally {
        conn.disconnect()
    }
}.getOrNull()

/** 解析检查结果：Malformed → null（检查失败）。 */
private fun parseGithubResponses(
    currentVersion: String,
    jsonText: String?,
    includePrerelease: Boolean,
): AppUpdateCheckResult? = when (
    val outcome = parseGithubReleasesResponse(currentVersion, jsonText, includePrerelease)
) {
    is AppUpdateCheckOutcome.Success -> outcome.result
    AppUpdateCheckOutcome.Malformed -> null
}

private data class DownloadProgressSnapshot(
    val status: Int,
    val downloadedBytes: Long,
    val totalBytes: Long,
)

private fun queryDownload(manager: DownloadManager, id: Long): DownloadProgressSnapshot? {
    val cursor = runCatching { manager.query(DownloadManager.Query().setFilterById(id)) }.getOrNull() ?: return null
    cursor.use {
        if (!it.moveToFirst()) return null
        val status = it.getInt(it.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
        val downloaded = it.getLong(it.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
        val total = it.getLong(it.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
        return DownloadProgressSnapshot(status, downloaded, total)
    }
}

/** HEAD 请求测速：2xx/3xx 视为成功，记录耗时。 */
private fun probeUrlHead(url: String): DownloadProbeResult {
    val start = System.nanoTime()
    return runCatching {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "HEAD"
            connectTimeout = 4000
            readTimeout = 4000
            instanceFollowRedirects = true
            setRequestProperty("User-Agent", "mikcb-android")
        }
        try {
            val code = conn.responseCode
            val elapsed = (System.nanoTime() - start) / 1_000_000
            DownloadProbeResult(
                isSuccess = code in 200..399,
                elapsedMillis = elapsed,
                statusCode = code,
            )
        } finally {
            conn.disconnect()
        }
    }.getOrElse {
        DownloadProbeResult(
            isSuccess = false,
            elapsedMillis = (System.nanoTime() - start) / 1_000_000,
            message = it.message,
        )
    }
}
