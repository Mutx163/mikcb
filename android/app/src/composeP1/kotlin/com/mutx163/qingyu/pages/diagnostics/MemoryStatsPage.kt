package com.mutx163.qingyu.pages.diagnostics

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.SmallTitle
import top.yukonga.miuix.kmp.basic.Switch
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.Background
import top.yukonga.miuix.kmp.icon.extended.Copy
import top.yukonga.miuix.kmp.icon.extended.File
import top.yukonga.miuix.kmp.icon.extended.GridView
import top.yukonga.miuix.kmp.icon.extended.Image
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.Layers
import top.yukonga.miuix.kmp.icon.extended.ListView
import top.yukonga.miuix.kmp.icon.extended.MindMap
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.Phone
import top.yukonga.miuix.kmp.icon.extended.Promotions
import top.yukonga.miuix.kmp.icon.extended.RecordingTape
import top.yukonga.miuix.kmp.icon.extended.Refresh
import top.yukonga.miuix.kmp.icon.extended.Report
import top.yukonga.miuix.kmp.icon.extended.Stopwatch
import top.yukonga.miuix.kmp.icon.extended.Tune
import top.yukonga.miuix.kmp.overlay.OverlayBottomSheet

/**
 * 内存统计页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/memory_stats_screen.dart`：
 * - 顶栏：返回 + 「内存统计」+ 立即刷新 / 复制 JSON；
 * - 运行概览：总 PSS 概览卡（点开应用总览弹层）+ 采样口径说明；
 * - 采样控制：自动刷新开关（含 Perf Report 入口）；
 * - 内存构成：Java 堆 / PSS 分类 / Debug.MemoryInfo / 图片缓存 / 系统内存；
 * - 运行环境：应用总览 / 前后台采样 / 超级岛服务 / 整包进程列表；
 * - 诊断工具：自动分析 / 采样历史 / memoryStats / 原始 JSON / 公平内存事件。
 *
 * 所有取值与文案来自 [MemoryStatsViewState]（模型层算好），本文件只负责布局与回调；
 * 弹层显隐是纯 UI 状态。
 */
@Composable
fun MemoryStatsPage(
    viewState: MemoryStatsViewState,
    onBack: () -> Unit,
    onRefresh: () -> Unit,
    onCopyJson: () -> Unit,
    onToggleAutoRefresh: (Boolean) -> Unit,
    onOpenPerfReport: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    var openSheet by remember { mutableStateOf<MemorySheet?>(null) }

    Scaffold(containerColor = Color(QingyuTheme.scaffoldBackground(dark))) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(innerPadding),
        ) {
            TopAppBar(
                title = MemoryStatsStrings.pageTitle,
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = MiuixIcons.Back,
                            contentDescription = DiagnosticsStrings.closeAction.zh,
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }
                },
                actions = {
                    IconButton(onClick = onRefresh) {
                        Icon(
                            imageVector = MiuixIcons.Refresh,
                            contentDescription = MemoryStatsStrings.refreshTooltip,
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }
                    IconButton(onClick = onCopyJson, enabled = viewState.hasSnapshot) {
                        Icon(
                            imageVector = MiuixIcons.Copy,
                            contentDescription = MemoryStatsStrings.copyJsonTooltip,
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }
                },
            )

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                // ── 运行概览 ──
                item { SmallTitle(text = MemoryStatsStrings.overviewSection) }
                item {
                    MemorySummaryCard(
                        viewState = viewState,
                        onClick = { openSheet = MemorySheet.OVERVIEW },
                        dark = dark,
                    )
                }
                item {
                    Text(
                        text = viewState.refreshDescription,
                        fontSize = 12.sp,
                        lineHeight = 16.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        modifier = Modifier.padding(horizontal = 4.dp),
                    )
                }

                if (viewState.isLoading && !viewState.hasSnapshot) {
                    item {
                        MemoryHintBanner(
                            text = viewState.loadingHint,
                            isError = false,
                            showProgress = true,
                            dark = dark,
                        )
                    }
                }
                viewState.errorText?.let { error ->
                    item {
                        MemoryHintBanner(text = error, isError = true, showProgress = false, dark = dark)
                    }
                }

                // ── 采样控制 ──
                item { SmallTitle(text = MemoryStatsStrings.samplingSection) }
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(vertical = 4.dp),
                    ) {
                        MemorySwitchRow(
                            title = MemoryStatsStrings.autoRefreshTitle,
                            subtitle = viewState.samplingRows
                                .first { it.row == MemoryStatsRow.AUTO_REFRESH }
                                .subtitle.orEmpty(),
                            checked = viewState.autoRefreshEnabled,
                            onCheckedChange = onToggleAutoRefresh,
                            dark = dark,
                        )
                        HorizontalDivider(modifier = Modifier.padding(horizontal = 14.dp))
                        MemoryRowItem(
                            row = MemoryRowView(
                                row = MemoryStatsRow.PERF_REPORT,
                                title = MemoryStatsStrings.perfReportTitle,
                                details = "",
                                subtitle = MemoryStatsStrings.perfReportSubtitle,
                            ),
                            onClick = onOpenPerfReport,
                            dark = dark,
                        )
                    }
                }

                // ── 内存构成 ──
                item { SmallTitle(text = MemoryStatsStrings.compositionSection) }
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(vertical = 4.dp),
                    ) {
                        viewState.compositionRows.forEachIndexed { index, row ->
                            if (index > 0) {
                                HorizontalDivider(modifier = Modifier.padding(horizontal = 14.dp))
                            }
                            MemoryRowItem(row = row, onClick = { openSheet = sheetOf(row.row) }, dark = dark)
                        }
                    }
                }
                item {
                    Text(
                        text = MemoryStatsStrings.compositionDescription,
                        fontSize = 12.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        modifier = Modifier.padding(horizontal = 4.dp),
                    )
                }

                // ── 运行环境 ──
                item { SmallTitle(text = MemoryStatsStrings.environmentSection) }
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(vertical = 4.dp),
                    ) {
                        viewState.environmentRows.forEachIndexed { index, row ->
                            if (index > 0) {
                                HorizontalDivider(modifier = Modifier.padding(horizontal = 14.dp))
                            }
                            MemoryRowItem(row = row, onClick = { openSheet = sheetOf(row.row) }, dark = dark)
                        }
                    }
                }

                // ── 诊断工具 ──
                item { SmallTitle(text = MemoryStatsStrings.toolsSection) }
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(vertical = 4.dp),
                    ) {
                        viewState.toolRows.forEachIndexed { index, row ->
                            if (index > 0) {
                                HorizontalDivider(modifier = Modifier.padding(horizontal = 14.dp))
                            }
                            MemoryRowItem(row = row, onClick = { openSheet = sheetOf(row.row) }, dark = dark)
                        }
                    }
                }
            }
        }
    }

    val sheet = openSheet?.let { viewState.sheets[it] }
    OverlayBottomSheet(
        show = sheet != null,
        title = sheet?.title,
        onDismissRequest = { openSheet = null },
    ) {
        if (sheet != null) {
            MemorySheetBody(sheet = sheet, dark = dark)
        }
    }
}

/** 行 → 弹层映射（Perf Report 是独立页面，不在这里）。 */
private fun sheetOf(row: MemoryStatsRow): MemorySheet = when (row) {
    MemoryStatsRow.JAVA_HEAP -> MemorySheet.JAVA_HEAP
    MemoryStatsRow.PSS_BREAKDOWN -> MemorySheet.PSS_BREAKDOWN
    MemoryStatsRow.DEBUG_MEMORY -> MemorySheet.DEBUG_MEMORY
    MemoryStatsRow.IMAGE_CACHE -> MemorySheet.IMAGE_CACHE
    MemoryStatsRow.SYSTEM_MEMORY -> MemorySheet.SYSTEM_MEMORY
    MemoryStatsRow.APP_OVERVIEW -> MemorySheet.OVERVIEW
    MemoryStatsRow.BACKGROUND_SAMPLING -> MemorySheet.BACKGROUND
    MemoryStatsRow.LIVE_ISLAND -> MemorySheet.LIVE_ISLAND
    MemoryStatsRow.PROCESS_LIST -> MemorySheet.PROCESS_LIST
    MemoryStatsRow.ANALYSIS -> MemorySheet.ANALYSIS
    MemoryStatsRow.HISTORY -> MemorySheet.HISTORY
    MemoryStatsRow.MEMORY_STATS -> MemorySheet.MEMORY_STATS
    MemoryStatsRow.RAW_JSON -> MemorySheet.RAW_JSON
    MemoryStatsRow.FAIR_MEMORY -> MemorySheet.FAIR_MEMORY
    MemoryStatsRow.AUTO_REFRESH -> MemorySheet.OVERVIEW
    MemoryStatsRow.PERF_REPORT -> MemorySheet.OVERVIEW
}

/** 运行概览卡：大数字总 PSS + 压力/前后台/峰值三段副标题。 */
@Composable
private fun MemorySummaryCard(
    viewState: MemoryStatsViewState,
    onClick: () -> Unit,
    dark: Boolean,
) {
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(horizontal = 16.dp, vertical = 14.dp),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(
                imageVector = MiuixIcons.Stopwatch,
                contentDescription = null,
                tint = pressureColor(viewState.pressure, dark),
                modifier = Modifier.size(26.dp),
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = viewState.summaryText,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                Text(
                    text = MemoryStatsStrings.summaryTitle,
                    fontSize = 13.sp,
                    color = Color(QingyuTheme.primaryText(dark)),
                    modifier = Modifier.padding(top = 2.dp),
                )
                Text(
                    text = viewState.summarySubtitle,
                    fontSize = 12.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
        }
    }
}

/** 开关行（Dart `HyperosSwitchTile`）。 */
@Composable
private fun MemorySwitchRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    dark: Boolean,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            imageVector = MiuixIcons.Refresh,
            contentDescription = null,
            tint = Color(QingyuTheme.actionIcon(dark)),
            modifier = Modifier.size(20.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                fontSize = 16.sp,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Text(
                text = subtitle,
                fontSize = 12.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

/** 列表行（Dart `HyperosListTile`）：图标 + 标题 + 右侧取值 + 可选副标题。 */
@Composable
private fun MemoryRowItem(
    row: MemoryRowView,
    onClick: () -> Unit,
    dark: Boolean,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            imageVector = iconOf(row.row),
            contentDescription = null,
            tint = Color(QingyuTheme.actionIcon(dark)),
            modifier = Modifier.size(20.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = row.title,
                fontSize = 16.sp,
                color = Color(QingyuTheme.primaryText(dark)),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            row.subtitle?.let { subtitle ->
                Text(
                    text = subtitle,
                    fontSize = 12.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
        }
        if (row.details.isNotEmpty()) {
            Text(
                text = row.details,
                fontSize = 14.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/** 提示条：加载中 / 错误（Dart `HyperosHintBanner`）。 */
@Composable
private fun MemoryHintBanner(
    text: String,
    isError: Boolean,
    showProgress: Boolean,
    dark: Boolean,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            if (showProgress) {
                CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
            } else if (isError) {
                Icon(
                    imageVector = MiuixIcons.Report,
                    contentDescription = null,
                    tint = Color(QingyuTheme.error(dark)),
                    modifier = Modifier.size(18.dp),
                )
            }
            Text(
                text = text,
                fontSize = 13.sp,
                color = if (isError) {
                    Color(QingyuTheme.error(dark))
                } else {
                    Color(QingyuTheme.secondaryText(dark))
                },
            )
        }
    }
}

/** 弹层内容：按 sheet 里填了哪块字段分别铺开。 */
@Composable
private fun MemorySheetBody(sheet: MemoryStatsSheet, dark: Boolean) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        sheet.description?.let { description ->
            Text(
                text = description,
                fontSize = 12.sp,
                lineHeight = 16.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }

        sheet.emptyText?.let { empty ->
            Text(
                text = empty,
                fontSize = 13.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
                textAlign = TextAlign.Start,
            )
        }

        if (sheet.rows.isNotEmpty()) {
            sheet.rows.forEach { row ->
                MemoryKvLine(label = row.label, value = row.value, dark = dark)
            }
        }

        sheet.cleanableSummary?.let { summary ->
            Text(
                text = summary,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = Color(QingyuTheme.primaryText(dark)),
            )
        }
        sheet.bullets.forEach { bullet ->
            Row {
                Text(text = "· ", fontSize = 13.sp, color = Color(QingyuTheme.secondaryText(dark)))
                Text(
                    text = bullet,
                    fontSize = 13.sp,
                    lineHeight = 18.sp,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
            }
        }

        sheet.breakdown.forEach { row ->
            Column(
                modifier = Modifier.padding(vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = row.label,
                        fontSize = 15.sp,
                        color = Color(QingyuTheme.primaryText(dark)),
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        text = "${row.pssText} · ${row.ratioText}",
                        fontSize = 15.sp,
                        color = Color(QingyuTheme.primaryText(dark)),
                    )
                }
                Text(
                    text = row.cleanableLabel,
                    fontSize = 11.sp,
                    color = cleanableColor(row.cleanable, dark),
                )
                if (row.meaning.isNotEmpty()) {
                    Text(
                        text = row.meaning,
                        fontSize = 12.sp,
                        lineHeight = 16.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                    )
                }
            }
        }

        sheet.processes.forEach { process ->
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = process.name,
                    fontSize = 15.sp,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                Text(
                    // Dart：`pid=$pid  PSS=$pss  privateDirty=$privateDirty` + 主进程 / 疑似超级岛相关
                    text = "pid=${process.pidText}  PSS=${process.pssText}  " +
                        "privateDirty=${process.privateDirtyText}" +
                        (if (process.isMainProcess) "  ·主进程" else "") +
                        (if (process.likelyLiveIsland) "  ·疑似超级岛相关" else ""),
                    fontSize = 11.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
        }

        sheet.historySummary?.let { summary ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = summary,
                    fontSize = 12.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
            sheet.history.forEach { row ->
                Text(
                    // Dart：`${时间}  [$state]  PSS $pss  堆 $ratio  $live  压力 $level`
                    text = "${row.timeText}  [${row.stateLabel}]  PSS ${row.pssText}  " +
                        "堆 ${row.heapRatioText}  ${row.liveLabel}  压力 ${row.pressureLevel}",
                    fontSize = 11.sp,
                    lineHeight = 16.sp,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
            }
        }

        sheet.bodyText?.let { body ->
            Text(
                text = body,
                fontSize = 11.sp,
                lineHeight = 16.sp,
                color = Color(QingyuTheme.primaryText(dark)),
            )
        }
    }
}

/** 弹层里的键值行（Dart `_KvTable` 的一行）。 */
@Composable
private fun MemoryKvLine(label: String, value: String, dark: Boolean) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(Color(QingyuTheme.rowHighlight(dark)))
            .padding(horizontal = 8.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = label,
            fontSize = 12.sp,
            color = Color(QingyuTheme.secondaryText(dark)),
            modifier = Modifier.weight(1f),
        )
        Text(
            text = value,
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            color = Color(QingyuTheme.primaryText(dark)),
        )
    }
}

/** 压力语义色（Dart `_pressureColor`）：危急/偏高红橙、升高黄、正常绿。 */
private fun pressureColor(pressure: MemoryPressure, dark: Boolean): Color = when (pressure) {
    MemoryPressure.CRITICAL -> Color(QingyuTheme.error(dark))
    MemoryPressure.HIGH -> Color(0xFFFF9F0A)
    MemoryPressure.ELEVATED -> Color(0xFFFFD60A)
    MemoryPressure.NORMAL -> Color(QingyuTheme.success(dark))
}

/** 可清性语义色（Dart `_BreakdownRow`）：部分可清橙、不可清次要文字、难清红。 */
private fun cleanableColor(cleanable: MemoryCleanability, dark: Boolean): Color = when (cleanable) {
    MemoryCleanability.PARTIAL -> Color(0xFFFF9F0A)
    MemoryCleanability.NO -> Color(QingyuTheme.secondaryText(dark))
    MemoryCleanability.HARD -> Color(QingyuTheme.error(dark))
}

/** 行图标（对应 Dart 源里每行的 Material 图标语义）。 */
private fun iconOf(row: MemoryStatsRow): ImageVector = when (row) {
    MemoryStatsRow.AUTO_REFRESH -> MiuixIcons.Refresh
    MemoryStatsRow.PERF_REPORT -> MiuixIcons.Stopwatch
    MemoryStatsRow.JAVA_HEAP -> MiuixIcons.Layers
    MemoryStatsRow.PSS_BREAKDOWN -> MiuixIcons.GridView
    MemoryStatsRow.DEBUG_MEMORY -> MiuixIcons.Tune
    MemoryStatsRow.IMAGE_CACHE -> MiuixIcons.Image
    MemoryStatsRow.SYSTEM_MEMORY -> MiuixIcons.Phone
    MemoryStatsRow.APP_OVERVIEW -> MiuixIcons.ListView
    MemoryStatsRow.BACKGROUND_SAMPLING -> MiuixIcons.Background
    MemoryStatsRow.LIVE_ISLAND -> MiuixIcons.Promotions
    MemoryStatsRow.PROCESS_LIST -> MiuixIcons.MindMap
    MemoryStatsRow.ANALYSIS -> MiuixIcons.Report
    MemoryStatsRow.HISTORY -> MiuixIcons.RecordingTape
    MemoryStatsRow.MEMORY_STATS -> MiuixIcons.Notes
    MemoryStatsRow.RAW_JSON -> MiuixIcons.File
    MemoryStatsRow.FAIR_MEMORY -> MiuixIcons.Info
}
