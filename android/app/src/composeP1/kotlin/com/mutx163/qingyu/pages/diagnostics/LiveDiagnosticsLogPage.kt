package com.mutx163.qingyu.pages.diagnostics

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
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
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuEmptyState
import com.mutx163.qingyu.components.QingyuGlassIconButton
import com.mutx163.qingyu.components.QingyuLoadingCenter
import com.mutx163.qingyu.components.QingyuLoadingInline
import com.mutx163.qingyu.components.QingyuLoadingSlot
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.infra.DiagnosticsLogLevel
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.BasicComponent
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
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
import top.yukonga.miuix.kmp.overlay.OverlayDialog
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
    /**
     * 列表状态由宿主持有：宿主用它做三件 Dart 侧有、渲染层做不了的事——
     * 贴最新端判定（`_syncStickToLatest` 382-400 行）、自动滚到最新端
     * （`_scheduleAutoScroll` 402-444 行）、「加载更早」后的视口锚定
     * （`_loadEarlierEntriesWithAnchor` 872-911 行）。
     */
    listState: LazyListState = rememberLazyListState(),
) {
    val dark = isSystemInDarkTheme()
    // 弹层显隐是纯 UI 状态（Dart 用 showHyperosSheet），不属于模型层。
    var showOptions by remember { mutableStateOf(false) }
    // 清空确认：Dart 的 `_clearLogs`（1001-1037 行）是点了就清、没有二次确认。
    // 本批按任务书要求加了确认步，避免误触把用户排查现场清掉（处置见 _DIAG-log-gaps.md）。
    var showClearConfirm by remember { mutableStateOf(false) }

    // 顶栏变体：Dart 侧 live_diagnostics_log_viewer_screen.dart 也是 HyperosSubpage，但显式写了
    // collapsibleLargeTitle: false（:481，日志页顶部有一段不动的死区）⇒ 对应官方 SmallTopAppBar，
    // 单行小标题、本来就没有大标题可收。
    // 所以必须走 `QingyuPageScaffold(smallTopBar = true)`：默认变体（可折叠大标题）
    // 会凭空长出一个 32sp 大标题，也会让 `PageScaffoldGuardTest` 变红。
    QingyuPageScaffold(
        title = viewState.title,
        onBack = onBack,
        smallTopBar = true,
        // 右上动作键与左上返回键同一套外观：共享玻璃圆底 + 细边 + 小外浮影
        //（门控：内容压到顶栏带下面才出圆底，静止是裸图标——与返回键同一个信号）。
        actions = {
            if (viewState.loadError == null) {
                QingyuGlassIconButton(
                    onClick = { showOptions = true },
                    contentDescription = DiagnosticsStrings.diagnosticsDisplayOptionsTitle.text,
                    icon = MiuixIcons.Tune,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                )
                QingyuGlassIconButton(
                    onClick = onCopy,
                    contentDescription = DiagnosticsStrings.appLogsCopyAction.text,
                    icon = MiuixIcons.Copy,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                    enabled = viewState.canCopy,
                )
                QingyuGlassIconButton(
                    onClick = onExport,
                    contentDescription = DiagnosticsStrings.appLogsExportAction.text,
                    icon = MiuixIcons.Share,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                    enabled = viewState.canExport,
                ) {
                    // 导出中换成进度圈（Dart `_buildHeaderActions` 516-525 行：
                    // `_exporting ? HyperosCircularProgress(18) : Icon(ios_share)`）。
                    if (viewState.isExporting) {
                        // 档 B2（D1 统一）：图标位替换 18dp / 2dp，**不传 tint**——发布版这里是裸
                        // `HyperosCircularProgress(18, 2)`，走 miuix 默认主色；套件 KDoc 口径同此。
                        QingyuLoadingInline(slot = QingyuLoadingSlot.IconSlot)
                    } else {
                        Icon(
                            imageVector = MiuixIcons.Share,
                            contentDescription = null,
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }
                }
                QingyuGlassIconButton(
                    onClick = { showClearConfirm = true },
                    contentDescription = DiagnosticsStrings.appLogsClearAction.text,
                    icon = MiuixIcons.Delete,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                    enabled = viewState.canClear,
                ) {
                    // 清空中同样换进度圈（Dart 526-532 行）。
                    if (viewState.isClearing) {
                        // 档 B2（D1 统一）：同上。
                        QingyuLoadingInline(slot = QingyuLoadingSlot.IconSlot)
                    } else {
                        Icon(
                            imageVector = MiuixIcons.Delete,
                            contentDescription = null,
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }
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

                viewState.isLoading -> QingyuLoadingCenter()

                viewState.isEmpty -> QingyuEmptyState(
                    icon = MiuixIcons.File,
                    title = DiagnosticsStrings.diagnosticsEmptyTitle.text,
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
                            text = DiagnosticsStrings.appLogsRecordingPausedHint.text,
                            style = MiuixTheme.textStyles.footnote1,
                            color = Color(QingyuTheme.secondaryText(dark)),
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
                        )
                    }

                    if (viewState.showNoMatching) {
                        QingyuEmptyState(
                            icon = MiuixIcons.Filter,
                            title = DiagnosticsStrings.diagnosticsNoMatchingTitle.text,
                        )
                    } else {
                        // 主滚动容器走官方配方的 QingyuPageList：三件套 + 右侧滚动条。
                        // 外层是 Column（筛选条固定在上），列表必须 weight(1f) 吃掉**剩余高度**，
                        // 否则 fillMaxSize 的列表会按整屏高度布局、底部一截被挤出屏幕 →
                        // 最后若干条日志永远滚不到可见区（“浏览不全”）。
                        DiagnosticsLogList(
                            viewState = viewState,
                            onLoadEarlier = onLoadEarlier,
                            onToggleEntry = onToggleEntry,
                            onToggleDeviceInfo = onToggleDeviceInfo,
                            dark = dark,
                            // 不接 scrollBehavior：小顶栏页（smallTopBar）不折叠，QingyuPageScaffold 的
                            // SmallTopAppBar 分支又没把 scrollBehavior 传给它 ⇒ 该 behavior 的
                            // heightOffsetLimit 保持默认 -Float.MAX，nestedScroll.onPreScroll 会把
                            // 一个方向的滚动整段吞掉（列表只能单向滚）。列表不挂它即恢复双向滚动。
                            listState = listState,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }
        }
    }

    QingyuSheet(
        show = showOptions,
        title = DiagnosticsStrings.diagnosticsDisplayOptionsTitle.text,
        onDismissRequest = { showOptions = false },
        // 内容自带 16dp（TabRow 的分段控件需要离面板边 16）：套件侧边距归零，避免叠成 32。
        contentPadsHorizontally = true,
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
                    DiagnosticsStrings.diagnosticsStructuredTab.text,
                    DiagnosticsStrings.diagnosticsRawTab.text,
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
                    DiagnosticsStrings.diagnosticsTimeSortAscending.text,
                    DiagnosticsStrings.diagnosticsTimeSortDescending.text,
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

    OverlayDialog(
        show = showClearConfirm,
        title = DiagnosticsStrings.appLogsClearAction.text,
        onDismissRequest = { showClearConfirm = false },
        // 内容自己写了左右 8dp；miuix 对话框默认 insideMargin 是 (24,24) ⇒ 合起来单边 32dp。
        // 横向给 8dp：8（框架）+ 8（内容）= **16dp**，正好是本仓 Dart 对话框的口径
        //（`docs/reference/changelog-2026-07-30-sheet-fixes.md`：`EdgeInsets.fromLTRB(16,16,16,16)`）。
        // 纵向内容无自带边距，直接给 16dp（与其他弹层一致，不再用 miuix 默认 24）。
        insideMargin = DpSize(8.dp, 16.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Button(
                onClick = { showClearConfirm = false },
                modifier = Modifier.weight(1f),
            ) {
                Text(text = DiagnosticsStrings.cancelAction.text)
            }
            Button(
                onClick = {
                    showClearConfirm = false
                    onClear()
                },
                modifier = Modifier.weight(1f),
                // 「确定」是出口：miuix `Button` 不传 colors 是 secondaryVariant 灰底，
                // 与 Dart 主按钮（强调色）不一致。
                colors = ButtonDefaults.buttonColorsPrimary(),
            ) {
                Text(text = DiagnosticsStrings.confirmAction.text)
            }
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
            // 档 B3（D1 统一）：行尾极小角标 14dp / 2dp。
            QingyuLoadingInline(slot = QingyuLoadingSlot.Badge)
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
            style = MiuixTheme.textStyles.footnote1.shiftWeight(
                if (chip.selected) QingyuWeightDelta.SEMIBOLD else 0,
            ),
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
    /**
     * 顶栏折叠行为。**日志页是 smallTopBar 页、不折叠**，调用方传 null；
     * 传了非 null 且其 `heightOffsetLimit` 未被 SmallTopAppBar 钉成 0 时，
     * `nestedScroll.onPreScroll` 会吞掉一个方向的列表滚动（只能单向滚）。
     */
    scrollBehavior: ScrollBehavior? = null,
    listState: LazyListState,
    modifier: Modifier = Modifier,
) {
    // 官方页面骨架（`QingyuPageList` 内含三件套与右侧滚动条）。
    // 横向留白由每张卡自己带 QingyuPageCardMargin，不塞进 contentPadding。
    QingyuPageList(
        innerPadding = PaddingValues(0.dp),
        modifier = modifier,
        state = listState,
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

        if (viewState.viewMode == DiagnosticsLogViewMode.RAW) {
            // 原文模式：一条是一整块可换行的原始文本，仍各自成卡——合并成一张卡反而看不出
            // 条目边界（原文里没有任何视觉锚点）。
            items(items = viewState.entries, key = { it.id }) { entry ->
                DiagnosticsRawEntryCard(entry = entry, dark = dark)
            }
        } else if (viewState.entries.isNotEmpty()) {
            // 结构化模式：**当前这一批日志并进一张卡**，条目之间用细线分隔（2026-11-08 用户口径）。
            // 一条一张卡时，8dp 的卡间缝把几条日志撑成几个独立胶囊，扫读时视线总被打断。
            item(key = "entry-group") {
                DiagnosticsEntryGroupCard(
                    entries = viewState.entries,
                    onToggleEntry = onToggleEntry,
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
        // P6-2（2026-11-10 评审）：本页四张卡圆角统一 24，对齐同域内存统计页
        // （`MemoryStatsPage` 的卡走 SettingsGroupCorner）；默认 16 在同域里会显得薄一档。
        cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
        onClick = onToggle,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = DiagnosticsStrings.diagnosticsDeviceInfoTitle.text,
                style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
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
            // Dart 展开态是 `Wrap` 里一串 `键: 值` 小胶囊（`_DiagnosticsHeaderRow`
            // 1215-1244 行），不是「左标签右值」的两列行——键长短不一时后者会留大片空白。
            DiagnosticsInfoChipFlow(rows = rows, dark = dark)
        }
    }
}

/** 设备信息展开后的胶囊流（Dart `Wrap(spacing: 8, runSpacing: 8)`）。 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DiagnosticsInfoChipFlow(
    rows: List<DiagnosticsKeyValueRow>,
    dark: Boolean,
) {
    FlowRow(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        rows.forEach { row ->
            Text(
                text = "${row.label}: ${row.value}",
                style = MiuixTheme.textStyles.footnote2,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(Color(QingyuTheme.rowHighlight(dark)))
                    .padding(horizontal = 8.dp, vertical = 4.dp),
            )
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
        cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
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
        cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
    ) {
        Text(
            text = entry.rawText,
            // Dart 原文模式是 `copyWith(fontFamily: 'monospace', height: 1.45)`
            //（`_buildRawView` 854-859 行）：原文里 `key=value` 的对齐靠等宽字体。
            // 行高不自己算倍数（会绕过字阶），沿用主题字号。
            style = MiuixTheme.textStyles.footnote1.copy(fontFamily = FontFamily.Monospace),
            color = Color(QingyuTheme.primaryText(dark)),
        )
    }
}

/**
 * 一组日志 = 一张卡（官方「一张 Card 里放多行」的分组用法）——行与行之间一条细线。
 *
 * 分隔线只用在**卡内部、行与行之间**；卡与卡之间仍由 12dp 外边距 + 8dp 卡间距分开。
 * 2026-11-08 用户口径：「同批日志并进一张卡加分隔线」——这里是给日志流补条目边界，
 * 与 2026-11-03 清掉的「设置卡里每两行都画线」不是同一种写法（豁免已在行间横线守卫里登记）。
 */
@Composable
private fun DiagnosticsEntryGroupCard(
    entries: List<DiagnosticsLogEntryView>,
    onToggleEntry: (String) -> Unit,
    dark: Boolean,
) {
    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = QingyuPageCardMargin),
        // 每行自带 14dp 内边距（BasicComponent 的 insideMargin），卡本身不再叠加一层。
        insideMargin = PaddingValues(0.dp),
        cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
    ) {
        entries.forEachIndexed { index, entry ->
            if (index > 0) {
                HorizontalDivider(
                    // 左侧让出 14dp，与行内文字的起始内边距对齐（分隔线不顶到卡片边缘）。
                    modifier = Modifier.padding(start = 14.dp),
                    color = MiuixTheme.colorScheme.dividerLine,
                )
            }
            DiagnosticsEntryRow(
                entry = entry,
                onToggle = { onToggleEntry(entry.id) },
                dark = dark,
            )
        }
    }
}

/**
 * 结构化模式：一条日志一行（官方 [BasicComponent] 行：自带按护反馈 / 点击指示 / 读屏按钮语义）。
 *
 * 折叠态 = 两行主次结构：第一行消息（最多两行），第二行小字「时间 · 等级 · 类别」。
 * 另写法把「时间 + 消息」拼成一行，400dp 屏上一半宽度被时间吃掉，消息只剩十几个字就省略。
 * 展开态在同一行里补来源 / 推断等级标签与详情键值，不再重复画一遍时间。
 */
@Composable
private fun DiagnosticsEntryRow(
    entry: DiagnosticsLogEntryView,
    onToggle: () -> Unit,
    dark: Boolean,
) {
    val levelColor = levelColor(entry.level, dark)

    BasicComponent(
        // 等级色点：折叠态只保留「一眼分辨级别」的语义。
        startAction = {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(levelColor),
            )
        },
        endActions = {
            Icon(
                imageVector = if (entry.isExpanded) MiuixIcons.ExpandLess else MiuixIcons.ChevronForward,
                contentDescription = null,
                tint = Color(QingyuTheme.actionIcon(dark)),
                modifier = Modifier.size(20.dp),
            )
        },
        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 10.dp),
        onClick = onToggle,
        role = Role.Button,
    ) {
        Text(
            text = entry.message.ifEmpty { entry.rawText },
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.primaryText(dark)),
            // 折叠态给两行：消息是主信息，不再和时间抢同一行的宽度。
            maxLines = if (entry.isExpanded) Int.MAX_VALUE else 2,
            overflow = TextOverflow.Ellipsis,
        )
        DiagnosticsEntryMetaLine(
            entry = entry,
            dark = dark,
            modifier = Modifier.padding(top = 2.dp),
        )
        if (entry.isExpanded) {
            DiagnosticsEntryBadgeRow(entry = entry, dark = dark)
            if (entry.detailRows.isNotEmpty()) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    entry.detailRows.forEach { row ->
                        DiagnosticsDetailBlock(label = row.label, value = row.value, dark = dark)
                    }
                }
            }
        }
    }
}

/** 行内副信息：时间 · 等级 · 类别（三段分开画，不在渲染层拼字符串）。 */
@Composable
private fun DiagnosticsEntryMetaLine(
    entry: DiagnosticsLogEntryView,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        entry.formattedTime?.let { time ->
            Text(
                text = time,
                style = MiuixTheme.textStyles.footnote2,
                color = Color(QingyuTheme.secondaryText(dark)),
                maxLines = 1,
            )
            DiagnosticsMetaDot(dark = dark)
        }
        Text(
            text = entry.levelLabel,
            style = MiuixTheme.textStyles.footnote2,
            color = Color(QingyuTheme.secondaryText(dark)),
            maxLines = 1,
        )
        if (entry.categoryLabel.isNotEmpty()) {
            DiagnosticsMetaDot(dark = dark)
            Text(
                text = entry.categoryLabel,
                style = MiuixTheme.textStyles.footnote2,
                color = Color(QingyuTheme.secondaryText(dark)),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f, fill = false),
            )
        }
    }
}

@Composable
private fun DiagnosticsMetaDot(dark: Boolean) {
    Text(
        text = "·",
        style = MiuixTheme.textStyles.footnote2,
        color = Color(QingyuTheme.secondaryText(dark)),
    )
}

/** 展开态补充标签：来源（原生 / 应用）与「推断等级」。等级、类别已在上面的副信息行。 */
@Composable
private fun DiagnosticsEntryBadgeRow(entry: DiagnosticsLogEntryView, dark: Boolean) {
    Row(
        modifier = Modifier.padding(top = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        DiagnosticsTag(label = entry.sourceLabel, outlined = true, dark = dark)
        if (entry.isLevelInferred) {
            DiagnosticsTag(
                label = DiagnosticsStrings.diagnosticsLevelInferred.text,
                outlined = true,
                dark = dark,
            )
        }
    }
}

/**
 * 详情键值块（Dart `_DiagnosticsDetailRow`，1404-1450 行）：**标签在上、值在下**，
 * 整块底色，值里含换行时切等宽字体。
 *
 * 之前这里画成「左标签 96dp + 右值」的两列行，与 Dart 的上下结构不一致；
 * 栈/异常这类长值在两列布局里会缩成很窄的一条。
 */
@Composable
private fun DiagnosticsDetailBlock(label: String, value: String, dark: Boolean) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(Color(QingyuTheme.rowHighlight(dark)))
            .padding(8.dp),
    ) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = Color(QingyuTheme.secondaryText(dark)),
        )
        Text(
            text = value,
            style = MiuixTheme.textStyles.footnote2,
            color = Color(QingyuTheme.primaryText(dark)),
            fontFamily = if (value.contains('\n')) FontFamily.Monospace else null,
            modifier = Modifier.padding(top = 4.dp),
        )
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
            text = DiagnosticsStrings.diagnosticsLoadFailedTitle.text,
            style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
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
                Text(text = DiagnosticsStrings.liveTestingRefreshAction.text)
            }
        }
    }
}

/** 中间空态（`viewState.isEmpty`）与「筛选后无匹配」共用 [QingyuEmptyState]（C 区统一，2026-11-10）。 */

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

// ── 预览 ──────────────────────────────────────────────────────────────────────
//
// 预览只做两件事：把「真实导出格式的原始日志」喂给真解析函数 `parseDiagnosticsLog`，
// 再交给真装配函数 `buildDiagnosticsLogViewState`。等级推断、等级芯片计数、时间格式化
// 全部由模型层算出来，预览里**不手写**一份假的计数或假的时间文本。
//
// 这两支函数在 `com.mutx163.qingyu.infra` / 同包模型文件里，本文件的 import 块按
// 预览约定只允许动三行（`Preview` / `QingyuPageTheme` / 总览的布局件），因此这里用
// 全限定名调用，避免为了预览而扩大 import 面。

/** 预览用的原始日志文本：首行标题 → `----` 分隔 → 键值条目，空行分条（与导出文件同格式）。 */
private val previewDiagnosticsRawLog: String = """
应用日志
----
time=1762574400000
category=live_update
level=info
message=超级岛已展开：高等数学 · 第 8 周 · 示例大学 A101

time=1762574460000
category=timetable
level=warn
message=课表快照缺少教室字段，已按空教室降级展示

time=1762574520000
category=live_update
level=error
message=超级岛通知投递失败：NoSuchElementException

time=1762574580000
category=diagnostics_log
level=debug
message=日志窗口重建：可见 4 条 / 总计 4 条
""".trimIndent()

/** 一档预览的视图状态；`name` 只用来给预览命名，不参与渲染。 */
private data class PreviewLogState(
    val name: String,
    val viewState: DiagnosticsLogViewState,
)

private fun previewLogStates(): List<PreviewLogState> = listOf(
    PreviewLogState(
        name = "有数据",
        viewState = com.mutx163.qingyu.infra.parseDiagnosticsLog(previewDiagnosticsRawLog).let { parsed ->
            buildDiagnosticsLogViewState(
                title = "应用日志",
                parsed = parsed,
                viewport = DiagnosticsLogViewport(),
            )
        },
    ),
    PreviewLogState(
        name = "空日志",
        viewState = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = com.mutx163.qingyu.infra.parseDiagnosticsLog(""),
            viewport = DiagnosticsLogViewport(),
        ),
    ),
    PreviewLogState(
        name = "加载中",
        viewState = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = com.mutx163.qingyu.infra.parseDiagnosticsLog(""),
            viewport = DiagnosticsLogViewport(),
            isInitializing = true,
        ),
    ),
    PreviewLogState(
        name = "失败",
        viewState = buildDiagnosticsLogViewState(
            title = "应用日志",
            parsed = com.mutx163.qingyu.infra.parseDiagnosticsLog(""),
            viewport = DiagnosticsLogViewport(),
            loadError = "读取日志失败：文件已被系统清理",
        ),
    ),
)

private fun previewLogState(name: String): PreviewLogState =
    previewLogStates().first { it.name == name }

/** 一档预览的公共身体：视图状态 + 外观档位。 */
@Composable
private fun PreviewDiagnosticsLogBody(
    state: PreviewLogState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        LiveDiagnosticsLogPage(
            viewState = state.viewState,
            onBack = {},
            onSelectLevel = {},
            onLoadEarlier = {},
            onToggleEntry = {},
            onToggleDeviceInfo = {},
            onViewModeChange = {},
            onTimeSortChange = {},
            onCopy = {},
            onExport = {},
            onClear = {},
        )
    }
}

// ── 单档：四态 × 亮色 ─────────────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 有数据", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewDiagnosticsLogData() {
    PreviewDiagnosticsLogBody(previewLogState("有数据"))
}

@Suppress("unused")
@Preview(name = "2 空日志", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewDiagnosticsLogEmpty() {
    PreviewDiagnosticsLogBody(previewLogState("空日志"))
}

@Suppress("unused")
@Preview(name = "3 加载中", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewDiagnosticsLogLoading() {
    PreviewDiagnosticsLogBody(previewLogState("加载中"))
}

@Suppress("unused")
@Preview(name = "4 失败", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewDiagnosticsLogError() {
    PreviewDiagnosticsLogBody(previewLogState("失败"))
}

// ── 单档：外观两档（以「有数据」为基准）──────────────────────────────────────

@Suppress("unused")
@Preview(name = "5 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewDiagnosticsLogDark() {
    PreviewDiagnosticsLogBody(previewLogState("有数据"), dark = true)
}

@Suppress("unused")
@Preview(name = "6 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewDiagnosticsLogLargeText() {
    PreviewDiagnosticsLogBody(previewLogState("有数据"), textScale = 1.3f)
}

// ── 整页档：一屏（900）放不下，验日志正文条目与各块不被裁 ─────────────────────

@Suppress("unused")
@Preview(name = "7 整页 1400", showBackground = true, widthDp = 400, heightDp = 1400)
@Composable
private fun PreviewDiagnosticsLogFullPage() {
    PreviewDiagnosticsLogBody(previewLogState("有数据"))
}

// ── 总览：四态并排，一屏比结构差异 ───────────────────────────────────────────

/**
 * 一屏总览：四种状态横向并排，用来一眼比结构差异（谁多了 / 少了哪一块）。
 *
 * 4 × 400dp = 1600dp，画布给 1600dp；Studio 等比缩小显示，**缩放后字看不清是正常的**
 * ——要看细节点上面 1~6 的单档标签。
 */
@Suppress("unused")
@Preview(name = "0 总览·四态并排", showBackground = true, widthDp = 1600, heightDp = 900)
@Composable
private fun PreviewDiagnosticsLogOverview() {
    Row(
        modifier = Modifier.fillMaxSize(),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        for (state in previewLogStates()) {
            Box(Modifier.width(400.dp).fillMaxHeight()) {
                PreviewDiagnosticsLogBody(state)
            }
        }
    }
}
