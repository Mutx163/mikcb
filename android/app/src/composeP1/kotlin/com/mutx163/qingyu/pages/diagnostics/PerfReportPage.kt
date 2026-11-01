package com.mutx163.qingyu.pages.diagnostics

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Copy
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.Download
import top.yukonga.miuix.kmp.icon.extended.File
import top.yukonga.miuix.kmp.icon.extended.Help
import top.yukonga.miuix.kmp.icon.extended.Layers
import top.yukonga.miuix.kmp.icon.extended.Refresh
import top.yukonga.miuix.kmp.icon.extended.Replace
import top.yukonga.miuix.kmp.icon.extended.Settings
import top.yukonga.miuix.kmp.icon.extended.Stopwatch
import top.yukonga.miuix.kmp.icon.extended.Tune
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.basic.Text as MiuixText

/**
 * 性能报告页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/perf_report_screen.dart`：探针没装时只显示一段说明；
 * 装了则依次是 Totals 概览卡、Startup phases、Per-page ranking、Round control
 * （清空账本 / 展开原文 / 复制文本与 JSON），最后一段「energy 列是代理指标」的说明。
 *
 * 骨架与滚动容器照 `docs/reference/compose-page-style-rules.md` §三 的标准配方
 *（[QingyuPageScaffold] + [QingyuPageList] + [QingyuCard] + [QingyuSectionTitle]）。
 *
 * 文案全英文（Dart 侧刻意如此，见 [PerfReportStrings] 注释）；取值与档位来自
 * [PerfReportViewState]，本文件不做业务计算。
 *
 * ## 与 Dart 的逐块对照（Dart 行号 → 本文件）
 *
 * | Dart | 本文件 |
 * |---|---|
 * | `HyperosSubpage(suffixes: 刷新 / 导出)`（`:101-115`） | [QingyuPageScaffold] 的 actions；导出在无快照时禁用 |
 * | 未安装说明（`:118-123`） | `not-installed` |
 * | `HyperosSectionLabel('Totals')` + `HyperosSummaryCard`（`:125-141`） | `totals-title` + [PerfIconBadge] + 三行文本 |
 * | `Startup phases`（`:144-162`） | `startup-*`，图标 teal |
 * | `Per-page ranking`（`:164-175`） | `page-*`，verdict 图标 + jank 档位色 |
 * | `Round control`（`:177-227`） | `round-card`：清空 / 展开 / 原文 / 复制文本 / 复制 JSON |
 * | energy 说明（`:229-239`） | `energy-note` |
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
) {
    val dark = isSystemInDarkTheme()
    // Dart perf_report_screen.dart 的 HyperosSubpage 标题是纯 Text ⇒ 可折叠大标题。
    QingyuPageScaffold(
        title = PerfReportStrings.pageTitle,
        onBack = onBack,
        actions = {
            IconButton(onClick = onRefresh) {
                Icon(
                    imageVector = MiuixIcons.Refresh,
                    contentDescription = PerfReportStrings.refreshTooltip,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                )
            }
            // Dart `:110-114`：`onPressed: snapshot == null ? null : _exportFiles`
            // ⇒ 没有快照时导出是禁用态，不是隐藏。
            IconButton(onClick = onExport, enabled = viewState.isAvailable) {
                Icon(
                    // Dart 是 `Icons.save_alt_rounded`（存盘），不是上传。
                    imageVector = MiuixIcons.Download,
                    contentDescription = PerfReportStrings.exportTooltip,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                )
            }
        },
    ) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            if (!viewState.isAvailable) {
                item(key = "not-installed") {
                    MiuixText(
                        text = viewState.notInstalledText,
                        style = MiuixTheme.textStyles.footnote1,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        // 与分组标题的 28dp 轴线对齐（Card 外边距 12 + 行内 16）。
                        modifier = Modifier.padding(horizontal = QingyuPageCardMargin + 16.dp),
                    )
                }
                return@QingyuPageList
            }

            // ── Totals ──
            item(key = "totals-title") { QingyuSectionTitle(PerfReportStrings.totalsSection) }
            item(key = "totals-card") {
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin),
                    insideMargin = PaddingValues(16.dp),
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        // Dart `:128`：`leading: HyperosIconBadge(icon: Icons.speed_rounded)`
                        // —— 26dp 实色圆角方块 + 14dp 白字形（`indicators.dart:143-166`）。
                        PerfIconBadge()
                        Column(modifier = Modifier.weight(1f)) {
                            MiuixText(
                                text = viewState.summaryText,
                                style = MiuixTheme.textStyles.title3.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                                color = Color(QingyuTheme.primaryText(dark)),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                            MiuixText(
                                text = viewState.summaryTitle,
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.primaryText(dark)),
                                modifier = Modifier.padding(top = 2.dp),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                            MiuixText(
                                // 判据三栏（budget / nominal / vsync）全部来自快照的 probe 块，
                                // 不是排行首行的副本；缺块时三栏都是 '?'。
                                text = viewState.summarySubtitle,
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.secondaryText(dark)),
                                modifier = Modifier.padding(top = 4.dp),
                            )
                        }
                    }
                }
            }

            // ── Startup phases ──
            item(key = "startup-title") { QingyuSectionTitle(PerfReportStrings.startupSection) }
            if (viewState.startupRows.isEmpty()) {
                item(key = "startup-empty") {
                    SectionHint(text = viewState.noStartupText, dark = dark)
                }
            } else {
                item(key = "startup-card") {
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin),
                        insideMargin = PaddingValues(vertical = 4.dp),
                    ) {
                        viewState.startupRows.forEachIndexed { index, row ->
                            if (index > 0) {
                                HorizontalDivider(modifier = Modifier.padding(horizontal = 14.dp))
                            }
                            PerfRow(
                                icon = MiuixIcons.Stopwatch,
                                // Dart `:155`：`iconAccent: HyperosIconColors.teal`
                                iconTint = Color(QingyuIconColors.TEAL),
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
            item(key = "page-title") { QingyuSectionTitle(PerfReportStrings.pageSection) }
            if (viewState.pageRows.isEmpty()) {
                item(key = "page-empty") { SectionHint(text = viewState.noPagesText, dark = dark) }
            } else {
                item(key = "page-card") {
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin),
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
            item(key = "round-title") { QingyuSectionTitle(PerfReportStrings.roundSection) }
            item(key = "round-card") {
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = QingyuPageCardMargin),
                    insideMargin = PaddingValues(vertical = 4.dp),
                ) {
                    PerfRow(
                        icon = MiuixIcons.Delete,
                        iconTint = Color(QingyuIconColors.ORANGE),
                        title = PerfReportStrings.clearLedger,
                        details = viewState.clearLedgerDetails,
                        subtitle = PerfReportStrings.clearLedgerHint,
                        onClick = onClearLedger,
                        dark = dark,
                    )
                    HorizontalDivider(modifier = Modifier.padding(horizontal = 14.dp))
                    PerfRow(
                        icon = MiuixIcons.File,
                        iconTint = Color(QingyuIconColors.INDIGO),
                        title = viewState.rawToggleText,
                        details = "",
                        subtitle = null,
                        onClick = onToggleRaw,
                        dark = dark,
                    )
                    if (viewState.rawReportVisible) {
                        HorizontalDivider(modifier = Modifier.padding(horizontal = 14.dp))
                        // Dart `:195-207`：`Padding(16,4,16,12)` 里放 `SelectableText`，
                        // monospace、`fontSize: 10`、`height: 1.45`。
                        // 字号走主题（R4 不许写死 sp），只把等宽字体与行距对齐。
                        SelectionContainer {
                            MiuixText(
                                text = rawReportText,
                                style = MiuixTheme.textStyles.footnote2.copy(
                                    fontFamily = FontFamily.Monospace,
                                    lineHeight = 15.sp,
                                ),
                                color = Color(QingyuTheme.primaryText(dark)),
                                modifier = Modifier.padding(
                                    start = 16.dp,
                                    top = 4.dp,
                                    end = 16.dp,
                                    bottom = 12.dp,
                                ),
                            )
                        }
                        Column(
                            modifier = Modifier.fillMaxWidth(),
                            verticalArrangement = Arrangement.spacedBy(0.dp),
                        ) {
                            PerfRow(
                                icon = MiuixIcons.Copy,
                                iconTint = Color(QingyuIconColors.BLUE),
                                title = PerfReportStrings.copyText,
                                details = "",
                                subtitle = null,
                                onClick = onCopyTextReport,
                                dark = dark,
                            )
                            HorizontalDivider(modifier = Modifier.padding(horizontal = 14.dp))
                            PerfRow(
                                icon = MiuixIcons.Tune,
                                iconTint = Color(QingyuIconColors.PURPLE),
                                title = PerfReportStrings.copyJson,
                                details = "",
                                subtitle = null,
                                onClick = onCopyJson,
                                dark = dark,
                            )
                        }
                    }
                }
            }

            // ── energy 列说明 ──
            item(key = "energy-note") {
                MiuixText(
                    text = viewState.energyNote,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.padding(
                        horizontal = QingyuPageCardMargin + 16.dp,
                        vertical = 8.dp,
                    ),
                )
            }
        }
    }
}

/**
 * Totals 卡的图标徽标（Dart `HyperosIconBadge`，`indicators.dart:143-166`）：
 * 26dp 实色蓝底 + 圆角 7 + 14dp 白字形。
 *
 * Dart 的 `Icons.speed_rounded` 在本仓 miuix 图标集里没有同名件，取语义最近的
 * [MiuixIcons.Tune]（仪表/调节，与「性能判据」同义）。
 */
@Composable
private fun PerfIconBadge() {
    Box(
        modifier = Modifier
            .size(26.dp)
            .clip(RoundedCornerShape(7.dp))
            .background(Color(QingyuIconColors.BLUE)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = MiuixIcons.Tune,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(14.dp),
        )
    }
}

/** 分组里缺内容时的灰字提示。 */
@Composable
private fun SectionHint(text: String, dark: Boolean) {
    MiuixText(
        text = text,
        style = MiuixTheme.textStyles.footnote1,
        color = Color(QingyuTheme.secondaryText(dark)),
        modifier = Modifier.padding(horizontal = QingyuPageCardMargin + 16.dp),
    )
}

/**
 * 列表行：图标 + 标题 + 右侧值 + 可选副标题（Dart `HyperosListTile`）。
 *
 * 点击用 `Modifier.clickable` 挂在行上，**不是**再套一层 [QingyuCard]：
 * 那样每个可点行会变成分组的卡片里再嵌一张卡（Dart 的分组是一张卡、行共用按压反馈）。
 * 同域 `MemoryStatsPage` 的 `MemoryRowItem` 也是这么做的。
 */
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
    val rowModifier = if (onClick == null) {
        Modifier.fillMaxWidth()
    } else {
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
    }
    Row(
        modifier = rowModifier.padding(horizontal = 14.dp, vertical = 10.dp),
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
                style = MiuixTheme.textStyles.body1,
                color = Color(QingyuTheme.primaryText(dark)),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            subtitle?.let {
                MiuixText(
                    text = it,
                    style = MiuixTheme.textStyles.footnote2,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
        }
        if (details.isNotEmpty()) {
            MiuixText(
                text = details,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/**
 * 卡顿比例档位 → 颜色（Dart：≥25% 红、≥5% 黄、否则绿，省略即默认蓝）。
 *
 * Dart 侧（`perf_report_screen.dart:253-256`）用的是**图标彩豆 token**
 *（`HyperosIconColors.red/yellow/green`），所以黄档走 [QingyuIconColors.YELLOW]；
 * 红/绿仍用主题语义槽（`error` / `success`），主题切换时随之变化。
 */
private fun accentColor(accent: PerfAccent, dark: Boolean): Color = when (accent) {
    PerfAccent.RED -> Color(QingyuTheme.error(dark))
    PerfAccent.YELLOW -> Color(QingyuIconColors.YELLOW)
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
