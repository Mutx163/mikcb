package com.mutx163.qingyu.pages

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
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
import com.mutx163.qingyu.pages.timetable.TimetableWeekPage
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
 * 已接：课表周视图（P3-C1）、日程列表、任务列表。课表槽位自 18:40 起是真实页面，
 * 不再是占位页。
 * 后续批：统计 / 多课表 / 导出 / 传输 / 云同步 / 诊断（viewState 样例另配）、
 * About 族、设置族——按原 App 层级接进 dock 的「全部功能」入口。
 */
class PagesShellActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // edge-to-edge 必须在这里真的调用一次：只 import 是没有任何效果的，
        // 那正是「状态栏与导航条仍然是黑条」的根因（2026-10-27 19:0x 修）。
        //
        // 之前的表现：LaunchTheme 继承了 @android:style/Theme.Light.NoTitleBar，
        // 平台主题的 statusBarColor / navigationBarColor 默认为黑，系统据此把
        // 状态栏与手势条区域涂黑、图标翻白，壳的内容区被挤到黑条下面。
        //
        // 两个 style 都传 Transparent 且用 light()：壳是浅色界面（MiuixTheme 白天档），
        // 需要深色系统图标。scrim 参数只对 API 26–28 的三键导航栏有意义，
        // 本工程 minSdk 33，透明即可。页面侧的内缩不在这里补——课表页已有
        // statusBarsPadding()、底部 dock 已有 navigationBarsPadding()，
        // 在这里再加会让顶部空白翻倍。
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.light(
                android.graphics.Color.TRANSPARENT,
                android.graphics.Color.TRANSPARENT,
            ),
            navigationBarStyle = SystemBarStyle.light(
                android.graphics.Color.TRANSPARENT,
                android.graphics.Color.TRANSPARENT,
            ),
        )

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
                DockSlot.TIMETABLE -> TimetableWeekPage()
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

/*
 * 课表槽位占位页已于 2026-10-27 18:40 移除：P3-C1 的 `pages/timetable/` 已挂进
 * composeUi 源集并取得 L1 绿，槽位换回 `TimetableWeekPage()`。
 */

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
