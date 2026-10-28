package com.mutx163.qingyu.pages.timetable.month

import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.calendar.HolidayData
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeSchemeLogic
import com.mutx163.qingyu.core.WeekCalculator
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 月视图的**宿主数据装配层**：真实课表快照 → 42 格月网格 + 当日议程。
 *
 * ## 为什么需要这一层（补的到底是哪个缺口）
 *
 * 2026-10-27 深夜交付的月视图只有两半：**纯模型**（[MonthGridModel] /
 * [MonthDayAgendaModel]，判据全在里头）与**纯渲染**（`composeP1` 的 `MonthViewPage`，
 * 它只要两个函数 `gridProvider` / `agendaProvider`）。
 *
 * 中间那一层一直没人写：**谁把仓储的 [TimetableSnapshot]、考试、日程、节假日
 * 拼成那两个函数**。壳因此只能把月视图标成「缺宿主数据」（`ShellPageCatalog`
 * 的 `MISSING_HOST_DATA`），页面写得再全也进不去。
 *
 * 本类就是那一层，且刻意**不碰 Android / Compose / IO**：
 * 它只做「输入 → 输出」的换算，所以能进 L0 的 JVM 单测；真正读盘、订阅仓储、
 * 取当前时间都由宿主（壳侧，属 Lead 接线范围）在构造前完成。
 *
 * ## 输入的边界（诚实清单，别指望它做更多）
 *
 * - [snapshot] 只带 `courses` / `settings` / `currentWeek` / `semesterStartEpochDay`
 *   / `timeSchemes` / `activeTimeSchemeId`；**考试与日程不在快照里**（它们各有
 *   自己的仓储），所以必须由宿主另行传入 [exams] / [scheduleItems]。
 * - 节假日的两个开关（`holidayOverrideEnabled` / `holidayMarkingEnabled`）同样
 *   不在 `core.TimetableSettings` 的四键子集里，宿主按设置存档读出后传进来
 *   —— 与 [MonthGridModel.build] 的入参口径完全一致，不在这里另立一套。
 * - **不取「今天」**：[now] 必须从外面给。测试固定日期才不会隔天翻红。
 *
 * ## 两个键的取法（唯一实现，渲染层不许再算一遍）
 *
 * - **开学日**：优先 [TimetableSnapshot.semesterStartEpochDay]（天序，不含时区），
 *   它为空才回落 `settings.semesterStartDate`（旧存档 / 手工构造的快照）。
 *   天序优先的理由与仓储头注释同源：毫秒会带写入方时区，换时区恢复会挪天。
 * - **节次表**：与 Dart `month_view_screen.dart:_sectionsFor` 逐字同口径 ——
 *   **当前生效的时间模板优先**，模板缺失或模板内节次为空才回落
 *   `settings.sections`。这里**不做**课程级 / 地点匹配的作息覆盖：那是周视图
 *   逐门课的口径，月视图一天一格、只画「第几节几点上」，两套混用会让同一门课
 *   在月视图与日视图显示不同钟点。
 *
 * ## 刻意不做的
 *
 * - 不缓存 42 格：[MonthViewPage] 自己按 `(年, 月, dataRevision)` 记结果，
 *   本类每次 [grid] 现算（42 天 × 过滤，纯内存）。
 * - 不用 [TimetableSnapshot.currentWeek] 算月网格周次：一格的周次必须由**那一天的
 *   日期**与开学日推出，拿「现在第几周」去顶会在翻月时整月错位。它只在
 *   [weekForDate] 里作为「学期未配置」的回落值出现（与周视图同一回落口径）。
 */
class MonthViewDataSource(
    /** 课表仓储的不可变快照（课程 / 设置 / 当前周 / 开学日 / 时间模板）。 */
    val snapshot: TimetableSnapshot,

    /**
     * 判定考试过期的「此刻」（只需精确到分钟）。
     *
     * **不进 [revision]**：它只影响「这场考试还显不显示」，不影响 42 格的缓存键。
     * 页面在拖拽的每一帧都会重算 `remember`，把 `now` 塞进版本戳会让 42 格
     * 每帧重算一遍（纯浪费）。宿主要求「过整点后立刻去掉过期考试」时，
     * 换一个新的 [revision] 语义由宿主决定（换 history 时重取即可）。
     */
    val now: LocalDateTime,

    /** 全部考试（月网格只数未过期的，议程同样过滤）。 */
    val exams: List<Exam> = emptyList(),

    /** 全部日程条目（含系列与例外；展开判据在 [MonthGridModel.scheduleInstancesOnDate]）。 */
    val scheduleItems: List<ScheduleItem> = emptyList(),

    /** 年度节假日数据；null = 没有数据（不作假，既不标假期也不标调休）。 */
    val holidayData: HolidayData? = null,

    /** 假期覆盖开关（用户设置；默认值与 Dart 一致，见 [MonthGridModel.build]）。 */
    val holidayOverrideEnabled: Boolean = false,

    /** 假期标记开关（同上）。 */
    val holidayMarkingEnabled: Boolean = true,
) {

    /** 学期开学日（本地零点）；null = 学期未配置（周次列整体隐藏）。 */
    val semesterStart: LocalDateTime? = semesterStartOf(snapshot)

    /** 课程节次 → 钟点要用的节次表（当前生效模板优先，缺失回落设置里那份）。 */
    val sections: List<SectionTime> = sectionsOf(snapshot)

    /** 学期是否已配置（渲染层据此决定要不要画「第 N 周」列）。 */
    val hasSemester: Boolean
        get() = semesterStart != null

    /**
     * [year] 年 [month] 月的 42 格月网格（含前后月补位）。
     *
     * **必须幂等**：[MonthViewPage] 会在「换月 / 换版本戳」时重新调用，但同一组
     * 输入必须给出同一份结果（它据此缓存）。
     *
     * 年月先按日历语义归一（13 月 → 次年 1 月、0 月 → 上年 12 月，与 Dart
     * `DateTime(year, month)` 同口径），再把**归一后的年月**交给
     * [MonthGridModel.build]：不归一会让「本月/邻月」判据拿 `13` 去比
     * `date.monthValue`，整屏 42 格全被判成邻月、忙碌日直接清零。
     */
    fun grid(year: Int, month: Int): MonthGrid {
        val anchor = monthAnchor(year, month)
        return MonthGridModel.build(
            semesterStart = semesterStart,
            settings = snapshot.settings,
            courses = snapshot.courses,
            exams = exams,
            scheduleItems = scheduleItems,
            holidayData = holidayData,
            today = now,
            year = anchor.year,
            month = anchor.monthValue,
            holidayOverrideEnabled = holidayOverrideEnabled,
            holidayMarkingEnabled = holidayMarkingEnabled,
        )
    }

    /**
     * [date] 当天的议程行（课程 / 考试 / 日程混排，已按钟点排序）。
     *
     * 日期只取日历日部分；不属于当天的条目不会混进来。
     */
    fun agenda(date: LocalDateTime): List<MonthAgendaRow> = MonthDayAgendaModel.build(
        date = date,
        courses = snapshot.courses,
        exams = exams,
        scheduleItems = scheduleItems,
        semesterStart = semesterStart,
        sections = sections,
        now = now,
    )

    /**
     * [date] 所属的教学周次（1 起，钳到学期周数）。
     *
     * 学期未配置时回落 [TimetableSnapshot.currentWeek] —— 与周视图标题的回落口径
     * 同一句话。月视图的「空态卡 → 加课」要把那天的星期与所在周带进表单，
     * 就是从这里取；网格角标**不用**这个函数（网格用真实周次，不钳制）。
     */
    fun weekForDate(date: LocalDateTime): Int = WeekCalculator.weekForDate(
        date = date,
        semesterStart = semesterStart,
        semesterWeekCount = snapshot.settings.semesterWeekCount,
        fallback = snapshot.currentWeek,
    )

    /**
     * 月份锚点：把 `(year, month)` 归一到合法年月（1 起）。
     *
     * `java.time` 的 `LocalDate.of` 对越界月份**抛异常**而不是顺延，所以先锚到
     * 该年 1 月再加月数 —— 这正好等价于 Dart `DateTime(year, month)` 的归一语义
     * （Dart 的 `month` 可以为 0 或 13）。
     */
    private fun monthAnchor(year: Int, month: Int): LocalDate =
        LocalDate.of(year, 1, 1).plusMonths((month - 1).toLong())

    /**
     * 数据版本戳：任意一项真实输入变了就换一个新值。
     *
     * 直接交给 [MonthViewPage] 的 `dataRevision`：页面靠它丢弃缓存的两份数据
     * （月网格 + 当日议程）。用输入本身做戳而不是递增计数，是为了让「同一份数据
     * 重建一次 data source」不触发无谓重算。
     *
     * 刻意不含 [now]（理由见构造参数注释）：只在跨过考试结束时刻的时刻误差，
     * 不会让网格显示错课程。
     */
    val revision: List<Any?>
        get() = listOf(
            snapshot,
            exams,
            scheduleItems,
            holidayData,
            holidayOverrideEnabled,
            holidayMarkingEnabled,
        )

    companion object {

        /**
         * 从快照解出开学日：**天序优先**，为空才回落设置里的毫秒/文本键。
         *
         * 两者都给且不一致时以天序为准：天序是仓储写盘时归一过的日历日
         * （`LocalDate.toEpochDay()`），设置里的那个可能来自旧毫秒键、
         * 带着写入方时区。这条优先级有单测钉住，别改成「谁先读到谁算」。
         */
        fun semesterStartOf(snapshot: TimetableSnapshot): LocalDateTime? {
            val epochDay = snapshot.semesterStartEpochDay
            if (epochDay != null) {
                return LocalDate.ofEpochDay(epochDay).atStartOfDay()
            }
            return snapshot.settings.semesterStartDate
        }

        /**
         * 从快照解出节次表：当前生效的时间模板优先，缺失（或模板内节次为空）
         * 回落 `settings.sections`。
         *
         * 与 Dart `_sectionsFor` 同口径；也刻意不用
         * [TimeSchemeLogic.resolveCourseTimeScheme]（那是逐门课的口径）。
         */
        fun sectionsOf(snapshot: TimetableSnapshot): List<SectionTime> {
            val schemeId = snapshot.activeTimeSchemeId ?: snapshot.settings.activeTimeSchemeId
            val schemeSections = TimeSchemeLogic.getSchemeById(snapshot.timeSchemes, schemeId)?.sections
            if (!schemeSections.isNullOrEmpty()) return schemeSections
            return snapshot.settings.sections
        }
    }
}
