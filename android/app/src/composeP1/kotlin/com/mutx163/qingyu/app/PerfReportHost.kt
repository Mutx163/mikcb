package com.mutx163.qingyu.app

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.pages.diagnostics.PerfReportPage
import com.mutx163.qingyu.pages.diagnostics.PerfReportStrings
import com.mutx163.qingyu.pages.diagnostics.buildPerfReportViewState
import com.mutx163.qingyu.pages.diagnostics.perfSnapshotJsonText
import com.mutx163.qingyu.platform.PerfProbe
import kotlinx.coroutines.delay

/**
 * 性能报告页的**真实宿主**（取代壳里 `buildPerfReportViewState(snapshot = null)` + 6 个空 lambda）。
 *
 * ## 数据从哪来（不是示例常量）
 *
 * 全部来自本轮新补的原生能力层：
 * * `platform/PerfProbe.kt` —— 用 `Window.OnFrameMetricsAvailableListener` 取每帧
 *   build/raster 耗时、`Choreographer`/`FrameMetrics.INTENDED_VSYNC` 取 vsync 节奏、
 *   `Process.getElapsedCpuTime()` + `/proc/self/statm` 取页内 CPU / RSS；
 * * `pages/diagnostics/PerfPageLedger.kt` —— 逐条对齐 Dart `perf_page_ledger.dart` 的台账
 *   （预算收紧、分片、按页排行、jank 比例、verdict、文本报表、JSON 快照）；
 * * `pages/diagnostics/PerfProbeCore.kt` —— 启动分段 + 快照结构 + 页面 id 归一化。
 *
 * 因此 `snapshot != null` 是真的有帧数据，`null` 只代表**这个变体没装探针**
 * （正式包：`BuildConfig.DEBUG == false` 且 buildType 不是 `bench` 且非 debuggable）。
 *
 * ## 六个交互全部是真的（与 Dart 逐条对齐）
 *
 * | Dart（`perf_report_screen.dart`） | 这里 |
 * |---|---|
 * | 刷新 `_reload()`（`:57-64`） | `tick++` → 重读 [PerfProbe.snapshotJson] 并重建视图状态 |
 * | 导出 `_exportFiles()`（`:73-84`） | [PerfProbe.exportSnapshot] 写 `<filesDir>/perf_reports/perf-export-<ms>.json/.txt`，toast 带路径 |
 * | 清空台账 `_clearLedger()`（`:86-92`） | [PerfProbe.reset] + 重读 + toast `ledger cleared` |
 * | 展开原文 `_showRaw`（`:191-193`） | 本地状态，切 `Show / Hide raw report` |
 * | 复制文本报告（`:209-214`） | 剪贴板写 [PerfProbe.reportText] + toast `copied` |
 * | 复制 JSON（`:215-222`） | 剪贴板写 2 空格缩进的整份快照（[perfSnapshotJsonText]） |
 *
 * ## 刷新节奏
 *
 * Dart 是 `Timer.periodic(5s)`（`:38`），并且注释写明了「再快就是纯浪费，而且诊断页烧帧
 * 正是我们要抓的东西」——这里沿用 5 秒，不做更勤的轮询。
 *
 * ## 探针挂载
 *
 * 首次组合时 `attach(context)` 一次（幂等）——这是**兜底**：壳在 Activity 起来时就已
 * `PerfProbe.attach(this)`（`PagesShellActivity.kt:125`），并每次换页
 * `PerfProbe.beginPage(pageId)`（`ShellPageIndex.kt` 的 `LaunchedEffect(pageId)`），
 * 所以「其它页面」的帧与 CPU/RSS 也记在各自页名下，不会全堆进 `boot` 行。
 *
 * 正式包里 [PerfProbe.attach] 返回 false，页面因此走 Dart 同款
 * 「Probe is not installed in this build.」说明文案，不会用空数据糊住。
 */
@Composable
fun PerfReportHost(onBack: () -> Unit) {
    val context = LocalContext.current

    // 在**组合期**装一次（`remember` 的 lambda 在首次组合时同步执行）。
    // 放在 DisposableEffect 里会晚一拍：同一帧读到的 isInstalled 还是 false，
    // 正式包永远显示「未安装」、诊断包要多等一个刷新周期才出数。
    val installed = remember(context) {
        PerfProbe.attach(context)
        PerfProbe.isInstalled
    }

    // 刷新心跳（Dart `_refreshInterval`，`:38`）。
    var tick by remember { mutableIntStateOf(0) }
    var showRaw by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(REFRESH_INTERVAL_MILLIS)
            tick++
        }
    }

    fun toast(message: String, description: String? = null) {
        val text = if (description.isNullOrEmpty()) message else "$message\n$description"
        Toast.makeText(context, text, Toast.LENGTH_SHORT).show()
    }

    fun copyToClipboard(text: String) {
        val manager = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        manager?.setPrimaryClip(ClipData.newPlainText(PerfReportStrings.pageTitle, text))
        toast(PerfReportStrings.toastCopied)
    }

    // `tick` 或探针可用性变化时重读一次快照（与 Dart `_reload()` 同一个位置）。
    val snapshot = remember(tick, installed) {
        if (installed) PerfProbe.snapshotJson() else null
    }
    val viewState = remember(snapshot, showRaw) {
        buildPerfReportViewState(
            snapshot = snapshot,
            showRaw = showRaw,
            observedFrames = PerfProbe.observedFrames(),
        )
    }
    // 展开时才取文本：不展开就没人看，没必要每次刷新都拼一遍整表。
    val rawReportText = remember(tick, showRaw, installed) {
        if (showRaw && installed) PerfProbe.reportText() else ""
    }

    PerfReportPage(
        viewState = viewState,
        onBack = onBack,
        onRefresh = { tick++ },
        onExport = {
            val path = PerfProbe.exportSnapshot(context)
            toast(
                message = if (path == null) {
                    PerfReportStrings.toastExportFailed
                } else {
                    PerfReportStrings.toastExported
                },
                description = path,
            )
        },
        onClearLedger = {
            PerfProbe.reset()
            tick++
            toast(PerfReportStrings.toastLedgerCleared)
        },
        onToggleRaw = { showRaw = !showRaw },
        onCopyTextReport = { copyToClipboard(PerfProbe.reportText()) },
        onCopyJson = {
            val current = snapshot ?: PerfProbe.snapshotJson()
            copyToClipboard(perfSnapshotJsonText(current))
        },
        rawReportText = rawReportText,
    )
}

/** Dart `_refreshInterval = Duration(seconds: 5)`。 */
private const val REFRESH_INTERVAL_MILLIS = 5_000L
