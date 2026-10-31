package com.mutx163.qingyu.app

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.mutx163.qingyu.MemoryStatsCollector
import com.mutx163.qingyu.pages.diagnostics.DEFAULT_REFRESH_INTERVAL_SECONDS
import com.mutx163.qingyu.pages.diagnostics.MemoryStatsPage
import com.mutx163.qingyu.pages.diagnostics.MemoryStatsStrings
import com.mutx163.qingyu.pages.diagnostics.buildMemoryStatsViewState
import com.mutx163.qingyu.pages.diagnostics.memorySnapshotError
import com.mutx163.qingyu.pages.diagnostics.memorySnapshotJson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.LocalTime

/**
 * 内存统计页的**真实宿主**（取代壳里 `snapshot = null` + 4 个空 lambda 的静态占位）。
 *
 * ## 数据从哪来（不是示例常量）
 *
 * 直接调原生真采集器 [MemoryStatsCollector.buildSnapshot]，它返回的 `Map<String, Any?>`
 * 键名就是模型层 `buildMemoryStatsViewState(...)` 的入参约定（模型层 KDoc 已写明）：
 *
 * ```
 * generatedAtMillis / uptimeMillis / packageName / diagnosticsPackage
 * pressureLevel / pressureLabel / appState / appInForeground
 * app{totalPssKb, peakTotalPssKb, sampleCount, …}    javaHeap{allocBytes, usageRatio, nearOom, …}
 * debugMemoryInfo{…}   system{…}   imageCache{currentSizeBytes, maxSizeBytes, entryCount}
 * liveIsland{…}   fairMemory{…}
 * backgroundStats{…}   pssBreakdown{ordered, …}   analysis{bullets, cleanableEstimate, …}
 * memoryStats{…}   processes[…]   history[…]
 * ```
 *
 * Dart 侧走的是同一个函数（`MainActivity.kt:477-491` 的 `getMemorySnapshot` 通道 →
 * `MemoryStatsService.fetchSnapshot`），所以这里不是「另造一套解析」，是**同源**。
 *
 * ## 与 Dart 行为逐条对齐（`lib/screens/memory_stats_screen.dart`）
 *
 * | Dart | 这里的做法 |
 * |---|---|
 * | `initState` 立刻 `_refresh(showLoading: true)`（`:39`） | `LaunchedEffect(Unit)` 首帧就采一次 |
 * | 自动刷新 `Duration(seconds: 3)`（`:24`）的 `Timer.periodic`（`:40-45`） | `delay(DEFAULT_REFRESH_INTERVAL_SECONDS)` 循环 |
 * | 仅在 resumed 且开关打开时刷新（`:41`） | `LifecycleEventObserver` + `LaunchedEffect` 双门控 |
 * | `_refreshInFlight` 防重入（`:61-63`） | `inFlight` 门闩，手动与自动共用 |
 * | 手动刷新才显示 loading，自动刷新不动 loading（`:60-70`） | `refresh(showLoading = …)` 同口径 |
 * | 复制 JSON 用 `JsonEncoder.withIndent('  ')`（`:166`） | 模型层 [memorySnapshotJson]（2 空格缩进，手写、无第三方依赖） |
 * | 成功后 `_errorText = snapshot['error']`（`:80`） | [memorySnapshotError] |
 * | 异常 `error.toString()`（`:88`） | `catch (Exception)` → `error.toString()` |
 *
 * ## 线程
 *
 * `buildSnapshot` 里是 `Debug.getPss()` / `getProcessMemoryInfo` / `getRunningServices`
 * 这类系统调用（同步、几十毫秒级），所以一律在 [Dispatchers.IO] 上跑，
 * 完成后再把结果写回 Compose 状态。Dart 侧那次调用其实跑在 platform 主线程上，
 * 这里换个线程只是去掉卡顿，取数口径完全一样。
 *
 * ## 与 Dart 的一处刻意不同：没有 Flutter 运行时指标
 *
 * Dart 页面的「图片缓存」行读 `dartVm` / `flutterImageCache`（由 `MemoryStatsService.fetchSnapshot`
 * 从 Flutter 运行时补进快照，`:82-94`）。Compose 壳里没有 Flutter 运行时，那两行曾经恒为 `—`。
 * 2026-10-31 起页面改读采集器的 `imageCache` 块（[com.mutx163.qingyu.platform.AndroidImageLoader]
 * 的真实 LruCache，占用 / 上限 / 条目数），页面上不再有永远没有数的 Flutter 字段。
 *
 * ## 诚实边界
 *
 * - 原生采集器只在 `.debug` / `.profile` 包启动会话采样（`MemoryStatsCollector:65-68`），
 *   正式包里「会话采样历史」会是空的；这是采集器的既定口径，本页不改它。
 */
@Composable
fun MemoryStatsHost(
    onBack: () -> Unit,
    onOpenPerfReport: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val lifecycleOwner = LocalLifecycleOwner.current

    var snapshot by remember { mutableStateOf<Map<String, Any?>?>(null) }
    // Dart 的 `_loading` 初值就是 true（快照还没到手），这里保持一致。
    var isLoading by remember { mutableStateOf(true) }
    var errorText by remember { mutableStateOf<String?>(null) }
    var lastRefreshedAt by remember { mutableStateOf<LocalTime?>(null) }
    var autoRefreshEnabled by remember { mutableStateOf(true) }
    // 对应 Dart `_refreshInFlight`：手动刷新与自动刷新不能叠着跑。
    var inFlight by remember { mutableStateOf(false) }
    // 对应 Dart `_isAppResumed`：后台不刷（`:49-51`）。
    var resumed by remember {
        mutableStateOf(lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED))
    }

    fun refresh(showLoading: Boolean) {
        if (inFlight) return
        inFlight = true
        if (showLoading) {
            isLoading = true
            errorText = null
        }
        scope.launch {
            try {
                val next = withContext(Dispatchers.IO) {
                    MemoryStatsCollector.buildSnapshot(context.applicationContext)
                }
                snapshot = next
                errorText = memorySnapshotError(next)
                lastRefreshedAt = LocalTime.now()
            } catch (error: Exception) {
                // 取数失败不动旧快照：Dart 也是只改 `_loading` / `_errorText`。
                errorText = error.toString()
            } finally {
                isLoading = false
                inFlight = false
            }
        }
    }

    fun copyJson() {
        val current = snapshot ?: return
        val text = memorySnapshotJson(current)
        val manager = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        if (manager == null) {
            // 拿不到剪贴板就明说，不弹「已复制」——那是骗用户。
            Toast.makeText(context, MemoryStatsStrings.copiedJsonFailedToast, Toast.LENGTH_SHORT).show()
            return
        }
        manager.setPrimaryClip(ClipData.newPlainText(MemoryStatsStrings.pageTitle, text))
        Toast.makeText(context, MemoryStatsStrings.copiedJsonToast, Toast.LENGTH_SHORT).show()
    }

    // 首帧立刻采一次（Dart `:39` 的 `_refresh(showLoading: true)`）。
    LaunchedEffect(Unit) { refresh(showLoading = true) }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME -> {
                    resumed = true
                    // 回前台先补一次，免得停在「离开前的旧数」上（Dart 里靠 3 秒定时器很快追上）。
                    if (autoRefreshEnabled) refresh(showLoading = false)
                }
                Lifecycle.Event.ON_PAUSE -> resumed = false
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    LaunchedEffect(autoRefreshEnabled, resumed) {
        if (!autoRefreshEnabled || !resumed) return@LaunchedEffect
        while (true) {
            delay(DEFAULT_REFRESH_INTERVAL_SECONDS * 1000L)
            refresh(showLoading = false)
        }
    }

    MemoryStatsPage(
        viewState = buildMemoryStatsViewState(
            snapshot = snapshot,
            autoRefreshEnabled = autoRefreshEnabled,
            refreshIntervalSeconds = DEFAULT_REFRESH_INTERVAL_SECONDS,
            lastRefreshedAt = lastRefreshedAt,
            isLoading = isLoading,
            errorText = errorText,
        ),
        onBack = onBack,
        onRefresh = { refresh(showLoading = true) },
        onCopyJson = { copyJson() },
        onToggleAutoRefresh = { autoRefreshEnabled = it },
        onOpenPerfReport = onOpenPerfReport,
    )
}
