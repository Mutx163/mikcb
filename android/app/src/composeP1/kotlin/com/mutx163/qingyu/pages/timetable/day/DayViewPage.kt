package com.mutx163.qingyu.pages.timetable.day

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.calculateEndPadding
import androidx.compose.foundation.layout.calculateStartPadding
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.clickable
import com.mutx163.qingyu.app.HomeMenuStyle
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.app.HomeTitleStyle
import com.mutx163.qingyu.components.BackToTodayFab
import com.mutx163.qingyu.components.FAB_SHADOW_REACH_DP
import com.mutx163.qingyu.components.liquid.lens
import com.mutx163.qingyu.components.liquid.vibrancy
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.settings.SettingsMaterialModel
import com.mutx163.qingyu.pages.settings.SurfaceMaterialState
import com.mutx163.qingyu.pages.shell.HomeBackgroundModel
import com.mutx163.qingyu.pages.shell.HomeFloatingMetrics
import com.mutx163.qingyu.pages.shell.HomeInkPolarity
import com.mutx163.qingyu.pages.timetable.ApplyChromeStatusBarInk
import com.mutx163.qingyu.pages.timetable.CourseCardInk
import com.mutx163.qingyu.pages.timetable.TimetableDateLogic
import com.mutx163.qingyu.pages.timetable.TimetableMenuItem
import com.mutx163.qingyu.pages.timetable.TimetableTopBar
import com.mutx163.qingyu.pages.timetable.TimetableWeekdayHeader
import com.mutx163.qingyu.pages.timetable.WeekSelectorSheet
import com.mutx163.qingyu.pages.timetable.WeekViewStyle
import com.mutx163.qingyu.pages.timetable.DaySelectionBridge
import com.mutx163.qingyu.pages.timetable.LocalDaySelectionBridge
import com.mutx163.qingyu.pages.timetable.TimetableChromeBandGlass
import com.mutx163.qingyu.theme.QingyuTheme
import com.mutx163.qingyu.weather.WeatherProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.blur.blur
import top.yukonga.miuix.kmp.blur.drawBackdrop
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import top.yukonga.miuix.kmp.theme.MiuixTheme
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 首页「周↔日」展开层里，嵌入日视图应采样的**页面级预糊/壁纸 Backdrop**。
 *
 * 由 `TimetableWeekPage` 渲染 `dayContent` 时用其 `cardGlassSource` 提供：壁纸只由页面级
 * 静态底画，展开层里的日视图自己**不画壁纸**、卡片玻璃改吃这一层，避免壁纸随展开层移动。
 * 非展开层（独立日页 `c3.day` / 设置页预览）为 null，行为不变。
 */
val LocalEmbeddedDayGlassBackdrop = compositionLocalOf<Backdrop?> { null }

/**
 * 首页「周↔日」展开层里，嵌入日视图「回今日」浮钮补壁纸用的**页面级全屏壁纸 Backdrop**
 * （窗口坐标、sharp，不是预糊层）。由 `TimetableWeekPage` 用其 `pageBackdrop` 提供。
 *
 * 用途：嵌入日页自己不画壁纸（靠页面级静态底），浮钮在「无内容、纯壁纸」处要采到壁纸模糊
 * 而不是黑。直接在日页**本地**用 composable 补画壁纸会随日页面板（位于顶栏玻璃带下方）
 * 下移/横滑而错位；改成在录制层里按**窗口坐标**采样这一层，天然与页面级静态底逐像素对齐。
 * 非展开层（独立日页 / 预览）为 null——那些场景本页自己画壁纸，不需要。
 */
val LocalEmbeddedDayWallpaperBackdrop = compositionLocalOf<Backdrop?> { null }

/**
 * 首页「周↔日」展开层里，日视图「回今日」浮钮**是否已等展开过渡落定**。
 *
 * 由 `TimetableWeekPage` 在渲染 `dayContent` 时用 `dayExpand` 的落定态提供：展开/收起
 * （dayExpand 动画）期间为 false，到终值后翻转 true。日视图用它门控浮钮 `visible`——
 * 过渡期间钮不显示、不随转场位移；落定后再交给共用件 [BackToTodayFab] 自带的
 * fadeIn+scaleIn 淡入，与周视图「回本周」浮钮的出场动效同一份实现。
 *
 * 非展开层（独立日页 `c3.day` / 设置页预览）默认 true，行为与旧版一致。
 */
val LocalEmbeddedDayTransitionSettled = compositionLocalOf { true }

/**
 * 首页展开层里，日页需要向下穿进顶栏玻璃带的**带高**（0 = 不下穿）。
 *
 * 由 `TimetableWeekPage` 在渲染 `dayContent` 时提供：日页自己拿不到顶栏真实高度，
 * 而列表顶部要补一个等高留白，第 1 张卡才仍停在带子下沿；上滑时卡片才能滑进
 * 玻璃带底下被第二遍玻璃糊住（2026-11-08）。
 *
 * 非展开层（独立日页 `c3.day` / 设置页预览）默认 0，行为与旧版一致。
 */
val LocalEmbeddedDayUnderlapBand = compositionLocalOf { 0.dp }

/**
 * 首页展开层里，宿主**已经量好**的壁纸亮度带（顶栏 / 星期栏 / 正文）。
 *
 * 为什么必须有这一槽（2026-11-09 用户报「空态与卡片的黑白不跟着壁纸翻」）：
 * 嵌入首页的日页**自己不画壁纸**（壁纸由页面级静态底画，见 [LocalEmbeddedDayGlassBackdrop]），
 * 于是它自己的 `rememberHomeBackdropChrome` 里那个 `HomeWallpaperBackdrop` 永远不会组合、
 * `onInkBands` 永远不回调——本页拿到的 `wallpaperBands` 只能靠进程 / 磁盘缓存撞运气。
 * 冷启动首开、刚换完壁纸这两段就是 null：空态退回主题墨色（亮色主题的 #333 压深壁纸）、
 * 卡片退回「按不透明卡色判墨」（浅课色半透明压在深壁纸上变成深底深字）。
 * 宿主 `TimetableWeekPage` 手上有量好的那一份，经这个槽交进来即可。
 *
 * 独立日页 / 设置页预览为 null（那些场景本页自己画壁纸、自己量）。
 */
val LocalEmbeddedDayInkBands =
    compositionLocalOf<HomeBackgroundModel.InkBands?> { null }

/**
 * 单日页面全量数据载体。
 *
 * 聚合全天概览卡状态、当日议程列表、当日待办带数据以及课程关联作业的存在性映射。
 */
data class DayViewPageData(
    val summaryState: DayViewSummaryState,
    val agendaEntries: List<DayAgendaEntry> = emptyList(),
    val taskBandData: DayTaskBandData? = null,
    val courseTaskPresenceMap: Map<String, Boolean> = emptyMap(),
    /** 议程条目 id → 该节次的天气一行（无数据时为空；Dart `day_course_weather_row.dart`）。 */
    val weatherLines: Map<String, String> = emptyMap(),
    /**
     * 天气「该有、但还没拿到」：日卡先占住那一行的高度（不可见），数据到了再淡入。
     * 仅「天气开关开着 + 已选城市 + 预报未到且未失败」时为真（见 `WeatherProvider.isAwaitingData`）。
     */
    val weatherAwaiting: Boolean = false,
)

/**
 * 模型层 [DayViewDay] → 渲染层 [DayViewPageData] 的唯一转换点。
 *
 * 壳里不再自己拼 `DayViewPageData`（那正是 P1-1/P1-2/P1-3/P1-4/P1-5 的病根：
 * 壳拼错了模型，页面只能照单全收）。现在壳只要给出仓储数据，装配交给
 * `DayViewDataAssembler`，这里只做一次字段搬运。
 */
fun dayViewPageDataOf(day: DayViewDay): DayViewPageData = DayViewPageData(
    summaryState = day.summaryState,
    agendaEntries = day.agendaEntries,
    taskBandData = day.taskBandData,
    courseTaskPresenceMap = day.courseTaskPresence,
    weatherLines = day.weatherLines,
    weatherAwaiting = day.weatherAwaiting,
)

/**
 * 日视图顶层页面（Day View Page · Compose Phase 3）。
 *
 * 对应 Flutter `lib/screens/timetable_day_view_part.dart`：
 * - 基于 Compose 原生 [HorizontalPager] 实现无限平滑切日；
 * - 维护当前选中日期状态（周次 + 星期几），与全局连续页号严格互逆（[DayViewPaging]）；
 * - 内置 1 Hz 局部进度心跳驱动：仅计算进行中课程/日程的实时进度比与剩余分钟数，驱动卡片局部重组，避免无谓全页刷新；
 * - 统一向外暴露导航动作与条目点击回调：
 *   - [onCloseToWeekView]：关闭日视图，返回周视图
 *   - [onOpenCourse]：点击课程卡片打开详情或编辑
 *   - [onOpenCourseNotes]：记备注入口
 *   - [onOpenCourseTask]：记作业入口
 *   - [onOpenSchedule]：点击日程卡片打开日程详情
 *   - [onOpenExam]：点击考试卡片打开考试详情
 *   - [onOpenTask]：点击待办行进入待办编辑
 *   - [onToggleTask]：切换待办勾选状态
 *   - [onViewAllOverdue]：查看全部逾期任务
 *   - [onPageChanged]：翻页时同步报告最新的 (week, dayOfWeek)
 *
 * ## 能力型回调：`null` 不等于「空 lambda」（2026-10-29 二轮修复）
 *
 * 审核结论 P0-1：这些参数原先都写成 `= {}`，于是壳不传也能编译——页面照样把
 * 「作业」「备注」两个胶囊画出来，点下去**什么都不发生**（`DayViewCourseCard.kt`
 * 的胶囊是 `.clickable`）。那是「假成功」的另一种形态。
 *
 * 现在改成**可空**，语义是「本页尚未具备这项能力」：
 * - 传了回调 ⇒ 入口照常出现、照常可点；
 * - 不传（null）⇒ **入口不渲染**（不画点了没反应的按钮），而不是静默吞掉点击。
 *
 * 这也是本仓既有口径：`CourseActionSheetModel` 对「单节课提醒」一行就是
 * 「与其画一个点了没反应的入口，不如诚实地不画」。
 *
 * ## 从周视图点某天进来
 *
 * [initialDayOfWeek] 是**显式意图**：点「周五」就传 5。不传（null）才回落今天——
 * 这是唯一没有意图时的行为，不是默认值巧合。审核结论 P0-2 就是壳丢了这一参数。
 */
@Composable
fun DayViewPage(
    initialWeek: Int = 1,
    /**
     * 从星期栏点进来的那一天（1..7）。
     *
     * `null` = 没有具体意图（例如从底栏进日视图）⇒ 落在今天；
     * 不在 [visibleDays] 里时由 [DayViewPaging.normalizeDayOfWeek] 归一到第一个可见日
     * （与 Dart `normalizeDayOfWeekForVisibleDays` 同口径）。
     */
    initialDayOfWeek: Int? = null,
    visibleDays: List<Int> = listOf(1, 2, 3, 4, 5, 6, 7),
    totalWeeks: Int = 30,
    /**
     * 学期开始日（`null` = 没设，页面按「今天所在这一周」兜底算日期）。
     *
     * 顶部星期条的日期（`10/26`）、「今天」下划线、回今日浮钮都靠它；
     * 只给周次的话这几样只能瞎猜。
     */
    semesterStartDate: LocalDate? = null,
    /** 仓储认的「当前周」；空 = 按 [semesterStartDate] 现算或回落到 [initialWeek]。 */
    realCurrentWeek: Int? = null,
    /** 注入时钟（测试用）。 */
    todayDate: LocalDate = LocalDate.now(),
    /** 顶部星期条的考试红点判定（Dart `TimetableWeekdayHeader.hasExamOn`）。 */
    hasExamOnDate: (LocalDate) -> Boolean = { false },
    /** 顶部星期条的日程圆点判定（Dart `TimetableWeekdayHeader.hasScheduleOn`）。 */
    hasScheduleOnDate: (LocalDate) -> Boolean = { false },
    /** 星期条配色（星期栏字色 / 强调色两对 hex，Dart 与周视图同源）。 */
    weekdayStyle: WeekViewStyle = WeekViewStyle(),
    /** 「课卡显示冲突角标」开关（Dart `showConflictBadgeOnTimetable`；关掉只藏角标，保留冲突边框）。 */
    showConflictBadge: Boolean = true,
    /** 日视图课程卡是否按课程颜色上色（设置 `dayViewUseCourseColor`，默认开）。 */
    useCourseColors: Boolean = true,
    /**
     * 冲突课程卡面透明度（设置 `timetableConflictCourseOpacity`，默认 0.70，读侧已 clamp 0.2~1.0）。
     *
     * Dart 日视图与周视图共用 `courseDisplayOpacity` 一条判据（`day_course_display_logic.dart:54-63`）；
     * 周视图走 `WeekViewStyle.conflictCourseOpacity`，日视图由宿主直接喂同一个设置值。
     * 2026-11-07 之前这里没有这个参数：设置里拖「冲突课程透明度」，周视图跟着变、日视图不变。
     * 默认值直接取 [weekdayStyle] 里的同一字段（同一份设置只留一条通路）。
     */
    conflictCourseOpacity: Float = weekdayStyle.conflictCourseOpacity,
    /**
     * 是否显示顶部星期日期条。
     *
     * Dart 日视图是**叠在首页上**的面板，顶栏、星期条都还在（`timetable_day_view_part.dart:10-39`
     * 只替换面板本体）。Compse 迁移后它成了独立页面，星期条一度整块丢掉：
     * 看不到今天标记、看不到哪天有考试/日程，也不能点某天直接切过去。
     */
    showWeekdayHeader: Boolean = true,
    dataProvider: (week: Int, dayOfWeek: Int) -> DayViewPageData,
    /**
     * 装配结果的**失效信号**：变了才重新调 [dataProvider]。
     *
     * 2026-11-03：`dataProvider` 原先直接写在 Pager 页内容里、没有任何 remember，
     * 而同一作用域里的进度快照 `remember` 又读了每秒变化的 `currentMinuteOfDay`
     * ⇒ **每秒**重跑一次整页装配（全量课程过滤 + 冲突表 + 日程/考试/任务扫描）。
     * 这里把装配结果按「周次 + 星期 + 数据版本」缓存：心跳只重算进度，不再重装配。
     *
     * 调用方传**仓库快照**（`TimetableRepository.snapshot`）或等价的不可变数据版本；
     * 传 null = 不缓存（预览等静态场景）。
     */
    dataVersion: Any? = null,
    onCloseToWeekView: () -> Unit,
    onOpenCourse: ((courseId: String) -> Unit)? = null,
    /**
     * 卡片右上角「备注」胶囊。
     *
     * 参数带 [week]：Dart `showCourseNoteSheet(course:, week:)` 打开的是**那一周的
     * 单节备注**（`day_view_course_agenda_card.dart:159-166`），周次传丢会编辑成
     * 「本周」的备注，翻到别的周再点就写错行。
     */
    onOpenCourseNotes: ((courseId: String, week: Int) -> Unit)? = null,
    /**
     * 卡片右上角「记作业」胶囊。
     *
     * 参数带 [week]：Dart `taskForm(initialCourse:, initialWeek: week)` 把**当前查看的
     * 那一周**作为来源周带进作业表单（`day_view_course_agenda_card.dart:174-183`）；
     * 只给课程会让壳退回仓储当前周，跨周查看时来源周记错。
     */
    onOpenCourseTask: ((courseId: String, week: Int) -> Unit)? = null,
    /**
     * 日程卡点击。
     *
     * 参数带 [occurrenceDate]：Dart `scheduleItemForm(scheduleItem:, occurrenceDate:)`
     * 编辑的是**那一次发生**（`day_view_schedule_agenda_card.dart:94-97`）；
     * 丢了它，重复日程会从「改这一次」变成「改整条系列」。
     */
    onOpenSchedule: ((scheduleId: String, occurrenceDate: java.time.LocalDateTime?) -> Unit)? = null,
    onOpenExam: ((examId: String) -> Unit)? = null,
    onOpenTask: ((task: CourseTask) -> Unit)? = null,
    onToggleTask: ((task: CourseTask) -> Unit)? = null,
    onViewAllOverdue: (() -> Unit)? = null,
    courseResolver: (CourseTask) -> Course? = { null },
    onPageChanged: ((week: Int, dayOfWeek: Int) -> Unit)? = null,
    homeTitleStyle: HomeTitleStyle = HomeTitleStyle.CLASSIC,
    profileName: String? = null,
    showTopBar: Boolean = true,
    /**
     * 作为**首页的日视图展开层**渲染时，顶栏玻璃带的高度（含状态栏 + 标题行 + 星期栏）。
     *
     * 非空 = 本页**不画自己的顶栏 / 星期栏 / 玻璃带**（那一条带由首页统一画，周视图
     * 也在用）。2026-11-08 起宿主会把这个值传给 `LocalEmbeddedDayUnderlapBand`，
     * 日页自己把面板向上接到屏幕顶、列表首个 item 补等高留白；本参数只作「是否嵌入」
     * 的判据（嵌入时为 0.dp）。
     */
    contentTopInset: Dp? = null,
    /**
     * 首页星期栏当前选中的那一天。窗口常驻时外部换日靠它驱动 pager 滚动
     * （`initial*` 只在第一次组合生效，之后不再重开页面）。
     */
    requestedWeek: Int? = null,
    requestedDayOfWeek: Int? = null,
    homeMenuStyle: HomeMenuStyle = HomeMenuStyle.LIST,
    homeMenuItems: List<TimetableMenuItem> = emptyList(),
    onHomeMenuSelect: (String) -> Unit = {},
    /**
     * 页面**最底层**的背景槽（首页壁纸，`HomeWallpaperBackdrop`）。
     *
     * 与周视图同一条层次（Dart `TimetableHomeStack`：壁纸 → 状态栏遮罩 → 内容）：
     * 非空时页面底色改透明、把这层画在内容下面。为空时行为与旧版完全一致（不透明主题底）。
     */
    backdrop: (@Composable BoxScope.() -> Unit)? = null,
    /**
     * 壁纸上的顶栏墨色：`Light` = 浅墨（深色壁纸）、`Dark` = 深墨（浅色壁纸）、
     * `null` = 没有壁纸 ⇒ 主题墨色（旧行为）。
     *
     * 判据不在这里算：宿主用壁纸顶部亮度过
     * [com.mutx163.qingyu.pages.shell.HomeBackgroundModel] 的 `chromeInkPolarity`。
     */
    chromeInk: HomeInkPolarity? = null,
    /**
     * 壁纸三档亮度带（顶栏 / 星期栏 / 正文）。星期栏与空态的字色靠它翻深/翻浅
     * （Dart `homePageOverWallpaperInk` 同口径，见
     * [com.mutx163.qingyu.pages.shell.HomeBackgroundModel.inkOverWallpaperArgb]）。
     * `null` = 没壁纸 / 亮度未知 ⇒ 保持设置 / 主题原色。
     */
    wallpaperBands: HomeBackgroundModel.InkBands? = null,
    /**
     * 材质快照（`SettingsMaterialModel.renderSpecOf` 的唯一出口）。null = 老行为
     * （顶栏不画玻璃带、议程卡按各自的实体填充）。
     */
    material: HomeMaterialRenderSpec? = null,
    /**
     * **纯**「当前有没有壁纸」信号（`homeChrome.hasBackdrop`，**不要**与材质开关相与）。
     *
     * 与 [hasBackdrop] 的区别：后者还要过「玻璃材质是否启用」，这里只回答屏幕上有没有壁纸。
     * 卡片墨色的页底回退只认这个信号：有壁纸但亮度还没测出来时，页面底色是壁纸而不是
     * 主题页底，按页底判墨会闪一帧反极性文字（见 [dayAgendaPageFallbackLuminance]）。
     */
    hasWallpaper: Boolean,
    /**
     * 当前有没有可用壁纸。顶栏玻璃带与议程卡液态档都只有在壁纸之上才值得采样
     * （没有壁纸时 Dart 一律回落实体）。
     */
    hasBackdrop: Boolean = false,
    /**
     * 无壁纸 / 实体玻璃带用的页底色（ARGB，来自 `HomeBackdropSnapshot.pageColorArgb`）。
     * null = 主题兜底色（老行为）。
     */
    pageColorArgb: Int? = null,
    /**
     * 「回今日」浮钮的底边距（从屏幕底端起，已含系统内边距）。
     *
     * 由宿主按**玻璃坞药丸的真实占用**算好传进来（`HomeFloatingMetrics`）：页面自己拿不到
     * 坞的几何，以前写死的 `20dp` 直接落在药丸底下 —— 用户报的「按钮在导航栏底下」就是这一条。
     *
     * `null` = 宿主没接 ⇒ 退回旧口径（系统内边距 + 20dp）。
     */
    floatingButtonBottomInset: Dp? = null,
    /**
     * 可滚动内容的底部避让（从屏幕底端起，已含系统内边距）：玻璃坞形态 = 药丸占用，
     * 经典形态 = 系统手势条。`null` = 退回 `innerPadding.bottom + 64dp`。
     */
    contentBottomInset: Dp? = null,
    /**
     * 首页「周 → 日」摘要卡飞行（阶段 A）的**测量 + 隐藏**修饰器，挂在真摘要卡上。
     *
     * 只有首页展开层传入：里面挂着两件事——`onGloballyPositioned` 把卡片真实落点
     * 量回去（飞行终点必须实测），以及飞行期间不绘制真卡（否则会看到「一张卡被
     * 窗口一路裁过去」，还是擦除）。独立页面 / 预览 / 分享图不传，行为完全不变。
     */
    summaryModifier: Modifier = Modifier,
    modifier: Modifier = Modifier,
    /**
     * 天气 provider（可选）：传了就在**日页挂载后**补一次「过期就刷」。
     *
     * Dart 对位：`day_course_weather_row.dart:72-80` 每张天气行 `addPostFrameCallback`
     * 里调 `provider.ensureFresh()`。一屏多卡各调一次也只有第一次可能真发请求——
     * provider 内部有单飞 + 3h TTL + 15min 失败退避，所以这里**只在页面级调一次**，
     * 等价且更省。
     *
     * 不传（预览 / 分享图 / 未接天气的入口）就完全不做事，行为与旧版一致。
     */
    weatherProvider: WeatherProvider? = null,
) {
    // 挂载后（首帧之后）补一次刷新：放 `LaunchedEffect` 而不是组合期，避免在绘制路径上
    // 发网络；线程走 IO，因为 `ensureFresh` 会读缓存盘并可能同步等一次 HTTP。
    LaunchedEffect(weatherProvider) {
        if (weatherProvider != null) {
            withContext(Dispatchers.IO) { weatherProvider.ensureFresh() }
        }
    }
    val dark = isSystemInDarkTheme()
    val pageCount = (totalWeeks * visibleDays.size).coerceAtLeast(1)

    // 打开哪一天：显式意图优先（点「周五」就开周五），没有意图才回落今天。
    // 不在 visibleDays 里时归一到第一个可见日（Dart `normalizeDayOfWeekForVisibleDays`）。
    val initialPage = remember(initialWeek, initialDayOfWeek, visibleDays) {
        val seededDay = DayViewPaging.normalizeDayOfWeek(
            visibleDays = visibleDays,
            dayOfWeek = initialDayOfWeek ?: LocalDate.now().dayOfWeek.value,
        )
        DayViewPaging.globalPage(visibleDays, initialWeek, seededDay)
    }

    val pagerState = rememberPagerState(
        initialPage = initialPage.coerceIn(0, pageCount - 1),
        pageCount = { pageCount },
    )

    // 首页嵌入时，把分页器的**实时选中**写给外层星期栏（经 CompositionLocal 桥）：
    // 只驱动高亮跟手 + 蓝条滑动，不落盘（落盘仍走下面「停稳后 onPageChanged」）。
    // 独立日页（c3.day）/ 外观预览没有宿主桥：自己建一份，星期栏同样拿得到连续页号，
    // 跨周时整条照样跟手平移（2026-11-08）。
    val selectionBridge = LocalDaySelectionBridge.current
    val localSelectionBridge = remember { DaySelectionBridge() }
    val headerSelectionBridge = selectionBridge ?: localSelectionBridge

    val scope = rememberCoroutineScope()
    var showWeekSelector by remember { mutableStateOf(false) }

    // ── 星期栏横向刮擦换日（Dart `timetable_screen.dart:3996-4004`）──
    // 星期栏只负责把「滑过了几天」发出来（经 `DaySelectionBridge.onScrubShift`），
    // 这里翻成目标页滚过去：连续滑就连续翻，跨周由全局页号天然处理。
    // 累计目标页在停稳后归位，下一次刮擦从真实页接着算。
    val scrubTargetPage = remember { mutableIntStateOf(-1) }
    val scrubShift: (Int) -> Unit = remember(pagerState, pageCount, visibleDays) {
        { deltaDays ->
            val base = if (scrubTargetPage.intValue >= 0) {
                scrubTargetPage.intValue
            } else {
                pagerState.currentPage
            }
            val target = (base + deltaDays).coerceIn(0, pageCount - 1)
            if (target != base) {
                scrubTargetPage.intValue = target
                scope.launch { pagerState.animateScrollToPage(target) }
            }
        }
    }
    DisposableEffect(headerSelectionBridge, scrubShift) {
        headerSelectionBridge.onScrubShift = scrubShift
        onDispose { headerSelectionBridge.onScrubShift = null }
    }
    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.isScrollInProgress }
            .collect { scrolling -> if (!scrolling) scrubTargetPage.intValue = -1 }
    }

    // 跨零点：`todayDate` 只是注入种子（测试可给固定日期），运行期按真实日历平移。
    // 只读参数的话，首页常驻不复位时「今天」高亮 / 回今日入口会停在昨天
    //（Dart 每次构建都重读 `DateTime.now()`，`timetable_screen.dart:1404`/`:1429`/`:1438`）。
    val seedRealToday = remember { LocalDate.now() }
    var viewToday by remember { mutableStateOf(todayDate) }

    // ── 外部选日（首页星期栏）→ pager ──
    // 作为首页展开层时，星期栏一直由首页画：点另一天不会重建本页（`initial*` 不会重跑），
    // 所以必须在这里把「想看的那天」滚进 pager。日视图自己翻页后经 `onPageChanged`
    // 回写同一份状态，因此这里不会和手势打架（目标与当前页相同时直接跳过）。
    LaunchedEffect(requestedWeek, requestedDayOfWeek, visibleDays) {
        val week = requestedWeek ?: return@LaunchedEffect
        val dayOfWeek = requestedDayOfWeek ?: return@LaunchedEffect
        val target = DayViewPaging.globalPage(
            visibleDays = visibleDays,
            week = week,
            dayOfWeek = DayViewPaging.normalizeDayOfWeek(visibleDays, dayOfWeek),
        ).coerceIn(0, pageCount - 1)
        if (pagerState.currentPage != target) {
            pagerState.animateScrollToPage(target)
        }
    }

    // 「今天在哪一周」：优先按开学日现算（跨周自动跟手），算不出才用仓储当前周。
    val todayWeek = realCurrentWeek
        ?: TimetableDateLogic.currentSemesterWeek(
            semesterStart = semesterStartDate,
            totalWeeks = totalWeeks.coerceAtLeast(1),
            today = viewToday,
        )
        ?: initialWeek

    // 当前页（用于星期条高亮 / 周次选择器 / 回今日浮钮显隐）。
    val currentTarget = DayViewPaging.targetForGlobalPage(visibleDays, pagerState.currentPage)
    val currentTargetWeek = currentTarget?.week ?: initialWeek
    val currentTargetDayOfWeek = currentTarget?.dayOfWeek
        ?: DayViewPaging.normalizeDayOfWeek(visibleDays, viewToday.dayOfWeek.value)
    val isCurrentPageToday = currentTarget != null &&
        if (semesterStartDate != null) {
            TimetableDateLogic.dateForWeekDay(
                semesterStart = semesterStartDate,
                week = currentTarget.week,
                dayOfWeek = currentTarget.dayOfWeek,
            ) == viewToday
        } else {
            // 没设开学日：与装配器同口径——同一周内、星期相同才算今天。
            currentTarget.dayOfWeek == viewToday.dayOfWeek.value && currentTarget.week == todayWeek
        }

    // ── 1 Hz 局部进度心跳驱动 ──
    // 维护当前时间的日内分钟数（精确到浮点小数，如 09:30:15 -> 570.25）
    // 仅驱动进行中卡片的重组，静止卡片与其它页面不受影响
    var currentMinuteOfDay by remember {
        val now = LocalDateTime.now()
        mutableDoubleStateOf(now.hour * 60.0 + now.minute + now.second / 60.0)
    }

    LaunchedEffect(Unit) {
        while (isActive) {
            delay(1000L)
            val now = LocalDateTime.now()
            currentMinuteOfDay = now.hour * 60.0 + now.minute + now.second / 60.0
            viewToday = TimetableDateLogic.rollTodayDate(todayDate, seedRealToday, now.toLocalDate())
        }
    }

    // ── 翻页监听与外部状态同步 ──
    // 只在**停稳**后上报一次：`snapshotFlow { currentPage }` 在快速甩动跨页时每越一页
    // 都会发射，直接同步会给仓储每页写一次盘（Dart 也是 ScrollEnd 后才 commit，见
    // `day_view_transition_controller.dart:646-702`）。
    LaunchedEffect(pagerState, visibleDays) {
        snapshotFlow { pagerState.currentPage to pagerState.isScrollInProgress }
            .collect { (page, scrolling) ->
                if (scrolling) return@collect
                val target = DayViewPaging.targetForGlobalPage(visibleDays, page)
                if (target != null) {
                    onPageChanged?.invoke(target.week, target.dayOfWeek)
                }
            }
    }

    // 实时选中桥：每翻到新的一页（含甩动途中越过页中点）就更新一次，星期栏据此**即时跟手**，
    // 不等停稳。只写内存状态，不落盘 —— 快速连续切日不会每页重写整份设置 JSON。
    LaunchedEffect(pagerState, visibleDays, headerSelectionBridge) {
        snapshotFlow { pagerState.currentPage }
            .distinctUntilChanged()
            .collect { page ->
                val target = DayViewPaging.targetForGlobalPage(visibleDays, page) ?: return@collect
                headerSelectionBridge.update(target.week, target.dayOfWeek)
            }
    }

    // 连续页号（`currentPage + currentPageOffsetFraction`）→ 星期栏。
    // 星期栏用它做两件事：同一周内选中条跟着手指走、跨周时整条跟着分页器平移
    // （Dart `timetable_weekday_header.dart:400-463`）。只写内存状态，逐帧更新不下盘。
    LaunchedEffect(pagerState, headerSelectionBridge) {
        snapshotFlow { pagerState.currentPage + pagerState.currentPageOffsetFraction }
            .distinctUntilChanged()
            .collect { headerSelectionBridge.updatePagePosition(it) }
    }

    // ── 首页壁纸 + 顶栏玻璃带 + 课卡液态档（2026-11-01）──
    // 与周视图（`TimetableWeekPage`）同一套三层接线，缺了任一层就会出现
    // 「周视图有壁纸、日视图是纯色底」这种同页不一致：
    //   ① 把壁纸层录进 `pageBackdrop`（记录 ≠ 上屏，壁纸照常画）；
    //   ② 顶栏玻璃带（状态栏 + 标题行 + 星期栏 = 一条带）在带子上采样 + 高斯 + 染色；
    //   ③ 议程卡从**整页共享的预糊层**取自己那块像素，一屏十来张卡只糊一趟。
    // 只有「液态档 + 真有壁纸 + 设备支持 RuntimeShader」三件事同时成立才真采样。
    val density = LocalDensity.current
    val scaffoldBg = Color(QingyuTheme.scaffoldBackground(dark))
    // 卡面墨色的「无壁纸」回退：半透明卡实际压在页底上（自定义页底色优先，缺省用主题页底）。
    // 有壁纸但亮度还没测出来时**必须置空**：屏幕上是壁纸，按页底判墨会闪一帧反极性文字
    // （等 `wallpaperBands` 量出来再用真壁纸亮度；见 [dayAgendaPageFallbackLuminance]）。
    val pageBackgroundLuminance = dayAgendaPageFallbackLuminance(
        hasWallpaper = hasWallpaper,
        pageLuminance = CourseCardInk.relativeLuminance(
            pageColorArgb ?: QingyuTheme.scaffoldBackground(dark),
        ),
    )
    val pageBackdrop = rememberLayerBackdrop()
    val cardGlassBackdrop = rememberLayerBackdrop()
    // ── 「回今日」浮钮的**真实内容**录制层（B1，2026-11-04）──
    // 浮钮原采 pageBackdrop / embeddedGlass（只录壁纸 / 预糊壁纸），压着日卡也只看得到壁纸。
    // 这一层录 [壁纸(非嵌入时) + 预糊层 + 内容 Column]（不含浮钮自己），浮钮摘成录制层外的
    // 兄弟再采它。嵌入日程时本页不画壁纸，录到的是日卡本身，浮钮即透出它压着的卡片内容。
    val contentBackdrop = rememberLayerBackdrop()
    // 玻璃带是否「液态档 + 真有壁纸 + 设备支持」：判据与渲染层同一份
    //（`TimetableChromeBandGlass` 里那段 `when`）。这里留一份只为给下面的
    // `pageBackdropActive`（要不要挂录像层）用，不参与画玻璃。
    val bandBlurActive = material?.band == SurfaceMaterialState.LIQUID_GLASS &&
        hasBackdrop && isRuntimeShaderSupported()
    // 星期条背后是不是壁纸：没画带子（老行为 / OFF）或液态玻璃 ⇒ 是；实体档 ⇒ 否。
    val bandOverWallpaper = material == null ||
        material.band == SurfaceMaterialState.OFF ||
        bandBlurActive
    val bandSolidColor = pageColorArgb?.let { Color(it) } ?: scaffoldBg
    // 形状边界要往屏幕外推多少（逻辑 dp，只算作用带那一份）：取值理由见
    // `SettingsMaterialModel.bandGlassOverdrawDp`。左右还要再叠上安全区，
    // 那一步要 `innerPadding`，所以在 Scaffold 内容里算（见下方 bandOverdrawPx）。
    val bandOverdrawBaseDp = SettingsMaterialModel.bandGlassOverdrawDp(
        material?.liquidRefractionBand ?: 0f,
    )


    // 状态栏图标 / 文字的明暗：沿用标题行同一条判据 [chromeInk]（宿主用壁纸顶部亮度算的）。
    //   Light = 深色壁纸 ⇒ 浅墨 ⇒ 状态栏图标要浅色（isAppearanceLightStatusBars = false）
    //   Dark  = 浅色壁纸 ⇒ 深墨 ⇒ 状态栏图标要深色（true）
    // 没有壁纸 / 亮度还没量出来 ⇒ 跟系统明暗，与壳的兜底一致。
    val lightStatusBarIcons = when (chromeInk) {
        HomeInkPolarity.Light -> false
        HomeInkPolarity.Dark -> true
        null -> !dark
    }
    ApplyChromeStatusBarInk(lightIcons = lightStatusBarIcons)

    // 议程卡液态档：门控与顶栏带同构，三件事缺一件就退回各卡原有的实体填充。
    val cardGlassActive = material?.courseCard == SurfaceMaterialState.LIQUID_GLASS &&
        hasBackdrop && isRuntimeShaderSupported()
    val cardBlurSigmaPx = with(density) {
        (material?.courseCardBlurSigma ?: 0f).dp.toPx()
    }
    // σ = 0 是**有效的清档**（Dart 清澈档）：背景原样透出、不跑高斯，连预糊也省掉。
    val cardPreblurActive = cardGlassActive && cardBlurSigmaPx > 0f
    // 浮钮只在「当前看的不是今天」时出现；不可见就不为它录整屏。
    // 今天还必须是可见星期、且落在学期内（Dart `_canNavigateDayViewToToday`，
    // `timetable_screen.dart:1428-1435`：假期/学期末、或今天那个星期被隐藏时不给入口，
    // 免得点一下跳到「上周同一个星期几」；判据收敛在 [TimetableDateLogic.canNavigateToToday]）。
    val showsBackToToday = TimetableDateLogic.canNavigateToToday(
        isCurrentPageToday = isCurrentPageToday,
        visibleDays = visibleDays,
        semesterStart = semesterStartDate,
        totalWeeks = totalWeeks.coerceAtLeast(1),
        today = viewToday,
    )
    // 浮钮与玻璃坞同一档：真有壁纸 + 设备支持 runtime shader + 坞本身是玻璃材质。
    // 只是「要不要录整屏」的判据；真正的档位判断在共用件里再做一次。
    val floatingGlassActive = showsBackToToday &&
        hasBackdrop && isRuntimeShaderSupported() &&
        (material?.dock == SurfaceMaterialState.LIQUID_GLASS ||
            material?.dock == SurfaceMaterialState.FROST)
    // 录像带只在真有人采时才挂：顶栏带要采、议程卡液态档要采、浮钮玻璃也要采。
    // 漏掉最后一项时浮钮采到的是空层——画出来是一块透明/发黑的胶囊。
    // ── 首页展开层（被塞进 TimetableWeekPage 的展开窗口）──
    // 此时壁纸由页面级静态底画；本页不画自己的壁纸、不录本地采样层，卡片玻璃改吃宿主
    // 经 CompositionLocal 提供的页面级预糊层（`TimetableWeekPage.cardGlassSource`）。
    // 判据：c3.day 展开层由宿主传 0.dp（contentTopInset 非空）；独立日页 / 设置页预览为 null。
    val embeddedInHomePanel = contentTopInset != null
    val embeddedGlass = LocalEmbeddedDayGlassBackdrop.current
    // 壁纸亮度带：嵌入首页时优先用宿主量好的那一份（本页不画壁纸 ⇒ 自己的量测永远不会跑，
    // 见 [LocalEmbeddedDayInkBands]）；宿主还没量出来才退回自己缓存的 / 调用方传入的。
    val effectiveWallpaperBands =
        if (embeddedInHomePanel) LocalEmbeddedDayInkBands.current ?: wallpaperBands else wallpaperBands
    // 首页展开层里日页下穿顶栏的带高（0 = 不下穿）。宿主在 `TimetableWeekPage` 里
    // 用同一个 band 高度把日页面板向上接了一截；这里只负责给列表顶部补等高留白，
    // 第 1 张卡仍停在带子下沿（2026-11-08）。
    val embeddedUnderlapBand = LocalEmbeddedDayUnderlapBand.current
    // 「回今日」浮钮补壁纸用的窗口坐标全屏壁纸层（sharp），仅嵌入日程由宿主提供。
    val embeddedWallpaper = LocalEmbeddedDayWallpaperBackdrop.current
    // 展开过渡是否已落定（见 [LocalEmbeddedDayTransitionSettled]）：独立页/预览恒 true。
    val embeddedTransitionSettled = LocalEmbeddedDayTransitionSettled.current
    // 真实内容录制层是否生效：浮钮玻璃档 + （独立页恒真 / 嵌入页需展开过渡落定）。
    // 嵌入页过渡期浮钮本来就不画（visible 需 settled），此时不录、也不往面板里补壁纸，
    // 免得壁纸跟着横滑/渐显一起动；落定后补的壁纸像素与页面级静态壁纸一致，视觉不变。
    val contentRecordActive = floatingGlassActive &&
        (!embeddedInHomePanel || embeddedTransitionSettled)

    // pageBackdrop 只给顶栏带 / 议程卡玻璃采样（只录壁纸）；「回今日」浮钮改用独立
    // contentBackdrop（录真实内容），故这里不含 floatingGlassActive（否则双重整屏录制）。
    val pageBackdropActive = bandBlurActive || cardGlassActive
    val cardGlassSource: Backdrop? = when {
        !cardGlassActive -> null
        // 首页展开层：吃宿主页面级预糊层（壁纸在页面级静态底画，本页不画）。
        embeddedInHomePanel -> embeddedGlass
        cardPreblurActive -> cardGlassBackdrop
        else -> pageBackdrop
    }

    Scaffold(
        // 有壁纸时底色必须透明，否则不透明主题底会把壁纸整张盖掉。
        // 展开层里本页不画壁纸 ⇒ 容器必须透明，让页面级静态壁纸透出（否则整块盖掉）。
        containerColor = if (backdrop == null && !embeddedInHomePanel) scaffoldBg else Color.Transparent,
        modifier = modifier.fillMaxSize(),
    ) { innerPadding ->
        // 底部避让：坞避让取「共享 relief / Scaffold 内边距 / 宿主给的 contentBottomInset」三者较大值
        //（去重，系统栏不双计；不用 innerPadding+64 魔法值）；「今」浮钮可见（非今天）时再叠一段
        // 让最后一张卡能滚到钮上方——今天无钮 ⇒ 这段=0，不为看不见的按钮留空白。
        val listBottomInset = maxOf(
            innerPadding.calculateBottomPadding(),
            com.mutx163.qingyu.components.LocalGlassDockScrollRelief.current,
            contentBottomInset ?: 0.dp,
        ) + if (showsBackToToday) HomeFloatingMetrics.BACK_TO_TODAY_SCROLL_EXTRA_DP.dp else 0.dp
        Box(modifier = Modifier.fillMaxSize()) {
        // ── 真实内容录制层（B1）：录 [壁纸 + 预糊层 + 内容 Column]，浮钮在本层之外 ──
        // 只有「回今日」浮钮真要采玻璃时才挂录像（录制 = 整屏离屏重画一帧，门控同 dock）。
        Box(
            modifier = Modifier
                .fillMaxSize()
                .then(
                    if (contentRecordActive) {
                        Modifier.layerBackdrop(contentBackdrop)
                    } else {
                        Modifier
                    },
                ),
        ) {
        // 嵌入日程时本页不画壁纸（壁纸由页面级静态底画）。为了让浮钮「无内容、纯壁纸」时
        // 也采到壁纸模糊而不是黑，落定后把**页面级壁纸层按窗口坐标采样**画进录制层——
        // pageBackdrop 是窗口坐标的壁纸录像层，采样天然与页面级静态底逐像素对齐，不受日页
        // 面板下移 / 横滑影响（不能用 composable 本地补画，那会随面板偏移往下偏）。
        if (embeddedInHomePanel && contentRecordActive && embeddedWallpaper != null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .drawBackdrop(
                        backdrop = embeddedWallpaper,
                        shape = { RectangleShape },
                        effects = {},
                    ),
            )
        }
        // 壁纸层在最底（Dart 的层次：壁纸 → 内容）。没有壁纸时这一行什么也不画。
        // 顶栏玻璃带与议程卡都要采样它，所以包一层（只有真要玻璃时才挂 `layerBackdrop`）。
        if (backdrop != null && !embeddedInHomePanel) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .then(
                        if (pageBackdropActive) {
                            Modifier.layerBackdrop(pageBackdrop)
                        } else {
                            Modifier
                        },
                    ),
            ) {
                backdrop.invoke(this)
            }
        }
        // ── 议程卡的共享预糊层：整屏只糊**这一趟** ──
        // `alpha(0f)` = 这一层不上屏，唯一作用是把自己录进 `cardGlassBackdrop`。
        // 所有卡随后都只从这张图里取自己那块：一屏十来张卡共用一次高斯。
        if (cardPreblurActive && !embeddedInHomePanel) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .alpha(0f)
                    .layerBackdrop(cardGlassBackdrop)
                    .drawBackdrop(
                        backdrop = pageBackdrop,
                        shape = { RectangleShape },
                        effects = {
                            blur(cardBlurSigmaPx)
                            vibrancy()
                        },
                    ),
            )
        }
        Column(
            modifier = Modifier
                .fillMaxSize()
                // 左右吃安全区；顶部**刻意不吃**——玻璃带要从 y = 0（状态栏背后）开始，
                // 由带子内部用等高的 Spacer 把标题行顶到状态栏下面。
                // 底部也刻意不吃——滚动视口要铺到屏幕最底，卡片从手势条底下穿过去。
                //
                // 展开层（`embeddedInHomePanel`）**不能再吃一次**：宿主
                // `TimetableWeekPage` 的正文容器已经按同一份窗口内边距缩过（同一个
                // `innerPadding`），这里再缩一次，横屏（左右内边距不对称：提升到
                // 内边距的那侧才是挖孔/侧边导航所在侧）会把正文整体往右推、右边变窄，
                // 用户看到的就是「右边内容不在容器里居中」。
                .padding(
                    start = if (embeddedInHomePanel) {
                        0.dp
                    } else {
                        innerPadding.calculateStartPadding(LocalLayoutDirection.current)
                    },
                    end = if (embeddedInHomePanel) {
                        0.dp
                    } else {
                        innerPadding.calculateEndPadding(LocalLayoutDirection.current)
                    },
                ),
        ) {
            // 玻璃节点是带子盒子的孩子，而带子盒子被左右安全区内缩过（上面 Column 的
            // padding）。横屏挖孔时只推「作用带 + 1」还压不住屏幕边 —— 形状的左 / 右边界
            // 会落进可见区，读成一条竖折射边。把安全区一起加进外溢量，形状边界才真的出屏
            //（Dart 那条带是 `Positioned(left: 0, right: 0)` 的全宽层，天然没这问题）。
            val bandOverdrawPx = with(density) {
                (bandOverdrawBaseDp.dp + maxOf(
                    innerPadding.calculateStartPadding(LocalLayoutDirection.current),
                    innerPadding.calculateEndPadding(LocalLayoutDirection.current),
                )).toPx()
            }
            // ── 顶栏玻璃带：状态栏 + 标题行 + 星期栏 = 同一条带 ──
            // 三块内容装在同一个盒子里，玻璃只在**一个**节点上挂一次（一次采样、
            // 一次高斯、一次折射、一次染色）。玻璃层本身是共享件
            //（`TimetableChromeBandGlass`），与周/月视图同一条带。
            //
            // 作为首页展开层（`contentTopInset != null`）时不画这条带：首页那条带
            // 已经在同一位置、同一材质上画好了，这里再画一遍会在界面交界处叠出
            // 第二份模糊/染色；正文按同一条带的高度下移即可。
            if (contentTopInset != null) {
                // 展开层：面板已由宿主向上接到屏幕顶（下穿一截带高），正文从面板顶开始；
                // 列表首个 item 补带高留白（`DayViewScrollContent.topUnderlap`），
                // 所以第 1 张卡仍停在带子下沿。这里不再加任何高度。
                Spacer(modifier = Modifier.height(contentTopInset))
            } else {
            TimetableChromeBandGlass(
                material = material,
                hasBackdrop = hasBackdrop,
                backdrop = pageBackdrop,
                solidColor = bandSolidColor,
                overdrawDp = (bandOverdrawBaseDp.dp + maxOf(
                    innerPadding.calculateStartPadding(LocalLayoutDirection.current),
                    innerPadding.calculateEndPadding(LocalLayoutDirection.current),
                )),
            ) {

                Column(modifier = Modifier.fillMaxWidth()) {
                    // 状态栏区域留白：带子画到屏幕最顶，内容仍停在状态栏下面。
                    Spacer(modifier = Modifier.height(innerPadding.calculateTopPadding()))

                    // 顶栏「轻屿课表」+ 右上角「更多」菜单（Flutter 日视图叠在首页上，顶部仍是它）。
                    if (showTopBar) {
                        TimetableTopBar(
                            brand = homeTitleStyle == HomeTitleStyle.BRAND,
                            inkPolarity = chromeInk,
                            profileName = profileName,
                            homeMenuStyle = homeMenuStyle,
                            menuItems = homeMenuItems,
                            onMenuSelect = onHomeMenuSelect,
                        )
                    }
                    // 顶部星期日期条（Dart 日视图叠在首页上，这一条一直可见）：
                    // 周次 + 周一..周日 + 日期 + 今天标记 + 考试/日程圆点 + 点某天换日。
                    if (showWeekdayHeader && currentTarget != null) {
                        TimetableWeekdayHeader(
                            week = currentTarget.week,
                            currentWeek = todayWeek,
                            todayDate = viewToday,
                            semesterStartDate = semesterStartDate,
                            visibleDays = visibleDays,
                            style = weekdayStyle,
                            // 星期条压在**壁纸**上才谈壁纸墨色：实体档的带子是不透明的
                            // 页底色条，底下没有壁纸（Dart `homePageWeekdayBarOverWallpaper`）。
                            wallpaperLuminance = effectiveWallpaperBands?.weekday?.takeIf {
                                bandOverWallpaper
                            },
                            selectedDayOfWeek = currentTarget.dayOfWeek,
                            // 连续页号桥：同一周内选中条跟手，跨周时整条跟手平移。
                            selectionBridge = headerSelectionBridge,
                            totalWeeks = totalWeeks,
                            hasExamOnDate = hasExamOnDate,
                            hasScheduleOnDate = hasScheduleOnDate,
                            onDayClick = { dayOfWeek ->
                                scope.launch {
                                    pagerState.animateScrollToPage(
                                        DayViewPaging.globalPage(
                                            visibleDays = visibleDays,
                                            week = currentTarget.week,
                                            dayOfWeek = dayOfWeek,
                                        ).coerceIn(0, pageCount - 1),
                                    )
                                }
                            },
                            onWeekTitleClick = { showWeekSelector = true },
                        )
                    }
                }
            }
            }
            // ── 顶部留缝已移入列表（2026-11-07）──
            // 独立路由与展开层同一条 14dp：现在由 `DayViewScrollContent` 的首个 item
            //（`day-top-seam`）提供。静止时首卡离星期栏 14dp；上滑时这道缝跟着滚走、
            // 吸顶后紧贴星期栏底边（用户口径：「吸顶卡不要贴住，但上滑也不要留空隙」）。
            // 这里不再加任何 Spacer：加在滚动区外面就是一条永远滚不走的空带。
            // 下方内容：从玻璃带底部开始，占满剩余高度（底部仍铺到屏幕最底）。
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
            ) {
                HorizontalPager(
                    state = pagerState,
                    modifier = Modifier.fillMaxSize(),
                ) { page ->
                    val target = DayViewPaging.targetForGlobalPage(visibleDays, page)
                    if (target != null) {
                        // 装配结果按「周次 + 星期 + 数据版本」缓存：1Hz 心跳只重算下面的
                        // progressMap，不再每秒重跑 DayViewDataAssembler。
                        val pageData = remember(target.week, target.dayOfWeek, dataVersion) {
                            dataProvider(target.week, target.dayOfWeek)
                        }

                        // 仅在当前查看的日子是今天时，计算进行中的进度快照
                        val progressMap = remember(
                            pageData.agendaEntries,
                            currentMinuteOfDay,
                            target.week,
                            target.dayOfWeek,
                        ) {
                            if (!pageData.summaryState.isToday) {
                                emptyMap()
                            } else {
                                val map = mutableMapOf<String, DayAgendaProgress>()
                                for (entry in pageData.agendaEntries) {
                                    val progress = DayAgendaLogic.resolveProgress(
                                        startTime = entry.startTime,
                                        endTime = entry.endTime,
                                        currentMinutes = currentMinuteOfDay,
                                    )
                                    if (progress != null) {
                                        map[entry.id] = progress
                                    }
                                }
                                map
                            }
                        }

                        DayViewScrollContent(
                            summaryState = pageData.summaryState,
                            summaryModifier = summaryModifier,
                            // 首页展开层：列表顶部先补一条带高留白，卡才能滑进顶栏玻璃带。
                            topUnderlap = if (embeddedInHomePanel) embeddedUnderlapBand else 0.dp,
                            agendaEntries = pageData.agendaEntries,
                            dayOfWeek = target.dayOfWeek,
                            taskBandData = pageData.taskBandData,
                            progressMap = progressMap,
                            courseTaskPresenceMap = pageData.courseTaskPresenceMap,
                            onCloseToWeekView = onCloseToWeekView,
                            onOpenCourse = onOpenCourse,
                            onOpenCourseNotes = onOpenCourseNotes,
                            onOpenCourseTask = onOpenCourseTask,
                            onOpenSchedule = onOpenSchedule,
                            onOpenExam = onOpenExam,
                            onOpenTask = onOpenTask,
                            onToggleTask = onToggleTask,
                            onViewAllOverdue = onViewAllOverdue,
                            courseResolver = courseResolver,
                            showConflictBadge = showConflictBadge,
                            // 冲突透明度：与周视图同一个设置键（Dart `courseDisplayOpacity` 共用判据）。
                            conflictCourseOpacity = conflictCourseOpacity,
                            // 日视图课程卡是否按课程颜色上色（关闭后改用主题卡片底色）。
                            useCourseColors = useCourseColors,
                            // 空态文字直接压在壁纸上：正文那档亮度决定字色。
                            // Dart `day_view_empty_state.dart:50-51` 是 `body ?? top`：
                            // 正文带没量到（极端取景 / 老缓存）时也不是直接回主题墨色。
                            wallpaperLuminance = effectiveWallpaperBands?.body
                                ?: effectiveWallpaperBands?.weekday
                                ?: effectiveWallpaperBands?.top,
                            // 无壁纸 / 亮度未知时的页底亮度（半透明卡按页底合成判墨）。
                            pageBackgroundLuminance = pageBackgroundLuminance,
                            // 摘要卡墨色：按壁纸**星期栏那档**亮度（发布版 `_weekdayInkLuminance` 口径）翻黑/白。
                            summaryWallpaperLuminance = effectiveWallpaperBands?.weekday,
                            // 摘要卡与星期栏**同一套自定义字色**（未配置/等于默认值时按亮度翻黑白）。
                            summaryWeekdayFontColorHex = if (dark) weekdayStyle.weekdayFontColorDark else weekdayStyle.weekdayFontColorLight,
                            summaryWeekdayFontDefaultHex = if (dark) WeekViewStyle().weekdayFontColorDark else WeekViewStyle().weekdayFontColorLight,
                            // 天气行：装配器按课程 id 算好的「一行文本」，不传就永远不显示
                            //（2026-10-29 二轮审核 P1-12 的病根就在这一行缺失）。
                            weatherLines = pageData.weatherLines,
                            // 预报还没到：先占住天气那一行的高度，到货后淡入（不跳版）。
                            weatherAwaiting = pageData.weatherAwaiting,
                            // 材质与整页共享采样层（见本函数上方那三段接线）。
                            material = material,
                            glassBackdrop = cardGlassSource,
                            // 视口铺到屏幕最底，底部避让由页面统一定好（含坞与浮钮）。
                            bottomInset = listBottomInset,
                        )
                    }
                }


            }
        }
        }  // 关闭真实内容录制层（B1）

        // ── 「回今日」浮钮（搬出录制层，采它背后的真实内容）──
        // 与周视图「回本周」同一颗 [BackToTodayFab]；backdrop 改为真实内容录制层
        // contentBackdrop（不再只采壁纸 / 预糊壁纸）。嵌入日程时本页不画壁纸，录到的是
        // 日卡本身，浮钮即透出它压着的真实卡片内容。
        BackToTodayFab(
            onClick = {
                scope.launch {
                    pagerState.animateScrollToPage(
                        DayViewPaging.globalPage(
                            visibleDays = visibleDays,
                            week = todayWeek,
                            dayOfWeek = todayDate.dayOfWeek.value,
                        ).coerceIn(0, pageCount - 1),
                    )
                }
            },
            // 屏上就是用户设计的单个「今」字（ARB `timetableBackToTodayShort`）：
            // 2026-11-10 用户报坏「回今日」全文字——这颗钮是他特意设计的短字形态，
            // 有意偏离发布版（发布版日钮是「回今日」14sp）。读屏语义仍走完整动作。
            label = DayViewStrings.backToTodayShort.text,
            contentDescription = DayViewStrings.backToTodayAction.text,
            visible = showsBackToToday &&
                (!embeddedInHomePanel || embeddedTransitionSettled),
            backdrop = when {
                contentRecordActive -> contentBackdrop
                embeddedInHomePanel -> embeddedGlass
                else -> pageBackdrop
            },
            material = material,
            hasBackdrop = hasBackdrop,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                // 底边距由宿主按玻璃坞药丸的真实占用算好（见 `HomeFloatingMetrics`）。
                .padding(
                    bottom = (floatingButtonBottomInset
                        ?: (innerPadding.calculateBottomPadding() + 20.dp)) -
                        FAB_SHADOW_REACH_DP.dp,
                ),
        )
        }
    }

    // 周次选择器：Dart 星期条左端的「第 N 周」可点开（`timetable_weekday_header.dart:176-196`）。
    WeekSelectorSheet(
        show = showWeekSelector,
        availableWeeks = (1..totalWeeks.coerceAtLeast(1)).toList(),
        visibleWeek = currentTargetWeek,
        currentSemesterWeek = todayWeek,
        onDismiss = { showWeekSelector = false },
        onSelect = { week ->
            showWeekSelector = false
            scope.launch {
                pagerState.animateScrollToPage(
                    DayViewPaging.globalPage(
                        visibleDays = visibleDays,
                        week = week,
                        dayOfWeek = currentTargetDayOfWeek,
                    ).coerceIn(0, pageCount - 1),
                )
            }
        },
    )
}

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（@Preview）
//
// 日视图这里只铺「能静态拍下来」的档位：渲染层入参都有默认值，传一个确定的
// 周次 / 日期就能拍出稳定的一帧，不依赖仓储与时钟。
// 交互（左右翻日、1Hz 进度心跳）在静态预览里看不到，要验靠 Studio 交互模式或真机。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用的一天：周三三门课，时段与配色按真实导入形态给。 */
private val previewDayCourses: List<com.mutx163.qingyu.core.Course> = listOf(
    com.mutx163.qingyu.core.Course(
        id = "preview-1",
        name = "高等数学（下）",
        teacher = "王老师",
        location = "三教 204",
        dayOfWeek = 3,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
        color = "#3B82F6",
    ),
    com.mutx163.qingyu.core.Course(
        id = "preview-2",
        name = "大学物理",
        teacher = "李老师",
        location = "理科楼 302",
        dayOfWeek = 3,
        startSection = 3,
        endSection = 4,
        startTime = "10:00",
        endTime = "11:40",
        color = "#10B981",
    ),
    com.mutx163.qingyu.core.Course(
        id = "preview-3",
        name = "线性代数",
        teacher = "张老师",
        location = "二教 105",
        dayOfWeek = 3,
        startSection = 7,
        endSection = 8,
        startTime = "14:00",
        endTime = "15:40",
        color = "#F59E0B",
    ),
)

/** 固定到「第 10 周 · 周三」，避开预览每次跑都跟着今天变。 */
@Composable
private fun PreviewDayViewPage(dark: Boolean = false, textScale: Float = 1f) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        DayViewPage(
            initialWeek = 10,
            initialDayOfWeek = 3,
            realCurrentWeek = 10,
            todayDate = java.time.LocalDate.of(2026, 11, 8),
            hasWallpaper = false,
            onCloseToWeekView = {},
            dataProvider = { week, dayOfWeek ->
                dayViewPageDataOf(
                    DayViewDataAssembler.build(
                        week = week,
                        dayOfWeek = dayOfWeek,
                        courses = previewDayCourses,
                        settings = com.mutx163.qingyu.core.TimetableSettings.defaults(),
                        currentWeek = 10,
                        now = java.time.LocalDateTime.of(2026, 11, 8, 10, 0),
                    ),
                )
            },
        )
    }
}

@Suppress("unused")
@Preview(name = "1 亮色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun DayViewPagePreviewLight() {
    PreviewDayViewPage()
}

@Suppress("unused")
@Preview(name = "2 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun DayViewPagePreviewDark() {
    PreviewDayViewPage(dark = true)
}

@Suppress("unused")
@Preview(name = "3 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun DayViewPagePreviewLargeText() {
    PreviewDayViewPage(textScale = 1.3f)
}




