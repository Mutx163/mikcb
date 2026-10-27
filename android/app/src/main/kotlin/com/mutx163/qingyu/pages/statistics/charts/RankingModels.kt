package com.mutx163.qingyu.pages.statistics.charts

import com.mutx163.qingyu.core.CourseNature
import com.mutx163.qingyu.statistics.CourseSemesterStat
import com.mutx163.qingyu.statistics.CourseSlot
import com.mutx163.qingyu.statistics.CourseStat
import com.mutx163.qingyu.statistics.WeeklyStats

/** 课程排行里「时间槽」的两种写法。 */
data class SlotLabels(
    /** 行内胶囊：`三 3-4节`（Dart `_slotLabel`，用星期短名 + 节次区间）。 */
    val short: String,
    /** 展开详情：`周三 第 3～4 节`（Dart `statisticsRankingSlotDetail`，用星期全名）。 */
    val detail: String,
)

/**
 * 课程排行的一行。
 *
 * @param rank 名次（1 基）。**严格照 Dart `index + 1`**，并列不特殊处理
 *   ——理由与取舍见 [ChartMath.sequentialRanks] 的 KDoc。
 */
data class CourseRankingRow(
    val rank: Int,
    val name: String,
    val teacher: String,
    val isRequired: Boolean,
    /** 必修 / 选修文字（ARB）。 */
    val natureLabel: String,
    val totalSections: Int,
    val slots: List<SlotLabels>,
    /** 该课课时占榜首的比例（0..1），用于画排名条。 */
    val barFraction: Double,
) {
    /** 名次 1~3 用奖杯图标，其余用数字（Dart `_RankBadge` 的 `switch (rank)`）。 */
    val showsTrophy: Boolean get() = rank in 1..3
}

/**
 * 课程排行（按整个学期课时排序）的模型层。
 *
 * 对应 Dart `lib/widgets/statistics/course_ranking.dart`（405 行）：
 * 每行 = 名次徽章 + 课程名 + 必修/选修胶囊 + 教师 + 时间槽胶囊 + 课时数，
 * 点开还有「每个时间槽的星期/节次/教室」明细与「编辑课程」入口。
 */
object CourseRankingModel {

    /** 空列表时显示的文案（Dart `l10n.statisticsNoData`）。 */
    val emptyMessage: String get() = ChartsStrings.statisticsNoData.zh

    /**
     * 构建排行行；入参必须已按课时**降序**排好（排序是上游统计服务的职责，
     * Dart 侧同理——`course_ranking.dart` 直接按下标编号）。
     */
    fun build(courseRanking: List<CourseSemesterStat>): List<CourseRankingRow> {
        if (courseRanking.isEmpty()) return emptyList()
        val top = courseRanking.maxOf { it.totalSections }
        return courseRanking.mapIndexed { index, stat ->
            CourseRankingRow(
                rank = ChartMath.rankOf(index),
                name = stat.name,
                teacher = stat.teacher,
                isRequired = stat.nature == CourseNature.REQUIRED,
                natureLabel = natureLabel(stat.nature),
                totalSections = stat.totalSections,
                slots = stat.slots.map { slotLabels(it) },
                barFraction = ChartMath.normalize(stat.totalSections.toDouble(), top.toDouble()),
            )
        }
    }

    /** 必修 / 选修文字：Dart `isRequired ? courseNatureRequired : courseNatureElective`。 */
    fun natureLabel(nature: CourseNature): String =
        if (nature == CourseNature.REQUIRED) {
            ChartsStrings.courseNatureRequired.zh
        } else {
            ChartsStrings.courseNatureElective.zh
        }

    /** 单个时间槽的两种写法。 */
    fun slotLabels(slot: CourseSlot): SlotLabels = SlotLabels(
        short = shortSlotLabel(slot.dayOfWeek, slot.startSection, slot.endSection),
        detail = detailSlotLabel(slot.dayOfWeek, slot.startSection, slot.endSection),
    )

    /**
     * 行内胶囊：`三 3-4节`；单节课时写 `三 3节`（Dart：
     * `startSection == endSection ? '$start' : '$start-$end'`）。
     *
     * 星期越界时 [ChartsStrings.weekdayShort] 返回空串，标签会以空格开头——
     * 这是 Dart 原行为（越界数据本来就该在上游被过滤）。
     */
    fun shortSlotLabel(dayOfWeek: Int, startSection: Int, endSection: Int): String {
        val day = ChartsStrings.weekdayShort(dayOfWeek)
        val sections = if (startSection == endSection) {
            startSection.toString()
        } else {
            "$startSection-$endSection"
        }
        return "$day $sections${ChartsStrings.statisticsSectionUnit.zh}"
    }

    /** 展开详情：`周三 第 3～4 节`（ARB `statisticsRankingSlotDetail`）。 */
    fun detailSlotLabel(dayOfWeek: Int, startSection: Int, endSection: Int): String =
        ChartsStrings.statisticsRankingSlotDetail.filled(
            "day" to ChartsStrings.weekdayFull(dayOfWeek),
            "startSection" to startSection.toString(),
            "endSection" to endSection.toString(),
        )

    /** 时间槽胶囊每行的最大个数（Dart 用 `Wrap`，这里是它换行的语义值）。 */
    const val SLOT_CHIPS_PER_ROW = 3
}

/**
 * 周统计视图（周选择器 + 本周小结 + 每日分布 + 必修/选修 + 时间利用 + 课程列表）。
 *
 * 对应 Dart `lib/widgets/statistics/week_stats_view.dart`（490 行）。
 * 视图本身是组合，模型层只钉**可错的那几个量**：周次文案、是否当前周、
 * 课程列表的数值排序与名次、每日柱图的强调档（已由 [DailyChartModel.weekSpec] 负责）。
 */
object WeekStatsModel {

    /** 周选择器主文案：`第 5 周`。 */
    fun weekSelectorLabel(week: Int): String =
        ChartsStrings.statisticsWeekSelector.filled("week", week.toString())

    /** 是否当前教学周（决定要不要挂「本周」小胶囊）。 */
    fun isCurrentWeek(week: Int, currentSemesterWeek: Int?): Boolean =
        currentSemesterWeek != null && week == currentSemesterWeek

    /** 「本周」胶囊文案。 */
    val currentWeekHint: String get() = ChartsStrings.statisticsWeekCurrentHint.zh

    /**
     * 本周课程列表的一行。
     *
     * @param weeklySections 周课时（Dart 展示的是 `weeklySections`，不是学期总课时）
     */
    data class WeekCourseRow(
        val name: String,
        val teacher: String,
        val isRequired: Boolean,
        val natureLabel: String,
        val weeklySections: Int,
        val slots: List<SlotLabels>,
    )

    /** 本周课程列表（保持上游顺序，不重排——Dart 也是直接遍历 `courseStats`）。 */
    fun buildCourseRows(stats: WeeklyStats): List<WeekCourseRow> =
        stats.courseStats.map { stat -> courseRow(stat) }

    /** 单条课程 → 列表行。 */
    fun courseRow(stat: CourseStat): WeekCourseRow = WeekCourseRow(
        name = stat.name,
        teacher = stat.teacher,
        isRequired = stat.nature == CourseNature.REQUIRED,
        natureLabel = CourseRankingModel.natureLabel(stat.nature),
        weeklySections = stat.weeklySections,
        slots = stat.slots.map { CourseRankingModel.slotLabels(it) },
    )

    /** 周次下拉可选项（1..maxWeek）。 */
    fun weekOptions(maxWeek: Int): List<Int> =
        if (maxWeek <= 0) emptyList() else (1..maxWeek).toList()

    /** 本周总课时（周视图顶部的数字）。 */
    fun totalSections(stats: WeeklyStats): Int = stats.totalSections

    /** 本周课程门数。 */
    fun courseCount(stats: WeeklyStats): Int = stats.totalCourses
}
