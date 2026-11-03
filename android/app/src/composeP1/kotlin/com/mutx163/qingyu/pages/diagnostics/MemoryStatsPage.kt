package com.mutx163.qingyu.pages.diagnostics

import androidx.compose.foundation.LocalIndication
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
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
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuSectionGap
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.BasicComponent
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.basic.ArrowRight
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
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.preference.SwitchPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 内存统计页 · Compose 渲染层（Phase 3.5 观感重构版）。
 *
 * 对应 Flutter `lib/screens/memory_stats_screen.dart`：
 * - 顶栏：返回 + 「内存统计」+ 立即刷新 / 复制 JSON；
 * - 运行概览：整包总 PSS 概览卡（点开应用总览弹层）+ 采样口径说明；
 * - 采样控制：自动刷新开关（含 Perf Report 入口）；
 * - 内存构成：Java 堆 / PSS 分类 / Debug.MemoryInfo / 图片缓存 / 系统内存；
 * - 运行环境：应用总览 / 前后台采样 / 超级岛服务 / 整包进程列表；
 * - 诊断工具：自动分析 / 采样历史 / memoryStats / 原始 JSON / 公平内存事件。
 *
 * ## 这一版按什么重构
 *
 * 2026-10-31：用户反馈「参数怎么都是统计 Flutter 的，现在都不是 Flutter 了」，并给了
 * 「视觉与组件按最新官方 demo 配方重写整页观感」。所以本次两件事一起做：
 *
 * 1. **去掉 Flutter 运行时指标**：原「Dart / Flutter 图片缓存」行与弹层里的
 *    `Dart RSS` / `Dart max RSS` 读的是 `dartVm` / `flutterImageCache`——那是 Flutter
 *    引擎通过通道补进快照的，Compose 壳里恒为 `—`。现在改读采集器新增的 `imageCache`
 *    块（[com.mutx163.qingyu.platform.AndroidImageLoader] 的真实 LruCache）。
 * 2. **观感换成官方 demo 配方**：一个分组 = 一个 `item`（`QingyuSectionTitle` → `QingyuCard`
 *    → 组内多行），卡片用设置组圆角 24dp，行用官方 `SwitchPreference` / `ArrowPreference`
 *    （行内 16dp、行尾读数 + 右箭头、官方按压反馈），而不是手搓 `Row`。
 *    出处：`docs/reference/miuix-demo/CHEATSHEET-Demo范例.md` §3.4 分组节奏表、
 *    `docs/reference/compose-page-style-rules.md` §三 标准配方。
 *
 * 取值与文案全部来自 [MemoryStatsViewState]（模型层算好），本文件只负责布局与回调；
 * 弹层显隐是纯 UI 状态。
 *
 * ## 与 Dart 的两处有意差异
 *
 * - **没有 Flutter 指标**（见上）；
 * - **原始 JSON 行的长按复制**：官方 `ArrowPreference` 没有长按回调（0.9.4
 *   `ArrowPreference.kt:49-62` 形参表只有 `onClick`），所以这一行照同族先例
 *   （`pages/task/TaskListPage.kt` 的 `TaskRowItem`、`pages/settings/SettingsPageRenderers.kt`
 *   的 `LongPressArrowRow`）用官方 `BasicComponent` + 外层 `combinedClickable`，
 *   外观仍是「行尾读数 + 右箭头」，**不是自研控件**。
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
    // Dart memory_stats_screen.dart 的 HyperosSubpage 标题是纯 Text ⇒ 可折叠大标题。
    var openSheet by remember { mutableStateOf<MemorySheet?>(null) }

    QingyuPageScaffold(
        title = MemoryStatsStrings.pageTitle,
        onBack = onBack,
        actions = {
            // Dart `:181-185`：加载中图标换成沙漏且**禁用**（`onPressed: _loading ? null : …`）。
            // miuix 没有沙漏图标，这里用同一处旋转进度替代「正在读」的语义，禁用条件照抄。
            IconButton(onClick = onRefresh, enabled = !viewState.isLoading) {
                if (viewState.isLoading) {
                    CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                } else {
                    Icon(
                        imageVector = MiuixIcons.Refresh,
                        contentDescription = MemoryStatsStrings.refreshTooltip,
                        tint = Color(QingyuTheme.actionIcon(dark)),
                    )
                }
            }
            IconButton(onClick = onCopyJson, enabled = viewState.hasSnapshot) {
                Icon(
                    imageVector = MiuixIcons.Copy,
                    contentDescription = MemoryStatsStrings.copyJsonTooltip,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                )
            }
        },
    ) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(bottom = QingyuSectionGap),
        ) {
            // ── 运行概览 ──
            item(key = "overview") {
                QingyuSectionTitle(MemoryStatsStrings.overviewSection)
                MemorySummaryCard(
                    viewState = viewState,
                    onClick = { openSheet = MemorySheet.OVERVIEW },
                    dark = dark,
                )
                SectionNote(
                    text = viewState.refreshDescription,
                    dark = dark,
                    withBottomGap = true,
                )
            }

            if (viewState.isLoading && !viewState.hasSnapshot) {
                item(key = "loading") {
                    MemoryHintBanner(
                        text = viewState.loadingHint,
                        isError = false,
                        showProgress = true,
                        dark = dark,
                    )
                }
            }
            viewState.errorText?.let { error ->
                item(key = "error") {
                    MemoryHintBanner(text = error, isError = true, showProgress = false, dark = dark)
                }
            }

            // ── 采样控制 ──
            item(key = "sampling") {
                QingyuSectionTitle(MemoryStatsStrings.samplingSection)
                QingyuCard(
                    modifier = Modifier.groupCard(withBottomGap = true),
                    cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
                ) {
                    val autoRefreshRow = viewState.samplingRows
                        .first { it.row == MemoryStatsRow.AUTO_REFRESH }
                    SwitchPreference(
                        title = autoRefreshRow.title,
                        summary = autoRefreshRow.subtitle,
                        checked = viewState.autoRefreshEnabled,
                        onCheckedChange = onToggleAutoRefresh,
                        startAction = {
                            MemoryStartIcon(
                                icon = MiuixIcons.Refresh,
                                tint = accentColor(autoRefreshRow.accent, viewState.pressure, dark),
                            )
                        },
                    )
                    // Dart `:242-254` 的 Perf Report 行；取值直接复用模型层的 samplingRows，
                    // 不在渲染层现拼一行（否则标题/副标题/语义色会和模型漂移）。
                    MemoryPreferenceRow(
                        row = viewState.samplingRows.first { it.row == MemoryStatsRow.PERF_REPORT },
                        pressure = viewState.pressure,
                        dark = dark,
                        onClick = onOpenPerfReport,
                    )
                }
            }

            // ── 内存构成 ──
            item(key = "composition") {
                QingyuSectionTitle(MemoryStatsStrings.compositionSection)
                QingyuCard(
                    modifier = Modifier.groupCard(withBottomGap = false),
                    cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
                ) {
                    viewState.compositionRows.forEachIndexed { index, row ->
                        MemoryPreferenceRow(
                            row = row,
                            pressure = viewState.pressure,
                            dark = dark,
                            onClick = { openSheet = sheetOf(row.row) },
                        )
                    }
                }
                SectionNote(
                    text = MemoryStatsStrings.compositionDescription,
                    dark = dark,
                    withBottomGap = true,
                )
            }

            // ── 运行环境 ──
            item(key = "environment") {
                QingyuSectionTitle(MemoryStatsStrings.environmentSection)
                QingyuCard(
                    modifier = Modifier.groupCard(withBottomGap = true),
                    cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
                ) {
                    viewState.environmentRows.forEachIndexed { index, row ->
                        MemoryPreferenceRow(
                            row = row,
                            pressure = viewState.pressure,
                            dark = dark,
                            onClick = { openSheet = sheetOf(row.row) },
                        )
                    }
                }
            }

            // ── 诊断工具 ──
            item(key = "tools") {
                QingyuSectionTitle(MemoryStatsStrings.toolsSection)
                QingyuCard(
                    modifier = Modifier.groupCard(withBottomGap = true),
                    cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
                ) {
                    viewState.toolRows.forEachIndexed { index, row ->
                        // Dart `:510-519`：「复制 / 查看原始 JSON」行没有快照时 onTap 为 null（不可点），
                        // 并且 `onLongPress: copyJson` —— 长按直接复制，不用先开弹层。
                        val isRawJson = row.row == MemoryStatsRow.RAW_JSON
                        val actionable = !isRawJson || viewState.hasSnapshot
                        MemoryPreferenceRow(
                            row = row,
                            pressure = viewState.pressure,
                            dark = dark,
                            enabled = actionable,
                            onClick = if (actionable) {
                                { openSheet = sheetOf(row.row) }
                            } else {
                                null
                            },
                            onLongPress = if (isRawJson && viewState.hasSnapshot) onCopyJson else null,
                        )
                    }
                }
            }
        }
    }

    val sheet = openSheet?.let { viewState.sheets[it] }
    // 弹层常驻组合：关闭只翻 `show`，正文用 remember 保留的最后一份非空快照渲染 ——
    // 否则 `openSheet` 置 null 的瞬间标题/正文/限高一起清空，退场动画播的是空板
    //（先例：.agents/notes/implemented/architecture/2026-11-02-settings-dialogs-persistent-composition.md）。
    var shownSheet by remember { mutableStateOf(sheet) }
    if (sheet != null) shownSheet = sheet
    val currentSheet = shownSheet
    QingyuSheet(
        show = sheet != null,
        title = currentSheet?.title,
        onDismissRequest = { openSheet = null },
        // 正文自己带 16dp（LazyColumn 的 contentPadding）⇒ 套件侧边距归零，避免叠成 32。
        contentPadsHorizontally = true,
        // 正文是 LazyColumn（自己管滚动）：套件不能再套 verticalScroll（嵌套滚动）。
        // 底部让位因此由正文自己落实 —— 见 [MemorySheetBody] 的 bottomInset 参数。
        contentScrolls = true,
        // Dart 每个弹层的限高比例不同（0.62 / 0.68 / 0.72）⇒ 走套件现成的限高参数，
        // 不在正文里再写一层 `heightIn`（两处限高会打架，且套件这边更清楚让位的落点）。
        maxHeightFraction = currentSheet?.let { sheetMaxHeightFraction(it) },
    ) {
        if (currentSheet != null) {
            MemorySheetBody(sheet = currentSheet, dark = dark, bottomInset = bottomInset)
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

/**
 * 分组卡的外边距：官方节奏表里「Card 外边距 12 + 下 12」。
 *
 * 与 `SmallTitle` 自带的 28dp 对齐（12 + Preference 自带 16），所以这里只加横向 12，
 * 不在 `QingyuPageList.contentPadding` 里再加左右边距（否则滚动条贴不到屏幕边）。
 */
private fun Modifier.groupCard(withBottomGap: Boolean): Modifier =
    fillMaxWidth()
        .padding(horizontal = QingyuPageCardMargin)
        .then(if (withBottomGap) Modifier.padding(bottom = QingyuSectionGap) else Modifier)

/** 分组卡下面的一句灰字（Dart `HyperosSectionDescription`）：整宽段落，允许折行。 */
@Composable
private fun SectionNote(text: String, dark: Boolean, withBottomGap: Boolean) {
    Text(
        text = text,
        style = MiuixTheme.textStyles.footnote1,
        color = Color(QingyuTheme.secondaryText(dark)),
        modifier = Modifier
            // 与分组标题的 28dp 轴线对齐（Card 外边距 12 + 行内 16）。
            .padding(horizontal = QingyuPageCardMargin + 16.dp)
            .then(if (withBottomGap) Modifier.padding(bottom = QingyuSectionGap) else Modifier),
    )
}

/** 运行概览卡：大数字总 PSS + 压力/前后台/峰值三段副标题。 */
@Composable
private fun MemorySummaryCard(
    viewState: MemoryStatsViewState,
    onClick: () -> Unit,
    dark: Boolean,
) {
    QingyuCard(
        modifier = Modifier.groupCard(withBottomGap = false),
        cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
        insideMargin = QingyuCardDefaults.ContentInsideMargin,
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp),
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
                    style = MiuixTheme.textStyles.title3.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                Text(
                    text = MemoryStatsStrings.summaryTitle,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.primaryText(dark)),
                    modifier = Modifier.padding(top = 2.dp),
                )
                Text(
                    text = viewState.summarySubtitle,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
        }
    }
}

/**
 * 一行设置项（Dart `HyperosListTile`）：图标 + 标题 + 可选副标题 + 行尾读数 + 右箭头。
 *
 * 默认走官方 [ArrowPreference]（行内 16dp、行尾读数、右箭头、官方按压反馈，全部免费）；
 * 只有需要长按的那一行（原始 JSON）才降级到 [BasicComponent] + 外层 `combinedClickable`，
 * 因为官方 [ArrowPreference] 没有长按回调（0.9.4 `:49-62`）。
 */
@Composable
private fun MemoryPreferenceRow(
    row: MemoryRowView,
    pressure: MemoryPressure,
    dark: Boolean,
    onClick: (() -> Unit)? = null,
    onLongPress: (() -> Unit)? = null,
    enabled: Boolean = true,
) {
    if (onLongPress == null) {
        ArrowPreference(
            title = row.title,
            summary = row.subtitle,
            onClick = onClick,
            enabled = enabled,
            startAction = {
                MemoryStartIcon(
                    icon = iconOf(row.row),
                    tint = accentColor(row.accent, pressure, dark),
                )
            },
            endActions = {
                if (row.details.isNotEmpty()) TrailingText(row.details)
            },
        )
        return
    }

    val interaction = remember { MutableInteractionSource() }
    BasicComponent(
        modifier = Modifier.combinedClickable(
            interactionSource = interaction,
            indication = LocalIndication.current,
            enabled = enabled,
            onClick = { onClick?.invoke() },
            onLongClick = onLongPress,
        ),
        title = row.title,
        summary = row.subtitle,
        startAction = {
            MemoryStartIcon(
                icon = iconOf(row.row),
                tint = accentColor(row.accent, pressure, dark),
            )
        },
        endActions = {
            if (row.details.isNotEmpty()) TrailingText(row.details)
            ArrowEndAction(enabled = enabled)
        },
        enabled = enabled,
        interactionSource = interaction,
    )
}

/** 行首图标：官方 demo 的 `startAction` 写法（图标 + 右侧 8dp 呼吸）。 */
@Composable
private fun MemoryStartIcon(icon: ImageVector, tint: Color) {
    Box(modifier = Modifier.padding(end = 8.dp)) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = tint,
            // 官方 demo 的 `Icon` 走默认 24dp；这里跟着 demo，不再自定字号/尺寸。
            modifier = Modifier.size(24.dp),
        )
    }
}

/** 行尾读数：与官方 demo 的 `endActions` 文本同口径（body2 字阶 + 次要色）。 */
@Composable
private fun TrailingText(text: String) {
    Text(
        text = text,
        style = MiuixTheme.textStyles.body2,
        color = MiuixTheme.colorScheme.onSurfaceVariantActions,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
    )
}

/**
 * 行尾右箭头：与官方 `ArrowPreference` 的 `ArrowPreferenceEndAction` 同尺寸同色
 * （10×16dp、`onSurfaceVariantActions` / 禁用 `disabledOnSecondaryVariant`）。
 * 官方那个是 `private`，长按行只能按同样口径画一次（同 `SettingsPageRenderers` 的先例）。
 */
@Composable
private fun RowScope.ArrowEndAction(enabled: Boolean) {
    Icon(
        imageVector = MiuixIcons.Basic.ArrowRight,
        contentDescription = null,
        tint = if (enabled) {
            MiuixTheme.colorScheme.onSurfaceVariantActions
        } else {
            MiuixTheme.colorScheme.disabledOnSecondaryVariant
        },
        modifier = Modifier
            .align(Alignment.CenterVertically)
            .size(width = 10.dp, height = 16.dp),
    )
}

/** 提示条：加载中 / 错误（Dart `HyperosHintBanner`）。 */
@Composable
private fun MemoryHintBanner(
    text: String,
    isError: Boolean,
    showProgress: Boolean,
    dark: Boolean,
) {
    QingyuCard(
        modifier = Modifier.groupCard(withBottomGap = true),
        cornerRadius = QingyuCardDefaults.Corner,
        insideMargin = QingyuCardDefaults.ContentInsideMargin,
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
                style = MiuixTheme.textStyles.footnote1,
                color = if (isError) {
                    Color(QingyuTheme.error(dark))
                } else {
                    Color(QingyuTheme.secondaryText(dark))
                },
            )
        }
    }
}

/**
 * 弹层正文的高度上限（Dart 各处 `MediaQuery.sizeOf(sheetContext).height * 0.62/0.68/0.72`）。
 *
 * 对应关系：键值表 `:683` 0.62、分类/进程/历史/memoryStats `:766/:835/:875/:803` 0.68、
 * 原始 JSON `:935` 0.72。现在交给 [QingyuSheet] 的 `maxHeightFraction`（套件先有这参数）。
 */
private fun sheetMaxHeightFraction(sheet: MemoryStatsSheet): Float = when (sheet.sheet) {
    MemorySheet.RAW_JSON -> 0.72f
    MemorySheet.PSS_BREAKDOWN,
    MemorySheet.PROCESS_LIST,
    MemorySheet.HISTORY,
    MemorySheet.MEMORY_STATS,
    -> 0.68f
    else -> 0.62f
}

/** 弹层内容：按 sheet 里填了哪块字段分别铺开（结构与 Dart `_showXxxSheet` 一一对应）。 */
@Composable
private fun MemorySheetBody(sheet: MemoryStatsSheet, dark: Boolean, bottomInset: Dp) {
    // Dart 每个弹层正文都是「限高 + 可滚动」（`SingleChildScrollView` + `ConstrainedBox`）。
    // 限高已交给 [QingyuSheet] 的 maxHeightFraction；这里用 LazyColumn 只承担**内部滚动**，
    // 不承担页面主滚动（主滚动仍是 QingyuPageList）——这是样式规则 R2 的弹层豁免口径。
    LazyColumn(
        modifier = Modifier.fillMaxWidth(),
        // 底部 = 原有 8dp + 套件给的让位（系统手势区 + 16）：让位必须落在**滚动内容**里，
        // 垫在滚动视口外面时那一截会永远空着（见 `QingyuSheet` KDoc 的 S2）。
        contentPadding = PaddingValues(
            start = 16.dp,
            top = 8.dp,
            end = 16.dp,
            bottom = 8.dp + bottomInset,
        ),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        sheet.description?.let { description ->
            item(key = "description") {
                Text(
                    text = description,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
        }

        sheet.emptyText?.let { empty ->
            item(key = "empty") {
                Text(
                    text = empty,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    textAlign = TextAlign.Start,
                )
            }
        }

        // 键值表：Dart `_KvTable` 是「左定宽 128」，行距由行自身 10dp 内边距承担。
        if (sheet.rows.isNotEmpty()) {
            item(key = "kv-rows") {
                Column(modifier = Modifier.fillMaxWidth()) {
                    sheet.rows.forEachIndexed { index, row ->
                        MemoryKvLine(label = row.label, value = row.value, dark = dark)
                    }
                }
            }
        }

        // 分析弹层：粗估 → 口径说明（Dart `:712-721`）→ 要点或空态。
        sheet.cleanableSummary?.let { summary ->
            item(key = "cleanable-summary") {
                Text(
                    text = summary,
                    style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                    color = Color(QingyuTheme.primaryText(dark)),
                )
            }
        }
        sheet.cleanableNote?.let { note ->
            item(key = "cleanable-note") {
                Text(
                    text = note,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
        }
        if (sheet.bullets.isNotEmpty()) {
            item(key = "bullets") {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    sheet.bullets.forEach { bullet ->
                        Row {
                            Text(
                                text = "· ",
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.secondaryText(dark)),
                            )
                            Text(
                                text = bullet,
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.primaryText(dark)),
                            )
                        }
                    }
                }
            }
        }

        if (sheet.breakdown.isNotEmpty()) {
            item(key = "breakdown") {
                Column(modifier = Modifier.fillMaxWidth()) {
                    sheet.breakdown.forEachIndexed { index, row ->
                        MemoryBreakdownItem(row = row, dark = dark)
                    }
                }
            }
        }

        if (sheet.processes.isNotEmpty()) {
            item(key = "processes") {
                Column(modifier = Modifier.fillMaxWidth()) {
                    sheet.processes.forEachIndexed { index, process ->
                        MemoryProcessItem(process = process, dark = dark)
                    }
                }
            }
        }

        sheet.historySummary?.let { summary ->
            item(key = "history-summary") {
                Text(
                    text = summary,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
            itemsIndexed(sheet.history, key = { _, row -> row.atMillis }) { index, row ->
                Text(
                    // 行文本由模型层的 `MemoryHistoryRow.lineText` 拼好（文案不落渲染层）。
                    text = row.lineText,
                    style = MiuixTheme.textStyles.footnote2,
                    fontFamily = FontFamily.Monospace,
                    color = Color(QingyuTheme.primaryText(dark)),
                    modifier = Modifier.padding(bottom = if (index == sheet.history.lastIndex) 0.dp else 8.dp),
                )
            }
        }

        sheet.bodyText?.let { body ->
            item(key = "body") {
                // memoryStats / 原始 JSON 都是「等宽原文」（Dart `fontFamily: 'monospace'`）。
                Text(
                    text = body,
                    style = MiuixTheme.textStyles.footnote2,
                    fontFamily = FontFamily.Monospace,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
            }
        }
    }
}

/** PSS 分类的一行（Dart `_BreakdownRow`：名称 + `PSS · 占比` + 可清性标签 + 释义）。 */
@Composable
private fun MemoryBreakdownItem(row: MemoryBreakdownRow, dark: Boolean) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = row.label,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.primaryText(dark)),
                modifier = Modifier.weight(1f),
            )
            Text(
                text = "${row.pssText} · ${row.ratioText}",
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.primaryText(dark)),
            )
        }
        // Dart `HyperosTag`：底色是同色 12% 透明，文字用语义色。
        Text(
            text = row.cleanableLabel,
            style = MiuixTheme.textStyles.footnote2,
            color = cleanableColor(row.cleanable, dark),
            modifier = Modifier
                .clip(RoundedCornerShape(6.dp))
                .background(cleanableColor(row.cleanable, dark).copy(alpha = 0.12f))
                .padding(horizontal = 6.dp, vertical = 2.dp),
        )
        if (row.meaning.isNotEmpty()) {
            Text(
                text = row.meaning,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
    }
}

/** 进程列表的一行（Dart `_ProcessRow`）。 */
@Composable
private fun MemoryProcessItem(process: MemoryProcessRow, dark: Boolean) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(
            text = process.name,
            style = MiuixTheme.textStyles.body2,
            color = Color(QingyuTheme.primaryText(dark)),
        )
        Text(
            // 行文本由模型层的 `MemoryProcessRow.detailLine` 拼好（文案不落渲染层）。
            text = process.detailLine,
            style = MiuixTheme.textStyles.footnote2,
            fontFamily = FontFamily.Monospace,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
    }
}

/** 弹层里的键值行（Dart `_KvTable` 的一行：左定宽 128 + 12 间隔 + 右值）。 */
@Composable
private fun MemoryKvLine(label: String, value: String, dark: Boolean) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.secondaryText(dark)),
            modifier = Modifier.width(128.dp),
        )
        Text(
            text = value,
            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
            color = Color(QingyuTheme.primaryText(dark)),
            modifier = Modifier.weight(1f),
        )
    }
}

/**
 * 行首图标语义色（Dart 每行的 `iconAccent`）。
 *
 * Dart 用的是 `HyperosIconColors.*` 彩豆 token，Compose 侧对应 [QingyuIconColors] 同名量。
 * [MemoryRowAccent.PRESSURE] 走 `_pressureColor`，只有分析行用。
 */
private fun accentColor(accent: MemoryRowAccent, pressure: MemoryPressure, dark: Boolean): Color =
    when (accent) {
        MemoryRowAccent.BLUE -> Color(QingyuIconColors.BLUE)
        MemoryRowAccent.GREEN -> Color(QingyuIconColors.GREEN)
        MemoryRowAccent.ORANGE -> Color(QingyuIconColors.ORANGE)
        MemoryRowAccent.PURPLE -> Color(QingyuIconColors.PURPLE)
        MemoryRowAccent.TEAL -> Color(QingyuIconColors.TEAL)
        MemoryRowAccent.RED -> Color(QingyuIconColors.RED)
        MemoryRowAccent.YELLOW -> Color(QingyuIconColors.YELLOW)
        MemoryRowAccent.INDIGO -> Color(QingyuIconColors.INDIGO)
        MemoryRowAccent.CYAN -> Color(QingyuIconColors.CYAN)
        MemoryRowAccent.PRESSURE -> pressureColor(pressure, dark)
    }

/**
 * 压力语义色（Dart `_pressureColor`，`memory_stats_screen.dart:953-960`）。
 *
 * Dart 用的是**图标彩豆 token**（`HyperosIconColors.red/orange/yellow/green`），
 * 不是写死的十六进制；所以这里走 [QingyuIconColors] 同名 token。
 */
private fun pressureColor(pressure: MemoryPressure, dark: Boolean): Color = when (pressure) {
    MemoryPressure.CRITICAL -> Color(QingyuTheme.error(dark))
    MemoryPressure.HIGH -> Color(QingyuIconColors.ORANGE)
    MemoryPressure.ELEVATED -> Color(QingyuIconColors.YELLOW)
    MemoryPressure.NORMAL -> Color(QingyuTheme.success(dark))
}

/**
 * 可清性语义色（Dart `_BreakdownRow`，`memory_stats_screen.dart:1081-1085`）。
 *
 * 同样按 Dart 走 token：部分可清 = `HyperosIconColors.orange`、不可清 = 次要文字、难清 = 错误色。
 */
private fun cleanableColor(cleanable: MemoryCleanability, dark: Boolean): Color = when (cleanable) {
    MemoryCleanability.PARTIAL -> Color(QingyuIconColors.ORANGE)
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
