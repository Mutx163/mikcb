package com.mutx163.qingyu.pages.diagnostics

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
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
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuGlassIconButton
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
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
        // 右上动作键与左上返回键同一套外观：共享玻璃圆底 + 细边 + 小外浮影
        //（门控：内容压到顶栏带下面才出圆底，静止是裸图标——与返回键同一个信号）。
        actions = {
            QingyuGlassIconButton(
                onClick = onRefresh,
                contentDescription = PerfReportStrings.refreshTooltip,
                icon = MiuixIcons.Refresh,
                tint = Color(QingyuTheme.actionIcon(dark)),
            )
            // Dart `:110-114`：`onPressed: snapshot == null ? null : _exportFiles`
            // ⇒ 没有快照时导出是禁用态，不是隐藏。
            QingyuGlassIconButton(
                onClick = onExport,
                contentDescription = PerfReportStrings.exportTooltip,
                // Dart 是 `Icons.save_alt_rounded`（存盘），不是上传。
                icon = MiuixIcons.Download,
                tint = Color(QingyuTheme.actionIcon(dark)),
                enabled = viewState.isAvailable,
            )
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

// ── 预览 ──────────────────────────────────────────────────────────────────────
//
// 快照用手写的平台真实形状（`totals` / `pages` / `startup` / `probe` 都是探针下发的键），
// 再交给同包真装配函数 `buildPerfReportViewState` 算：排序后的页排行、判据三栏、
// 能量说明全部由模型层算出来，预览里不手写一份假的读数。

/** 一份“刚跑完一轮”的 Perf 快照：3 个页 486 帧、跳帧 2.1%、60Hz 设备。 */
private val previewPerfSnapshot: Map<String, Any?> = mapOf(
    "refreshRateHz" to 60,
    "totals" to mapOf("pages" to 3, "frames" to 486, "janky" to 11, "jankyPct" to "2.3"),
    "probe" to mapOf("budgetMs" to 16.7, "nominalMs" to 16.6, "observedVsyncMs" to 16.6),
    "startup" to listOf(
        mapOf("phase" to "进程启动", "stepMs" to 186, "totalMs" to 186),
        mapOf("phase" to "首帧", "stepMs" to 421, "totalMs" to 607),
    ),
    "pages" to listOf(
        mapOf(
            "page" to "课程总览",
            "frames" to 212,
            "janky" to 3,
            "verdict" to "ui",
            "fps" to 58.4,
            "worstBuildMs" to 12.4,
            "avgBuildMs" to 4.1,
            "worstRasterMs" to 9.8,
            "avgRasterMs" to 3.2,
            "firstFrameMs" to 421,
            "cpuMs" to 268.5,
            "rssDeltaKb" to 12_480,
        ),
        mapOf(
            "page" to "课程统计",
            "frames" to 186,
            "janky" to 7,
            "verdict" to "raster",
            "fps" to 56.1,
            "worstBuildMs" to 8.6,
            "avgBuildMs" to 3.4,
            "worstRasterMs" to 21.7,
            "avgRasterMs" to 6.8,
            "firstFrameMs" to 312,
            "cpuMs" to 210.2,
            "rssDeltaKb" to 8_192,
        ),
        mapOf(
            "page" to "课表主页",
            "frames" to 88,
            "janky" to 1,
            "verdict" to "unknown",
            "fps" to 59.2,
            "worstBuildMs" to 6.1,
            "avgBuildMs" to 2.8,
            "worstRasterMs" to 7.4,
            "avgRasterMs" to 2.1,
            "firstFrameMs" to 268,
            "cpuMs" to 96.4,
            "rssDeltaKb" to 4_096,
        ),
    ),
)

/** 原文报告示例（页面「展开原文」后才出现）。 */
private val previewPerfRawReport: String = """
{
  "totals": { "pages": 3, "frames": 486, "janky": 11 },
  "refreshRateHz": 60,
  "pages": [
    { "page": "课程总览", "frames": 212, "janky": 3, "fps": 58.4 },
    { "page": "课程统计", "frames": 186, "janky": 7, "fps": 56.1 }
  ]
}
""".trimIndent()

private fun previewPerfState(name: String): PerfReportViewState = when (name) {
    "未安装" -> buildPerfReportViewState(snapshot = null)
    "空数据" -> buildPerfReportViewState(snapshot = mapOf("totals" to emptyMap<String, Any>()))
    "展开原文" -> buildPerfReportViewState(snapshot = previewPerfSnapshot, showRaw = true)
    else -> buildPerfReportViewState(snapshot = previewPerfSnapshot)
}

/** 一档预览的公共身体：视图状态 + 外观档位。 */
@Composable
private fun PreviewPerfReportBody(
    state: PerfReportViewState,
    dark: Boolean = false,
    textScale: Float = 1f,
    rawReportText: String = "",
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        PerfReportPage(
            viewState = state,
            onBack = {},
            onRefresh = {},
            onExport = {},
            onClearLedger = {},
            onToggleRaw = {},
            onCopyTextReport = {},
            onCopyJson = {},
            rawReportText = rawReportText,
        )
    }
}

// ── 单档：三态 × 亮色 ─────────────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 有数据", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewPerfReportData() {
    PreviewPerfReportBody(previewPerfState("有数据"))
}

@Suppress("unused")
@Preview(name = "2 空数据", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewPerfReportEmpty() {
    PreviewPerfReportBody(previewPerfState("空数据"))
}

@Suppress("unused")
@Preview(name = "3 未安装探针", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewPerfReportNotInstalled() {
    PreviewPerfReportBody(previewPerfState("未安装"))
}

@Suppress("unused")
@Preview(name = "4 展开原文", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewPerfReportRaw() {
    PreviewPerfReportBody(previewPerfState("展开原文"), rawReportText = previewPerfRawReport)
}

// ── 单档：外观两档（以「有数据」为基准）──────────────────────────────────────

@Suppress("unused")
@Preview(name = "5 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewPerfReportDark() {
    PreviewPerfReportBody(previewPerfState("有数据"), dark = true)
}

@Suppress("unused")
@Preview(name = "6 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewPerfReportLargeText() {
    PreviewPerfReportBody(previewPerfState("有数据"), textScale = 1.3f)
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
private fun PreviewPerfReportOverview() {
    Row(
        modifier = Modifier.fillMaxSize(),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        for (name in listOf("有数据", "空数据", "未安装", "展开原文")) {
            Box(Modifier.width(400.dp).fillMaxHeight()) {
                PreviewPerfReportBody(previewPerfState(name), rawReportText = previewPerfRawReport)
            }
        }
    }
}
