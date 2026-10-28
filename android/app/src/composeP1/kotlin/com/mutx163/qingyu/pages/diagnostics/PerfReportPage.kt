package com.mutx163.qingyu.pages.diagnostics

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.SmallTitle
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.Copy
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.File
import top.yukonga.miuix.kmp.icon.extended.Help
import top.yukonga.miuix.kmp.icon.extended.Layers
import top.yukonga.miuix.kmp.icon.extended.Refresh
import top.yukonga.miuix.kmp.icon.extended.Replace
import top.yukonga.miuix.kmp.icon.extended.Settings
import top.yukonga.miuix.kmp.icon.extended.Stopwatch
import top.yukonga.miuix.kmp.icon.extended.UploadCloud
import top.yukonga.miuix.kmp.basic.Text as MiuixText

/**
 * 性能报告页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/perf_report_screen.dart`：探针没装时只显示一段说明；
 * 装了则依次是 Totals 概览卡、Startup phases、Per-page ranking、Round control
 * （清空账本 / 展开原文 / 复制文本与 JSON），最后一段「energy 列是代理指标」的说明。
 *
 * 文案全英文（Dart 侧刻意如此，见 [PerfReportStrings] 注释）；取值与档位来自
 * [PerfReportViewState]，本文件不做业务计算。
 */
@Composable
fun PerfReportPage(
    viewState: PerfReportViewState,
    onBack: () -> Unit,
    onRefresh: () -> Unit,
    onExport: () -> Unit,
    onClearLedger: () -> Unit,
    onToggleRaw: () -> Unit,
    onCopyTextReport: () -> Unit,
    onCopyJson: () -> Unit,
    rawReportText: String = "",
    jsonSnapshotText: String = "",
) {
    val dark = isSystemInDarkTheme()
    // Dart perf_report_screen.dart 的 HyperosSubpage 标题是纯 Text ⇒ 可折叠大标题。
    val scrollBehavior = MiuixScrollBehavior()

    Scaffold(
        containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
        topBar = {
            TopAppBar(
                title = PerfReportStrings.pageTitle,
                largeTitle = PerfReportStrings.pageTitle,
                scrollBehavior = scrollBehavior,
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
                            contentDescription = PerfReportStrings.refreshTooltip,
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }
                    IconButton(onClick = onExport, enabled = viewState.isAvailable) {
                        Icon(
                            imageVector = MiuixIcons.UploadCloud,
                            contentDescription = PerfReportStrings.exportTooltip,
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }
                },
            )
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                // 不手写 statusBarsPadding()：miuix Scaffold 的 contentWindowInsets
                // 默认含 systemBars 顶部，TopAppBar 自己也会加 systemBars.only(Top)，
                // 再写一次是第三次叠加，标题会下移一个多状态栏高（2026-10-27）。
                .padding(innerPadding),
        ) {
            LazyColumn(
                modifier = Modifier.fillMaxSize().nestedScroll(scrollBehavior.nestedScrollConnection),
                contentPadding = PaddingValues(
                    start = 16.dp,
                    end = 16.dp,
                    bottom = innerPadding.calculateBottomPadding() + 24.dp,
                ),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                if (!viewState.isAvailable) {
                    item {
                        MiuixText(
                            text = viewState.notInstalledText,
                            fontSize = 13.sp,
                            lineHeight = 18.sp,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                    }
                    return@LazyColumn
                }

                // ── Totals ──
                item { SmallTitle(text = PerfReportStrings.totalsSection) }
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(horizontal = 16.dp, vertical = 14.dp),
                    ) {
                        MiuixText(
                            text = viewState.summaryText,
                            fontSize = 22.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                        MiuixText(
                            text = viewState.summaryTitle,
                            fontSize = 13.sp,
                            color = Color(QingyuTheme.primaryText(dark)),
                            modifier = Modifier.padding(top = 2.dp),
                        )
                        MiuixText(
                            text = viewState.summarySubtitle,
                            fontSize = 12.sp,
                            lineHeight = 16.sp,
                            color = Color(QingyuTheme.secondaryText(dark)),
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                }

                // ── Startup phases ──
                item { SmallTitle(text = PerfReportStrings.startupSection) }
                if (viewState.startupRows.isEmpty()) {
                    item {
                        SectionHint(text = viewState.noStartupText, dark = dark)
                    }
                } else {
                    item {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            insideMargin = PaddingValues(vertical = 4.dp),
                        ) {
                            viewState.startupRows.forEachIndexed { index, row ->
                                if (index > 0) {
                                    HorizontalDivider(modifier = Modifier.padding(horizontal = 14.dp))
                                }
                                PerfRow(
                                    icon = MiuixIcons.Stopwatch,
                                    title = row.phase,
                                    details = row.details,
                                    subtitle = row.subtitle,
                                    dark = dark,
                                )
                            }
                        }
                    }
                }

                // ── Per-page ranking ──
                item { SmallTitle(text = PerfReportStrings.pageSection) }
                if (viewState.pageRows.isEmpty()) {
                    item { SectionHint(text = viewState.noPagesText, dark = dark) }
                } else {
                    item {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            insideMargin = PaddingValues(vertical = 4.dp),
                        ) {
                            viewState.pageRows.forEachIndexed { index, row ->
                                if (index > 0) {
                                    HorizontalDivider(modifier = Modifier.padding(horizontal = 14.dp))
                                }
                                PerfRow(
                                    icon = verdictIcon(row.verdict),
                                    iconTint = accentColor(row.accent, dark),
                                    title = row.page,
                                    details = row.details,
                                    subtitle = row.subtitle,
                                    dark = dark,
                                )
                            }
                        }
                    }
                }

                // ── Round control ──
                item { SmallTitle(text = PerfReportStrings.roundSection) }
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(vertical = 4.dp),
                    ) {
                        PerfRow(
                            icon = MiuixIcons.Delete,
                            title = PerfReportStrings.clearLedger,
                            details = viewState.clearLedgerDetails,
                            subtitle = PerfReportStrings.clearLedgerHint,
                            onClick = onClearLedger,
                            dark = dark,
                        )
                        HorizontalDivider(modifier = Modifier.padding(horizontal = 14.dp))
                        PerfRow(
                            icon = MiuixIcons.File,
                            title = viewState.rawToggleText,
                            details = "",
                            subtitle = null,
                            onClick = onToggleRaw,
                            dark = dark,
                        )
                        if (viewState.rawReportVisible) {
                            HorizontalDivider(modifier = Modifier.padding(horizontal = 14.dp))
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 14.dp, vertical = 10.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                MiuixText(
                                    text = rawReportText,
                                    fontSize = 10.sp,
                                    lineHeight = 15.sp,
                                    color = Color(QingyuTheme.primaryText(dark)),
                                )
                                PerfRow(
                                    icon = MiuixIcons.Copy,
                                    title = PerfReportStrings.copyText,
                                    details = "",
                                    subtitle = null,
                                    onClick = onCopyTextReport,
                                    dark = dark,
                                )
                                PerfRow(
                                    icon = MiuixIcons.File,
                                    title = PerfReportStrings.copyJson,
                                    details = "",
                                    subtitle = null,
                                    onClick = onCopyJson,
                                    dark = dark,
                                )
                                if (jsonSnapshotText.isNotEmpty()) {
                                    MiuixText(
                                        text = jsonSnapshotText,
                                        fontSize = 10.sp,
                                        lineHeight = 15.sp,
                                        color = Color(QingyuTheme.secondaryText(dark)),
                                        maxLines = 12,
                                        overflow = TextOverflow.Ellipsis,
                                    )
                                }
                            }
                        }
                    }
                }

                // ── energy 列说明 ──
                item {
                    MiuixText(
                        text = viewState.energyNote,
                        fontSize = 12.sp,
                        lineHeight = 17.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
                    )
                }
            }
        }
    }
}

/** 分组里缺内容时的灰字提示。 */
@Composable
private fun SectionHint(text: String, dark: Boolean) {
    MiuixText(
        text = text,
        fontSize = 12.sp,
        color = Color(QingyuTheme.secondaryText(dark)),
        modifier = Modifier.padding(horizontal = 4.dp),
    )
}

/** 列表行：图标 + 标题 + 右侧值 + 可选副标题。 */
@Composable
private fun PerfRow(
    icon: ImageVector,
    title: String,
    details: String,
    subtitle: String?,
    dark: Boolean,
    iconTint: Color? = null,
    onClick: (() -> Unit)? = null,
) {
    val tint = iconTint ?: Color(QingyuTheme.actionIcon(dark))
    val content: @Composable () -> Unit = {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = tint,
                modifier = Modifier.size(20.dp),
            )
            Column(modifier = Modifier.weight(1f)) {
                MiuixText(
                    text = title,
                    fontSize = 16.sp,
                    color = Color(QingyuTheme.primaryText(dark)),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                subtitle?.let {
                    MiuixText(
                        text = it,
                        fontSize = 11.sp,
                        lineHeight = 15.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }
            }
            if (details.isNotEmpty()) {
                MiuixText(
                    text = details,
                    fontSize = 13.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
    if (onClick == null) {
        content()
    } else {
        QingyuCard(
            modifier = Modifier.fillMaxWidth(),
            insideMargin = PaddingValues(0.dp),
            onClick = onClick,
        ) {
            content()
        }
    }
}

/** 卡顿比例档位 → 颜色（Dart：≥25% 红、≥5% 黄、否则绿，省略即默认蓝）。 */
private fun accentColor(accent: PerfAccent, dark: Boolean): Color = when (accent) {
    PerfAccent.RED -> Color(QingyuTheme.error(dark))
    PerfAccent.YELLOW -> Color(0xFFFFD60A)
    PerfAccent.GREEN -> Color(QingyuTheme.success(dark))
    PerfAccent.DEFAULT -> Color(QingyuTheme.actionIcon(dark))
}

/** 卡在哪一线程 → 图标（Dart `_iconForVerdict`）。 */
private fun verdictIcon(verdict: PerfVerdict): ImageVector = when (verdict) {
    PerfVerdict.UI_BOUND -> MiuixIcons.Settings
    PerfVerdict.RASTER_BOUND -> MiuixIcons.Layers
    PerfVerdict.BOTH -> MiuixIcons.Replace
    PerfVerdict.UNKNOWN -> MiuixIcons.Help
}
