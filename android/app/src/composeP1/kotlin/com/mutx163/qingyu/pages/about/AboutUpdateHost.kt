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
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.infra.AppUpdateCheckResult
import com.mutx163.qingyu.infra.buildDownloadUrl
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
 * - **应用内下载 + 安装**依赖 `FileProvider`（manifest 未注册，属 Lead），本版把「应用内下载」
 *   URL 交给浏览器打开（受信任的直连则走系统下载器）。系统下载器路径完整可用。
 * - GitHub releases API 匿名请求有速率限制；失败按「检查更新失败」画（可重试）。
 * - 镜像测速用 HEAD 请求测耗时；结果只用于推荐，不改变下载地址信任根。
 */
@Composable
fun AboutUpdateHostPage(onBack: () -> Unit) {
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

    fun persist(updated: AppUpdateSettings) {
        settings = updated
        runCatching { store.saveSettingsPatch(updated.toPatch()) }
    }

    fun runCheck() {
        val info = packageInfo ?: run { checking = false; return }
        checking = true
        scope.launch {
            val text = withContext(Dispatchers.IO) { fetchReleasesJson() }
            val outcome = parseGithubResponses(info.version, text, settings.includePrerelease)
            result = outcome
            checking = false
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

    /** 直连 URL → 系统下载器；镜像/外部 URL → 浏览器。 */
    fun startDownload(url: String?) {
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
            return
        }
        toast(AboutUpdatePageStrings.systemDownloaderQueued)
        cancelPolling = false
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
                    toast(AboutUpdatePageStrings.installReady)
                    break
                }
                if (progress.status == DownloadManager.STATUS_FAILED) {
                    download = null
                    toast(AboutUpdatePageStrings.systemDownloaderFailed)
                    break
                }
                delay(500)
            }
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

    if (showAdvanced) {
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
            onEditMirrorUrl = { Toast.makeText(context, AboutUpdatePageStrings.mirrorPrefixLabel, Toast.LENGTH_SHORT).show() },
            onOpenDiagnostics = { /* 日志页路由未在本批次接入 */ },
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
            onInAppDownload = { url, _ /* expectedApkSha256 */, _ /* fallbackUrl */ -> startDownload(url) },
            onSystemDownload = { startDownload(it) },
            onSystemDownloadUnavailable = { toast(AboutUpdatePageStrings.systemDownloaderFailed) },
            onCancelDownload = {
                cancelPolling = true
                download = null
            },
        )
    }
}

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
