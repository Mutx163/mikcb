package com.mutx163.qingyu.pages.statistics

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.pages.statistics.StatisticsSessionModel.CoverageRow
import com.mutx163.qingyu.pages.statistics.StatisticsSessionModel.SessionRow
import com.mutx163.qingyu.pages.statistics.StatisticsSessionModel.StatisticsSessionViewState
import com.mutx163.qingyu.pages.statistics.StatisticsSessionModel.SummaryMetric
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.TopDownloads
import top.yukonga.miuix.kmp.preference.ArrowPreference

/**
 * 单节课明细页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/statistics_session_screen.dart`（147 行）：
 * - 顶栏：返回 + "单节课明细"；
 * - 课程选择行（`ArrowPreference`，对应 `HyperosSelectTile<String>`）；
 * - 没设开学日期时一行提示（`statisticsSessionNoCalendarHint`）；
 * - 四格汇总（课次 / 已过 / 课时 / 有备注，首格强调）；
 * - 「记录覆盖」块：三行进度（有备注 / 有作业 / 设过提醒）；
 * - 「课次列表」块：每行阶段徽标 + 副标题 + 备注；
 * - 一门课都没有时整页空态。
 *
 * 不持业务状态、不做业务计算：选中项收敛、四格数值、覆盖比例、阶段标签
 * 全在 [StatisticsSessionModel] 里算好（有单测钉住），这里只画。
 *
 * @param viewState 已算好的整页状态
 * @param onBack 返回
 * @param onSelectCourse 换一门课
 */
@Composable
fun StatisticsSessionPage(
    viewState: StatisticsSessionViewState,
    onBack: () -> Unit,
    onSelectCourse: (String) -> Unit,
) {
    val dark = isSystemInDarkTheme()

    QingyuPageTheme {
        Scaffold(
            containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
            topBar = {
                TopAppBar(
                    title = viewState.title,
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(
                                imageVector = MiuixIcons.Back,
                                contentDescription = viewState.title,
                                tint = Color(QingyuTheme.actionIcon(dark)),
                            )
                        }
                    },
                )
            },
        ) { innerPadding ->
            if (viewState.isEmpty) {
                // 一门课都没有：整页空态（Dart 在 groups.isEmpty() 时就走这里，
                // 连课程选择行都不出现）。
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(innerPadding),
                    contentAlignment = Alignment.Center,
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Icon(
                            imageVector = MiuixIcons.TopDownloads,
                            contentDescription = null,
                            tint = Color(QingyuTheme.secondaryText(dark)),
                            modifier = Modifier.size(40.dp),
                        )
                        Text(
                            text = viewState.emptyTitle,
                            fontSize = 16.sp,
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                        Text(
                            text = viewState.emptySubtitle,
                            fontSize = 13.sp,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                    }
                }
                return@Scaffold
            }

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                // ── 课程选择行 ──
                QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(vertical = 2.dp)) {
                    val current = viewState.selectedCourse ?: ""
                    ArrowPreference(
                        title = viewState.courseLabel,
                        summary = current,
                        onClick = {
                            // 选中项由宿主决定（模型层 resolveSelection 收敛），
                            // 这里只把「用户点了哪一门」上报。没有下拉是因为官方
                            // ArrowPreference 不带选项集；宿主侧弹选择器。
                            val next = viewState.courseNames.let { names ->
                                if (names.isEmpty()) {
                                    current
                                } else {
                                    val index = names.indexOf(current)
                                    names[(index + 1) % names.size]
                                }
                            }
                            onSelectCourse(next)
                        },
                    )
                }

                // ── 没设开学日期的提示 ──
                val hint = viewState.noCalendarHint
                if (hint != null) {
                    Text(
                        text = hint,
                        fontSize = 13.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        modifier = Modifier.padding(horizontal = 4.dp),
                    )
                }

                // ── 四格汇总 ──
                if (viewState.summaryMetrics.isNotEmpty()) {
                    SummaryCard(viewState.summaryMetrics)
                }

                // ── 记录覆盖 ──
                SectionBlock(title = StatisticsExtStrings.statisticsSessionCoverageTitle.zh) {
                    if (viewState.stats == null || viewState.stats.sessions.isEmpty()) {
                        Text(
                            text = viewState.coverageEmptyText,
                            fontSize = 14.sp,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                    } else {
                        for ((index, row) in viewState.coverageRows.withIndex()) {
                            CoverageLine(row)
                            if (index < viewState.coverageRows.lastIndex) {
                                Spacer(Modifier.height(12.dp))
                            }
                        }
                    }
                }

                // ── 课次列表 ──
                SectionBlock(title = StatisticsExtStrings.statisticsSessionListTitle.zh) {
                    if (viewState.sessionRows.isEmpty()) {
                        Text(
                            text = viewState.coverageEmptyText,
                            fontSize = 14.sp,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                    } else {
                        for ((index, row) in viewState.sessionRows.withIndex()) {
                            SessionLine(row)
                            if (index < viewState.sessionRows.lastIndex) {
                                HorizontalDivider(
                                    modifier = Modifier.padding(vertical = 10.dp),
                                    color = Color(QingyuTheme.dividerLine(dark)),
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

/** 四格汇总（Dart `SessionSummaryCard`：一行四格 + 细分隔线 + 首格强调）。 */
@Composable
private fun SummaryCard(metrics: List<SummaryMetric>) {
    val dark = isSystemInDarkTheme()
    QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(vertical = 14.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            for ((index, metric) in metrics.withIndex()) {
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = metric.value,
                        fontSize = 22.sp,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        color = if (metric.highlight) {
                            Color(QingyuTheme.primary(dark = dark))
                        } else {
                            Color(QingyuTheme.primaryText(dark))
                        },
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = metric.label,
                        fontSize = 12.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        color = if (metric.highlight) {
                            Color(QingyuTheme.primaryText(dark))
                        } else {
                            Color(QingyuTheme.secondaryText(dark))
                        },
                    )
                }
                if (index < metrics.lastIndex) {
                    Box(
                        modifier = Modifier
                            .width(1.dp)
                            .height(28.dp)
                            .background(Color(QingyuTheme.dividerLine(dark))),
                    )
                }
            }
        }
    }
}

/** 覆盖行（Dart `_CoverageRow`：标签 + 计数 + 进度条）。 */
@Composable
private fun CoverageLine(row: CoverageRow) {
    val dark = isSystemInDarkTheme()
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(text = row.label, fontSize = 14.sp, color = Color(QingyuTheme.primaryText(dark)))
            Text(
                text = row.valueText,
                fontSize = 13.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
        Spacer(Modifier.height(6.dp))
        // 进度条：底色整条 + 前景按比例。比例为 0 时不画前景（宽度 0）。
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(Color(QingyuTheme.surfaceContainerHighest(dark))),
        ) {
            val fraction = row.ratio.coerceIn(0f, 1f)
            if (fraction > 0f) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(fraction)
                        .height(6.dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(Color(QingyuTheme.primary(dark = dark))),
                )
            }
        }
    }
}

/** 课次行（Dart `_SessionTile`：阶段徽标 + 副标题 + 备注）。 */
@Composable
private fun SessionLine(row: SessionRow) {
    val dark = isSystemInDarkTheme()
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .background(Color(QingyuTheme.rowHighlight(dark)))
                    .padding(horizontal = 8.dp, vertical = 3.dp),
            ) {
                Text(
                    text = row.phaseLabel,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
            }
            Spacer(Modifier.width(8.dp))
            Text(
                text = row.subtitle,
                fontSize = 14.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
        val note = row.noteText
        if (note != null) {
            Spacer(Modifier.height(4.dp))
            Text(
                text = note,
                fontSize = 14.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                color = Color(QingyuTheme.primaryText(dark)),
            )
        }
    }
}

/** 区块（Dart `HyperosSettingsBlock`：块头 + 卡内内容）。 */
@Composable
private fun SectionBlock(title: String, content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = title,
            fontSize = 13.sp,
            color = Color(QingyuTheme.sectionLabel(dark)),
            modifier = Modifier.padding(start = 4.dp, top = 8.dp, bottom = 4.dp),
        )
        QingyuCard(
            modifier = Modifier.fillMaxWidth(),
            insideMargin = PaddingValues(horizontal = 16.dp, vertical = 14.dp),
        ) {
            content()
        }
    }
}
