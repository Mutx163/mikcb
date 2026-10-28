package com.mutx163.qingyu.pages.timetable.month

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import com.mutx163.qingyu.app.HomeMenuStyle
import com.mutx163.qingyu.app.HomeTitleStyle
import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.calendar.HolidayData
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.pages.timetable.TimetableMenuItem
import java.time.LocalDateTime

/**
 * 月视图的**渲染入口**：把宿主手里的真实数据喂给 [MonthViewPage]。
 *
 * ## 它补的是哪一段
 *
 * 2026-10-27 深夜交付时，月视图有两半：纯模型（[MonthGridModel] /
 * [MonthDayAgendaModel]）和纯渲染（[MonthViewPage]，只认两个数据源函数）。
 * 中间的装配层（快照 → 42 格 + 当日议程）是空的，所以壳里这一条只能标
 * 「缺宿主数据」。装配本身在 [MonthViewDataSource]（纯 Kotlin，有 JVM 单测），
 * 本文件只做**三件不该在页面里做的事**：
 *
 * 1. 把 [MonthViewDataSource] 按输入重建（数据源对象要跟着数据走，不能每帧新建）；
 * 2. 把 `gridProvider` / `agendaProvider` / `dataRevision` 一起交给页面；
 * 3. 让「今天」只有一个来源（[now]），页面与装配层用的是**同一个**时刻。
 *
 * ## 刻意没做（壳侧接线不在本泳道）
 *
 * - 不订阅仓储、不读盘、不取设置存档里那两个假期开关：这些都在壳侧（属 Lead），
 *   本函数只接收已经取好的值。宿主怎么把 `TimetableRepository.observe` 的
 *   `TimetableSnapshot`、考试仓储、日程仓储、节假日数据接进来，是壳接线那一步的事。
 * - 不做「今天」的定时刷新：`now` 只影响考试是否过期，跨过考试结束时刻的
 *   分钟级误差不影响月网格显示。宿主需要更实时就自己换 [now]。
 *
 * @param snapshot 课表仓储的不可变快照（课程 / 设置 / 当前周 / 开学日 / 时间模板）。
 * @param now 判定考试过期的「此刻」。**为 null 时取第一次组合时的时刻并记住**
 *   （不传就让页面自己稳定住，避免默认参数每帧 `LocalDateTime.now()` 造成
 *   数据源对象每帧重建）。
 * @param exams 全部考试；日程、节假日的口径说明见 [MonthViewDataSource]。
 * @param onOpenAgendaRow 点议程行（去课程 / 考试 / 日程的编辑页）。
 * @param onAddCourse 空态卡里的「加课」（带回那天的日期；教学周次用
 *   [MonthViewDataSource.weekForDate] 取，不要在表单里另算一套）。
 */
@Composable
fun MonthViewHost(
    snapshot: TimetableSnapshot,
    modifier: Modifier = Modifier,
    now: LocalDateTime? = null,
    exams: List<Exam> = emptyList(),
    scheduleItems: List<ScheduleItem> = emptyList(),
    holidayData: HolidayData? = null,
    holidayOverrideEnabled: Boolean = false,
    holidayMarkingEnabled: Boolean = true,
    showWeekNumbers: Boolean = true,
    onOpenAgendaRow: (MonthAgendaRow) -> Unit = {},
    onAddCourse: (LocalDateTime) -> Unit = {},
    homeTitleStyle: HomeTitleStyle = HomeTitleStyle.CLASSIC,
    profileName: String? = null,
    homeMenuStyle: HomeMenuStyle = HomeMenuStyle.LIST,
    homeMenuItems: List<TimetableMenuItem> = emptyList(),
    onHomeMenuSelect: (String) -> Unit = {},
) {
    val clock = now ?: remember { LocalDateTime.now() }

    // 数据源跟着「真实输入」重建：同一份数据重建一次也不换版本戳（见 revision），
    // 所以页面缓存的 42 格不会被无谓重算。
    val source = remember(
        snapshot,
        clock,
        exams,
        scheduleItems,
        holidayData,
        holidayOverrideEnabled,
        holidayMarkingEnabled,
    ) {
        MonthViewDataSource(
            snapshot = snapshot,
            now = clock,
            exams = exams,
            scheduleItems = scheduleItems,
            holidayData = holidayData,
            holidayOverrideEnabled = holidayOverrideEnabled,
            holidayMarkingEnabled = holidayMarkingEnabled,
        )
    }

    MonthViewPage(
        gridProvider = { year, month -> source.grid(year, month) },
        agendaProvider = { date -> source.agenda(date) },
        modifier = modifier,
        initialYear = clock.year,
        initialMonth = clock.monthValue,
        today = clock,
        dataRevision = source.revision,
        showWeekNumbers = showWeekNumbers,
        onOpenAgendaRow = onOpenAgendaRow,
        onAddCourse = onAddCourse,
        homeTitleStyle = homeTitleStyle,
        profileName = profileName,
        homeMenuStyle = homeMenuStyle,
        homeMenuItems = homeMenuItems,
        onHomeMenuSelect = onHomeMenuSelect,
    )
}
