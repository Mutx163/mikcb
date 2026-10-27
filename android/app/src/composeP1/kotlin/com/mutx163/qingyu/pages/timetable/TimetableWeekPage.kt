package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Close
import top.yukonga.miuix.kmp.icon.extended.Favorites
import top.yukonga.miuix.kmp.icon.extended.Refresh
import java.time.LocalDate

/**
 * 课表周视图完整页面（Timetable Week Page · Compose Phase 3）。
 *
 * 对应 Flutter `lib/screens/timetable_screen.dart` 周视图部分：
 * - 顶部 ActionBar：
 *   - 标题区：当前课表名称 + 下拉切换入口；当前浏览第 N 周；
 *   - 右侧操作项：回到本周按钮（非本周高亮）、"+" 号快捷添课入口、课表管理入口（跳转 Profiles）；
 * - 主体区：
 *   - 基于 [HorizontalPager] 原生实现 1..totalWeeks 平滑翻周手势；
 *   - 每周页面组合 [TimetableWeekdayHeader]、[TimetableTimeColumn]、[TimetableWeekGrid]；
 *   - 本周无课时展示优雅极简空态提示（"本周没有排课"）。
 */
@Composable
fun TimetableWeekPage(
    courses: List<Course> = emptyList(),
    timeScheme: TimeScheme? = null,
    settings: TimetableSettings = TimetableSettings.defaults(),
    profileName: String = "我的课表",
    currentWeek: Int = 1,
    totalWeeks: Int = 20,
    initialWeek: Int = currentWeek,
    visibleDays: List<Int> = listOf(1, 2, 3, 4, 5, 6, 7),
    timeColumnWidth: Dp = 34.dp,
    sectionHeight: Dp = 64.dp,
    onCourseClick: (Course) -> Unit = {},
    onEmptySlotClick: (dayOfWeek: Int, section: Int) -> Unit = { _, _ -> },
    onDayClick: (dayOfWeek: Int) -> Unit = {},
    onAddClick: () -> Unit = {},
    onManageProfilesClick: () -> Unit = {},
    onSwitchProfileClick: () -> Unit = {},
    onWeekChanged: (week: Int) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    val coroutineScope = rememberCoroutineScope()

    val pageCount = totalWeeks.coerceAtLeast(1)
    val startPage = (initialWeek - 1).coerceIn(0, pageCount - 1)

    val pagerState = rememberPagerState(
        initialPage = startPage,
        pageCount = { pageCount },
    )

    // 监听翻页事件
    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.currentPage }.collect { page ->
            onWeekChanged(page + 1)
        }
    }

    val activeBrowsingWeek = pagerState.currentPage + 1
    val isViewingCurrentWeek = activeBrowsingWeek == currentWeek

    var showWeekSelectorDialog by remember { mutableStateOf(false) }

    val accentColor = Color(QingyuTheme.primary(dark = dark))
    val textColor = Color(QingyuTheme.primaryText(dark))
    val subTextColor = Color(QingyuTheme.secondaryText(dark))
    val scaffoldBg = Color(QingyuTheme.scaffoldBackground(dark))

    val sectionTimes: List<SectionTime> = timeScheme?.sections?.takeIf { it.isNotEmpty() }
        ?: settings.sections
    val sectionCount = sectionTimes.size.coerceAtLeast(12)

    Scaffold(
        containerColor = scaffoldBg,
        modifier = modifier.fillMaxSize(),
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(innerPadding),
        ) {
            // ── 1. 顶部 ActionBar ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                // 左侧标题区（课表名称 + 当前周次标签 + 下拉切换）
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .clickable { showWeekSelectorDialog = true }
                        .padding(horizontal = 6.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = profileName,
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Bold,
                                color = textColor,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Icon(
                                imageVector = MiuixIcons.ChevronForward,
                                contentDescription = "切换课表",
                                modifier = Modifier.size(14.dp),
                                tint = subTextColor,
                            )
                        }
                        Spacer(modifier = Modifier.height(2.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = "第 $activeBrowsingWeek 周",
                                fontSize = 11.5.sp,
                                fontWeight = FontWeight.Medium,
                                color = if (isViewingCurrentWeek) accentColor else subTextColor,
                            )
                            if (isViewingCurrentWeek) {
                                Spacer(modifier = Modifier.width(4.dp))
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(999.dp))
                                        .background(accentColor.copy(alpha = 0.16f))
                                        .padding(horizontal = 5.dp, vertical = 1.dp),
                                ) {
                                    Text(
                                        text = "本周",
                                        fontSize = 9.5.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = accentColor,
                                        lineHeight = 11.sp,
                                    )
                                }
                            }
                        }
                    }
                }

                // 右侧操作项
                Row(verticalAlignment = Alignment.CenterVertically) {
                    // 回到本周按钮（若非本周高亮）
                    if (!isViewingCurrentWeek) {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(999.dp))
                                .background(accentColor)
                                .clickable {
                                    coroutineScope.launch {
                                        pagerState.animateScrollToPage((currentWeek - 1).coerceIn(0, pageCount - 1))
                                    }
                                }
                                .padding(horizontal = 10.dp, vertical = 5.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    imageVector = MiuixIcons.Refresh,
                                    contentDescription = "回到本周",
                                    modifier = Modifier.size(12.dp),
                                    tint = Color.White,
                                )
                                Spacer(modifier = Modifier.width(3.dp))
                                Text(
                                    text = "回本周",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = Color.White,
                                )
                            }
                        }
                        Spacer(modifier = Modifier.width(4.dp))
                    }

                    // "+" 号快捷添加
                    IconButton(onClick = onAddClick) {
                        Icon(
                            imageVector = MiuixIcons.Add,
                            contentDescription = "添加",
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }

                    // 课表管理入口
                    IconButton(onClick = onManageProfilesClick) {
                        Icon(
                            imageVector = MiuixIcons.Favorites,
                            contentDescription = "课表管理",
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }
                }
            }

            // ── 2. 主体区：HorizontalPager 翻周 ──
            HorizontalPager(
                state = pagerState,
                modifier = Modifier.fillMaxSize(),
            ) { page ->
                val pageWeek = page + 1
                val weekCourses = remember(courses, pageWeek) {
                    courses.filter { it.isInWeek(pageWeek) }
                }
                val hasCoursesInWeek = weekCourses.isNotEmpty()

                Column(modifier = Modifier.fillMaxSize()) {
                    // 表头星期栏
                    TimetableWeekdayHeader(
                        week = pageWeek,
                        currentWeek = currentWeek,
                        semesterStartDate = settings.semesterStartDate?.toLocalDate(),
                        visibleDays = visibleDays,
                        timeColumnWidth = timeColumnWidth,
                        onDayClick = onDayClick,
                        onWeekTitleClick = { showWeekSelectorDialog = true },
                    )

                    // 滚动课表主体
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState()),
                    ) {
                        Row(modifier = Modifier.fillMaxWidth()) {
                            // 左侧时间轴
                            TimetableTimeColumn(
                                sectionCount = sectionCount,
                                sectionTimes = sectionTimes,
                                sectionHeight = sectionHeight,
                                timeColumnWidth = timeColumnWidth,
                            )

                            // 右侧课程网格
                            TimetableWeekGrid(
                                courses = weekCourses,
                                week = pageWeek,
                                visibleDays = visibleDays,
                                sectionCount = sectionCount,
                                sectionHeight = sectionHeight,
                                onCourseClick = onCourseClick,
                                onEmptySlotClick = onEmptySlotClick,
                                modifier = Modifier.weight(1f),
                            )
                        }

                        // 本周无课空态覆盖
                        if (!hasCoursesInWeek) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(top = 120.dp, start = timeColumnWidth + 16.dp, end = 16.dp),
                                contentAlignment = Alignment.Center,
                            ) {
                                QingyuCard(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(16.dp)),
                                    insideMargin = PaddingValues(16.dp),
                                    onClick = onAddClick,
                                ) {
                                    Column(
                                        horizontalAlignment = Alignment.CenterHorizontally,
                                        verticalArrangement = Arrangement.Center,
                                        modifier = Modifier.padding(16.dp),
                                    ) {
                                        Text(
                                            text = "本周没有排课",
                                            fontSize = 14.sp,
                                            fontWeight = FontWeight.SemiBold,
                                            color = textColor,
                                        )
                                        Spacer(modifier = Modifier.height(4.dp))
                                        Text(
                                            text = "点击空白格子或右上角 + 号添课",
                                            fontSize = 11.5.sp,
                                            color = subTextColor,
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── 3. 周次切换弹窗选择器 ──
    if (showWeekSelectorDialog) {
        Dialog(onDismissRequest = { showWeekSelectorDialog = false }) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = "选择周次",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            color = textColor,
                        )
                        IconButton(onClick = { showWeekSelectorDialog = false }) {
                            Icon(
                                imageVector = MiuixIcons.Close,
                                contentDescription = "关闭",
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
                            val isCurrentWeekItem = targetWeek == currentWeek
                            val isSelectedWeekItem = targetWeek == activeBrowsingWeek

                            val itemBg = if (isSelectedWeekItem) {
                                accentColor
                            } else if (isCurrentWeekItem) {
                                accentColor.copy(alpha = 0.16f)
                            } else {
                                Color(QingyuTheme.card(dark))
                            }

                            val itemTextColor = if (isSelectedWeekItem) {
                                Color.White
                            } else if (isCurrentWeekItem) {
                                accentColor
                            } else {
                                textColor
                            }

                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(itemBg)
                                    .clickable {
                                        showWeekSelectorDialog = false
                                        coroutineScope.launch {
                                            pagerState.animateScrollToPage(idx)
                                        }
                                    }
                                    .padding(vertical = 10.dp),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    text = "$targetWeek",
                                    fontSize = 13.sp,
                                    fontWeight = if (isSelectedWeekItem || isCurrentWeekItem) FontWeight.Bold else FontWeight.Medium,
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
