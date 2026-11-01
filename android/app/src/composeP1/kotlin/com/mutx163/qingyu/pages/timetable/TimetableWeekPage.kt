package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.calculateEndPadding
import androidx.compose.foundation.layout.calculateStartPadding
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import com.mutx163.qingyu.app.HomeMenuStyle
import com.mutx163.qingyu.app.HomeTitleStyle
import com.mutx163.qingyu.components.liquid.vibrancy
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.settings.SurfaceMaterialState
import com.mutx163.qingyu.pages.shell.HomeInkPolarity
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.blur
import top.yukonga.miuix.kmp.blur.drawBackdrop
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.theme.MiuixTheme
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 课表周视图完整页面（对应 Flutter `lib/screens/timetable_screen.dart` 的周视图部分）。
 *
 * ## 2026-10-29 重做的四个决定
 *
 * 1. **不画自造空态**：旧版在「本周无课」时盖一张卡「本周没有排课 / 点击空白格子…」。
 *    Dart 周网格没有空态（`grep 本周没有排课 lib/` = 0），无课就是一张空白网格。
 * 2. **节高按设置 + 自动充满**：`weekSectionHeight` 走
 *    `settings.timetableAutoFitSectionHeight`（Dart `gridSectionHeight`），
 *    旧版永远用宿主注入的固定值。
 * 3. **「回本周」浮钮**：当浏览的周 ≠ 按开学日算出的真实周时出现（Dart
 *    `_shouldShowFloatingBackToCurrentWeekButton`），点它跳回本周。
 * 4. **设置全部下传**：卡面字段/字号/材质/冲突开关/时间列显示档/星期栏字色都由
 *    [WeekViewStyle] 决定，页面不再写死。
 *
 * ## 已知未复刻（见 `docs/plans/2026-10-29-compose-week-view-audit.md` §六）
 *
 * 壁纸与玻璃坞（属于壳）、下拉快捷导入（`homePull`）、周↔日/月飞行动效、
 * 课卡天气行、情侣课表叠加。这些不是本页能单独补齐的。
 */
@Composable
fun TimetableWeekPage(
    courses: List<Course> = emptyList(),
    timeScheme: TimeScheme? = null,
    settings: TimetableSettings = TimetableSettings.defaults(),
    style: WeekViewStyle = WeekViewStyle(),
    profileName: String = "",
    currentWeek: Int = 1,
    totalWeeks: Int = 20,
    initialWeek: Int = currentWeek,
    visibleDays: List<Int> = (1..7).toList(),
    exams: List<Exam> = emptyList(),
    scheduleItems: List<ScheduleItem> = emptyList(),
    now: LocalDateTime = LocalDateTime.now(),
    todayDate: LocalDate = now.toLocalDate(),
    onCourseClick: (Course) -> Unit = {},
    onAgendaClick: (WeekAgendaCardModel) -> Unit = {},
    /**
     * 某周某天是否假期（Dart `timetable_day_column.dart:76` `provider.isHoliday(date)`）。
     *
     * 2026-10-29 二轮修复：以前 `TimetableWeekGrid.holidayForDay` 全仓没有调用方，
     * 恒 `{ false }` ⇒ 假期课卡既不压淡、也没有「假」角标。
     */
    holidayOf: (week: Int, dayOfWeek: Int) -> Boolean = { _, _ -> false },
    /**
     * 某天某节课的天气一行（Dart `weather: callbacks.weather(item, date)`）。
     *
     * 为 null（宿主没接天气）或返回 null（设置关 / 没数据）时卡面不出现天气行。
     */
    weatherOf: ((week: Int, dayOfWeek: Int, Course) -> String?)? = null,
    onLongPressEmptySlot: (dayOfWeek: Int, section: Int) -> Unit = { _, _ -> },
    onDayClick: (dayOfWeek: Int) -> Unit = {},
    onSwitchProfileClick: () -> Unit = {},
    onWeekChanged: (week: Int) -> Unit = {},
    homeTitleStyle: HomeTitleStyle = HomeTitleStyle.CLASSIC,
    homeMenuStyle: HomeMenuStyle = HomeMenuStyle.LIST,
    homeMenuItems: List<TimetableMenuItem> = emptyList(),
    onHomeMenuSelect: (String) -> Unit = {},
    /**
     * 页面**最底层**的背景槽（首页壁纸，`HomeWallpaperBackdrop`）。
     *
     * 非空时页面底色改透明、把这层画在内容下面 —— 对应 Dart `TimetableHomeStack`
     * 的层次（壁纸 → 状态栏遮罩 → 内容）：有壁纸时 `scaffoldBackgroundColor` 也是
     * `Colors.transparent`（`lib/ui/home/home_chrome_spec.dart:126-128`）。
     *
     * 为空时行为与旧版完全一致（不透明主题底）。壁纸数据由宿主 `TimetableHost`
     * 从用户存档建快照后传进来，本页不读设置。
     */
    backdrop: (@Composable BoxScope.() -> Unit)? = null,
    /**
     * 壁纸上的顶栏墨色：`Light` = 浅墨（深色壁纸）、`Dark` = 深墨（浅色壁纸）、
     * `null` = 没有壁纸 ⇒ 走主题墨色（旧行为）。
     *
     * 判据不在这里算：宿主用壁纸顶部亮度过
     * [com.mutx163.qingyu.pages.shell.HomeBackgroundModel] 的 `chromeInkPolarity`
     * （阈值与 Dart `homePageChromeForegroundForLuminance` 一致，0.45）。
     */
    chromeInk: HomeInkPolarity? = null,
    /**
     * 材质快照（`SettingsMaterialModel.renderSpecOf` 的唯一出口）。null = 老行为
     * （顶栏不画带、课卡按 [WeekViewStyle.surfaceStyle] 的旧透明度）。
     *
     * 页面**不读设置**：哪一档、多大模糊 / 染色由模型层算好，这里只执行。
     */
    material: HomeMaterialRenderSpec? = null,
    /**
     * 当前有没有可用壁纸。顶栏玻璃带只有在壁纸之上才值得采样（没有壁纸时
     * Dart `homePageHeaderUsesFrostedChrome` 恒 false，实心条即可）。
     */
    hasBackdrop: Boolean = false,
    /**
     * 无壁纸 / 实体玻璃带用的页底色（ARGB，来自 `HomeBackdropSnapshot.pageColorArgb`）。
     * null = 主题兜底色（老行为）。不传的话「课表页背景色板」选的自定义色会在
     * 顶栏实心条上露出一截主题色，与页面底色对不上。
     */
    pageColorArgb: Int? = null,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    val coroutineScope = rememberCoroutineScope()

    val pageCount = totalWeeks.coerceAtLeast(1)
    val startPage = (initialWeek - 1).coerceIn(0, pageCount - 1)
    val pagerState = rememberPagerState(initialPage = startPage, pageCount = { pageCount })

    // 翻页 → 通知宿主（Dart `commitPendingWeek`：停稳后写回 provider.currentWeek）。
    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.currentPage }.collect { page ->
            onWeekChanged(page + 1)
        }
    }

    val browsingWeek = pagerState.currentPage + 1
    var showWeekSelectorDialog by remember { mutableStateOf(false) }

    val accentColor = Color(QingyuTheme.primary(dark = dark))
    val textColor = Color(QingyuTheme.primaryText(dark))
    val subTextColor = Color(QingyuTheme.secondaryText(dark))
    val scaffoldBg = Color(QingyuTheme.scaffoldBackground(dark))

    // ── 首页顶栏玻璃带（2026-11-01）──
    // Dart 这条带是「标题行 + 星期栏」共用的一条连续玻璃（`home_page_region_blur.dart`
    // 的 `HomePageChromeGlassFill`）；本页把同一份 modifier 套给这两块。
    //
    // 三步接线的第 ① 步：把壁纸层录进 `bandBackdrop`（记录 ≠ 上屏，原内容照常画）；
    // 第 ② 步在带子上 `drawBackdrop` 采样 + 高斯 + 染色。只有「液态 + 真有壁纸 +
    // 设备支持 RuntimeShader」三件事同时成立才录，否则省掉整层采样。
    val density = LocalDensity.current
    val bandBackdrop = rememberLayerBackdrop()
    val bandSpec = material
    val bandSurface = bandSpec?.band
    val bandBlurActive = bandSurface == SurfaceMaterialState.LIQUID_GLASS &&
        hasBackdrop && isRuntimeShaderSupported()
    val bandTint = MiuixTheme.colorScheme.surface.copy(
        alpha = bandSpec?.liquidTintAlpha ?: 1f,
    )
    val bandSolidColor = pageColorArgb?.let { Color(it) } ?: scaffoldBg
    // 玻璃带按 `material.band` 分三档：OFF 不画；SOLID 不透明页面底色（有壁纸时
    // 盖住壁纸，Dart `homePageHeaderUsesFrostedChrome` 的实体分支）；LIQUID 走
    // miuix 高斯 + 主题底染色，模糊量与染色都来自材质面板那八根旋钮。
    //
    // 标题行与星期栏**共用这一份 modifier**（Dart 那条带就是两块连着的），
    // 否则实体档下会看到「标题实心、星期栏透壁纸」的一道接缝。
    val bandModifier = when {
        bandSpec == null -> Modifier
        bandSurface == SurfaceMaterialState.OFF -> Modifier
        bandBlurActive -> Modifier.drawBackdrop(
            backdrop = bandBackdrop,
            shape = { RectangleShape },
            effects = {
                blur(with(density) { bandSpec.liquidBlurSigma.dp.toPx() })
                // `vibrancy()` = 官方 `colorControls(saturation = 1.5)`：
                // 少了它玻璃会发灰（见 miuix demo 的 LiquidGlass 四层结构）。
                vibrancy()
            },
            onDrawSurface = { drawRect(bandTint) },
        )
        else -> Modifier.background(bandSolidColor)
    }

    val sectionTimes: List<SectionTime> = timeScheme?.sections?.takeIf { it.isNotEmpty() }
        ?: settings.sections
    // 节数口径：Dart `settings.sectionCount => sections.length`
    //（`lib/models/timetable_settings.dart:2479`，周网格 `List.generate(settings.sectionCount)`）。
    // 旧实现写成 `coerceAtLeast(12)`，用户把作息表配成 10 节时 Compose 仍画 12 行、Dart 只画 10 行。
    val sectionCount = sectionTimes.size
    val semesterStart = settings.semesterStartDate?.toLocalDate()
    val realCurrentWeek = currentSemesterWeek(semesterStart, totalWeeks, todayDate)
    val showBackToCurrentWeek = style.showBackToCurrentWeek &&
        realCurrentWeek != null &&
        realCurrentWeek != browsingWeek

    Scaffold(
        // 有壁纸时底色必须透明，否则不透明主题底会把壁纸整张盖掉。
        containerColor = if (backdrop == null) scaffoldBg else Color.Transparent,
        modifier = modifier.fillMaxSize(),
    ) { innerPadding ->
        Box(modifier = Modifier.fillMaxSize()) {
        // 壁纸层在最底（Dart 的层次：壁纸 → 内容）。没有壁纸时这一行什么也不画。
        // 顶栏玻璃带要采样它，所以包一层（只有真要玻璃时才挂 `layerBackdrop`）。
        if (backdrop != null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .then(
                        if (bandBlurActive) Modifier.layerBackdrop(bandBackdrop) else Modifier,
                    ),
            ) {
                backdrop.invoke(this)
            }
        }
        Column(
            modifier = Modifier
                .fillMaxSize()
                // 顶部吃 innerPadding（miuix Scaffold 的 contentWindowInsets 已含状态栏）；
                // 底部刻意不吃——滚动视口要铺到屏幕最底，卡片从手势条底下穿过去
                // （2026-10-28 用户反馈「卡片被手势条截断」就是这层多算了一次）。
                .padding(
                    start = innerPadding.calculateStartPadding(LocalLayoutDirection.current),
                    top = innerPadding.calculateTopPadding(),
                    end = innerPadding.calculateEndPadding(LocalLayoutDirection.current),
                ),
        ) {
            // ── 顶栏「轻屿课表」+ 右上角「更多」菜单（三视图共用一份）──
            Box(modifier = Modifier.fillMaxWidth().then(bandModifier)) {
                TimetableTopBar(
                    brand = homeTitleStyle == HomeTitleStyle.BRAND,
                    inkPolarity = chromeInk,
                    profileName = profileName,
                    onTitleClick = onSwitchProfileClick,
                    homeMenuStyle = homeMenuStyle,
                    menuItems = homeMenuItems,
                    onMenuSelect = onHomeMenuSelect,
                )
            }

            Box(modifier = Modifier.fillMaxSize()) {
                HorizontalPager(
                    state = pagerState,
                    modifier = Modifier.fillMaxSize(),
                ) { page ->
                    WeekPageContent(
                        pageWeek = page + 1,
                        currentWeek = currentWeek,
                        todayDate = todayDate,
                        semesterStart = semesterStart,
                        visibleDays = visibleDays,
                        courses = courses,
                        style = style,
                        sectionTimes = sectionTimes,
                        sectionCount = sectionCount,
                        exams = exams,
                        scheduleItems = scheduleItems,
                        now = now,
                        bottomInset = innerPadding.calculateBottomPadding(),
                        holidayOf = holidayOf,
                        weatherOf = weatherOf,
                        onCourseClick = onCourseClick,
                        onAgendaClick = onAgendaClick,
                        onLongPressEmptySlot = onLongPressEmptySlot,
                        onDayClick = onDayClick,
                        onWeekTitleClick = { showWeekSelectorDialog = true },
                        material = material,
                        bandModifier = bandModifier,
                    )
                }

                // ── 「回本周」浮钮（Dart 浮钮唯一入口）──
                if (showBackToCurrentWeek) {
                    Button(
                        onClick = {
                            realCurrentWeek?.let { target ->
                                coroutineScope.launch {
                                    pagerState.animateScrollToPage(
                                        (target - 1).coerceIn(0, pageCount - 1),
                                    )
                                }
                            }
                        },
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(bottom = innerPadding.calculateBottomPadding() + 72.dp)
                            // Dart 把 `timetableFloatingBackToCurrentWeekButtonOpacity`
                            // 乘在整颗浮钮上（`timetable_back_to_current_week_button.dart:40-82`）。
                            // 以前这个设置映射进了 WeekViewStyle 却没人读，改了不起作用。
                            .alpha(style.backToCurrentWeekOpacity),
                        colors = ButtonDefaults.buttonColors(),
                    ) {
                        Text(
                            text = TimetableStrings.backToCurrentWeekAction.zh,
                            style = MiuixTheme.textStyles.button,
                        )
                    }
                }
            }
        }
        }
    }

    // ── 周次选择弹层（点星期栏左端「8 周」打开）──
    // Dart `week_selector_picker_sheet.dart`：底部弹层 + 4 列网格 + 「第 N 周」+ 说明行 + 回本周。
    // 旧实现是居中 Dialog + 5 列 + 只写数字 + 固定 220dp 高（用户口径「看起来非常奇怪」），
    // 逐条对照后重写，见 `WeekSelectorSheet.kt` 的 KDoc 对照表。
    WeekSelectorSheet(
        show = showWeekSelectorDialog,
        // 可选周次 = 1..总周数（Dart `settings.availableWeeks` 即 startWeek..endWeek，
        // 学期周数在宿主侧已经钳过，这里不再二次过滤）。
        availableWeeks = (1..pageCount).toList(),
        visibleWeek = browsingWeek,
        currentSemesterWeek = realCurrentWeek,
        onDismiss = { showWeekSelectorDialog = false },
        onSelect = { week ->
            showWeekSelectorDialog = false
            coroutineScope.launch {
                pagerState.animateScrollToPage((week - 1).coerceIn(0, pageCount - 1))
            }
        },
    )
}

/**
 * pager 里的一周：星期栏 + 可纵向滚动的时间列/网格。
 *
 * 节高在这里定：`weekSectionHeight` 要拿到实际可用高度才能算「自动充满」。
 */
@Composable
private fun WeekPageContent(
    pageWeek: Int,
    currentWeek: Int,
    todayDate: LocalDate,
    semesterStart: LocalDate?,
    visibleDays: List<Int>,
    courses: List<Course>,
    style: WeekViewStyle,
    sectionTimes: List<SectionTime>,
    sectionCount: Int,
    exams: List<Exam>,
    scheduleItems: List<ScheduleItem>,
    now: LocalDateTime,
    bottomInset: Dp,
    holidayOf: (week: Int, dayOfWeek: Int) -> Boolean,
    weatherOf: ((week: Int, dayOfWeek: Int, Course) -> String?)?,
    onCourseClick: (Course) -> Unit,
    onAgendaClick: (WeekAgendaCardModel) -> Unit,
    onLongPressEmptySlot: (dayOfWeek: Int, section: Int) -> Unit,
    onDayClick: (dayOfWeek: Int) -> Unit,
    onWeekTitleClick: () -> Unit,
    material: HomeMaterialRenderSpec? = null,
    bandModifier: Modifier = Modifier,
) {
    val cardsByDay = remember(courses, pageWeek, style, visibleDays, weatherOf) {
        WeekGridCourseMapping.cardsForWeek(
            courses = courses,
            week = pageWeek,
            style = style,
            visibleDays = visibleDays,
            weatherOf = weatherOf,
        )
    }
    val agendaByDay = remember(exams, scheduleItems, pageWeek, style, visibleDays, semesterStart) {
        buildAgendaByDay(
            week = pageWeek,
            semesterStart = semesterStart,
            visibleDays = visibleDays,
            sectionTimes = sectionTimes,
            exams = exams,
            scheduleItems = scheduleItems,
            now = now,
            style = style,
        )
    }

    Column(modifier = Modifier.fillMaxSize()) {
        // 星期栏与标题行共用同一条玻璃带（Dart `HomePageChromeGlassFill` 盖的就是这两块）。
        Box(modifier = Modifier.fillMaxWidth().then(bandModifier)) {
            TimetableWeekdayHeader(
                week = pageWeek,
                currentWeek = currentWeek,
                todayDate = todayDate,
                semesterStartDate = semesterStart,
                visibleDays = visibleDays,
                style = style,
                timeColumnWidth = style.timeColumnWidthDp.dp,
                hasExamOnDate = { date -> WeekAgendaLogic.hasExamOn(date, exams, now) },
                hasScheduleOnDate = { date -> WeekAgendaLogic.hasScheduleOn(date, scheduleItems) },
                onDayClick = onDayClick,
                onWeekTitleClick = onWeekTitleClick,
            )
        }

        BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
            val sectionHeight = weekSectionHeight(
                style = style,
                availableHeightDp = maxHeight.value,
                weekdayHeaderHeightDp = WEEKDAY_HEADER_HEIGHT_DP,
                sectionCount = sectionCount,
            ).dp

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState()),
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        // 底部留白 = 手势条高度 + 底坞避让余量（最后一行能滑到坞上方）。
                        .padding(bottom = bottomInset + WEEK_GRID_BOTTOM_CLEARANCE_DP.dp),
                ) {
                    TimetableTimeColumn(
                        sectionCount = sectionCount,
                        sectionTimes = sectionTimes,
                        sectionHeight = sectionHeight,
                        timeColumnWidth = style.timeColumnWidthDp.dp,
                        style = style,
                    )
                    TimetableWeekGrid(
                        cardsByDay = cardsByDay,
                        agendaByDay = agendaByDay,
                        visibleDays = visibleDays,
                        sectionCount = sectionCount,
                        sectionHeight = sectionHeight,
                        style = style,
                        // 之前这个参数没人传（恒 { false }），假期压淡与「假」角标永远不出现。
                        holidayForDay = { dayOfWeek -> holidayOf(pageWeek, dayOfWeek) },
                        onCourseClick = onCourseClick,
                        onAgendaClick = onAgendaClick,
                        onLongPressEmptySlot = onLongPressEmptySlot,
                        modifier = Modifier.weight(1f),
                        material = material,
                    )
                }
            }
        }
    }
}

/** 星期栏高度（Dart `TimetableWeekdayHeader.height = 40`）。 */
private const val WEEKDAY_HEADER_HEIGHT_DP = 40f

/** 周网格底部避让：手势条之上再留 64dp 给浮坞。 */
private const val WEEK_GRID_BOTTOM_CLEARANCE_DP = 64f

/** 某周某天的真实日期（Dart `timetable_weekday_header.dart:_dateForWeekDay`）。 */
fun dateForWeekDay(semesterStart: LocalDate?, week: Int, dayOfWeek: Int): LocalDate? =
    TimetableDateLogic.dateForWeekDay(semesterStart, week, dayOfWeek)

/**
 * 按开学日算出的「真实当前周」；学期未配置或超出周数范围返回 null。
 *
 * 对齐 Dart `_resolveCurrentSemesterWeek`：开学日先归一化到周一，
 * `(今天 - 周一)/7 + 1`，越界即 null（此时「回本周」浮钮不出现）。
 */
fun currentSemesterWeek(semesterStart: LocalDate?, totalWeeks: Int, today: LocalDate): Int? =
    TimetableDateLogic.currentSemesterWeek(semesterStart, totalWeeks, today)

/**
 * 整周的考试/日程落格（Dart `_agendaEntriesFor`）：逐天算日期再映射节次。
 *
 * 学期开始日未设置时返回空——与星期栏圆点同口径，避免「有点没卡」或
 * 「有卡没点」两边打架。
 */
fun buildAgendaByDay(
    week: Int,
    semesterStart: LocalDate?,
    visibleDays: List<Int>,
    sectionTimes: List<SectionTime>,
    exams: List<Exam>,
    scheduleItems: List<ScheduleItem>,
    now: LocalDateTime,
    style: WeekViewStyle,
): Map<Int, List<WeekAgendaCardModel>> {
    if (semesterStart == null) return emptyMap()
    if (!style.showWeekGridExams && !style.showWeekGridSchedules) return emptyMap()
    return visibleDays.associateWith { dayOfWeek ->
        val date = dateForWeekDay(semesterStart, week, dayOfWeek)
            ?: return@associateWith emptyList()
        WeekAgendaLogic.resolve(
            date = date,
            sections = sectionTimes,
            exams = exams,
            scheduleItems = scheduleItems,
            now = now,
            showExams = style.showWeekGridExams,
            showSchedules = style.showWeekGridSchedules,
        )
    }
}
