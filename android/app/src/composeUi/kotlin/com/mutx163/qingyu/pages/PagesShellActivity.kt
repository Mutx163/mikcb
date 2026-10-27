package com.mutx163.qingyu.pages

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.pages.schedule.ScheduleItemData
import com.mutx163.qingyu.pages.schedule.ScheduleListEntry
import com.mutx163.qingyu.pages.schedule.ScheduleListGroups
import com.mutx163.qingyu.pages.schedule.ScheduleListPage
import com.mutx163.qingyu.pages.task.TaskDateFilter
import com.mutx163.qingyu.pages.task.TaskListViewState
import com.mutx163.qingyu.pages.task.TaskListPage
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * Compose 迁移 Phase 3 · 页面开发壳（composeUi 变体专属）。
 *
 * ## 结构按原 App 骨架排版（2026-10-27 起，替代早期的「示例菜单」）
 *
 * 主屏 = 课表周视图；底部 dock 三个槽位：课表 / 日程 / 任务——与正式 App 的
 * 「课表主屏 + 玻璃坞内嵌页」同构（玻璃/壁纸效果不在壳里复刻，那属于样式批次）。
 * 带 `.ui` 包名后缀，与正式版/调试版并存，**不会覆盖手机上的正式版**。
 *
 * ## 数据是示例值，不是真实数据
 *
 * 本壳读不到正式版的 FlutterSharedPreferences。日程页喂示例条目只为核对版式与
 * 文案；任务页/课表是空态骨架，示例条目与真实数据接线属于后续批次。
 *
 * ## 接线进度（2026-10-27）
 *
 * 已接：日程列表、任务列表。课表槽位 = 占位页（pages/timetable 泳道重构中，
 * 落地后换回 TimetableWeekPage 并恢复挂载行）。
 * 后续批：统计 / 多课表 / 导出 / 传输 / 云同步 / 诊断（viewState 样例另配）、
 * About 族、设置族——按原 App 层级接进 dock 的「全部功能」入口。
 */
class PagesShellActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MiuixTheme {
                PagesShell()
            }
        }
    }
}

/** dock 槽位，对应原 App 玻璃坞的三个常驻入口。 */
private enum class DockSlot(val label: String) {
    TIMETABLE("课表"),
    SCHEDULE("日程"),
    TASK("任务"),
}

@Composable
private fun PagesShell() {
    var slot by remember { mutableStateOf(DockSlot.TIMETABLE) }

    // dock 结构不是导航栈：非主屏时系统返回回课表主屏，而不是退出壳。
    BackHandler(enabled = slot != DockSlot.TIMETABLE) { slot = DockSlot.TIMETABLE }

    Column(modifier = Modifier.fillMaxSize()) {
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
        ) {
            when (slot) {
                DockSlot.TIMETABLE -> TimetablePendingPage()
                DockSlot.SCHEDULE -> ScheduleListPage(
                    groups = sampleScheduleGroups(),
                    onBack = { slot = DockSlot.TIMETABLE },
                    onAddSchedule = { },
                    onEditSchedule = { },
                    onDeleteSchedule = { },
                )
                DockSlot.TASK -> TaskListPage(
                    viewState = sampleTaskViewState(),
                    onBack = { slot = DockSlot.TIMETABLE },
                    onDateFilterChange = { },
                    onCourseFilterClick = { },
                    onAddTask = { },
                    onEditTask = { },
                    onToggleTask = { },
                    onDeleteTask = { },
                )
            }
        }
        ShellDock(current = slot, onSelect = { slot = it })
    }
}

/** 底部 dock：与原 App 玻璃坞同构的槽位条（玻璃材质后续样式批复刻）。 */
@Composable
private fun ShellDock(current: DockSlot, onSelect: (DockSlot) -> Unit) {
    val colors = MiuixTheme.colorScheme
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(colors.surface)
            .navigationBarsPadding()
            .padding(horizontal = 12.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        DockSlot.entries.forEach { slot ->
            val selected = slot == current
            Box(
                modifier = Modifier
                    .weight(1f)
                    .background(
                        if (selected) colors.primary.copy(alpha = 0.16f) else Color.Transparent,
                        androidx.compose.foundation.shape.RoundedCornerShape(14.dp),
                    )
                    .clickable { onSelect(slot) }
                    .padding(vertical = 10.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = slot.label,
                    fontSize = 14.sp,
                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
                    color = if (selected) colors.primary else colors.onSurfaceVariantSummary,
                )
            }
        }
    }
}

/**
 * 课表槽位占位：pages/timetable 泳道正在重构模型层（main 源集与暂存区暂有重名冲突，
 * 挂载被暂时摘除）。该泳道落地后：恢复 build.gradle 里的 timetable 挂载行，
 * 把本占位换回 `TimetableWeekPage()` 即可点亮，dock 结构无需再动。
 */
@Composable
private fun TimetablePendingPage() {
    val colors = MiuixTheme.colorScheme
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(top = 96.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = "课表",
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = colors.onSurface,
        )
        Text(
            text = "课表页正在迁移泳道中重构，落地后本页自动换入。",
            fontSize = 13.sp,
            lineHeight = 19.sp,
            color = colors.onSurfaceVariantSummary,
            modifier = Modifier.padding(top = 10.dp),
        )
    }
}

/** 示例日程条目：三组各一两条，覆盖版式的三种状态。 */
private fun sampleScheduleGroups(): ScheduleListGroups = ScheduleListGroups(
    upcoming = listOf(
        ScheduleListEntry(
            item = ScheduleItemData(
                id = "demo-1",
                title = "教研会议",
                location = "教学楼 302",
                note = "带教材与期末安排",
                startDate = "2026-11-02",
                startTime = "14:00",
                endTime = "15:30",
                reminderMinutesBefore = 30,
            ),
            nextDate = "2026-11-02",
        ),
        ScheduleListEntry(
            item = ScheduleItemData(
                id = "demo-2",
                title = "实验室例会",
                location = "实验楼 508",
                startDate = "2026-11-06",
                startTime = "09:00",
                endTime = "10:00",
            ),
            nextDate = "2026-11-06",
        ),
    ),
    past = listOf(
        ScheduleListEntry(
            item = ScheduleItemData(
                id = "demo-3",
                title = "期中答疑",
                location = "线上",
                startDate = "2026-10-16",
                startTime = "19:00",
                endTime = "20:00",
            ),
            nextDate = null,
        ),
    ),
    paused = listOf(
        ScheduleListEntry(
            item = ScheduleItemData(
                id = "demo-4",
                title = "暑假集训（已暂停）",
                startDate = "2026-07-01",
                endDate = "2026-08-31",
                startTime = "08:00",
                endTime = "11:30",
                enabled = false,
            ),
            nextDate = null,
        ),
    ),
)

/** 任务列表空态：先看版式骨架，示例条目等 CourseTask 样例批补。 */
private fun sampleTaskViewState(): TaskListViewState = TaskListViewState(
    dateFilter = TaskDateFilter.ALL,
    courseFilter = null,
    selectedCourseLabel = "全部课程",
    sections = emptyList(),
    emptyTitle = "暂无任务",
    undatedHiddenCount = 0,
    totalTasksCount = 0,
)
