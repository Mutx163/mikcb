package com.mutx163.qingyu.pages.timetable.month

import androidx.compose.foundation.layout.BoxScope
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.mutx163.qingyu.app.HomeMenuStyle
import com.mutx163.qingyu.app.HomeTitleStyle
import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.calendar.HolidayData
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.shell.HomeInkPolarity
import com.mutx163.qingyu.pages.timetable.TimetableMenuItem
import java.time.Duration
import java.time.LocalDateTime
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

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
 * - 不做「今天」的分钟级刷新：本页只关心**哪一天**是今天，所以心跳**不按秒跳**，
 *   而是睡到下一个零点再醒（跨日才换值，不会按分钟改数据）。需要更实时的过期判定
 *   就由宿主自己换 [now]。
 *
 * @param snapshot 课表仓储的不可变快照（课程 / 设置 / 当前周 / 开学日 / 时间模板）。
 * @param now 判定考试过期的「此刻」。**为 null 时取当前时刻，并跨日自动推进**——
 *   睡到下一个零点再探一次，只在日历日变化时换值，所以不会每帧重建数据源；传了值就以传入的
 *   为准（测试 / 预览由调用方自己刷新）。
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
    /** 页面最底层的壁纸槽；由壳从 `rememberHomeBackdropChrome` 取（与周 / 日视图同源）。 */
    backdrop: (@Composable BoxScope.() -> Unit)? = null,
    /** 壁纸上的顶栏墨色。 */
    chromeInk: HomeInkPolarity? = null,
    /** 材质快照：决定顶栏玻璃带画不画。 */
    material: HomeMaterialRenderSpec? = null,
    hasBackdrop: Boolean = false,
    pageColorArgb: Int? = null,
    /** 顶栏返回键的去处；显隐由页面里的根页判据决定。 */
    onBack: () -> Unit = {},
) {
    // ── 「此刻」：跨日会自动往前走（2026-11-05 补）──
    // 原来这里是 `now ?: remember { LocalDateTime.now() }`：只在首帧取一次值，月视图常驻时
    // 跨过零点后，「今天」高亮、「本月」药丸、考试是否过期、概览「从今天往后」的
    // 排序全都停在昨天（周视图有 `TimetableHost` 的分钟心跳、日视图有 `DayViewPage`
    // 的 1Hz 心跳，只有月视图漏了这一层）。
    // 节奏**不按秒**：睡到「下一个零点」再醒一次（2026-11-05 复核后改）。原来每秒醒一次，
    // 但月视图在底栏 pager 里作邻居页**常驻**（`beyondViewportPageCount = 1`），看不见时
    // 也在每秒空转；本页只关心「哪一天」，醒的时机选在零点最省。
    // 上限 [MIDNIGHT_POLL_CAP_MS]（15 分钟）是给 Doze 兜底：`delay` 走的是单调时钟
    //（uptime），设备深度睡眠时它不走字，若一觉直睡到零点，真到零点那一刻设备可能还在睡，
    // 醒来后「今天」会旧掉好几个小时；有上限就最多旧 15 分钟，代价是一天不到 100 次空醒。
    // 判据本身没变：**只在跨日时换值**（数据源 `remember` 以 `clock` 为 key，
    // 日内改写会让 42 格与当日议程重算）。
    var clock by remember(now) { mutableStateOf(now ?: LocalDateTime.now()) }
    LaunchedEffect(now) {
        // 调用方显式注入时刻（测试 / 预览）：由它自己负责刷新，心跳不接管。
        if (now != null) return@LaunchedEffect
        while (isActive) {
            // `minOf(...)` 里的上限**不是写漏**：见 [MIDNIGHT_POLL_CAP_MS] 的说明（Doze 兜底）。
            delay(minOf(millisUntilNextMidnight(LocalDateTime.now()), MIDNIGHT_POLL_CAP_MS))
            val fresh = LocalDateTime.now()
            if (fresh.toLocalDate() != clock.toLocalDate()) clock = fresh
        }
    }

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
        onBack = onBack,
        homeMenuStyle = homeMenuStyle,
        homeMenuItems = homeMenuItems,
        onHomeMenuSelect = onHomeMenuSelect,
        backdrop = backdrop,
        chromeInk = chromeInk,
        material = material,
        hasBackdrop = hasBackdrop,
        pageColorArgb = pageColorArgb,
    )
}

/**
 * 单次最长睡眠：给 Doze 兜底，**不是写漏**。
 *
 * `delay` 走的是单调时钟（uptime），而设备深度睡眠 / Doze 时它不走字。若一觉直睡到
 * 下一个零点（可能 8、9 小时），整夜休眠期间这个钟几乎不累加，真到零点那一刻协程还在睡，
 * 用户早上点亮屏幕后「今天」会旧着一两个小时才跳。加了这个上限，最坏滞后就是这个值；
 * 代价是一天不到 100 次空醒（每次只做一次取时间 + 一次日期比较，可忽略）。
 */
private const val MIDNIGHT_POLL_CAP_MS: Long = 15L * 60L * 1000L

/**
 * 距**下一个零点**还有多少毫秒（按墙钟算，不是单调时钟）。
 *
 * 恰好在零点时给出约 24 小时（`plusDays(1)` 后再取当天 00:00）；夏令时那种
 * 「当天没有 00:00」的地区由 `atStartOfDay()` 返回当天第一个有效时刻，仍然安全。
 */
private fun millisUntilNextMidnight(from: LocalDateTime): Long {
    val nextMidnight = from.toLocalDate().plusDays(1).atStartOfDay()
    return Duration.between(from, nextMidnight).toMillis().coerceAtLeast(1L)
}
