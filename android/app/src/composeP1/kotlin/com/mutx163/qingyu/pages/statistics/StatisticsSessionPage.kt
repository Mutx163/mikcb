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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.statistics.StatisticsSessionModel.CoverageRow
import com.mutx163.qingyu.pages.statistics.StatisticsSessionModel.SessionRow
import com.mutx163.qingyu.pages.statistics.StatisticsSessionModel.StatisticsSessionViewState
import com.mutx163.qingyu.pages.statistics.StatisticsSessionModel.SummaryMetric
import com.mutx163.qingyu.pages.statistics.charts.ChartPalette
import com.mutx163.qingyu.pages.statistics.charts.SessionTone
import com.mutx163.qingyu.pages.timetable.day.DayViewStrings
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.preference.WindowDropdownPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.TopDownloads

/**
 * 单节课明细页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/statistics_session_screen.dart`（147 行）：
 * - 顶栏：返回 + "单节课明细"；
 * - 课程选择行（`WindowDropdownPreference`，对应 `HyperosSelectTile<String>`，任意一门直达）；
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

    // 顶栏 / 返回键 / 折叠行为 / 页面主题桥统一走共享骨架（规则 R1）。
    QingyuPageScaffold(title = viewState.title, onBack = onBack) {
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
                        style = MiuixTheme.textStyles.body1,
                        color = Color(QingyuTheme.primaryText(dark)),
                    )
                    Text(
                        text = viewState.emptySubtitle,
                        style = MiuixTheme.textStyles.footnote1,
                        color = Color(QingyuTheme.secondaryText(dark)),
                    )
                }
            }
            return@QingyuPageScaffold
        }

        // 官方页面骨架：LazyColumn + 滚动条 + 末端触感（见 QingyuPageList 注释）
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            horizontalPadding = QingyuPageCardMargin,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    // ── 课程选择行（2026-11-05 审核修复：真下拉选择，替换「点一下换下一门」轮换）──
                    // 官方 [WindowDropdownPreference]：点行弹窗内列表，任意一门直达，
                    // 选中项高亮 + 行尾箭头；课多时不再要连点 N 次。
                    // 「共 N 门」副标题复用 timetable/day 域的既有 ARB 键
                    // `courseCountSummary`（"{count} 门课"，逐字一致）——统计域没有
                    // 现成的门数文案，而新增 ARB 键会触发死键扫描（Dart 侧无人用），
                    // 跨包复用既有键是仓内先例（warehouse 宿主复用 `aboutUnavailable` 同款）。
                    // 显式 isNotEmpty 兜底（2026-11-05 成员八复核④）：不依赖「空态先行
                    // return」的隐式契约——上游契约一变，这里宁可不画，不画空下拉。
                    if (viewState.courseNames.isNotEmpty()) {
                        QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(0.dp)) {
                            val names = viewState.courseNames
                            WindowDropdownPreference(
                                // 偏好行按压 ripple 是矩形；裁到卡片圆角（16dp），按压态才
                                // 完整贴合圆角框（同 AddExamPage 提醒行 2026-11-04 的修法）。
                                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)),
                                items = names,
                                selectedIndex = names.indexOf(viewState.selectedCourse).coerceAtLeast(0),
                                title = viewState.courseLabel,
                                summary = DayViewStrings.courseCountSummary(names.size),
                                onSelectedIndexChange = { index ->
                                    names.getOrNull(index)?.let(onSelectCourse)
                                },
                            )
                        }
                    }

                    // ── 没设开学日期的提示 ──
                    val hint = viewState.noCalendarHint
                    if (hint != null) {
                        Text(
                            text = hint,
                            style = MiuixTheme.textStyles.footnote1,
                            color = Color(QingyuTheme.secondaryText(dark)),
                            modifier = Modifier.padding(horizontal = 4.dp),
                        )
                    }

                    // ── 四格汇总 ──
                    if (viewState.summaryMetrics.isNotEmpty()) {
                        SummaryCard(viewState.summaryMetrics)
                    }

                    // ── 记录覆盖 ──
                    SectionBlock(title = StatisticsExtStrings.statisticsSessionCoverageTitle.text) {
                        if (viewState.stats == null || viewState.stats.sessions.isEmpty()) {
                            Text(
                                text = viewState.coverageEmptyText,
                                style = MiuixTheme.textStyles.body2,
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
                    // 版式对照（2026-11-08 真机点名「太乱」后理顺）：
                    // 发布版 Dart `SessionListCard` = `HyperosListGroup` 单卡，
                    // 行内边距 `settingsRowPadding(16, 13)` 恒定——靠「同一张卡 +
                    // 均匀行边距」把几十行压成一条齐整的长列表；
                    // miuix demo（SettingsPage/DropdownSection，`docs/reference/miuix-demo`）
                    // 也是「Card 内多行直叠、无大段 Spacer」。原 Compose 移植只抄了壳，
                    // 行与行之间只剩 12dp 空隙，没有行边距也没有细线，备注又比副标题
                    // 更显眼，所以长列表看起来像一堵跳动的墙。
                    // 这里回归：卡内边距为 0、每行自带 16/13 边距、行间 hairline 分隔；
                    // 备注降到 footnote1 副信息字，不再与标题抢层级。
                    SectionBlock(
                        title = StatisticsExtStrings.statisticsSessionListTitle.text,
                        insideMargin = PaddingValues(0.dp),
                    ) {
                        if (viewState.sessionRows.isEmpty()) {
                            Text(
                                text = viewState.coverageEmptyText,
                                style = MiuixTheme.textStyles.body2,
                                color = Color(QingyuTheme.secondaryText(dark)),
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
                            )
                        } else {
                            for ((index, row) in viewState.sessionRows.withIndex()) {
                                SessionLine(row)
                                if (index < viewState.sessionRows.lastIndex) {
                                    HorizontalDivider(
                                        modifier = Modifier.padding(horizontal = 16.dp),
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
                        style = MiuixTheme.textStyles.title3.shiftWeight(QingyuWeightDelta.SEMIBOLD),
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
                        style = MiuixTheme.textStyles.footnote1,
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
            Text(text = row.label, style = MiuixTheme.textStyles.body2, color = Color(QingyuTheme.primaryText(dark)))
            Text(
                text = row.valueText,
                style = MiuixTheme.textStyles.footnote1,
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

/**
 * 课次行（Dart `_SessionRow`：标题 + 考试/阶段徽标 + 副标题 + 备注）。
 *
 * 行边距 16/13 与发布版 `settingsRowPadding` 同口径（`hyperos_miuix_spec.dart:81`），
 * 长列表就是碎了一地 12dp 空隙的「乱」——行高 1~3 行跳动，没有固定轨道。
 *
 * 徽标：顶齐标题首行（原为 CenterVertically，标题两行时徽标会下沉）；
 * 相位底色按发布版 `_phaseColor` 六色走（绿/主题/蓝/橙/紫/灰），
 * 与 `charts/SessionCards.kt` 的 `sessionToneColor` 同源映射。
 *
 * 备注：空备注由模型层直接给 `null`（`sessionRow`），渲染层只在非空时画，
 * 空备注不占行（发布版 `if (_noteText(session) != null)` 同行为）。
 * 字色降为 footnote1 副信息字——初版移植把备注写成 body2 主色，
 * 结果备注比副标题还醒目、像大标题一样喊。
 */
@Composable
private fun SessionLine(row: SessionRow) {
    val dark = isSystemInDarkTheme()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 13.dp),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            Text(
                text = row.title,
                modifier = Modifier.weight(1f),
                style = MiuixTheme.textStyles.body1,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            val examBadge = row.examBadge
            if (examBadge != null) {
                Spacer(Modifier.width(8.dp))
                Badge(
                    text = examBadge,
                    textColor = Color(QingyuTheme.error(dark)),
                    backgroundColor = Color(QingyuTheme.error(dark)),
                    backgroundAlpha = 0.12f,
                )
            }
            Spacer(Modifier.width(6.dp))
            Badge(
                text = row.phaseLabel,
                textColor = sessionToneColor(row.tone, dark),
                backgroundColor = sessionToneColor(row.tone, dark),
                backgroundAlpha = 0.12f,
            )
        }
        Spacer(Modifier.height(2.dp))
        Text(
            text = row.subtitle,
            style = MiuixTheme.textStyles.body2,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
        val note = row.noteText
        if (note != null) {
            Spacer(Modifier.height(4.dp))
            Text(
                text = note,
                style = MiuixTheme.textStyles.footnote1,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
    }
}

/** [SessionTone] → 实际颜色（Dart `_phaseColor` 六色；与 `charts/SessionCards.sessionToneColor` 同源）。 */
private fun sessionToneColor(tone: SessionTone, dark: Boolean): Color = when (tone) {
    SessionTone.GREEN -> ChartPalette.Green
    SessionTone.PRIMARY -> Color(QingyuTheme.primary(dark = dark))
    SessionTone.BLUE -> ChartPalette.Blue
    SessionTone.ORANGE -> ChartPalette.Orange
    SessionTone.PURPLE -> ChartPalette.Purple
    SessionTone.SECONDARY -> Color(QingyuTheme.secondaryText(dark))
}

/** 行内小徽标（Dart `HyperosTag`：圆角底 + footnote2 + 中等字重）。 */
@Composable
private fun Badge(
    text: String,
    textColor: Color,
    backgroundColor: Color,
    backgroundAlpha: Float = 1f,
) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(backgroundColor.copy(alpha = backgroundAlpha))
            .padding(horizontal = 8.dp, vertical = 3.dp),
    ) {
        Text(
            text = text,
            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            color = textColor,
        )
    }
}

/**
 * 区块（Dart `HyperosSettingsBlock`：块头 + 卡内内容）。
 *
 * @param insideMargin 卡内边距：记录覆盖块用默认 16/14；课次列表传 0，
 *   行边距由每行自己承担（16/13），与发布版 `settingsRowPadding` 一致。
 */
@Composable
private fun SectionBlock(
    title: String,
    insideMargin: PaddingValues = PaddingValues(horizontal = 16.dp, vertical = 14.dp),
    content: @Composable () -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        QingyuSectionTitle(text = title)
        QingyuCard(
            modifier = Modifier.fillMaxWidth(),
            insideMargin = insideMargin,
        ) {
            content()
        }
    }
}

// ── 预览 ──────────────────────────────────────────────────────────────────────
//
// 课次、四格汇总、覆盖三行都不手写：课次由 `CourseSessionStatsCalculator.build(...)`
// 从真实课表 + 作息 + 开学日推导，汇总再由 `StatisticsSessionModel.viewState(...)` 装配。
//
// `Course` / `CourseSessionNote` / `TimetableSettings` 用全限定名：本文件的 import 块按
// 预览约定只允许动三行（`Preview` / `QingyuPageTheme` / 总览布局件），不为预览扩大 import 面。

/** 预览基准时刻：2026-11-08（第 8 周）周日 10:00。 */
private val previewSessionNow: java.time.LocalDateTime = java.time.LocalDateTime.of(2026, 11, 8, 10, 0)

/** 预览作息与开学日：20 周学期，2026-09-07 开学。 */
private val previewSessionSettings = com.mutx163.qingyu.core.TimetableSettings(
    semesterWeekCount = 20,
    semesterStartDate = java.time.LocalDateTime.of(2026, 9, 7, 0, 0),
)

/** 预览课表：两门课，高等数学带第 1/2 周的备注与作业。 */
private val previewSessionCourses = listOf(
    com.mutx163.qingyu.core.Course(
        id = "course-math",
        name = "高等数学",
        teacher = "张明",
        location = "示例大学 A101",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
        endWeek = 20,
        sessionNotes = mapOf(
            1 to com.mutx163.qingyu.core.CourseSessionNote(text = "复习极限存在的定义"),
            2 to com.mutx163.qingyu.core.CourseSessionNote(text = "习题 3.1 第 1~8 题", hasHomework = true),
        ),
    ),
    com.mutx163.qingyu.core.Course(
        id = "course-physics",
        name = "大学物理",
        teacher = "李海",
        location = "示例大学 B203",
        dayOfWeek = 2,
        startSection = 3,
        endSection = 4,
        startTime = "10:00",
        endTime = "11:40",
        endWeek = 20,
    ),
)

private fun previewSessionState(name: String): StatisticsSessionViewState {
    val names = if (name == "空课表") emptyList() else listOf("高等数学", "大学物理")
    return StatisticsSessionModel.viewState(
        courseNames = names,
        previousSelection = if (names.isEmpty()) null else "高等数学",
        statsOf = { courseName ->
            if (names.isEmpty()) {
                null
            } else {
                com.mutx163.qingyu.core.CourseSessionStatsCalculator.build(
                    courseName = courseName,
                    courses = previewSessionCourses,
                    settings = previewSessionSettings,
                    now = previewSessionNow,
                )
            }
        },
        dateTextOf = { session ->
            session.date?.let { date -> "${date.monthValue}月${date.dayOfMonth}日" }
        },
    )
}

/** 一档预览的公共身体：视图状态 + 外观档位。 */
@Composable
private fun PreviewSessionBody(
    state: StatisticsSessionViewState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        StatisticsSessionPage(
            viewState = state,
            onBack = {},
            onSelectCourse = {},
        )
    }
}

// ── 单档：两态 × 亮色 ─────────────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 有记录", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewSessionData() {
    PreviewSessionBody(previewSessionState("有记录"))
}

@Suppress("unused")
@Preview(name = "2 空课表", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewSessionEmpty() {
    PreviewSessionBody(previewSessionState("空课表"))
}

// ── 单档：外观两档（以「有记录」为基准）──────────────────────────────────────

@Suppress("unused")
@Preview(name = "3 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewSessionDark() {
    PreviewSessionBody(previewSessionState("有记录"), dark = true)
}

@Suppress("unused")
@Preview(name = "4 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewSessionLargeText() {
    PreviewSessionBody(previewSessionState("有记录"), textScale = 1.3f)
}
