package com.mutx163.qingyu.app

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.Toast
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.infra.AppLogStore
import com.mutx163.qingyu.infra.DIAGNOSTICS_LOG_TIME_SORT_KEY
import com.mutx163.qingyu.infra.DiagnosticsLogLevel
import com.mutx163.qingyu.infra.recordingEnabledFromPrefs
import com.mutx163.qingyu.pages.diagnostics.AppLogSource
import com.mutx163.qingyu.pages.diagnostics.DiagnosticsLogFeedLogic
import com.mutx163.qingyu.pages.diagnostics.DiagnosticsLogFeedState
import com.mutx163.qingyu.pages.diagnostics.DiagnosticsLogPaging
import com.mutx163.qingyu.pages.diagnostics.DiagnosticsLogTimeSort
import com.mutx163.qingyu.pages.diagnostics.DiagnosticsLogViewMode
import com.mutx163.qingyu.pages.diagnostics.DiagnosticsLogViewport
import com.mutx163.qingyu.pages.diagnostics.DiagnosticsStrings
import com.mutx163.qingyu.pages.diagnostics.LiveDiagnosticsLogPage
import com.mutx163.qingyu.pages.diagnostics.LogViewerEntryLogic
import com.mutx163.qingyu.pages.diagnostics.buildDiagnosticsFullLogText
import com.mutx163.qingyu.pages.diagnostics.buildDiagnosticsLogViewState
import com.mutx163.qingyu.pages.diagnostics.chronologicalDiagnosticsEntries
import com.mutx163.qingyu.pages.diagnostics.diagnosticsEntryIdAtItemIndex
import com.mutx163.qingyu.pages.diagnostics.diagnosticsItemIndexOfEntry
import com.mutx163.qingyu.pages.diagnostics.isStuckToLatest
import com.mutx163.qingyu.pages.diagnostics.latestEdgeItemIndex
import com.mutx163.qingyu.pages.diagnostics.resetWindowForFilter
import com.mutx163.qingyu.pages.diagnostics.timeSortFromPreference
import com.mutx163.qingyu.pages.diagnostics.timeSortPreferenceValue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/**
 * 应用日志查看器的**真实宿主**（取代壳里 `DiagnosticsLogSnapshot.EMPTY` + 9 个空 lambda 的假页面）。
 *
 * 数据来自真实文件 + 定时轮询，交互逐个落成真动作；渲染仍是 [LiveDiagnosticsLogPage]
 * （页面本身不做业务计算）。
 *
 * ## 数据从哪来（Dart `AppLogService.watchMergedLogsText` 的等价物）
 *
 * 1. `AppLogStore` 读 `filesDir/logs/app_runtime.log`（应用日志）与
 *    `filesDir/logs/live_update_diagnostics.log`（原生超级岛诊断日志，写入方是
 *    `UmengDiagnosticReporter.appendToLocalFile`）；
 * 2. 每秒做一次**文件指纹**比对（`size:mtime`，Dart `_logFileFingerprint` 489-497 行），
 *    两份都没变就整轮跳过——这是 Dart 侧「日志页自己把自己拖死」的修复，必须照做；
 * 3. 变了才读全文、按 `source=app` / `source=native` 合并（Dart `readMergedLogsText`），
 *    再交给 [DiagnosticsLogFeedLogic] 判定「增量追加」还是「整份重解析」。
 *
 * ## 九个交互的落点
 *
 * | # | 交互 | 落点 |
 * |---|---|---|
 * | 1 | 选级别过滤 | `selectLevel` + [resetWindowForFilter]（Dart 605-615 行） |
 * | 2 | 加载更早 | `loadEarlier` → [DiagnosticsLogPaging.loadEarlier] + 视口锚定（Dart 872-911 行） |
 * | 3 | 展开条目 | `expandedEntryIds`（Dart `_expandedEntryIds`） |
 * | 4 | 显示设备信息 | `deviceInfoExpanded`（Dart `_deviceInfoExpanded`） |
 * | 5 | 切视图模式 | `viewMode`（Dart `_showDisplayOptionsSheet` 637-647 行） |
 * | 6 | 切时间排序 | `setTimeSort` + 落盘 `flutter.diagnostics_log_time_sort`（Dart 131-151 行） |
 * | 7 | 复制 | `copyLogs` → `ClipboardManager` + toast `appLogsCopied`（Dart 970-981 行） |
 * | 8 | 导出/分享 | `exportLogs` → 写缓存文件 + 系统分享面板（见 [shareLogText]） |
 * | 9 | 清空 | 页面内确认弹层 → `clearLogs` → 应用日志 + 原生诊断日志一起清 |
 *
 * ## 已知边界（诚实说明，详见 `.agents/compose-phase3/claims/_DIAG-log-gaps.md`）
 *
 * - **warehouseImport 源**没有宿主数据：Kotlin 侧没有「教务导入会话日志」的内存实现，
 *   传进来只会是空页（[source] 默认 [AppLogSource.MERGED]，壳里也只接 MERGED）。
 * - **导出走系统分享**：写 `cacheDir/log-share/` 下的临时文件 → `FileProvider` 换成
 *   content Uri → `Intent.createChooser`。白名单条目在 `res/xml/file_paths.xml`
 *   （`name="log_share"`）。provider 万一不可用时降级为「整份日志当纯文本交给分享面板」，
 *   不静默失败、也不自研分享面板。
 * - 记录开关 `liveEnableLocalDiagnostics`：`TimetableSettingsModel` 已补该字段（泳道 D），
 *   但这里仍读 `FlutterSharedPreferences` —— 迁移期两边写的是同一份 prefs，读盘能同时看到
 *   Flutter 侧与 Kotlin 侧写入的值；等 Flutter 入口下线再改读模型。
 */
@Composable
fun DiagnosticsLogHost(
    onBack: () -> Unit,
    source: AppLogSource = AppLogSource.MERGED,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val config = remember(source) { LogViewerEntryLogic.configFor(source) }
    val listState = rememberLazyListState()

    var feed by remember { mutableStateOf(DiagnosticsLogFeedState.INITIAL) }
    var viewMode by remember { mutableStateOf(DiagnosticsLogViewMode.STRUCTURED) }
    var timeSort by remember { mutableStateOf(DiagnosticsLogTimeSort.ASCENDING) }
    var selectedLevel by remember { mutableStateOf(DiagnosticsLogLevel.ALL) }
    var viewport by remember { mutableStateOf(DiagnosticsLogViewport()) }
    var expandedEntryIds by remember { mutableStateOf(emptySet<String>()) }
    var deviceInfoExpanded by remember { mutableStateOf(false) }
    var isExporting by remember { mutableStateOf(false) }
    var isClearing by remember { mutableStateOf(false) }
    var recordingEnabled by remember { mutableStateOf<Boolean?>(null) }
    var loadedOnce by remember { mutableStateOf(false) }

    // 「加载更早」后的视口锚定：记下点之前第一可见条目的 id 与像素偏移。
    var pendingAnchor by remember { mutableStateOf<Pair<String, Int>?>(null) }

    // 首帧：读时间排序偏好（Dart `_loadViewerPreferences` 118-129 行）与记录开关。
    LaunchedEffect(Unit) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        timeSort = timeSortFromPreference(
            prefs.getString("$PREFS_KEY_PREFIX$DIAGNOSTICS_LOG_TIME_SORT_KEY", null),
        )
        recordingEnabled = withContext(Dispatchers.IO) {
            recordingEnabledFromPrefs(
                settingsJson = prefs.getString("$PREFS_KEY_PREFIX$KEY_TIMETABLE_SETTINGS", null),
                profilesJson = prefs.getString("$PREFS_KEY_PREFIX$KEY_TIMETABLE_PROFILES", null),
                activeProfileId = prefs.getString("$PREFS_KEY_PREFIX$KEY_ACTIVE_PROFILE_ID", null),
            )
        }
    }

    // 数据轮询：指纹不变就整轮跳过（Dart `watchMergedLogsText` 292-362 行）。
    LaunchedEffect(source) {
        var lastKey: String? = null
        var firstEmission = true
        while (true) {
            val loaded = withContext(Dispatchers.IO) {
                val appFingerprint = if (source == AppLogSource.LIVE) null else AppLogStore.fingerprint()
                val nativeFingerprint = AppLogStore.nativeFingerprint()
                val key = "$appFingerprint|$nativeFingerprint"
                if (!firstEmission && key == lastKey) {
                    null
                } else {
                    lastKey = key
                    if (source == AppLogSource.LIVE) {
                        AppLogStore.readNativeText()
                    } else {
                        AppLogStore.readMergedText()
                    }
                }
            }
            if (loaded != null) {
                firstEmission = false
                loadedOnce = true
                feed = runCatching {
                    DiagnosticsLogFeedLogic.onLoaded(feed, loaded, config.title)
                }.getOrElse { error ->
                    DiagnosticsLogFeedLogic.onLoadError(feed, error.toString())
                }
            }
            delay(POLL_INTERVAL_MILLIS)
        }
    }

    // 空态退出（只有 live 源：Dart `onLoadEmpty` 会 toast + pop）。
    LaunchedEffect(loadedOnce, feed.body, feed.parsed.entries.size) {
        if (loadedOnce && DiagnosticsLogFeedLogic.shouldPopOnEmpty(feed, config.popsOnEmpty)) {
            config.emptyLoadMessage?.let { toast(context, it) }
            onBack()
        }
    }

    // 窗口每个组合帧都重算一次：`buildDiagnosticsLogViewState` 内部的 resolve 结果
    // 不会回写宿主状态，而「加载更早 / 贴最新端」要读**当下**的窗口起点。
    val resolvedViewport = remember(feed.parsed, selectedLevel, viewport) {
        DiagnosticsLogPaging.resolve(
            total = chronologicalDiagnosticsEntries(feed.parsed, selectedLevel).size,
            state = viewport,
        )
    }

    val viewState = buildDiagnosticsLogViewState(
        title = config.title,
        parsed = feed.parsed,
        viewport = resolvedViewport,
        viewMode = viewMode,
        timeSort = timeSort,
        selectedLevel = selectedLevel,
        expandedEntryIds = expandedEntryIds,
        isDeviceInfoExpanded = deviceInfoExpanded,
        isRecordingEnabled = recordingEnabled,
        isInitializing = feed.isInitializing,
        isParsing = feed.isParsing,
        loadError = feed.loadError,
        isExporting = isExporting,
        isClearing = isClearing,
        canClear = config.supportsClear,
    )

    // 贴最新端判定（Dart `_syncStickToLatest` 382-400 行）。
    //
    // **只在「用户滚动停下」时改 stick**：内容追加造成的 canScrollForward 变化不算
    // 「用户离开最新端」——否则自动跟最新时会被自己的追加误判成离开而停更。
    // 拖动过程中一旦离开边缘就立刻解钉，绝不和手指抢（这是「每次更新把人拽回底部、
    // 只能朝一个方向滑」的根因）。
    val latestResolvedViewport = rememberUpdatedState(resolvedViewport)
    LaunchedEffect(listState, viewState.latestAtBottom) {
        var wasScrolling = false
        snapshotFlow {
            Triple(
                listState.isScrollInProgress,
                listState.canScrollForward,
                listState.canScrollBackward,
            )
        }.collect { (scrolling, forward, backward) ->
            val atEdge = isStuckToLatest(viewState.latestAtBottom, forward, backward)
            if (scrolling) {
                if (!atEdge && latestResolvedViewport.value.stickToLatest) {
                    viewport = DiagnosticsLogPaging.onStickToLatestChange(latestResolvedViewport.value, false)
                }
                wasScrolling = true
            } else if (wasScrolling) {
                viewport = DiagnosticsLogPaging.onStickToLatestChange(latestResolvedViewport.value, atEdge)
                wasScrolling = false
            }
        }
    }

    // 列表项总数（派生值：滚动时 layoutInfo 每帧变、但总数不变，避免每帧重组）。
    val totalItems by remember {
        derivedStateOf { listState.layoutInfo.totalItemsCount }
    }

    // 贴最新端时，新增条目 / 首次布局后自动滚到最新那一端（Dart `_scheduleAutoScroll` 402-444 行）。
    // 只有「仍贴最新端且用户没在拖动」才跟；用户手动翻历史（stick=false）时绝不打断。
    LaunchedEffect(viewState.entries.size, totalItems, viewState.latestAtBottom) {
        if (!latestResolvedViewport.value.stickToLatest) return@LaunchedEffect
        if (viewState.entries.isEmpty() || listState.isScrollInProgress) return@LaunchedEffect
        if (totalItems <= 0) return@LaunchedEffect
        val target = latestEdgeItemIndex(viewState.latestAtBottom, totalItems)
        runCatching { listState.scrollToItem(target) }
    }

    // 「加载更早」之后把视口锚回原先第一可见条目（Dart 895-910 行）。
    LaunchedEffect(pendingAnchor, viewState.entries) {
        val anchor = pendingAnchor ?: return@LaunchedEffect
        val index = diagnosticsItemIndexOfEntry(viewState, anchor.first)
        if (index != null) {
            runCatching { listState.scrollToItem(index, anchor.second) }
        }
        pendingAnchor = null
    }

    // ---------- 九个交互 ----------

    fun selectLevel(level: DiagnosticsLogLevel) {
        if (level == selectedLevel) {
            return
        }
        selectedLevel = level
        // Dart 605-615：换筛选时解开起点与末端冻结，回到贴最新一页。
        viewport = resetWindowForFilter(resolvedViewport)
    }

    fun loadEarlier() {
        if (resolvedViewport.currentStartIndex <= 0) {
            return
        }
        // 先记锚点：屏幕顶部那条日志的 id 与像素偏移。
        val anchorId = diagnosticsEntryIdAtItemIndex(viewState, listState.firstVisibleItemIndex)
        if (anchorId != null) {
            pendingAnchor = anchorId to listState.firstVisibleItemScrollOffset
        }
        viewport = DiagnosticsLogPaging.loadEarlier(resolvedViewport)
    }

    fun setTimeSort(sort: DiagnosticsLogTimeSort) {
        if (sort == timeSort) {
            return
        }
        timeSort = sort
        // Dart `_setTimeSort` 137-139：换排序解钉，回到贴最新端。
        viewport = resolvedViewport.copy(pinnedStartIndex = null, windowEndPin = null)
        scope.launch(Dispatchers.IO) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(
                    "$PREFS_KEY_PREFIX$DIAGNOSTICS_LOG_TIME_SORT_KEY",
                    timeSortPreferenceValue(sort),
                )
                .apply()
        }
    }

    fun copyLogs() {
        val text = buildDiagnosticsFullLogText(feed.parsed, selectedLevel)
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        // 只有真写进剪贴板才提示「已复制」。Dart `_copyLogs`（:970-981）是 `await
        // Clipboard.setData(...)` 成功之后才 toast；这里原来是「写了就报成功」，
        // clipboard 为 null（少见但可能：策略机型/系统服务缺失）时会骗用户。
        val copied = clipboard != null && runCatching {
            clipboard.setPrimaryClip(ClipData.newPlainText(CLIP_LABEL, text))
        }.isSuccess
        if (copied) {
            toast(context, DiagnosticsStrings.appLogsCopied.text)
        } else {
            // 失败路径的专用文案还没有 ARB 键（已记「ARB 新增请求」）；
            // 宁可「只留 logcat」也不假装复制成功。
            Log.w(LOG_TAG, "copy clipped logs failed: clipboard unavailable")
        }
    }

    fun exportLogs() {
        if (isExporting) {
            return
        }
        val text = buildDiagnosticsFullLogText(feed.parsed, selectedLevel)
        if (text.trim().isEmpty()) {
            // Dart `_shareViewedLogText` 93-102 行：空文本只提示、不拉起分享。
            config.emptyExportMessage?.let { toast(context, it) }
            return
        }
        isExporting = true
        scope.launch {
            val fileName = LogViewerEntryLogic.exportFileName(source, System.currentTimeMillis())
            val shared = withContext(Dispatchers.IO) {
                shareLogText(
                    context = context,
                    text = text,
                    fileName = fileName,
                    shareText = config.shareText,
                    shareSubject = config.shareSubject,
                )
            }
            // `shareLogText` 明确返回「是否拉起过分享面板」（见其 KDoc）。原来把这个
            // 返回值整个丢掉：系统没有可用分享目标时用户什么都看不到，像是按钮失灵。
            if (!shared) {
                // 失败文案同样缺 ARB 键（已记「ARB 新增请求」），先留 logcat。
                Log.w(LOG_TAG, "share chooser not launched for $fileName")
            }
            isExporting = false
        }
    }

    fun clearLogs() {
        if (isClearing) {
            return
        }
        isClearing = true
        scope.launch {
            // Dart `_buildMergedViewer` 139-146 行（`log_viewer_entry.dart`）：合并入口清的是
            // **两份**——`clearAppLogs()` 之后再清原生超级岛诊断日志，两者都成功才算清空成功。
            // live 入口 Dart 侧根本没有清空按钮（`supportsClear=false`），这里同样不动原生文件。
            val cleared = withContext(Dispatchers.IO) {
                val appCleared = if (source == AppLogSource.LIVE) true else AppLogStore.clear()
                val nativeCleared = if (source == AppLogSource.MERGED) AppLogStore.clearNative() else true
                appCleared && nativeCleared
            }
            if (cleared) {
                // Dart 1013-1021 行：清空成功后正文与解析结果一起复位、展开态清掉。
                feed = DiagnosticsLogFeedLogic.onCleared(feed)
                expandedEntryIds = emptySet()
                viewport = DiagnosticsLogViewport()
            }
            isClearing = false
            toast(
                context,
                if (cleared) {
                    DiagnosticsStrings.appLogsCleared.text
                } else {
                    DiagnosticsStrings.appLogsClearFailed.text
                },
            )
        }
    }

    LiveDiagnosticsLogPage(
        viewState = viewState,
        listState = listState,
        onBack = onBack,
        onSelectLevel = ::selectLevel,
        onLoadEarlier = ::loadEarlier,
        onToggleEntry = { id ->
            expandedEntryIds = if (expandedEntryIds.contains(id)) {
                expandedEntryIds - id
            } else {
                expandedEntryIds + id
            }
        },
        onToggleDeviceInfo = { deviceInfoExpanded = !deviceInfoExpanded },
        onViewModeChange = { mode -> viewMode = mode },
        onTimeSortChange = ::setTimeSort,
        onCopy = ::copyLogs,
        onExport = ::exportLogs,
        onClear = ::clearLogs,
        // watch 模式下流自己会恢复，手动重拉没有意义（Dart 562-570 行同理）。
        onRefresh = null,
    )
}

/** 与 `PrefsKeyValueStore` / Flutter 侧同一份 prefs（`flutter.` 前缀由这里补）。 */
private const val PREFS_NAME = "FlutterSharedPreferences"
private const val PREFS_KEY_PREFIX = "flutter."
private const val KEY_TIMETABLE_SETTINGS = "timetable_settings"
private const val KEY_TIMETABLE_PROFILES = "timetable_profiles"
private const val KEY_ACTIVE_PROFILE_ID = "active_timetable_profile_id"

/** 轮询间隔（Dart `nativePollInterval` 默认 1 秒）。 */
private const val POLL_INTERVAL_MILLIS = 1_000L

private const val CLIP_LABEL = "mikcb-app-logs"

/** logcat 标签（失败路径没有 ARB 文案时的唯一留痕，别删）。 */
private const val LOG_TAG = "[diagnostics-log]"

/**
 * 日志导出临时副本的子目录名（相对 `cacheDir`）。
 *
 * 必须与 `res/xml/file_paths.xml` 里 `<cache-path name="log_share" path="log-share/">`
 * 的 `path` **逐字一致**（连字符，不是下划线）；名字对不上时 `FileProvider.getUriForFile`
 * 会抛 IllegalArgumentException，分享就退化成纯文本。改这里必须同步改那个 XML。
 */
private const val LOG_SHARE_DIR_NAME = "log-share"

/**
 * 把整份日志交给系统分享面板。
 *
 * 与 `platform/AndroidShareAdapter.kt` 同一套三步（写缓存文件 → content Uri →
 * `Intent.createChooser`），差别只在**不抛异常、缺 FileProvider 时降级**：
 * `AndroidManifest.xml` 目前没有注册 `FileProvider`，`getUriForFile` 会抛
 * `IllegalArgumentException`；此时把整份日志当纯文本放进 [Intent.EXTRA_TEXT]，
 * 用户仍然拿得到内容，只是没有 `.log` 附件。不自研分享面板。
 *
 * `internal`（不是 private）：同一模块的「实时活动自检」宿主
 * （`LiveSelfCheckHost.kt`）的「导出并分享日志」与这里共用**同一份**分享实现，
 * 不再各抄一条。可见性之外没有任何改动，查看器的行为逐字不变。
 *
 * @return 是否成功拉起过分享面板。
 */
internal fun shareLogText(
    context: Context,
    text: String,
    fileName: String,
    shareText: String,
    shareSubject: String,
): Boolean {
    // 必须写进 cacheDir 的**已登记子目录**：FileProvider 只放行 `res/xml/file_paths.xml`
    // 里列出的路径，写在 cacheDir 根目录会让 getUriForFile 抛 IllegalArgumentException，
    // 于是静默降级成「纯文本分享」——接收方拿不到 .log 附件，与 Dart（share_plus 发文件）不一致。
    val file = runCatching {
        File(File(context.cacheDir, LOG_SHARE_DIR_NAME), fileName).apply {
            parentFile?.mkdirs()
            writeText(text, Charsets.UTF_8)
        }
    }.getOrNull()

    val uri = file?.let {
        runCatching {
            androidx.core.content.FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                it,
            )
        }.getOrNull()
    }

    val send = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_SUBJECT, shareSubject)
        if (uri != null) {
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, shareText)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } else {
            // 没有 provider：正文直接在 Intent 里（日志上限 512KB，仍在 Binder 事务范围内）。
            putExtra(Intent.EXTRA_TEXT, "$shareText\n\n$text")
        }
    }
    val chooser = Intent.createChooser(send, shareSubject)
    if (context !is android.app.Activity) {
        chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    return runCatching {
        context.startActivity(chooser)
        true
    }.getOrDefault(false)
}

private fun toast(context: Context, message: String) {
    Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
}
