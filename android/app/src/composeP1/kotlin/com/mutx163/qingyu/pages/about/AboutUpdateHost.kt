package com.mutx163.qingyu.pages.about

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.os.Environment
import android.widget.Toast
import androidx.activity.compose.BackHandler
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
import com.mutx163.qingyu.infra.AppReleaseInfo
import com.mutx163.qingyu.infra.AppUpdateCheckResult
import com.mutx163.qingyu.infra.AppUpdateDotShare
import com.mutx163.qingyu.infra.AppUpdateDownloadChannel
import com.mutx163.qingyu.infra.AppUpdateManifestCandidate
import com.mutx163.qingyu.infra.AppUpdateManifestSource
import com.mutx163.qingyu.infra.appUpdateManifestCandidates
import com.mutx163.qingyu.infra.buildCheckResult
import com.mutx163.qingyu.infra.buildDownloadUrl
import com.mutx163.qingyu.infra.isTrustedManifestUrl
import com.mutx163.qingyu.infra.recordingEnabledFromPrefs
import com.mutx163.qingyu.pages.settings.SettingsStringsExt2
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import com.mutx163.qingyu.isTrustedSystemDownloadUrl
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
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
        val previous = settings
        settings = updated
        val saved = runCatching { store.saveSettingsPatch(updated.toPatch()) }.isSuccess
        if (!saved) {
            // 写盘失败必须让用户知道，并把界面退回旧值：不能停在「看着改了、其实没存」的假成功态。
            settings = previous
            Toast.makeText(context, SettingsStringsExt2.saveFailed.text, Toast.LENGTH_SHORT).show()
        }
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
            // 2026-11-11 R-3：竞速/解析路径里任何未捕获异常都必须把「检查中」复位，
            // 否则异常逃出协程后 `checking` 永远停在 true —— 页面就是「一直转」。
            try {
                val outcome = checkForUpdatesAcrossManifestSources(
                    currentVersion = info.version,
                    channel = settings.downloadChannel,
                    includePrerelease = settings.includePrerelease,
                )
                result = outcome
                if (outcome == null) {
                    appendLog("warn", UPDATE_LOG_CATEGORY_CHECK, UPDATE_LOG_CHECK_FAILED)
                }
            } catch (cancelled: CancellationException) {
                // 页面离开导致的取消：原样抛出，不动 UI 状态（作用域已经结束）。
                throw cancelled
            } catch (error: Throwable) {
                result = null
                appendLog("warn", UPDATE_LOG_CATEGORY_CHECK, UPDATE_LOG_CHECK_FAILED)
                appendLog("warn", UPDATE_LOG_CATEGORY_CHECK, error.message ?: error.javaClass.simpleName)
            } finally {
                checking = false
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
        // 页内嵌的日志查看器是同一宿主里的**一层子视图**（不是壳路由）：系统返回键要先退这一层，
        // 不能让它冒泡到壳把整个「版本更新」页 pop 掉——否则就是"多退一层"回到「关于」。
        BackHandler { showLogs = false }
        DiagnosticsLogHost(onBack = { showLogs = false })
    } else if (showAdvanced) {
        // 高级选项同样是本宿主的页内子页（showAdvanced 状态层）：系统返回键只退回版本更新页，
        // 版本更新页再按返回才回关于页（逐层退）。缺了这颗 BackHandler 就会越级退出。
        BackHandler { showAdvanced = false }
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
 * 首页顶栏「待更新」状态（发布版 `_scheduleUpdateCheckIfNeeded` / `_runUpdateCheck`，
 * `lib/screens/timetable_screen.dart:7467-7517`；调度在
 * `timetable_update_download_part.dart:36-50`）。
 *
 * 只做三件事：
 * 1. **查一次**：进首页时按存档的「检测测试版」开关拉一次清单（与版本更新页同一条
 *    三路竞速链路：[checkForUpdatesAcrossManifestSources] + [parseGithubResponses] /
 *    [parseGitCodeReleasesResponse] / [parseReleasesPageHtml]，没有第二套检查逻辑），
 *    并按当前安装版本判定有没有新版；
 * 2. **登记**：结果写 [AppUpdateDotShare]（跨页面共享的「有更新」登记，未查过读
 *    false）。首页三处提示都读它：「更多」按钮红点、八宫格「更新」瓷贴角标、
 *    列表档「更新」行提示；
 * 3. **调试构建**：与发布版一致——`!kReleaseMode` 直接把「有更新」置真
 *    （`timetable_screen.dart:7467-7475`），开发包不必真发一版就能验红点/角标；
 *    正式包走真检查，检查失败静默（不打扰用户，版本页自己有失败态）。
 *
 * @param enabled `false` = 完全不查（外观编辑页的缩尺预览：[TimetableHost] 传
 *   `!previewMode`）。
 */
@Composable
fun rememberHomeUpdateAvailability(enabled: Boolean = true): Boolean {
    val context = LocalContext.current
    val store = remember(context) { TimetableStore(PrefsKeyValueStore(context)) }
    // 与版本更新页同一份读侧口径（`appUpdateIncludePrerelease` 等 7 键）；首页只读一次。
    val updateSettings = remember { AppUpdateSettings.fromJson(store.loadSettingsJson()) }
    val packageInfo = remember(context) { readHostPackageInfo(context) }
    var hasUpdate by remember { mutableStateOf(AppUpdateDotShare.hasUpdate) }

    LaunchedEffect(enabled, updateSettings.includePrerelease, packageInfo?.version) {
        if (!enabled) return@LaunchedEffect
        if (!isDebuggableBuild(context)) {
            val info = packageInfo
            val latest = if (info == null) {
                false
            } else {
                // 与版本更新页同一条竞速链路（渠道取同一份设置），首页红点不再单独写一套。
                // R-3 同口径：任何异常都只当「这次没查到」，不许把 LaunchedEffect 炸掉
                //（首页红点是旁路功能，失败静默，不打扰用户）。
                val check = runCatching {
                    checkForUpdatesAcrossManifestSources(
                        currentVersion = info.version,
                        channel = updateSettings.downloadChannel,
                        includePrerelease = updateSettings.includePrerelease,
                    )
                }.getOrNull()
                check?.hasUpdate == true
            }
            AppUpdateDotShare.publish(latest)
            hasUpdate = latest
        } else {
            // 发布版同口径：非 release 构建把「有更新」当作真，供人工验红点/角标。
            AppUpdateDotShare.publish(true)
            hasUpdate = true
        }
    }
    return hasUpdate
}

/**
 * 调试/性能包判据（发布版 `!kReleaseMode` 的等价物）：debuggable 包 = 调试/性能包。
 *
 * 用运行时 `ApplicationInfo.FLAG_DEBUGGABLE` 而不是 `BuildConfig.DEBUG`：`BuildConfig`
 * 是 AGP 生成的变体类，composeP1 的免 Gradle 类型检查通道（`scripts/typecheck-compose.ps1`）
 * 看不到它，会把新引用记成 unresolved（假错，还得往基线里加行——纪律不许）。
 */
private fun isDebuggableBuild(context: Context): Boolean =
    (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

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

/**
 * 三路清单竞速（发布版 `app_update_service.dart:256-307` 的 `raceFutures` + `:396-434`
 * 的摘要回填）。
 *
 * ## 为什么必须三路
 *
 * 2026-11-10 联网审计：此前只接了 GitHub API 一条（4s 连接 / 6s 读超时），国内网络下
 * `api.github.com` 常被丢包 ⇒ 「检查更新」基本必挂。发布版是 **GitHub API + Release 页 HTML
 * + GitCode API** 三路并行，谁先拿到可用版本用谁；渠道只决定顺序（见
 * [appUpdateManifestCandidates]），**不裁源**。
 *
 * ## 为什么不用 `coroutineScope`（2026-11-11 R-1 修复：用户报「检查更新一直转」）
 *
 * `coroutineScope` 必须等**全部**子协程结束才返回；而 `cancel()` 打不断阻塞的 socket 读
 * （`inputStream.read`），未胜出的那两路要等满 `readTimeout`（6s）才收尾。国内丢包时
 * 明明 GitCode 200ms 就拿到了结果，用户仍要干等 4s 以上。
 *
 * 发布版 `raceFutures`（`async_utils.dart:42-66`）的语义是「首个成功立即返回、**不 join
 * 落败者**」，所以这里把三路放进**独立 scope**（`SupervisorJob + Dispatchers.IO`）：
 * 胜负一分就返回；落败者在后台跑完或到超时自行收尾，摘要回填窗口内照样往
 * [RaceHandle.successes] 写入。
 *
 * ## 摘要回填
 *
 * Release 页 HTML 拿不到 asset 级摘要；若胜者没有摘要，按发布版同口径在
 * [DIGEST_BACKFILL_DEADLINE_MS] 内轮询兄弟策略的结果，找到**同版本 + 直连渠道**的摘要就补上
 *（安装闸门据此决定「直接装」还是「引导去 Release 页」）。窗口用协程时钟
 *（`withTimeoutOrNull`，单调）而不是墙上时钟，理由见 [mergeDigestFromSiblings]。
 */
private suspend fun checkForUpdatesAcrossManifestSources(
    currentVersion: String,
    channel: AppUpdateDownloadChannel,
    includePrerelease: Boolean,
): AppUpdateCheckResult? = withContext(Dispatchers.IO) {
    val candidates = appUpdateManifestCandidates(channel)
    if (candidates.isEmpty()) return@withContext null
    // 竞速内核（main 层 [startRaceFirstSuccess]，有 JVM 单测钉「首胜不等慢兄弟」）：
    // 三路各占一个线程，`awaitWinner()` 只等首个成功，不 join 落败者。
    val race = startRaceFirstSuccess(candidates) { candidate ->
        fetchManifestBody(candidate)?.let { body ->
            parseManifestBody(candidate, currentVersion, body, includePrerelease)
                ?.takeIf { it.hasRelease }
        }
    }
    try {
        val winner = race.awaitWinner()
        // 摘要回填窗口里，落败者仍可继续往 successes 写入（发布版同口径 120ms×1600ms）。
        winner?.let { mergeDigestFromSiblings(it, race.successes) }
    } finally {
        // 回填结束后停掉后台竞速；阻塞读不保证立刻停，但已经没有人等它。
        race.cancel()
    }
}

/**
 * 胜者没有摘要时，从兄弟策略回填（同版本 + 直连渠道才有资格）。
 *
 * 与发布版一致：120ms 轮询、最多等 1600ms —— 不为摘要把「检查更新」拖成十几秒。
 *
 * @param successes 竞速内核的「已成功结果」表；键是候选（[AppUpdateManifestCandidate]），
 *   本函数只读 values，所以按 `Map<*, AppUpdateCheckResult>` 收，键类型由内核决定。
 */
private suspend fun mergeDigestFromSiblings(
    winner: AppUpdateCheckResult,
    successes: Map<*, AppUpdateCheckResult>,
): AppUpdateCheckResult {
    val release = winner.latestRelease ?: return winner
    if (release.expectedApkSha256 != null) return winner

    // 2026-11-11 R-4（评审四建议级）：窗口用**协程时钟**（`withTimeoutOrNull`），不再拿
    // `System.currentTimeMillis()` 算 deadline。墙上时钟会被拨——NTP 校正、用户改时间、
    // 时区工具走一遭，这个 1600ms 窗口就会提前结束（摘要补不上 ⇒ 安装闸门退化成
    // 「引导去 Release 页」）或突然拉长（多等好几秒）。协程超时走单调时钟，且随调用方取消一起收。
    //
    // 必须是 ***OrNull*** 版本：裸 `withTimeout` 超时会抛 `TimeoutCancellationException`
    //（`CancellationException` 的子类），被 [runCheck] 的「取消原样抛出」分支重抛 ⇒ `result`
    // 不赋值，界面停在上一版，等于这次检查白做。`withTimeoutOrNull` 只是「没等到」。
    val sibling: AppReleaseInfo? = withTimeoutOrNull(DIGEST_BACKFILL_DEADLINE_MS) {
        var found: AppReleaseInfo? = null
        while (found == null) {
            found = successes.values.firstNotNullOfOrNull { other ->
                other.latestRelease?.takeIf {
                    it.version == release.version &&
                        it.digestFromDirectChannel &&
                        it.expectedApkSha256 != null
                }
            }
            // 第一轮就是「兄弟可能已经写好了」；之后每 120ms 再看一次。
            if (found == null) delay(DIGEST_BACKFILL_POLL_MS)
        }
        found
    }
    if (sibling == null) return winner

    return buildCheckResult(
        currentVersion = winner.currentVersion,
        release = release.copy(
            expectedApkSha256 = sibling.expectedApkSha256,
            digestFromDirectChannel = true,
        ),
    )
}

/** 拉一条清单候选；非 2xx / 传输失败 / 非信任根 / 超体积一律返回 null。 */
private fun fetchManifestBody(candidate: AppUpdateManifestCandidate): String? = runCatching {
    // 信任根兜底：清单只认官方直连（镜像候选永远不该出现在这条链里）。
    if (!isTrustedManifestUrl(candidate.url)) return null
    val conn = (URL(candidate.url).openConnection() as HttpURLConnection).apply {
        requestMethod = "GET"
        connectTimeout = 4000
        readTimeout = 6000
        setRequestProperty("User-Agent", "mikcb-android")
        when (candidate.source) {
            AppUpdateManifestSource.GITHUB_API -> setRequestProperty("Accept", "application/vnd.github+json")
            AppUpdateManifestSource.GITCODE_API -> setRequestProperty("Accept", "application/json")
            AppUpdateManifestSource.RELEASES_PAGE_HTML -> setRequestProperty("Accept", "text/html")
        }
    }
    try {
        if (conn.responseCode !in 200..299) return null
        // 2026-11-11 R-5：清单是 JSON/HTML，正常几十 KB。别让一个异常响应（或中间设备
        // 塞进来的大文件）无上限读进内存——Content-Length 可信就先挡，否则边读边数。
        val declared = conn.getHeaderField("Content-Length")?.trim()?.toLongOrNull()
        if (declared != null && declared > MAX_MANIFEST_BODY_BYTES) return null
        conn.inputStream.use { stream ->
            val out = java.io.ByteArrayOutputStream()
            val chunk = ByteArray(16 * 1024)
            var total = 0L
            while (true) {
                val read = stream.read(chunk)
                if (read < 0) break
                total += read
                if (total > MAX_MANIFEST_BODY_BYTES) return null
                out.write(chunk, 0, read)
            }
            out.toString(Charsets.UTF_8.name())
        }
    } finally {
        conn.disconnect()
    }
}.getOrNull()

/**
 * 清单响应体上限（2MB）。
 *
 * 三条来源的正文都在几十 KB 量级；2MB 是「够宽松、又能挡住异常大响应」的折中值。
 * 超限按该路失败处理（让兄弟策略接手），不 partial 解析——半截 JSON/HTML 解析出来的
 * 版本号与摘要都不可信。
 */
private const val MAX_MANIFEST_BODY_BYTES = 2L * 1024L * 1024L

/** 按来源分派到对应的纯解析核；解析不出来返回 null（该路让位给兄弟策略）。 */
private fun parseManifestBody(
    candidate: AppUpdateManifestCandidate,
    currentVersion: String,
    body: String,
    includePrerelease: Boolean,
): AppUpdateCheckResult? = when (candidate.source) {
    AppUpdateManifestSource.GITHUB_API ->
        parseGithubResponses(currentVersion, body, includePrerelease)

    AppUpdateManifestSource.GITCODE_API ->
        when (val outcome = parseGitCodeReleasesResponse(currentVersion, body, includePrerelease)) {
            is AppUpdateCheckOutcome.Success -> outcome.result
            AppUpdateCheckOutcome.Malformed -> null
        }

    AppUpdateManifestSource.RELEASES_PAGE_HTML ->
        when (val outcome = parseReleasesPageHtml(currentVersion, body, includePrerelease)) {
            is AppUpdateCheckOutcome.Success -> outcome.result
            AppUpdateCheckOutcome.Malformed -> null
        }
}

/** 摘要回填轮询间隔（发布版 `_mergeDigestFromOtherStrategies` 同值）。 */
private const val DIGEST_BACKFILL_POLL_MS = 120L

/** 摘要回填最多等多久（发布版同值；超过就按「无摘要」交出，安装闸门照常拒装）。 */
private const val DIGEST_BACKFILL_DEADLINE_MS = 1600L

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
