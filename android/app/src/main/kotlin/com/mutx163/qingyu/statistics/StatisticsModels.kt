package com.mutx163.qingyu.statistics

/**
 * 统计模型（源：lib/models/statistics_models.dart + lib/models/statistics_export_options.dart）。
 *
 * 移植说明：
 * - Dart 侧这两个文件**没有** toJson/fromJson（全仓 grep 证实，统计模型的唯一 JSON
 *   契约在 lib/services/stats_widget_service.dart 的 StatsWidgetSnapshot，不在本泳道清单）。
 *   字段名与 Dart 构造参数逐字一致，供后续接入序列化时对齐。
 * - CourseNature 直接复用泳道 A 已落地的 core 包定义（2026-10-26，桩同步改用）。
 * - Dart 的 `IconData icon`（Flutter 图标句柄）在纯逻辑层无意义，以 `icon: Any?` 占位，
 *   由 UI 层按 Achievement.id 自行映射。
 * - 枚举带 [dartName]，钉住与 Dart 完全相同的名字（序列化/对照用）。
 */

import com.mutx163.qingyu.core.CourseNature

/** models:92-98 */
enum class StoryType(val dartName: String) {
    BUSIEST_DAY("busiestDay"), // 最忙的一天
    LIGHTEST_DAY("lightestDay"), // 最轻松的一天
    FAVORITE_ROOM("favoriteRoom"), // 最常去的教室
    BUILDING_COUNT("buildingCount"), // 教学楼数量
    TIME_RANGE("timeRange"), // 时间跨度
}

/** models:234-246 */
enum class SemesterProgressPhase(val dartName: String) {
    /** 已设置开学日期，今天早于开学日 */
    BEFORE_START("beforeStart"),

    /** 学期进行中（按天精确：当前周只累计今天及之前的课时） */
    IN_PROGRESS("inProgress"),

    /** 今天已过学期最后一周，进度收满 */
    ENDED("ended"),

    /** 未设置开学日期，无法锚定真实日期，按查看周整周估算 */
    ESTIMATED("estimated"),
}

/** models:5-24 学期统计总览（账单式） */
data class SemesterStats(
    val totalCourses: Int, // 总课程门数（去重）
    val totalSections: Int, // 总课时数（整个学期，截至当前周）
    val totalWeeks: Int, // 学期总周数
    val longestStreak: Int, // 最长连续上课天数
    val dailyAverages: List<DailyAverageStats>, // 每日平均课时
    val natureStats: CourseNatureStats, // 必修/选修比例
    val courseRanking: List<CourseSemesterStat>, // 课程排行
)

/** models:27-39 每日平均课时统计 */
data class DailyAverageStats(
    val dayOfWeek: Int, // 1-7
    val averageSections: Double, // 平均课时数
    val totalSections: Int, // 总课时数（整个学期）
    val courseCount: Int, // 课程门数
)

/**
 * models:45-63 成就系统（文案由 UI 层 l10n 按 [id] 组装）。
 *
 * [progressCurrent] / [progressTarget] 为可选进度（如 学霸 86/100），
 * 用于展示解锁进度；已解锁时仍保留进度值。
 */
data class Achievement(
    val id: String,
    val icon: Any? = null, // Dart: IconData，纯逻辑层不消费
    val isUnlocked: Boolean,
    val progressCurrent: Int? = null,
    val progressTarget: Int? = null,
) {
    /** 是否携带进度信息（models:61-62） */
    val hasProgress: Boolean
        get() = progressCurrent != null && progressTarget != null && progressTarget > 0

    /**
     * 进度「越小越好」的成就：目标是最多 N 节空档，而不是攒够 N 个。
     *
     * 这两枚（`balanced` 均衡大师 / `gap_master` 时间管理大师）的
     * `progressCurrent` 是当前空档数、`progressTarget` 是上限。拿它当
     * 「已完成 / 目标」显示会得到「6/2」和一条满格进度条——与「未达成」自相矛盾。
     * 渲染层据此**不展示线性进度**（宁缺勿假），只保留达成状态。
     */
    val isLowerBetterProgress: Boolean
        get() = id == "balanced" || id == "gap_master"
}

/** models:66-90 数据故事（结构化数据，文案由 UI 层 l10n 组装） */
data class DataStory(
    val type: StoryType,
    val icon: Any? = null, // Dart: IconData，纯逻辑层不消费
    val dayOfWeek: Int? = null, // 1-7, busiestDay / lightestDay
    val weekNumber: Int? = null,
    val averageSections: Double? = null, // busiestDay / lightestDay
    val room: String? = null, // favoriteRoom
    val visitCount: Int? = null, // favoriteRoom
    val buildingCount: Int? = null, // buildingCount
    val earliestTime: String? = null, // timeRange
    val latestTime: String? = null, // timeRange
)

/** models:101-115 课程学期统计（用于排行榜） */
data class CourseSemesterStat(
    val name: String,
    val teacher: String,
    val nature: CourseNature,
    val totalSections: Int, // 整学期总课时
    val slots: List<CourseSlot>, // 上课时间列表
)

/** models:118-146 周统计概览 */
data class WeeklyStats(
    val weekNumber: Int,
    val totalCourses: Int, // 课程门数（去重）
    val totalSections: Int, // 总课时数
    val dailyStats: List<DailyStats>, // 每日统计
    val natureStats: CourseNatureStats, // 必修/选修统计
    val courseStats: List<CourseStat>, // 各课程统计
) {
    /** 最忙的一天（1-7），无课返回 null（models:136-145，并列取先出现者） */
    val busiestDay: Int?
        get() {
            var max: DailyStats? = null
            for (day in dailyStats) {
                if (day.sectionCount == 0) continue
                if (max == null || day.sectionCount > max.sectionCount) {
                    max = day
                }
            }
            return max?.dayOfWeek
        }
}

/** models:149-159 每日统计 */
data class DailyStats(
    val dayOfWeek: Int, // 1-7 (周一至周日)
    val sectionCount: Int, // 当天课时数
    val courseCount: Int, // 当天课程门数
)

/** models:162-180 必修/选修统计 */
data class CourseNatureStats(
    val requiredCount: Int, // 必修课门数
    val electiveCount: Int, // 选修课门数
    val requiredSections: Int, // 必修课时数
    val electiveSections: Int, // 选修课时数
) {
    val totalCount: Int get() = requiredCount + electiveCount
    val totalSections: Int get() = requiredSections + electiveSections
    val requiredRatio: Double get() = if (totalCount > 0) requiredCount.toDouble() / totalCount else 0.0
    val electiveRatio: Double get() = if (totalCount > 0) electiveCount.toDouble() / totalCount else 0.0
}

/** models:183-197 单门课程的统计信息 */
data class CourseStat(
    val name: String,
    val teacher: String,
    val nature: CourseNature,
    val weeklySections: Int, // 周课时数
    val slots: List<CourseSlot>, // 上课时间列表
)

/** models:200-212 课程的单个时间槽 */
data class CourseSlot(
    val dayOfWeek: Int,
    val startSection: Int,
    val endSection: Int,
    val location: String,
)

/** models:215-231 每周课时趋势点（计划口径，覆盖整个学期） */
data class WeeklyTrendPoint(
    val weekNumber: Int,
    val sections: Int, // 该周计划课时（含单双周/停课扣除）
    val courseCount: Int, // 该周有效课程门数（去重）
    val requiredSections: Int,
    val electiveSections: Int,
    val activeDayCount: Int, // 该周有课的天数
)

/** models:249-273 学期进度（校历对齐，按天精确） */
data class SemesterProgress(
    val semesterStartDate: java.time.LocalDate?, // 开学日期（可为空）
    val currentDate: java.time.LocalDate?, // 计算基准日（真实"今天"；估算口径下为空）
    val semesterEndDate: java.time.LocalDate?, // 学期结束日期
    val weeksElapsed: Int, // 已过周数（开学前为 0；估算口径为当前查看周）
    val totalWeeks: Int, // 学期总周数
    val sectionsDone: Int, // 已上课时（今天及之前实际发生）
    val sectionsTotal: Int, // 学期计划总课时
    val remainingSections: Int, // 剩余课时
    val phase: SemesterProgressPhase, // 进度阶段
) {
    val percent: Double get() = if (sectionsTotal > 0) sectionsDone.toDouble() / sectionsTotal else 0.0
}

/** models:276-290 本周小结（周对比） */
data class WeeklyComparison(
    val weekSections: Int, // 本周课时
    val lastWeekSections: Int, // 上周课时
    val semesterAverageSections: Double, // 学期每周平均课时
    val deltaVsLastWeek: Int, // 较上周差值（正=变多）
    val deltaVsAverage: Double, // 较平均差值
)

/** models:293-321 学期热力图（周 × 天课时密度） */
data class SemesterHeatmap(
    val weekCount: Int,
    val maxSections: Int, // 单格最大值（用于配色标度）
    val rows: List<List<Int>>, // 7 行（周一~周日），每行 [weekCount] 列
) {
    /** 未来周（超过 [currentWeek]）置 0 后返回新实例（models:307-320） */
    fun clippedToWeek(currentWeek: Int): SemesterHeatmap {
        val clipped = List(7) { day ->
            List(weekCount) { week ->
                if (week + 1 <= currentWeek) rows[day][week] else 0
            }
        }
        var max = 0
        for (row in clipped) {
            for (v in row) {
                if (v > max) max = v
            }
        }
        return SemesterHeatmap(weekCount = weekCount, maxSections = max, rows = clipped)
    }
}

/** models:324-346 时间利用统计 */
data class TimeUtilizationStats(
    val earliestStart: String, // 最早上课时间 HH:mm
    val latestEnd: String, // 最晚下课时间 HH:mm
    val morningSections: Int, // 早间课时（12:00 前开始）
    val noonSections: Int, // 午间课时（与 12:00-14:00 相交）
    val eveningSections: Int, // 晚间课时（18:00 后结束）
    val weekendSections: Int, // 周末课时
    val maxDailyGapSections: Int, // 单日最长课间空档（节）
    val activeCourseCount: Int, // 参与统计的排课条目数
) {
    val isEmpty: Boolean get() = activeCourseCount == 0
}

/** models:349-354 教室到访统计 */
data class RoomVisitStat(
    val name: String,
    val visits: Int, // 到访次数（条目数 × 有效周数加权）
)

/** models:357-362 教学楼统计 */
data class BuildingStat(
    val name: String,
    val sections: Int, // 总课时
)

/** models:365-372 教室与教学楼统计 */
data class VenueStats(
    val topRooms: List<RoomVisitStat>,
    val buildings: List<BuildingStat>,
) {
    val isEmpty: Boolean get() = topRooms.isEmpty() && buildings.isEmpty()
}

/** models:375-385 教师课时统计 */
data class TeacherStat(
    val name: String,
    val sections: Int, // 学期总课时
    val courseCount: Int, // 任教课程门数（去重）
)

// ========== statistics_export_options.dart ==========

/** export_options:2-9 Modules that can be included when exporting course statistics. */
enum class StatisticsExportModule(val dartName: String) {
    OVERVIEW("overview"),
    ACHIEVEMENTS("achievements"),
    STORIES("stories"),
    DAILY_DISTRIBUTION("dailyDistribution"),
    NATURE_RATIO("natureRatio"),
    RANKING("ranking"),
}

/** export_options:12-47 User choices from the statistics export sheet (image only). */
data class StatisticsExportOptions(
    val modules: Set<StatisticsExportModule>,
) {
    /** export_options:42 */
    val hasModules: Boolean get() = modules.isNotEmpty()

    companion object {
        /** export_options:18-26 All modules available for export. */
        val allModules: Set<StatisticsExportModule> = StatisticsExportModule.entries.toSet()

        /** export_options:29-36 Default selection: everything except course ranking (long and optional). */
        val defaultModules: Set<StatisticsExportModule> = setOf(
            StatisticsExportModule.OVERVIEW,
            StatisticsExportModule.ACHIEVEMENTS,
            StatisticsExportModule.STORIES,
            StatisticsExportModule.DAILY_DISTRIBUTION,
            StatisticsExportModule.NATURE_RATIO,
        )

        /** export_options:38-40 */
        fun defaults(): StatisticsExportOptions = StatisticsExportOptions(modules = defaultModules)
    }
}

/** export_options:50-55 Brand URLs shown on the export-only header / footer. */
object StatisticsExportBrand {
    const val WEBSITE_URL = "https://163366.xyz/"
    const val WEBSITE_DISPLAY = "163366.xyz"
    const val GITHUB_URL = "https://github.com/Mutx163/mikcb"
    const val GITHUB_DISPLAY = "github.com/Mutx163/mikcb"
}
