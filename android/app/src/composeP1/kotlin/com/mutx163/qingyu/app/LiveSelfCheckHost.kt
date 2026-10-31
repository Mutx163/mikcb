package com.mutx163.qingyu.app

import android.content.Context
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.BuildConfig
import com.mutx163.qingyu.LiveUpdateService
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.infra.AppLogStore
import com.mutx163.qingyu.pages.diagnostics.DiagnosticsStrings
import com.mutx163.qingyu.pages.diagnostics.perfSnapshotJsonText
import com.mutx163.qingyu.pages.settings.LiveDebugRow
import com.mutx163.qingyu.pages.settings.LiveDebugSection
import com.mutx163.qingyu.pages.settings.LiveSelfCheckData
import com.mutx163.qingyu.pages.settings.SettingsLiveSelfCheckPage
import com.mutx163.qingyu.pages.settings.SettingsPageScreen
import com.mutx163.qingyu.pages.settings.SettingsPageState
import com.mutx163.qingyu.pages.settings.SettingsStrings
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** 本地日志卡「清空日志」的节点 rowId（`SettingsLiveSelfCheckPage.localLogButtons` 的第一个动作）。 */
private const val ROW_LOCAL_LOGS_CLEAR = "liveSelfCheck.card.localLogs.clear"

/** 本地日志卡「查看手机日志」的节点 rowId：跳到应用日志查看器（`h.log`）。 */
private const val ROW_LOCAL_LOGS_VIEW = "liveSelfCheck.card.localLogs.view"

/** 本地日志卡「更多测试者选项」的节点 rowId：Kotlin 侧还没有对应能力，诚实提示不可用。 */
private const val ROW_LOCAL_LOGS_MORE = "liveSelfCheck.card.localLogs.more"

/** 上岛状态卡「刷新诊断」的节点 rowId（`SettingsLiveSelfCheckPage.islandStatusButtons` 的第一个）。 */
private const val ROW_ISLAND_REFRESH = "liveSelfCheck.island.refresh"

/** 上岛状态卡「自动刷新」开关的节点 id（`SettingsLiveSelfCheckPage.autoRefreshRow`）。 */
private const val ROW_ISLAND_AUTO_REFRESH = "liveSelfCheck.island.autoRefresh"

/** 应用日志查看器的路由（壳里 `"h.log" -> DiagnosticsLogHost(...)`）。 */
private const val LOG_VIEWER_PAGE_ID = "h.log"

/** 轮询间隔（Dart `:189` 默认 1 秒）。 */
private const val POLL_INTERVAL_MILLIS = 1_000L

/** `buildDebugStatus` 里每次都变的字段，指纹比对必须排除。 */
private const val KEY_GENERATED_AT = "generatedAtMillis"

/**
 * 「实时活动自检」页（`b.liveSelfCheck`）的**真宿主**。
 *
 * 壳里原来是 `SettingsScreen(SettingsLiveSelfCheckPage.spec(SettingsPageState()), onBack)`：
 * 19 个字段全走默认值，8 块原生诊断卡永远不出现，三个本地日志按钮因为
 * `controlCardWiring` 白名单里没有对应键而点了没反应（认领文件 F23 §2）。
 *
 * ## 数据从哪来
 *
 * `LiveUpdateService.buildDebugStatus(context)`（`LiveUpdateService.kt:125`，companion 公开）
 * 一次给出 `summary` / 8 个诊断分区 / `recentDiagnostics`，每秒读一次。
 * 与日志查看器同一套**指纹去重**：`generatedAtMillis` 每次都变，先摘掉再取哈希；
 * 指纹没变就不重建行数据（Dart 侧「自检页自己把自己拖死」的修复，见
 * `DiagnosticsLogHost` 头注释）。
 *
 * 接真值的字段（页面数据类 19 个里的一半以上）：
 * `serviceRunning` / `statusText` / `notIslandReason` 来自 `summary`，
 * 8 块诊断卡来自对应分区（`recentDiagnostics` → `RECENT_LOGS`），
 * `rawDebugJson` 用与 Dart `JsonEncoder.withIndent('  ')` 逐字符对齐的
 * [perfSnapshotJsonText]，`refreshedAtText` 取 `generatedAtMillis`，
 * `semesterUnset` 读 `timetable_settings.semesterStartDate`。
 *
 * **没有 Kotlin 来源、保持默认值的 4 个**（不编数据）：
 * `holidayOverrideEnabled` / `timeCorrectionSeconds` / `sessionActive` / `courseTestLabel`；
 * `holidayBlocksIsland` 需要 Dart 侧的假期判定，同样保持默认。
 *
 * ## 交互落点
 *
 * | 按钮 | 落点 |
 * |---|---|
 * | 清空日志 | `AppLogStore.clear()` + `clearNative()`，两者都成功才提示「已清空」 |
 * | 查看手机日志 | `onOpenPage("h.log")` |
 * | 更多测试者选项 | 诚实提示 `aboutUnavailable`（Kotlin 侧没有这个页面） |
 * | 刷新诊断 | 立刻重读一次 `buildDebugStatus` |
 * | 自动刷新开关 | 宿主本地状态（Dart `_autoRefreshEnabled` 也是本地态） |
 *
 * 测试通知卡的按钮（开始/取消测试、课中测试、崩溃 / 卡顿）没有数据来源，
 * 本轮不接线——它们仍会落到分派器的未知 rowId，不会假装成功。
 */
@Composable
fun LiveSelfCheckHost(
    onOpenPage: (String) -> Unit,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val timetableStore = remember(context) { TimetableStore(PrefsKeyValueStore(context)) }

    var debugLoaded by remember { mutableStateOf(false) }
    var serviceRunning by remember { mutableStateOf(false) }
    var statusText by remember { mutableStateOf("") }
    var notIslandReason by remember { mutableStateOf("") }
    var semesterUnset by remember { mutableStateOf(false) }
    var debugSections by remember {
        mutableStateOf<Map<LiveDebugSection, List<LiveDebugRow>>>(emptyMap())
    }
    var rawDebugJson by remember { mutableStateOf("") }
    var refreshedAtText by remember { mutableStateOf<String?>(null) }
    var autoRefreshEnabled by remember { mutableStateOf(true) }
    var clearingDiagnostics by remember { mutableStateOf(false) }

    // 刷新按钮 → 自增一次，让下面的轮询 effect 立刻重跑一轮。
    var reloadTick by remember { mutableIntStateOf(0) }

    LaunchedEffect(autoRefreshEnabled, reloadTick) {
        var lastFingerprint: String? = null
        while (true) {
            val reading = withContext(Dispatchers.IO) {
                readDebugReading(context, timetableStore, lastFingerprint)
            }
            if (reading != null) {
                lastFingerprint = reading.fingerprint
                // 「上次刷新」按**实际读取成功**的时刻算，不是数据变化的时刻：
                // 原生每隔一秒都会回一份新的 generatedAtMillis。
                refreshedAtText = reading.refreshedAtText
                // 原生状态没变就只动时刻那一行：8 块分区与原始 JSON 不重算。
                val changed = reading.changed
                if (changed != null) {
                    debugLoaded = true
                    serviceRunning = changed.serviceRunning
                    statusText = changed.statusText
                    notIslandReason = changed.notIslandReason
                    semesterUnset = changed.semesterUnset
                    debugSections = changed.sections
                    rawDebugJson = changed.rawJson
                }
            }
            if (!autoRefreshEnabled) {
                break
            }
            delay(POLL_INTERVAL_MILLIS)
        }
    }

    fun clearLogs() {
        if (clearingDiagnostics) {
            return
        }
        clearingDiagnostics = true
        scope.launch {
            // 与日志查看器同一口径：应用日志 + 原生诊断日志**两份都清掉**才算成功。
            // 失败必须如实提示，不能把「没清掉」报成「已清空」。
            val cleared = withContext(Dispatchers.IO) {
                val appCleared = AppLogStore.clear()
                val nativeCleared = AppLogStore.clearNative()
                appCleared && nativeCleared
            }
            clearingDiagnostics = false
            showToast(
                context,
                if (cleared) {
                    DiagnosticsStrings.appLogsCleared.zh
                } else {
                    DiagnosticsStrings.appLogsClearFailed.zh
                },
            )
        }
    }

    val data = LiveSelfCheckData(
        isReleaseBuild = !BuildConfig.DEBUG,
        semesterUnset = semesterUnset,
        serviceRunning = serviceRunning,
        notIslandReason = notIslandReason,
        statusText = statusText,
        loadingDebugStatus = !debugLoaded,
        clearingDiagnostics = clearingDiagnostics,
        autoRefreshEnabled = autoRefreshEnabled,
        refreshedAtText = refreshedAtText,
        autoRefreshIntervalSeconds = (POLL_INTERVAL_MILLIS / 1_000L).toInt(),
        debugLoaded = debugLoaded,
        debugSections = debugSections,
        rawDebugJson = rawDebugJson,
    )

    SettingsPageScreen(
        spec = SettingsLiveSelfCheckPage.spec(SettingsPageState(), data),
        onBack = onBack,
        onAction = { _, _, rowId ->
            when (rowId) {
                ROW_LOCAL_LOGS_CLEAR -> clearLogs()
                ROW_LOCAL_LOGS_VIEW -> onOpenPage(LOG_VIEWER_PAGE_ID)
                ROW_LOCAL_LOGS_MORE -> showToast(context, SettingsStrings.aboutUnavailable.zh)
                ROW_ISLAND_REFRESH -> reloadTick += 1
                ROW_ISLAND_AUTO_REFRESH -> autoRefreshEnabled = !autoRefreshEnabled
            }
        },
    )
}

/**
 * 一轮轮询的结果。
 *
 * `fingerprint` 是**排除 `generatedAtMillis` 之后**整份状态的哈希；
 * `changed` 为 `null` 表示与上一轮完全相同（宿主只需更新刷新时刻，
 * 不必重建 8 块分区与原始 JSON——与日志查看器「不变就整轮跳过」同一纪律）。
 */
private class DebugReading(
    val fingerprint: String,
    val refreshedAtText: String,
    val changed: DebugSnapshot?,
)

/** 状态**变了**的那一份数据；`changed == null` 时宿主沿用上一份。 */
private class DebugSnapshot(
    val serviceRunning: Boolean,
    val statusText: String,
    val notIslandReason: String,
    val semesterUnset: Boolean,
    val sections: Map<LiveDebugSection, List<LiveDebugRow>>,
    val rawJson: String,
)

/**
 * 读一次原生诊断（必须在 IO 线程调用：里面会读 SharedPreferences 与日志尾部）。
 *
 * 失败返回 `null`，宿主保留上一份数据——不把异常翻译成「全 false」，那等于把
 * 「读不到」伪装成「服务没在跑」。
 */
private fun readDebugReading(
    context: Context,
    timetableStore: TimetableStore,
    previousFingerprint: String?,
): DebugReading? = runCatching {
    val status = LiveUpdateService.buildDebugStatus(context)
    val fingerprint = status.filterKeys { it != KEY_GENERATED_AT }.hashCode().toString()
    val generatedAt = (status[KEY_GENERATED_AT] as? Number)?.toLong()
    val refreshedAtText = formatClock(generatedAt ?: System.currentTimeMillis())

    if (fingerprint == previousFingerprint) {
        return@runCatching DebugReading(fingerprint, refreshedAtText, changed = null)
    }

    val summary = status["summary"] as? Map<*, *>
    val sections = linkedMapOf<LiveDebugSection, List<LiveDebugRow>>()
    LiveDebugSection.entries.forEach { section ->
        val raw = status[statusKeyOf(section)] as? Map<*, *> ?: return@forEach
        sections[section] = raw.entries.map { (key, value) ->
            LiveDebugRow(label = key.toString(), value = formatDebugValue(value))
        }
    }

    DebugReading(
        fingerprint = fingerprint,
        refreshedAtText = refreshedAtText,
        changed = DebugSnapshot(
            serviceRunning = summary?.get("serviceRunning") as? Boolean ?: false,
            statusText = summary?.get("statusText") as? String ?: "",
            notIslandReason = summary?.get("notIslandReason") as? String ?: "",
            semesterUnset = timetableStore.loadSettingsJson().let { json ->
                TimetableSettings.fromJson(json).semesterStartDate == null
            },
            sections = sections,
            rawJson = perfSnapshotJsonText(status),
        ),
    )
}.getOrNull()

/** 诊断分区 → `buildDebugStatus` 的顶层键（顺序与页面上的卡片顺序一致）。 */
private fun statusKeyOf(section: LiveDebugSection): String = when (section) {
    LiveDebugSection.ENVIRONMENT -> "environment"
    LiveDebugSection.SERVICE -> "service"
    LiveDebugSection.COURSE -> "course"
    LiveDebugSection.TIMING -> "timing"
    LiveDebugSection.SWITCHES -> "switches"
    LiveDebugSection.DISPLAY -> "display"
    LiveDebugSection.NOTIFICATION -> "notification"
    LiveDebugSection.RECENT_LOGS -> "recentDiagnostics"
}

/**
 * 原生字段值的展示口径。
 *
 * 标量直接 `toString()`（与 Dart 的 `'$value'` 一致）；嵌套的 Map / List 用
 * [MiniJson] 压成一行，避免 `{enabled=true, tail=…}` 这种 Java 默认写法。
 * `null` 交给页面统一渲染成 `-`（`debugValueRow` 的 `ifEmpty { "-" }`）。
 */
private fun formatDebugValue(value: Any?): String = when (value) {
    null -> ""
    is String -> value
    is Boolean, is Number -> value.toString()
    is Map<*, *>, is Iterable<*>, is Array<*> -> MiniJson.encode(value)
    else -> value.toString()
}

private fun formatClock(millis: Long): String =
    SimpleDateFormat("HH:mm:ss", Locale.US).format(Date(millis))

private fun showToast(context: Context, message: String) {
    Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
}
