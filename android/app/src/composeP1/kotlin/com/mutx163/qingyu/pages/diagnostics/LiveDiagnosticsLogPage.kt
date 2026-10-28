package com.mutx163.qingyu.pages.diagnostics

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
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
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.infra.DiagnosticsLogLevel
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.ScrollBehavior
import top.yukonga.miuix.kmp.basic.TabRow
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Copy
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.ExpandLess
import top.yukonga.miuix.kmp.icon.extended.ExpandMore
import top.yukonga.miuix.kmp.icon.extended.File
import top.yukonga.miuix.kmp.icon.extended.Filter
import top.yukonga.miuix.kmp.icon.extended.Help
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.ListView
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.Report
import top.yukonga.miuix.kmp.icon.extended.Share
import top.yukonga.miuix.kmp.icon.extended.Tune
import top.yukonga.miuix.kmp.overlay.OverlayBottomSheet
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 诊断日志查看器 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/live_diagnostics_log_viewer_screen.dart`：
 * - 顶栏：返回 + 标题（来自 viewState，如「应用日志」「超级岛日志」）+ 查看与排序 /
 *   复制 / 导出 / 清空四个动作（可用性由 viewState 的 canXxx 决定）；
 * - 头部：等级筛选芯片条（`全部 12` 这样带计数），解析中追加小进度圈；
 * - 列表：设备与导出信息卡（可展开）、「加载更早日志 剩余 N 条」入口行、
 *   日志条目（折叠一行 / 展开看时间、消息与详情键值）；
 * - 三态：加载中 / 暂无日志 / 当前筛选下没有日志；加载失败改用错误态并提供刷新；
 * - 「查看与排序」底部弹层：结构化/原文 + 正序/倒序。
 *
 * **不做业务计算**：条目顺序、分页窗口、计数、文案都来自 [DiagnosticsLogViewState]；
 * 这里只把状态画出来，并把点击换成回调。
 */
@Composable
fun LiveDiagnosticsLogPage(
    viewState: DiagnosticsLogViewState,
    onBack: () -> Unit,
    onSelectLevel: (DiagnosticsLogLevel) -> Unit,
    onLoadEarlier: () -> Unit,
    onToggleEntry: (String) -> Unit,
    onToggleDeviceInfo: () -> Unit,
    onViewModeChange: (DiagnosticsLogViewMode) -> Unit,
    onTimeSortChange: (DiagnosticsLogTimeSort) -> Unit,
    onCopy: () -> Unit,
    onExport: () -> Unit,
    onClear: () -> Unit,
    onRefresh: (() -> Unit)? = null,
) {
    val dark = isSystemInDarkTheme()
    // 弹层显隐是纯 UI 状态（Dart 用 showHyperosSheet），不属于模型层。
    var showOptions by remember { mutableStateOf(false) }

    // 顶栏变体：Dart 侧 live_diagnostics_log_viewer_screen.dart 也是 HyperosSubpage，但显式写了
    // collapsibleLargeTitle: false（:481，日志页顶部有一段不动的死区）⇒ 对应官方 SmallTopAppBar，
    // 单行小标题、本来就没有大标题可收。
    // 所以必须走 `QingyuPageScaffold(smallTopBar = true)`：默认变体（可折叠大标题）
    // 会凭空长出一个 32sp 大标题，也会让 `PageScaffoldGuardTest` 变红。
    QingyuPageScaffold(
        title = viewState.title,
        onBack = onBack,
        smallTopBar = true,
        actions = {
            if (viewState.loadError == null) {
                IconButton(onClick = { showOptions = true }) {
                    Icon(
                        imageVector = MiuixIcons.Tune,
                        contentDescription = DiagnosticsStrings.diagnosticsDisplayOptionsTitle.zh,
                        tint = Color(QingyuTheme.actionIcon(dark)),
                    )
                }
                IconButton(onClick = onCopy, enabled = viewState.canCopy) {
                    Icon(
                        imageVector = MiuixIcons.Copy,
                        contentDescription = DiagnosticsStrings.appLogsCopyAction.zh,
                        tint = Color(QingyuTheme.actionIcon(dark)),
                    )
                }
                IconButton(onClick = onExport, enabled = viewState.canExport) {
                    Icon(
                        imageVector = MiuixIcons.Share,
                        contentDescription = DiagnosticsStrings.appLogsExportAction.zh,
                        tint = Color(QingyuTheme.actionIcon(dark)),
                    )
                }
                IconButton(onClick = onClear, enabled = viewState.canClear) {
                    Icon(
                        imageVector = MiuixIcons.Delete,
                        contentDescription = DiagnosticsStrings.appLogsClearAction.zh,
                        tint = Color(QingyuTheme.actionIcon(dark)),
                    )
                }
            }
        },
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                // 不手写 statusBarsPadding()：miuix Scaffold 的 contentWindowInsets
                // 默认含 systemBars 顶部，TopAppBar 自己也会加 systemBars.only(Top)，
                // 再写一次是第三次叠加，标题会下移一个多状态栏高（2026-10-27）。
                // 内边距在这里一次性吃掉，所以下面给列表传 0，避免顶/底叠加两次。
                .padding(innerPadding),
        ) {
            when {
                viewState.loadError != null -> DiagnosticsLoadErrorBody(
                    error = viewState.loadError,
                    onRefresh = onRefresh,
                    dark = dark,
                )

                viewState.isLoading -> Column(
                    modifier = Modifier.fillMaxSize(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    CircularProgressIndicator()
                }

                viewState.isEmpty -> DiagnosticsCenteredState(
                    icon = MiuixIcons.File,
                    title = DiagnosticsStrings.diagnosticsEmptyTitle.zh,
                    dark = dark,
                )

                else -> {
                    // 等级筛选条固定在列表上方（Dart 侧它在 headerExtension 里，
                    // 属于固定头部，不随日志列表滚动）。
                    DiagnosticsLevelFilterBar(
                        chips = viewState.levelChips,
                        isParsing = viewState.isParsing,
                        onSelectLevel = onSelectLevel,
                        dark = dark,
                    )

                    if (viewState.showPausedHint) {
                        Text(
                            text = DiagnosticsStrings.appLogsRecordingPausedHint.zh,
                            style = MiuixTheme.textStyles.footnote1,
                            color = Color(QingyuTheme.secondaryText(dark)),
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
                        )
                    }

                    if (viewState.showNoMatching) {
                        DiagnosticsCenteredState(
                            icon = MiuixIcons.Filter,
                            title = DiagnosticsStrings.diagnosticsNoMatchingTitle.zh,
                            dark = dark,
                        )
                    } else {
                        // 主滚动容器走官方配方的 QingyuPageList：三件套 + 右侧滚动条。
                        DiagnosticsLogList(
                            viewState = viewState,
                            onLoadEarlier = onLoadEarlier,
                            onToggleEntry = onToggleEntry,
                            onToggleDeviceInfo = onToggleDeviceInfo,
                            dark = dark,
                            scrollBehavior = scrollBehavior,
                        )
                    }
                }
            }
        }
    }

    OverlayBottomSheet(
        show = showOptions,
        title = DiagnosticsStrings.diagnosticsDisplayOptionsTitle.zh,
        onDismissRequest = { showOptions = false },
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // 查看方式：结构化 / 原文（Dart 两个 tab）
            TabRow(
                tabs = listOf(
                    DiagnosticsStrings.diagnosticsStructuredTab.zh,
                    DiagnosticsStrings.diagnosticsRawTab.zh,
                ),
                selectedTabIndex = if (viewState.viewMode == DiagnosticsLogViewMode.STRUCTURED) 0 else 1,
                onTabSelected = { index ->
                    val mode = if (index == 0) {
                        DiagnosticsLogViewMode.STRUCTURED
                    } else {
                        DiagnosticsLogViewMode.RAW
                    }
                    if (mode != viewState.viewMode) onViewModeChange(mode)
                },
            )
            // 时间排序：正序 / 倒序（Dart 第二个分段控件）
            TabRow(
                tabs = listOf(
                    DiagnosticsStrings.diagnosticsTimeSortAscending.zh,
                    DiagnosticsStrings.diagnosticsTimeSortDescending.zh,
                ),
                selectedTabIndex = if (viewState.timeSort == DiagnosticsLogTimeSort.ASCENDING) 0 else 1,
                onTabSelected = { index ->
                    val sort = if (index == 0) {
                        DiagnosticsLogTimeSort.ASCENDING
                    } else {
                        DiagnosticsLogTimeSort.DESCENDING
                    }
                    if (sort != viewState.timeSort) onTimeSortChange(sort)
                },
            )
        }
    }
}

/** 等级筛选芯片条（Dart `_buildLevelFilterBar`）。 */
@Composable
private fun DiagnosticsLevelFilterBar(
    chips: List<DiagnosticsLevelChip>,
    isParsing: Boolean,
    onSelectLevel: (DiagnosticsLogLevel) -> Unit,
    dark: Boolean,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            modifier = Modifier
                .horizontalScroll(rememberScrollState())
                .padding(end = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            chips.forEach { chip ->
                DiagnosticsFilterChip(
                    chip = chip,
                    onClick = { onSelectLevel(chip.level) },
                    dark = dark,
                )
            }
        }
        if (isParsing) {
            CircularProgressIndicator(modifier = Modifier.size(14.dp), strokeWidth = 2.dp)
        }
    }
}

@Composable
private fun DiagnosticsFilterChip(
    chip: DiagnosticsLevelChip,
    onClick: () -> Unit,
    dark: Boolean,
) {
    val background = if (chip.selected) {
        Color(QingyuTheme.primary(dark = dark)).copy(alpha = if (dark) 0.22f else 0.12f)
    } else {
        Color(QingyuTheme.card(dark))
    }
    val textColor = if (chip.selected) {
        Color(QingyuTheme.primary(dark = dark))
    } else {
        Color(QingyuTheme.secondaryText(dark))
    }

    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(background)
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = chip.label,
            style = MiuixTheme.textStyles.footnote1,
            fontWeight = if (chip.selected) FontWeight.SemiBold else FontWeight.Normal,
            color = textColor,
        )
    }
}

/** 日志列表：设备信息卡 + 加载更早入口 + 条目（原文模式直接铺原始块）。 */
@Composable
private fun DiagnosticsLogList(
    viewState: DiagnosticsLogViewState,
    onLoadEarlier: () -> Unit,
    onToggleEntry: (String) -> Unit,
    onToggleDeviceInfo: () -> Unit,
    dark: Boolean,
    scrollBehavior: ScrollBehavior,
    modifier: Modifier = Modifier,
) {
    // 官方页面骨架（`QingyuPageList` 内含三件套与右侧滚动条）。
    // 横向留白由每张卡自己带 QingyuPageCardMargin，不塞进 contentPadding。
    QingyuPageList(
        innerPadding = PaddingValues(0.dp),
        modifier = modifier,
        scrollBehavior = scrollBehavior,
        contentPadding = PaddingValues(top = 4.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (viewState.headerRows.isNotEmpty()) {
            item(key = "device-info") {
                DiagnosticsDeviceInfoCard(
                    rows = viewState.headerRows,
                    expanded = viewState.isDeviceInfoExpanded,
                    onToggle = onToggleDeviceInfo,
                    dark = dark,
                )
            }
        }

        // 正序时更早日志在上方，入口行放在条目之前；倒序时挂在末尾。
        val loadEarlierLabel = viewState.loadEarlierLabel
        if (loadEarlierLabel != null && viewState.latestAtBottom) {
            item(key = "load-earlier-top") {
                DiagnosticsLoadEarlierRow(
                    label = loadEarlierLabel,
                    expandingUp = true,
                    onClick = onLoadEarlier,
                    dark = dark,
                )
            }
        }

        items(items = viewState.entries, key = { it.id }) { entry ->
            if (viewState.viewMode == DiagnosticsLogViewMode.RAW) {
                DiagnosticsRawEntryCard(entry = entry, dark = dark)
            } else {
                DiagnosticsEntryCard(
                    entry = entry,
                    onToggle = { onToggleEntry(entry.id) },
                    dark = dark,
                )
            }
        }

        if (loadEarlierLabel != null && !viewState.latestAtBottom) {
            item(key = "load-earlier-bottom") {
                DiagnosticsLoadEarlierRow(
                    label = loadEarlierLabel,
                    expandingUp = false,
                    onClick = onLoadEarlier,
                    dark = dark,
                )
            }
        }
    }
}

/** 设备与导出信息（Dart `_DiagnosticsHeaderRow`）：点击展开成键值标签流。 */
@Composable
private fun DiagnosticsDeviceInfoCard(
    rows: List<DiagnosticsKeyValueRow>,
    expanded: Boolean,
    onToggle: () -> Unit,
    dark: Boolean,
) {
    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = QingyuPageCardMargin),
        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
        onClick = onToggle,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = DiagnosticsStrings.diagnosticsDeviceInfoTitle.zh,
                style = MiuixTheme.textStyles.body1,
                fontWeight = FontWeight.Medium,
                color = Color(QingyuTheme.primaryText(dark)),
                modifier = Modifier.weight(1f),
            )
            Icon(
                imageVector = if (expanded) MiuixIcons.ExpandLess else MiuixIcons.ExpandMore,
                contentDescription = null,
                tint = Color(QingyuTheme.actionIcon(dark)),
            )
        }
        if (expanded) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                rows.forEach { row ->
                    DiagnosticsTagRow(label = row.label, value = row.value, dark = dark)
                }
            }
        }
    }
}

/** 「加载更早日志 剩余 N 条」（Dart `_buildLoadEarlierRow`）。 */
@Composable
private fun DiagnosticsLoadEarlierRow(
    label: String,
    expandingUp: Boolean,
    onClick: () -> Unit,
    dark: Boolean,
) {
    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = QingyuPageCardMargin),
        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(
                imageVector = if (expandingUp) MiuixIcons.ExpandLess else MiuixIcons.ExpandMore,
                contentDescription = null,
                tint = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.size(18.dp),
            )
            Text(
                text = label,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            Icon(
                imageVector = MiuixIcons.ChevronForward,
                contentDescription = null,
                tint = Color(QingyuTheme.actionIcon(dark)),
            )
        }
    }
}

/** 原文模式：一条日志的原始文本块（Dart `_buildRawView`）。 */
@Composable
private fun DiagnosticsRawEntryCard(entry: DiagnosticsLogEntryView, dark: Boolean) {
    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = QingyuPageCardMargin),
        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Text(
            text = entry.rawText,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.primaryText(dark)),
        )
    }
}

/** 结构化模式：折叠一行 / 展开看详情（Dart `_DiagnosticsLogEntryTile`）。 */
@Composable
private fun DiagnosticsEntryCard(
    entry: DiagnosticsLogEntryView,
    onToggle: () -> Unit,
    dark: Boolean,
) {
    val levelColor = levelColor(entry.level, dark)

    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = QingyuPageCardMargin),
        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
        onClick = onToggle,
    ) {
        if (!entry.isExpanded) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(6.dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(levelColor),
                )
                Text(
                    text = entry.collapsedText,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.primaryText(dark)),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                Icon(
                    imageVector = MiuixIcons.ChevronForward,
                    contentDescription = null,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                )
            }
        } else {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Icon(
                        imageVector = levelIcon(entry.level),
                        contentDescription = null,
                        tint = levelColor,
                        modifier = Modifier.size(18.dp),
                    )
                    Row(
                        modifier = Modifier.weight(1f),
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        DiagnosticsTag(label = entry.levelLabel, outlined = true, dark = dark)
                        DiagnosticsTag(label = entry.sourceLabel, outlined = true, dark = dark)
                        if (entry.isLevelInferred) {
                            DiagnosticsTag(
                                label = DiagnosticsStrings.diagnosticsLevelInferred.zh,
                                outlined = true,
                                dark = dark,
                            )
                        }
                    }
                    Icon(
                        imageVector = MiuixIcons.ExpandLess,
                        contentDescription = null,
                        tint = Color(QingyuTheme.actionIcon(dark)),
                    )
                }

                if (entry.categoryLabel.isNotEmpty()) {
                    Text(
                        text = entry.categoryLabel,
                        style = MiuixTheme.textStyles.footnote1,
                        fontWeight = FontWeight.SemiBold,
                        color = Color(QingyuTheme.secondaryText(dark)),
                    )
                }
                entry.formattedTime?.let { time ->
                    Text(
                        text = time,
                        style = MiuixTheme.textStyles.footnote1,
                        color = Color(QingyuTheme.secondaryText(dark)),
                    )
                }
                if (entry.message.isNotEmpty()) {
                    Text(
                        text = entry.message,
                        style = MiuixTheme.textStyles.body2,
                        color = Color(QingyuTheme.primaryText(dark)),
                    )
                }
                if (entry.detailRows.isNotEmpty()) {
                    HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                    entry.detailRows.forEach { row ->
                        DiagnosticsTagRow(label = row.label, value = row.value, dark = dark)
                    }
                }
            }
        }
    }
}

/** 一枚标签样式的文字（Dart `HyperosTag`；Miuix 0.9.4 无对应组件，按页内样式画）。 */
@Composable
private fun DiagnosticsTag(label: String, outlined: Boolean, dark: Boolean) {
    val background = if (outlined) {
        Color.Transparent
    } else {
        Color(QingyuTheme.rowHighlight(dark))
    }
    val textColor = Color(QingyuTheme.secondaryText(dark))
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(background)
            .padding(horizontal = 6.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(text = label, style = MiuixTheme.textStyles.footnote2, color = textColor)
    }
}

/** 详情 / 设备信息的一行：左标签 + 右值（值里含换行时按原文铺）。 */
@Composable
private fun DiagnosticsTagRow(label: String, value: String, dark: Boolean) {
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
            style = MiuixTheme.textStyles.footnote2,
            fontWeight = FontWeight.SemiBold,
            color = Color(QingyuTheme.secondaryText(dark)),
            modifier = Modifier.width(96.dp),
        )
        Text(
            text = value,
            style = MiuixTheme.textStyles.footnote2,
            color = Color(QingyuTheme.primaryText(dark)),
            modifier = Modifier.weight(1f),
        )
    }
}

/** 加载失败态（Dart `_buildLoadError`）：错误态不复用空态标题。 */
@Composable
private fun DiagnosticsLoadErrorBody(
    error: String,
    onRefresh: (() -> Unit)?,
    dark: Boolean,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            imageVector = MiuixIcons.Report,
            contentDescription = null,
            tint = Color(QingyuTheme.error(dark)),
            modifier = Modifier.size(40.dp),
        )
        Text(
            text = DiagnosticsStrings.diagnosticsLoadFailedTitle.zh,
            style = MiuixTheme.textStyles.body1,
            fontWeight = FontWeight.Medium,
            color = Color(QingyuTheme.primaryText(dark)),
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 12.dp),
        )
        Text(
            text = error,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.secondaryText(dark)),
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 8.dp),
        )
        // 刷新按钮只在「一次性加载」模式下有意义（Dart 565 行同样的条件）。
        if (onRefresh != null) {
            Button(
                onClick = onRefresh,
                modifier = Modifier.padding(top = 16.dp),
            ) {
                Text(text = DiagnosticsStrings.liveTestingRefreshAction.zh)
            }
        }
    }
}

/** 居中空态 / 无匹配态。 */
@Composable
private fun DiagnosticsCenteredState(
    icon: ImageVector,
    title: String,
    dark: Boolean,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = Color(QingyuTheme.secondaryText(dark)),
            modifier = Modifier.size(40.dp),
        )
        Text(
            text = title,
            style = MiuixTheme.textStyles.body1,
            fontWeight = FontWeight.Medium,
            color = Color(QingyuTheme.primaryText(dark)),
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 12.dp),
        )
    }
}

/**
 * 警告档的固定琥珀色（0xFFFF9F0A）。
 *
 * Dart 侧 `_levelColor`（`live_diagnostics_log_viewer_screen.dart:1484`）对 warn 档**也是写死的**
 * `const Color(0xFFFF9F0A)`，不走主题 token——这是「与主题无关的固定语义色」：
 * 它表达的是日志级别，亮暗两种主题下都应当是同一档琥珀色。
 * 官方彩豆里没有同值 token（`QingyuIconColors.ORANGE` 是 0xFFFF6B00，改了就是改行为），
 * 而 Dart 是行为真相，所以这里逐通道构造保留原值，并集中成命名常量。
 */
private val LogWarnAmber = Color(red = 0xFF, green = 0x9F, blue = 0x0A)

/** 等级语义色（Dart `_levelColor` 1480-1489 行）。 */
private fun levelColor(level: DiagnosticsLogLevel, dark: Boolean): Color = when (level) {
    DiagnosticsLogLevel.ALL -> Color(QingyuTheme.primary(dark = dark))
    DiagnosticsLogLevel.ERROR -> Color(QingyuTheme.error(dark))
    DiagnosticsLogLevel.WARN -> LogWarnAmber
    DiagnosticsLogLevel.INFO -> Color(QingyuTheme.primary(dark = dark))
    DiagnosticsLogLevel.DEBUG -> Color(QingyuTheme.actionIcon(dark))
    DiagnosticsLogLevel.VERBOSE -> Color(QingyuTheme.secondaryText(dark))
}

/** 等级图标（Dart `_levelIcon` 1469-1478 行的 Miuix 近似物）。 */
private fun levelIcon(level: DiagnosticsLogLevel) = when (level) {
    DiagnosticsLogLevel.ALL -> MiuixIcons.ListView
    DiagnosticsLogLevel.ERROR -> MiuixIcons.Report
    DiagnosticsLogLevel.WARN -> MiuixIcons.Help
    DiagnosticsLogLevel.INFO -> MiuixIcons.Info
    DiagnosticsLogLevel.DEBUG -> MiuixIcons.Notes
    DiagnosticsLogLevel.VERBOSE -> MiuixIcons.File
}
