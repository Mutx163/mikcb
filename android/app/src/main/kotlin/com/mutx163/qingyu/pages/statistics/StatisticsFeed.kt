package com.mutx163.qingyu.pages.statistics

import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.core.ClassReminderLogic
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseSession
import com.mutx163.qingyu.core.CourseSessionStatsCalculator
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.core.clampCurrentWeekToSettings
import com.mutx163.qingyu.pages.statistics.StatisticsSessionModel.StatisticsSessionViewState
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 统计族的**唯一数据入口**：真实课表快照 → 统计页视图状态。
 *
 * ## 为什么需要这一层
 *
 * Phase 3 把统计族 5 页的渲染层与模型层都搬完了，但**没有任何东西给它们提供数据**：
 * 壳（`composeUi`，Lead 专属）只能喂空列表与写死的常量（`currentWeek = 1`、
 * `semesterWeekCount = 20`、`courseNames = emptyList()`），于是统计页永远空态、
 * 或者更糟——喂进一组**看起来像真数据的常量**。本类就是补上这一刀：
 * 把 [TimetableSnapshot]（`app/TimetableRepository` 的只读视图）换装成页面入参。
 *
 * ## 分工（谁都不越界）
 *
 * ```
 * TimetableRepository.snapshot  ← 本类只读，不改 app/ 一行
 *        ↓ StatisticsFeed.Input.fromSnapshot
 * StatisticsFeed                ← 本类：分组 / 周次收敛 / 注入时钟
 *        ↓                            ↓
 * StatisticsSessionModel.viewState   CourseStatisticsLogic.buildViewState（已交付）
 * ```
 *
 * 本类**不做统计算数**：课次展开在 `CourseSessionStatsCalculator`（core），
 * 学期/周聚合在 `statistics.StatisticsService`（domain），屏层文案在
 * `StatisticsStrings` / `StatisticsExtStrings`（ARB 逐字对拍）。
 * 这里只做三件屏层之外没人做的事：
 *
 * 1. **同名课程聚合**（Dart `CourseGroup.buildFrom`：按 `name` 聚合，保留首次出现顺序）；
 * 2. **周次收敛**：快照里的 `currentWeek` 再按 `semesterWeekCount` 钳一次
 *    （与 `TimetableRepository.resolvedCurrentWeek` 同一函数
 *    [clampCurrentWeekToSettings]，防止上游给了越界值就让统计页翻到第 99 周）；
 * 3. **时钟注入**：`now` 是入参，不是 `LocalDateTime.now()`
 *    ——否则「今天/已过/未到」这三档在单测里永远不可复现（TEST-POLICY「日期老化」）。
 *
 * ## 空课表：只给空态，不给假数据
 *
 * - `courses` 为空 → 单节课明细页 `stats == null` + `isEmpty == true`（整页空态，
 *   连课程选择行都不出现），统计主页 `hasData == false` + 空态文案；
 * - 本类**没有任何兜底课程**：宁可空态，也不让「演示数据」冒充用户的课表。
 *   这条由 `StatisticsFeedTest` 的「空课表」用例钉住，咬合探针也打在这里
 *   （把 [Input.fromSnapshot] 改回写死课程 → 用例立刻红）。
 *
 * ## 诚实清单（快照里拿不到的东西，这里不编）
 *
 * | 能力 | 现状 | 影响 |
 * |---|---|---|
 * | 单节课提醒（`classReminders`） | **已接**：`core/TimetableSettings.classReminders` 随快照进来，[Input.reminderKeys] 直接给出真键集 | 明细页「设过提醒」按真实条目计数；空表 = 真的没设过（不再隐藏那一行） |
 * | 节假日（`isHoliday`） | 快照不含节假日表 | 课次不会出现 `HOLIDAY` 阶段；可由调用方注入 `isHoliday` |
 * | 生效作息（`timeSchemes`）解析出的真实钟点 | 快照带 `timeSchemes`，但课次统计按课程自带的 `startTime/endTime` | 与已交付的 `CourseStatisticsLogic` 同口径，不在这里另起一套解析 |
 * | 学期起始日 | 优先用 `semesterStartEpochDay`（天序，跨时区不挪天），缺失才回落 `settings.semesterStartDate` | 未设时统计页走「按周估算」分支，单节课明细页出现 ARB 提示 |
 *
 * ## 只读约束
 *
 * 本文件只 `import` `app/` 里的两个符号（[TimetableSnapshot] 与
 * [TimetableRepository] 的默认档案名常量），**不写也不改 `app/` 下任何文件**
 * ——那里有多条泳道在并行写。
 */
object StatisticsFeed {

    /**
     * 同名课程聚合（Dart `CourseGroup`，`lib/utils/course_group.dart:24-32`）。
     *
     * 单节课明细页是按「课名」选的，一门课一周上两次（两个 [Course] 条目）
     * 必须合成一个可选项目；拆成两项会让同一门课出现两次、每项只有一半课次。
     */
    data class CourseGroup(val name: String, val courses: List<Course>)

    /**
     * 统计族需要的**全部输入**，从快照一次换装出来。
     *
     * 用独立数据类而不是直接吃 [TimetableSnapshot]，理由有二：
     * 1. 单测不必造 `TimetableRepository`（它要 `KeyValueStore`，属 `platform/`，
     *    进不了 JVM classpath）；直接构造本类即可覆盖所有边界；
     * 2. 换装口径（周次钳制、起始日来源、档案名回落）只写一处，壳侧不必重复。
     */
    data class Input(
        val courses: List<Course>,
        val settings: TimetableSettings = TimetableSettings.defaults(),
        val currentWeek: Int = 1,
        /** 学期起始日（天序换装后的日历日）；null = 用户没设开学日期。 */
        val semesterStartDate: LocalDate? = null,
        /** 活动档案名（统计小组件快照上会印出来）；空串 = 无名。 */
        val activeProfileName: String = "",
        /** 除活动档案外还有别的档案（决定「课表对比」入口出不出现）。 */
        val hasOtherProfiles: Boolean = false,
        val tasks: List<CourseTask> = emptyList(),
        val exams: List<Exam> = emptyList(),
    ) {

        /** 学期总周数（Dart `provider.settings.semesterWeekCount`，原样，不做下限修正）。 */
        val semesterWeekCount: Int get() = settings.semesterWeekCount

        val hasCourses: Boolean get() = courses.isNotEmpty()

        val courseCount: Int get() = courses.size

        /** 同一门课的多个上课时段（顺序 = 课程在快照里的出现顺序）。 */
        val courseGroups: List<CourseGroup> get() = groupByCourseName(courses)

        /**
         * 已设的单节课提醒键集合（格式 `courseId|yyyy-MM-dd`）。
         *
         * **真源**：[settings]、即 `core/TimetableSettings.classReminders`（随仓储快照进来）。
         * 空集 = 用户真的没设过提醒，不是「数据拿不到」——两者在屏上的含义完全不同。
         */
        val reminderKeys: Set<String> get() = ClassReminderLogic.keysOf(settings.classReminders)

        /** 收敛后的当前周次：`< 1` 归 1，`> semesterWeekCount` 归总周数。 */
        val settledCurrentWeek: Int
            get() = clampCurrentWeekToSettings(currentWeek.toLong(), settings).toInt()

        /**
         * 课次统计要用的设置：把「起始日」统一成从天序换装出来的那一天。
         *
         * [CourseSessionStatsCalculator] 只认 `settings.semesterStartDate`，
         * 而快照的权威表示是 `semesterStartEpochDay`（天序，跨时区不挪天）。
         * 两者在 `TimetableRepository` 里同源，这里显式以天序为准，避免将来
         * 有人只改一边后两处算出不同的课次日期。
         */
        val settingsWithCalendar: TimetableSettings
            get() = semesterStartDate?.let { settings.copy(semesterStartDate = it.atStartOfDay()) }
                ?: settings

        companion object {

            /**
             * 从仓储快照换装。
             *
             * 只读：不改快照、不改仓储。活动档案的回落顺序与
             * `TimetableRepository.activeProfile` 一致（先按 id 找，找不到退第一份），
             * 这样「盘上 id 悬空」时作业/考试仍能取到**同一份**档案的那批。
             */
            fun fromSnapshot(snapshot: TimetableSnapshot): Input {
                val active = snapshot.profiles.firstOrNull { it.id == snapshot.activeProfileId }
                    ?: snapshot.profiles.firstOrNull()
                return Input(
                    courses = snapshot.courses,
                    settings = snapshot.settings,
                    currentWeek = snapshot.currentWeek,
                    semesterStartDate = resolveSemesterStartDate(snapshot),
                    // 首启（盘上一份档案都没有）时仓储会在内存里合成一份默认档案，
                    // 它的名字不在 profiles 里——回落仓储自己的常量，别在这里另写一份中文。
                    activeProfileName = active?.name ?: TimetableRepository.DEFAULT_PROFILE_NAME,
                    hasOtherProfiles = snapshot.profiles.any { it.id != snapshot.activeProfileId },
                    tasks = active?.tasks ?: emptyList(),
                    exams = active?.exams ?: emptyList(),
                )
            }

            /**
             * 学期起始日：**天序优先**。
             *
             * `semesterStartEpochDay` 是 `LocalDate.toEpochDay()`，写入方时区不会混进来
             * （见 [TimetableSnapshot] KDoc 里那条「换时区恢复会挪天」的历史事故）；
             * 只有它缺失时才回落 `settings.semesterStartDate`（同一份设置的另一份表示）。
             */
            private fun resolveSemesterStartDate(snapshot: TimetableSnapshot): LocalDate? =
                snapshot.semesterStartEpochDay?.let { LocalDate.ofEpochDay(it) }
                    ?: snapshot.settings.semesterStartDate?.toLocalDate()
        }
    }

    /** 在本文件里聚合（`Input.courseGroups` 的公开实现，便于单测直接打）。 */
    fun groupByCourseName(courses: List<Course>): List<CourseGroup> {
        val grouped = LinkedHashMap<String, MutableList<Course>>()
        for (course in courses) {
            grouped.getOrPut(course.name) { mutableListOf() }.add(course)
        }
        return grouped.map { (name, list) -> CourseGroup(name, list.toList()) }
    }

    /**
     * 课次行上的「哪一次」文本（Dart `session_list_card.dart:_title` 的信息量，
     * 但落在 Compose 版的行副标题上）。
     *
     * - 有日期轴：`9月16日 · 周三`；
     * - 没日期轴：`第 3 周 · 周三`（ARB `statisticsWeekSelector`，与主页周选择器同一句）。
     *
     * 文案全部来自既有 ARB（`StatisticsStrings.weekdayFull` / `statisticsWeekSelector`、
     * `StatisticsDateLabels.monthDay`），本类**不自拟任何可见文字**。
     */
    fun sessionDateText(session: CourseSession): String {
        val weekday = StatisticsStrings.weekdayFull(session.dayOfWeek)
        val date = session.date
        return if (date != null) {
            "${StatisticsDateLabels.monthDay(date)} · $weekday"
        } else {
            val weekLabel = StatisticsStrings.statisticsWeekSelector.filled(
                "week" to session.week.toString(),
            )
            "$weekLabel · $weekday"
        }
    }

    /**
     * 单节课明细页视图状态（`StatisticsSessionViewState`）。
     *
     * @param previousSelection 上次选中的课名；被删了自动回落第一门
     *   （收敛逻辑在 [StatisticsSessionModel.resolveSelection]，这里不另写一份）。
     * @param now 注入时钟（「已过 / 今天 / 未到」的唯一判据来源）。
     * @param reminderKeys 覆盖用的提醒键集合，格式 `courseId|yyyy-MM-dd`；`null` = 用
     *   [Input.reminderKeys]（快照里的真实 `classReminders`）。**数据源已接通**，
     *   空集是「真的没设过」，覆盖行照常画出来（不再因为「拿不到」而整行隐藏）；
     *   保留该参数只为让调用方能显式换一份键集（测试 / 离线导入）。
     * @param isHoliday 节假日判定；快照不含节假日表，默认不判。
     */
    fun sessionViewState(
        input: Input,
        now: LocalDateTime,
        previousSelection: String? = null,
        reminderKeys: Set<String>? = null,
        isHoliday: ((LocalDateTime) -> Boolean)? = null,
    ): StatisticsSessionViewState {
        val groups = input.courseGroups
        val coursesByName = groups.associateBy { it.name }
        val effectiveReminderKeys = reminderKeys ?: input.reminderKeys
        return StatisticsSessionModel.viewState(
            courseNames = groups.map { it.name },
            previousSelection = previousSelection,
            statsOf = { name ->
                coursesByName[name]?.let { group ->
                    CourseSessionStatsCalculator.build(
                        courseName = group.name,
                        courses = group.courses,
                        settings = input.settingsWithCalendar,
                        tasks = input.tasks,
                        exams = input.exams,
                        now = now,
                        isHoliday = isHoliday,
                        reminderKeys = effectiveReminderKeys,
                    )
                }
            },
            dateTextOf = ::sessionDateText,
            reminderDataAvailable = true,
        )
    }

    /**
     * 统计主页视图状态（`CourseStatisticsViewState`）。
     *
     * @param now 注入时钟（学期进度卡的「今天」与「已过多少节」都按它算）。
     * @param selectedWeek 周视图选中的周；null = 跟随当前周。越界由已交付的
     *   [CourseStatisticsLogic.resolveSelectedWeek] 回正，这里不重算。
     * @param semesterView true = 学期视图，false = 周视图（顶部分段选中项）。
     */
    fun homeViewState(
        input: Input,
        now: LocalDateTime,
        selectedWeek: Int? = null,
        semesterView: Boolean = true,
    ): CourseStatisticsViewState {
        val currentWeek = input.settledCurrentWeek
        return CourseStatisticsLogic.buildViewState(
            courses = input.courses,
            currentWeek = currentWeek,
            semesterWeekCount = input.semesterWeekCount,
            semesterStartDate = input.semesterStartDate,
            selectedWeek = selectedWeek ?: currentWeek,
            semesterView = semesterView,
            hasOtherProfiles = input.hasOtherProfiles,
            now = now,
            profileName = input.activeProfileName,
        )
    }

    /**
     * 一次装配两份视图状态：壳每次重组只需要一个入口。
     *
     * 两份状态必须来自**同一份输入**，否则「主页说 3 门课、明细页只有一个可选」
     * 这类不一致会天天出现（它们以前各自被喂一份写死常量，正是这个病）。
     * @param reminderKeys 见 [sessionViewState]：`null` = 用快照里的真实 `classReminders`。
     */
    fun feed(
        input: Input,
        now: LocalDateTime,
        previousSelection: String? = null,
        selectedWeek: Int? = null,
        semesterView: Boolean = true,
        reminderKeys: Set<String>? = null,
        isHoliday: ((LocalDateTime) -> Boolean)? = null,
    ): StatisticsFeedState = StatisticsFeedState(
        session = sessionViewState(
            input = input,
            now = now,
            previousSelection = previousSelection,
            reminderKeys = reminderKeys,
            isHoliday = isHoliday,
        ),
        home = homeViewState(
            input = input,
            now = now,
            selectedWeek = selectedWeek,
            semesterView = semesterView,
        ),
        courseCount = input.courseCount,
        hasOtherProfiles = input.hasOtherProfiles,
        currentWeek = input.settledCurrentWeek,
        semesterWeekCount = input.semesterWeekCount,
    )

    /** 统计族一次装配的产物（壳的入参）。 */
    data class StatisticsFeedState(
        val session: StatisticsSessionViewState,
        val home: CourseStatisticsViewState,
        /** 深度分析二级页只需要「有几门课」这一个数（空态判据），同源给出。 */
        val courseCount: Int,
        val hasOtherProfiles: Boolean,
        val currentWeek: Int,
        val semesterWeekCount: Int,
    ) {
        /** 全族空态：一门课都没有（页面自己画空态，不补假数据）。 */
        val isEmpty: Boolean get() = courseCount == 0
    }
}
