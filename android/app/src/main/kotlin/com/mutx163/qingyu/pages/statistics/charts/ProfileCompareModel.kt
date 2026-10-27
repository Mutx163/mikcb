package com.mutx163.qingyu.pages.statistics.charts

import kotlin.math.roundToInt

/**
 * 课表对比的一行输入（一门课表的快照）。
 *
 * Dart 侧同名类在 `lib/widgets/statistics/profile_compare_card.dart:6-24`；
 * 这里放在模型层，让「列宽 / 百分比 / 差值文案」先被单测钉住再画。
 */
data class ProfileCompareEntry(
    val name: String,
    /** 是否是当前正在用的课表（决定圆点颜色、名次加粗、节数高亮）。 */
    val isActive: Boolean,
    val currentWeek: Int,
    val totalSections: Int,
    val totalCourses: Int,
    /** 必修占比（0..1），界面上只显示必修，选修 = 100 − 必修 不重复占列。 */
    val requiredRatio: Double,
    val longestStreak: Int,
    /** 相对当前课表的课时差；当前课表这一项为 `null`。 */
    val deltaSections: Int? = null,
)

/** 对比表的一行（已把数值格式化成屏上文案）。 */
data class ProfileCompareRow(
    val name: String,
    val isActive: Boolean,
    /** 四列读数：课程门数 / 节课 / 必修占比 / 天连续。 */
    val columns: List<String>,
    /** `第 5 周` */
    val weekLabel: String,
    /** 当前课表时的「当前课表」标记；否则为 `null`。 */
    val activeLabel: String?,
    /** `较当前 +3 节`；当前课表或无差值时为 `null`。 */
    val deltaLabel: String?,
    val deltaTone: ChartMath.DeltaTone?,
)

/**
 * 课表对比卡（表格式平铺：指标做表头、课表做行）。
 *
 * 对应 Dart `lib/widgets/statistics/profile_compare_card.dart`（232 行）。
 *
 * ## 为什么四列是**定宽右对齐**
 *
 * Dart 注释写得很清楚：对比页的核心是「同一列比大小」，不是每张课表一块自我介绍。
 * 列宽取「表头（11sp 中文）与数值（18sp）的最大需求宽度」，四列分别为
 * 48 / 40 / 64 / 36 dp，列间距 8dp。改宽度会让表头与数据列错位。
 */
object ProfileCompareModel {

    /** 课程门数列表宽（`_colCourses`）。 */
    const val COL_COURSES_DP = 48f

    /** 节课列表宽（`_colSections`）。 */
    const val COL_SECTIONS_DP = 40f

    /** 必修占比列宽（`_colRatio`）。 */
    const val COL_RATIO_DP = 64f

    /** 天连续列宽（`_colStreak`）。 */
    const val COL_STREAK_DP = 36f

    /** 列间距（`_colGap`）。 */
    const val COL_GAP_DP = 8f

    /** 表头文案（顺序与 [ProfileCompareRow.columns] 一一对应）。 */
    fun headers(): List<String> = listOf(
        ChartsStrings.statisticsCourseCount.zh,
        ChartsStrings.statisticsSemesterLabelSections.zh,
        ChartsStrings.statisticsNatureRatio.zh,
        ChartsStrings.statisticsSemesterLabelDayStreak.zh,
    )

    /** 表头对应的列宽（与 [headers] 同序）。 */
    fun headerWidths(): List<Float> = listOf(
        COL_COURSES_DP,
        COL_SECTIONS_DP,
        COL_RATIO_DP,
        COL_STREAK_DP,
    )

    fun rows(entries: List<ProfileCompareEntry>): List<ProfileCompareRow> =
        entries.map { entry ->
            val delta = entry.deltaSections
            ProfileCompareRow(
                name = entry.name,
                isActive = entry.isActive,
                columns = listOf(
                    entry.totalCourses.toString(),
                    entry.totalSections.toString(),
                    percentLabel(entry.requiredRatio),
                    entry.longestStreak.toString(),
                ),
                weekLabel = WeekStatsModel.weekSelectorLabel(entry.currentWeek),
                activeLabel = if (entry.isActive) ChartsStrings.statisticsCompareActive.zh else null,
                deltaLabel = if (!entry.isActive && delta != null) {
                    ChartsStrings.statisticsCompareDelta.filled("delta", ChartMath.deltaText(delta))
                } else {
                    null
                },
                deltaTone = if (!entry.isActive && delta != null) ChartMath.deltaTone(delta) else null,
            )
        }

    /**
     * 必修占比：四舍五入到整数百分比。
     *
     * Dart 写的是 `(ratio * 100).round()`，这里用同一口径（不用 [ChartMath.percentRounded]，
     * 因为那个签名要求整数分子分母，而这边拿到的是已经算好的 double 比例）。
     */
    fun percentLabel(ratio: Double): String =
        "${(ratio.coerceIn(0.0, 1.0) * 100).roundToInt()}%"
}
