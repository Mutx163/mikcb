package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import com.mutx163.qingyu.app.HomeMenuStyle
import com.mutx163.qingyu.app.HomeTitleStyle
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.core.Course
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
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Close
import top.yukonga.miuix.kmp.theme.MiuixTheme
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit

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
    onLongPressEmptySlot: (dayOfWeek: Int, section: Int) -> Unit = { _, _ -> },
    onDayClick: (dayOfWeek: Int) -> Unit = {},
    onSwitchProfileClick: () -> Unit = {},
    onWeekChanged: (week: Int) -> Unit = {},
    homeTitleStyle: HomeTitleStyle = HomeTitleStyle.CLASSIC,
    homeMenuStyle: HomeMenuStyle = HomeMenuStyle.LIST,
    homeMenuItems: List<TimetableMenuItem> = emptyList(),
    onHomeMenuSelect: (String) -> Unit = {},
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

    val sectionTimes: List<SectionTime> = timeScheme?.sections?.takeIf { it.isNotEmpty() }
        ?: settings.sections
    val sectionCount = sectionTimes.size.coerceAtLeast(12)
    val semesterStart = settings.semesterStartDate?.toLocalDate()
    val realCurrentWeek = currentSemesterWeek(semesterStart, totalWeeks, todayDate)
    val showBackToCurrentWeek = style.showBackToCurrentWeek &&
        realCurrentWeek != null &&
        realCurrentWeek != browsingWeek

    Scaffold(
        containerColor = scaffoldBg,
        modifier = modifier.fillMaxSize(),
    ) { innerPadding ->
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
            TimetableTopBar(
                brand = homeTitleStyle == HomeTitleStyle.BRAND,
                profileName = profileName,
                onTitleClick = onSwitchProfileClick,
                homeMenuStyle = homeMenuStyle,
                menuItems = homeMenuItems,
                onMenuSelect = onHomeMenuSelect,
            )

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
                        onCourseClick = onCourseClick,
                        onAgendaClick = onAgendaClick,
                        onLongPressEmptySlot = onLongPressEmptySlot,
                        onDayClick = onDayClick,
                        onWeekTitleClick = { showWeekSelectorDialog = true },
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
                            .padding(bottom = innerPadding.calculateBottomPadding() + 72.dp),
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

    // ── 周次选择弹窗（点星期栏左端「8 周」打开）──
    if (showWeekSelectorDialog) {
        Dialog(onDismissRequest = { showWeekSelectorDialog = false }) {
            QingyuCard(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = TimetableStrings.selectWeekTitle.zh,
                            style = MiuixTheme.textStyles.body1,
                            fontWeight = FontWeight.Bold,
                            color = textColor,
                        )
                        IconButton(onClick = { showWeekSelectorDialog = false }) {
                            Icon(
                                imageVector = MiuixIcons.Close,
                                contentDescription = TimetableStrings.closeAction.zh,
                                modifier = Modifier.size(18.dp),
                                tint = subTextColor,
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    LazyVerticalGrid(
                        columns = GridCells.Fixed(5),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.height(220.dp),
                    ) {
                        items(pageCount) { idx ->
                            val targetWeek = idx + 1
                            val isRealCurrentWeek = targetWeek == realCurrentWeek
                            val isSelectedWeek = targetWeek == browsingWeek
                            val itemBg = when {
                                isSelectedWeek -> accentColor
                                isRealCurrentWeek -> accentColor.copy(alpha = 0.16f)
                                else -> Color(QingyuTheme.card(dark))
                            }
                            val itemTextColor = when {
                                isSelectedWeek -> Color.White
                                isRealCurrentWeek -> accentColor
                                else -> textColor
                            }
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(itemBg)
                                    .clickable {
                                        showWeekSelectorDialog = false
                                        coroutineScope.launch { pagerState.animateScrollToPage(idx) }
                                    }
                                    .padding(vertical = 10.dp),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    text = "$targetWeek",
                                    style = MiuixTheme.textStyles.footnote1,
                                    fontWeight = if (isSelectedWeek || isRealCurrentWeek) {
                                        FontWeight.Bold
                                    } else {
                                        FontWeight.Medium
                                    },
                                    color = itemTextColor,
                                    textAlign = TextAlign.Center,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
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
    onCourseClick: (Course) -> Unit,
    onAgendaClick: (WeekAgendaCardModel) -> Unit,
    onLongPressEmptySlot: (dayOfWeek: Int, section: Int) -> Unit,
    onDayClick: (dayOfWeek: Int) -> Unit,
    onWeekTitleClick: () -> Unit,
) {
    val cardsByDay = remember(courses, pageWeek, style, visibleDays) {
        WeekGridCourseMapping.cardsForWeek(courses, pageWeek, style, visibleDays)
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
                        onCourseClick = onCourseClick,
                        onAgendaClick = onAgendaClick,
                        onLongPressEmptySlot = onLongPressEmptySlot,
                        modifier = Modifier.weight(1f),
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
fun dateForWeekDay(semesterStart: LocalDate?, week: Int, dayOfWeek: Int): LocalDate? {
    val start = semesterStart ?: return null
    val monday = start.minusDays((start.dayOfWeek.value - 1).toLong())
    return monday.plusDays(((week - 1) * 7 + (dayOfWeek - 1)).toLong())
}

/**
 * 按开学日算出的「真实当前周」；学期未配置或超出周数范围返回 null。
 *
 * 对齐 Dart `_resolveCurrentSemesterWeek`：开学日先归一化到周一，
 * `(今天 - 周一)/7 + 1`，越界即 null（此时「回本周」浮钮不出现）。
 */
fun currentSemesterWeek(semesterStart: LocalDate?, totalWeeks: Int, today: LocalDate): Int? {
    val start = semesterStart ?: return null
    val monday = start.minusDays((start.dayOfWeek.value - 1).toLong())
    val days = ChronoUnit.DAYS.between(monday, today)
    val week = (days / 7).toInt() + 1
    if (week < 1 || week > totalWeeks) return null
    return week
}

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
