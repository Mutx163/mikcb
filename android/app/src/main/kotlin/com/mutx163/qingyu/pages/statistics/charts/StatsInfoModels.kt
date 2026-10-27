package com.mutx163.qingyu.pages.statistics.charts

import com.mutx163.qingyu.statistics.SemesterProgress
import com.mutx163.qingyu.statistics.SemesterProgressPhase
import com.mutx163.qingyu.statistics.TeacherStat
import com.mutx163.qingyu.statistics.TimeUtilizationStats
import com.mutx163.qingyu.statistics.VenueStats
import java.time.LocalDate
import kotlin.math.roundToInt

/** 时间利用卡的读数色（对应 Dart 每行一个语义色）。 */
enum class TimeAccent { ORANGE, INDIGO, YELLOW, TEAL, PURPLE, BLUE, RED }

/** 一行读数：标签 + 读数 + 语义色。 */
data class TimeFact(
    val label: String,
    val value: String,
    val accent: TimeAccent,
)

/**
 * 时间利用分析（7 项并列读数）。
 *
 * 对应 Dart `lib/widgets/statistics/time_utilization_card.dart`（163 行）。
 */
object TimeUtilizationModel {

    /** 读数项数与顺序与 Dart 完全一致（早→晚→早间→午间→晚间→周末→最长空档）。 */
    fun facts(stats: TimeUtilizationStats): List<TimeFact> {
        val empty = ChartsStrings.statisticsNoData.zh
        val unit = ChartsStrings.statisticsSectionsUnit.zh
        fun orEmpty(value: String) = value.ifEmpty { empty }
        return listOf(
            TimeFact(ChartsStrings.statisticsTimeEarliest.zh, orEmpty(stats.earliestStart), TimeAccent.ORANGE),
            TimeFact(ChartsStrings.statisticsTimeLatest.zh, orEmpty(stats.latestEnd), TimeAccent.INDIGO),
            TimeFact(ChartsStrings.statisticsTimeMorning.zh, "${stats.morningSections} $unit", TimeAccent.YELLOW),
            TimeFact(ChartsStrings.statisticsTimeNoon.zh, "${stats.noonSections} $unit", TimeAccent.TEAL),
            TimeFact(ChartsStrings.statisticsTimeEvening.zh, "${stats.eveningSections} $unit", TimeAccent.PURPLE),
            TimeFact(ChartsStrings.statisticsTimeWeekend.zh, "${stats.weekendSections} $unit", TimeAccent.BLUE),
            TimeFact(
                ChartsStrings.statisticsTimeGap.zh,
                ChartsStrings.statisticsTimeGapValue.filled(
                    "sections",
                    stats.maxDailyGapSections.toString(),
                ),
                TimeAccent.RED,
            ),
        )
    }
}

/** 一条横条读数的模型：标签 + 读数 + 填充比例。 */
data class BarRowModel(
    val label: String,
    val value: String,
    val fraction: Double,
)

/** 教室与教学楼的分组读数。 */
data class VenueBars(
    val rooms: List<BarRowModel>,
    val buildings: List<BarRowModel>,
) {
    val isEmpty: Boolean get() = rooms.isEmpty() && buildings.isEmpty()
}

/**
 * 教室与教学楼统计。
 *
 * 对应 Dart `lib/widgets/statistics/venue_stats_card.dart`（177 行）：
 * 两组横条读数（常去教室 / 教学楼课时），比例 = 本项 / **榜首项**。
 *
 * Dart 用的是 `first`（假定上游已按次数降序），这里保留同一口径但加了防零：
 * 榜首为 0 时比例取 0，避免除零得到 NaN 把整条画丢。
 */
object VenueStatsModel {

    fun bars(stats: VenueStats): VenueBars {
        val maxRoom = stats.topRooms.firstOrNull()?.visits ?: 0
        val maxBuilding = stats.buildings.firstOrNull()?.sections ?: 0
        val unit = ChartsStrings.statisticsSectionsUnit.zh
        return VenueBars(
            rooms = stats.topRooms.map { room ->
                BarRowModel(
                    label = room.name,
                    value = ChartsStrings.statisticsVenueVisits.filled("count", room.visits.toString()),
                    fraction = ChartMath.normalize(room.visits.toDouble(), maxRoom.toDouble()),
                )
            },
            buildings = stats.buildings.map { building ->
                BarRowModel(
                    label = building.name,
                    value = "${building.sections} $unit",
                    fraction = ChartMath.normalize(building.sections.toDouble(), maxBuilding.toDouble()),
                )
            },
        )
    }
}

/** 教师课时排行的一行。 */
data class TeacherRow(
    val rank: Int,
    val name: String,
    /** `3 门课` */
    val courseCountLabel: String,
    /** `12 节` */
    val sectionsLabel: String,
) {
    /** 前三名名次数字用黄色（Dart `i < 3 ? yellow : secondaryText`）。 */
    val topThree: Boolean get() = rank <= 3
}

/**
 * 教师课时排行。
 *
 * 对应 Dart `lib/widgets/statistics/teacher_stats_card.dart`（97 行）。
 * 名次同样照 Dart 的 `i + 1`（并列不特殊处理，见 [ChartMath.sequentialRanks]）。
 */
object TeacherStatsModel {

    fun rows(stats: List<TeacherStat>): List<TeacherRow> {
        val unit = ChartsStrings.statisticsSectionsUnit.zh
        return stats.mapIndexed { index, stat ->
            TeacherRow(
                rank = ChartMath.rankOf(index),
                name = stat.name,
                courseCountLabel = ChartsStrings.statisticsTeacherCourseCount
                    .filled("count", stat.courseCount.toString()),
                sectionsLabel = "${stat.sections} $unit",
            )
        }
    }
}

/**
 * 学期进度的渲染规格。
 *
 * 对应 Dart `lib/widgets/statistics/semester_progress_card.dart`（148 行）。
 */
data class SemesterProgressSpec(
    /** 右上角 `8/20`（已过周 / 总周数）。 */
    val weekRatioLabel: String,
    /** `学期 2026年9月1日 - 2027年1月10日`；无开学日期时为 `null`。 */
    val dateRangeLabel: String?,
    /** 进度比例 0..1（画进度条用）。 */
    val percent: Double,
    /** `50%`。 */
    val percentLabel: String,
    /** `截至第 8 周，已上 96 节 / 共 192 节` 或 `还未开学，尚未上课`。 */
    val detailLabel: String,
    /** 左侧读数下的说明：`今天 9月1日` 或 `按周估算`。 */
    val sideLabel: String?,
    /** 右侧读数：`剩余 96 节`。 */
    val remainingLabel: String?,
    /** 是否还没开学（左侧文案换成「还未开学，尚未上课」，右侧整列不显示）。 */
    val beforeStart: Boolean,
)

object SemesterProgressModel {

    /**
     * 构建进度卡规格。
     *
     * 日期格式按中文习惯手写（`2026年9月1日` / `9月1日`），与 Dart
     * `DateFormat.yMMMd(l10n.localeName)` 在 zh 下的输出一致。
     * **已知范围**：其它语区的日期格式不同，本批只钉中文；
     * 多语区日期格式属本地化批次，别在这里硬编码更多格式。
     */
    fun build(progress: SemesterProgress): SemesterProgressSpec {
        val start = progress.semesterStartDate
        val end = progress.semesterEndDate
        val hasDates = start != null && end != null
        val beforeStart = progress.phase == SemesterProgressPhase.BEFORE_START

        val dateRange = if (hasDates) {
            ChartsStrings.statisticsSemesterProgressRange.filled(
                "start" to formatYmd(start),
                "end" to formatYmd(end),
            )
        } else {
            null
        }

        val detail = if (beforeStart) {
            ChartsStrings.statisticsSemesterProgressNotStarted.zh
        } else {
            ChartsStrings.statisticsSemesterProgressDetail.filled(
                "week" to progress.weeksElapsed.toString(),
                "done" to progress.sectionsDone.toString(),
                "total" to progress.sectionsTotal.toString(),
            )
        }

        val side = when {
            beforeStart -> null
            hasDates && progress.currentDate != null ->
                ChartsStrings.statisticsSemesterProgressAsOf.filled("date" to formatMd(progress.currentDate))
            else -> ChartsStrings.statisticsSemesterProgressEstimated.zh
        }

        val remaining = if (beforeStart) {
            null
        } else {
            ChartsStrings.statisticsSemesterProgressRemaining.filled(
                "count",
                progress.remainingSections.toString(),
            )
        }

        return SemesterProgressSpec(
            weekRatioLabel = "${progress.weeksElapsed}/${progress.totalWeeks}",
            dateRangeLabel = dateRange,
            percent = progress.percent.coerceIn(0.0, 1.0),
            percentLabel = "${(progress.percent.coerceIn(0.0, 1.0) * 100).roundToInt()}%",
            detailLabel = detail,
            sideLabel = side,
            remainingLabel = remaining,
            beforeStart = beforeStart,
        )
    }

    /** `2026年9月1日`。 */
    fun formatYmd(date: LocalDate): String =
        "${date.year}年${date.monthValue}月${date.dayOfMonth}日"

    /** `9月1日`。 */
    fun formatMd(date: LocalDate): String =
        "${date.monthValue}月${date.dayOfMonth}日"
}
