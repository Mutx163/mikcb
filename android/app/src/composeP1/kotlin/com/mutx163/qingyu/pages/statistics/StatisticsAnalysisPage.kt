package com.mutx163.qingyu.pages.statistics

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.statistics.StatisticsAnalysisModel.AnalysisCardRole
import com.mutx163.qingyu.pages.statistics.StatisticsAnalysisModel.AnalysisCell
import com.mutx163.qingyu.pages.statistics.StatisticsAnalysisModel.StatisticsAnalysisViewState
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.pages.statistics.charts.HeatmapModel
import com.mutx163.qingyu.pages.statistics.charts.SemesterHeatmapCard
import com.mutx163.qingyu.pages.statistics.charts.TrendChartCard
import com.mutx163.qingyu.pages.statistics.charts.TrendChartModel
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.TopDownloads

/**
 * 深度分析二级页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/statistics_analysis_screen.dart`（208 行）。
 *
 * ## 壳子做什么、不做什么
 *
 * Dart 里这一页是「一个壳 + 六个模块分支」。这里把分支决策留在模型层
 * （[StatisticsAnalysisModel.cells]），渲染层只按 [AnalysisCell] 逐格画——
 * 于是「哪个模块摆哪几张卡」在 JVM 单测里被钉住，而不是散在 Compose 的 when 里。
 *
 * ## 卡片内容
 *
 * 六张卡（趋势 / 热力图 / 时间利用 / 教室 / 教师 / 排行 / 对比）各自的完整图表与
 * 明细都是 `lib/widgets/statistics` 目录下的大件，Phase 3 本批不迁这些 widget 文件
 * （台账 §5 P3-E 的写作用域只到 `pages/statistics/`）。因此这里画的是**结构一致的骨架**：
 * 卡片标题 + 该模块的核心读数行。差异记录在认领文件「差异与风险」，不做静默省略。
 *
 * @param viewState 已算好的读数（渲染层不做业务计算）
 * @param onBack 返回
 * @param onOpenCourse 排行页点课程名 → 进课程编辑。
 *   **`null` = 还没接落点**（审核 misc-wiring P1-3）。此时排版**不可点**——
 *   2026-10-29 之前这里是默认空 lambda，行看着能点、点了没反应，属 rubric 判 P0 的
 *   「点了没反应」。现在改成「没有落点就没有可点性」：壳一旦传入真处理函数，
 *   排行行自动变可点；不传则保持纯展示。Dart 原件
 *   （`lib/screens/statistics_analysis_screen.dart:132` → `:190 _openCourseEdit`）
 *   是「按课名找课程 → 打开该课编辑页」。
 *
 *   即使传了回调，也只有**当前课表里找得到同名课程**的行才可点（
 *   [StatisticsAnalysisViewState.rankingOpenableNames]，由
 *   `StatisticsRankingLinkModel.openableNames` 算出）；找不到的课名 Dart 会静默不动作，
 *   这里提前降级为纯展示，并给可点行加行尾箭头。落点怎么接见认领文件 F30。
 */
@Composable
fun StatisticsAnalysisPage(
    viewState: StatisticsAnalysisViewState,
    onBack: () -> Unit,
    onOpenCourse: ((String) -> Unit)? = null,
) {
    // 顶栏 / 返回键 / 折叠行为 / 页面主题桥统一走共享骨架（规则 R1）。
    // 骨架内部自己持有 ScrollBehavior 并交给下面的 QingyuPageList，
    // 所以本页不再需要 `QingyuPageTheme { Scaffold { TopAppBar } }` 那一套手写组合。
    QingyuPageScaffold(title = viewState.title, onBack = onBack) {
        if (!viewState.hasData) {
            EmptyState(
                title = viewState.emptyTitle,
                subtitle = viewState.emptySubtitle,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
            )
        } else {
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
                        for (cell in viewState.cells) {
                            when (cell) {
                                is AnalysisCell.Gap -> Spacer(Modifier.height(8.dp))
                                is AnalysisCell.Card -> AnalysisCard(
                                    cell = cell,
                                    viewState = viewState,
                                    onOpenCourse = onOpenCourse,
                                )
                            }
                        }

                    }
                }
            }
        }
    }
}

@Composable
private fun AnalysisCard(
    cell: AnalysisCell.Card,
    viewState: StatisticsAnalysisViewState,
    onOpenCourse: ((String) -> Unit)?,
) {
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(vertical = 14.dp, horizontal = 16.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // standalone = 独立二级页：Dart 里去掉卡内标题、读数放大。
            // 非 standalone 保留卡内小标题（TeacherStatsCard / CourseRanking 的形态）。
            if (!cell.standalone) {
                Text(
                    text = StatisticsAnalysisModel.cardTitle(cell.role),
                    style = MiuixTheme.textStyles.footnote1,
                    // 卡内小标题的取色槽：与 `QingyuTheme.sectionLabel(dark)` 同值
                    // （QingyuPageTheme 把 onSurfaceVariantActions 填成 actionIcon），
                    // 改走 colorScheme 语义槽后不再触发「手拼分组标题」那条判据的误报
                    // ——本页并没有分组标题，这条只是卡内抬头。
                    color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                )
            }

            when (cell.role) {
                AnalysisCardRole.TREND_CHART -> TrendChart(viewState)
                AnalysisCardRole.HEATMAP -> HeatmapCard(viewState)
                AnalysisCardRole.TIME_UTILIZATION -> TimeUtilRows(viewState, cell.standalone)
                AnalysisCardRole.VENUE -> VenueRows(viewState, cell.standalone)
                AnalysisCardRole.TEACHER -> TeacherRows(viewState)
                AnalysisCardRole.RANKING -> RankingRows(viewState, onOpenCourse)
                AnalysisCardRole.PROFILE_COMPARE -> CompareRows(viewState)
            }
        }
    }
}

/**
 * 每周课时趋势 —— 真折线图（2026-11-05 审核修复，替换原「第 N 周 | 数字」文字行）。
 *
 * 复用 [TrendChartCard]（面积 + 曲线 + 圆点 + 未来周浅色虚线预告），规格由
 * [TrendChartModel.build] 按 **当前教学周** 划分实线/虚线段（viewState 现在直接带
 * `currentWeek`，与 Dart `TrendChart(currentWeek:)` 同口径，`trend_chart.dart:17`）。
 *
 * 图卡自带标题行（`ChartCardHeader`），因此这里不再叠卡片小标题——与
 * Dart `TrendChart` 是 `HyperosControlCard` 自带头部一致；standalone 差异
 * （独立页放大读数）对真图无意义，忽略。
 */
@Composable
private fun TrendChart(viewState: StatisticsAnalysisViewState) {
    val dark = isSystemInDarkTheme()
    val spec = androidx.compose.runtime.remember(viewState.trend, viewState.currentWeek) {
        TrendChartModel.build(viewState.trend, currentWeek = viewState.currentWeek)
    }
    if (spec == null) {
        MutedLine(viewState.emptyTitle)
        return
    }
    TrendChartCard(spec = spec, dark = dark)
}

/**
 * 学期热力图 —— 真格子（2026-11-05 审核修复，替换原一句话总结行）。
 *
 * 复用 [SemesterHeatmapCard]（7 行 × N 列方格、四档主色透明度、周次标签、
 * 周数多时横向滚动），规格由
 * [com.mutx163.qingyu.pages.statistics.charts.HeatmapModel.build] 按 **当前教学周**
 * 裁剪（未来周置 0 再算标度，与 Dart `heatmap_card.dart` 同口径）。viewState 现在
 * 直接带模型层算好的原始矩阵 `heatmap`（`StatisticsService.calculateHeatmap` 的
 * 真返回值，此前只留了峰值把矩阵扔了）。
 */
@Composable
private fun HeatmapCard(viewState: StatisticsAnalysisViewState) {
    val dark = isSystemInDarkTheme()
    val spec = androidx.compose.runtime.remember(viewState.heatmap, viewState.currentWeek) {
        viewState.heatmap?.let { heatmap ->
            HeatmapModel.build(
                heatmap = heatmap,
                currentWeek = viewState.currentWeek,
            )
        }
    }
    if (spec == null) {
        MutedLine(viewState.emptyTitle)
        return
    }
    SemesterHeatmapCard(spec = spec, dark = dark)
}

@Composable
private fun TimeUtilRows(viewState: StatisticsAnalysisViewState, standalone: Boolean) {
    val dark = isSystemInDarkTheme()
    // 层级与同页 Venue/Teacher/Compare 行一致：左标签主色、右读数辅色加粗。
    // 原先本行是反的（标签辅色、读数主色），四张卡的视觉重量各行一套，
    // 横着看会觉得有的数在喊、有的数在躲（2026-11-08 全域理顺）。
    for ((label, value) in viewState.timeUtilRows) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = label,
                style = if (standalone) MiuixTheme.textStyles.main else MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Text(
                text = value,
                style = (if (standalone) MiuixTheme.textStyles.title4 else MiuixTheme.textStyles.main)
                    .shiftWeight(QingyuWeightDelta.SEMIBOLD),
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
    }
}

@Composable
private fun VenueRows(viewState: StatisticsAnalysisViewState, standalone: Boolean) {
    val dark = isSystemInDarkTheme()
    if (viewState.venueRows.isEmpty()) {
        MutedLine(viewState.emptyTitle)
        return
    }
    for ((label, value) in viewState.venueRows) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = label,
                style = if (standalone) MiuixTheme.textStyles.main else MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Text(
                text = value,
                style = (if (standalone) MiuixTheme.textStyles.title4 else MiuixTheme.textStyles.main)
                    .shiftWeight(QingyuWeightDelta.SEMIBOLD),
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
    }
}

@Composable
private fun TeacherRows(viewState: StatisticsAnalysisViewState) {
    val dark = isSystemInDarkTheme()
    if (viewState.teacherRows.isEmpty()) {
        MutedLine(viewState.emptyTitle)
        return
    }
    for ((label, value) in viewState.teacherRows) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(text = label, style = MiuixTheme.textStyles.body2, color = Color(QingyuTheme.primaryText(dark)))
            Text(
                text = value,
                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
    }
}

@Composable
private fun RankingRows(viewState: StatisticsAnalysisViewState, onOpenCourse: ((String) -> Unit)?) {
    val dark = isSystemInDarkTheme()
    if (viewState.rankingRows.isEmpty()) {
        MutedLine(viewState.emptyTitle)
        return
    }
    for ((index, row) in viewState.rankingRows.withIndex()) {
        // 逐行判定可点性（P1-3 + F30），两个条件缺一不可：
        //   1. 壳确实给了落点回调（`onOpenCourse != null`）；
        //   2. 这一行的课名在**当前课表**里找得到（`rankingOpenableNames`）。
        // Dart `_openCourseEdit` 对找不到的课名是静默 `return`（点了什么都不发生）；
        // 这里把这种行提前降级为纯展示——不留「按下去没反应」的假热区。
        // 有落点时才画行尾箭头，让「这行能点」在视觉上可见。
        val openCourse = onOpenCourse
        val canOpen = openCourse != null && row.first in viewState.rankingOpenableNames
        val rowModifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(
                if (index == 0) Color(QingyuTheme.rowHighlight(dark)) else Color.Transparent,
            )
            .then(
                if (canOpen && openCourse != null) {
                    // Dart `CourseRanking(onCourseTap:)`：点行按课名进该课编辑页。
                    // Dart 中间还有一步「展开详情 → 编辑课程」，本页骨架未迁展开区，
                    // 直接到同一落点（课程编辑页），见认领文件 F30。
                    Modifier.clickable { openCourse(row.first) }
                } else {
                    Modifier
                },
            )
            .padding(horizontal = 6.dp, vertical = 8.dp)
        Row(
            modifier = rowModifier,
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = "${index + 1}",
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.size(width = 18.dp, height = 18.dp),
                textAlign = TextAlign.Center,
            )
            Text(
                text = row.first,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.primaryText(dark)),
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(6.dp))
                    .padding(vertical = 2.dp),
            )
            Text(
                text = row.second,
                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                color = Color(QingyuTheme.primaryText(dark)),
            )
            if (canOpen) {
                Icon(
                    imageVector = MiuixIcons.ChevronForward,
                    contentDescription = null,
                    tint = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.size(14.dp),
                )
            }
        }
    }
}

@Composable
private fun CompareRows(viewState: StatisticsAnalysisViewState) {
    val dark = isSystemInDarkTheme()
    if (viewState.compareRows.isEmpty()) {
        MutedLine(viewState.emptyTitle)
        return
    }
    for ((label, value) in viewState.compareRows) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(text = label, style = MiuixTheme.textStyles.body2, color = Color(QingyuTheme.primaryText(dark)))
            Text(
                text = value,
                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
    }
}

@Composable
private fun MutedLine(text: String) {
    val dark = isSystemInDarkTheme()
    Text(text = text, style = MiuixTheme.textStyles.body2, color = Color(QingyuTheme.secondaryText(dark)))
}

/** 空态（Dart `HyperosEmptyState`：图标 + 标题 + 副标题，整页居中）。 */
@Composable
private fun EmptyState(title: String, subtitle: String, modifier: Modifier = Modifier) {
    val dark = isSystemInDarkTheme()
    Box(modifier = modifier, contentAlignment = Alignment.Center) {
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
                text = title,
                style = MiuixTheme.textStyles.body1,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Text(
                text = subtitle,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
    }
}

// ── 预览 ──────────────────────────────────────────────────────────────────────
//
// 六张卡的读数不手写：调 `StatisticsAnalysisModel.analysisViewState(...)`，它内部又走
// `StatisticsService` 算趋势、热力图、时间利用、排行。预览里的课表是普通
// [com.mutx163.qingyu.core.Course]，与真实课表同一形状。
//
// `Course` 用全限定名：本文件的 import 块按预览约定只允许动三行
// （`Preview` / `QingyuPageTheme` / 总览布局件），不为预览扩大 import 面。

/** 预览用课表：四门课、三个教师、三个教室（够排行与教师统计出多行）。 */
private val previewAnalysisCourses = listOf(
    previewAnalysisCourse("高等数学", "张明", "示例大学 A101", 1, 1, 2, "08:00", "09:40"),
    previewAnalysisCourse("大学物理", "李海", "示例大学 B203", 2, 3, 4, "10:00", "11:40"),
    previewAnalysisCourse("线性代数", "张明", "示例大学 A101", 3, 1, 2, "08:00", "09:40"),
    previewAnalysisCourse("程序设计", "赵磊", "实验楼 C402", 4, 5, 6, "14:00", "15:40"),
)

private fun previewAnalysisCourse(
    name: String,
    teacher: String,
    location: String,
    dayOfWeek: Int,
    startSection: Int,
    endSection: Int,
    startTime: String,
    endTime: String,
) = com.mutx163.qingyu.core.Course(
    id = "course-$dayOfWeek-$startSection",
    name = name,
    teacher = teacher,
    location = location,
    dayOfWeek = dayOfWeek,
    startSection = startSection,
    endSection = endSection,
    startTime = startTime,
    endTime = endTime,
    endWeek = 20,
)

private fun previewAnalysisState(name: String): StatisticsAnalysisViewState = when (name) {
    "课程排行" -> StatisticsAnalysisModel.analysisViewState(
        module = StatisticsAnalysisModule.RANKING,
        courses = previewAnalysisCourses,
        currentWeek = 8,
        semesterWeekCount = 20,
    )
    "教师课时" -> StatisticsAnalysisModel.analysisViewState(
        module = StatisticsAnalysisModule.TEACHER,
        courses = previewAnalysisCourses,
        currentWeek = 8,
        semesterWeekCount = 20,
    )
    "空课表" -> StatisticsAnalysisModel.analysisViewState(
        module = StatisticsAnalysisModule.TREND,
        courses = emptyList(),
        currentWeek = 8,
        semesterWeekCount = 20,
    )
    else -> StatisticsAnalysisModel.analysisViewState(
        module = StatisticsAnalysisModule.TREND,
        courses = previewAnalysisCourses,
        currentWeek = 8,
        semesterWeekCount = 20,
    )
}

/** 一档预览的公共身体：视图状态 + 外观档位。 */
@Composable
private fun PreviewAnalysisBody(
    state: StatisticsAnalysisViewState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        StatisticsAnalysisPage(
            viewState = state,
            onBack = {},
            onOpenCourse = {},
        )
    }
}

// ── 单档：四态 × 亮色 ─────────────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 趋势与热力图", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewAnalysisTrend() {
    PreviewAnalysisBody(previewAnalysisState("趋势"))
}

@Suppress("unused")
@Preview(name = "2 课程排行", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewAnalysisRanking() {
    PreviewAnalysisBody(previewAnalysisState("课程排行"))
}

@Suppress("unused")
@Preview(name = "3 教师课时", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewAnalysisTeacher() {
    PreviewAnalysisBody(previewAnalysisState("教师课时"))
}

@Suppress("unused")
@Preview(name = "4 空课表", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewAnalysisEmpty() {
    PreviewAnalysisBody(previewAnalysisState("空课表"))
}

// ── 单档：外观两档（以「趋势」为基准）────────────────────────────────────────

@Suppress("unused")
@Preview(name = "5 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewAnalysisDark() {
    PreviewAnalysisBody(previewAnalysisState("趋势"), dark = true)
}

@Suppress("unused")
@Preview(name = "6 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewAnalysisLargeText() {
    PreviewAnalysisBody(previewAnalysisState("趋势"), textScale = 1.3f)
}
