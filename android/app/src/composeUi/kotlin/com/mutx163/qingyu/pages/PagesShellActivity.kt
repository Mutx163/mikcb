package com.mutx163.qingyu.pages

import android.content.res.Configuration
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.pages.schedule.ScheduleItemData
import com.mutx163.qingyu.pages.schedule.ScheduleListEntry
import com.mutx163.qingyu.pages.schedule.ScheduleListGroups
import com.mutx163.qingyu.pages.schedule.ScheduleListPage
import com.mutx163.qingyu.pages.shell.GlassDockItem
import com.mutx163.qingyu.pages.shell.GlassDockNavigationBar
import com.mutx163.qingyu.pages.task.TaskDateFilter
import com.mutx163.qingyu.pages.task.TaskListViewState
import com.mutx163.qingyu.pages.task.TaskListPage
import com.mutx163.qingyu.pages.timetable.TimetableWeekPage
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ListView
import top.yukonga.miuix.kmp.icon.extended.Months
import top.yukonga.miuix.kmp.icon.extended.Tasks

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
        // 系统栏图标必须跟壳的明暗走：亮色界面要深色图标（light()），深色界面
        // 要浅色图标（dark()）。此前固定 light()，系统切深色后图标与背景同色，
        // 状态栏内容直接不可见。这里先按当前配置给出首帧的正确值，之后由
        // setContent 内的 SideEffect 跟随 isSystemInDarkTheme() 持续校正
        // （manifest 未声明 uiMode 的 configChanges，切深色通常走 Activity 重建，
        // 但 SideEffect 能兜住不重建的路径，两条路都不会留错色）。
        //
        // scrim 参数只对 API 26–28 的三键导航栏有意义，本工程 minSdk 33，
        // 透明即可。页面侧的内缩不在这里补——课表页已有 statusBarsPadding()、
        // 底部 dock 已有 navigationBarsPadding()，在这里再加会让顶部空白翻倍。
        applyShellSystemBars(isDark = isNightMode())

        setContent {
            val dark = isSystemInDarkTheme()
            SideEffect { applyShellSystemBars(isDark = dark) }
            // 壳的主题必须也走主题桥：无参 MiuixTheme{ } 的配色恒取官方默认亮色板，
            // 系统切深色后卡片仍是 #FFFFFF，而正文取的是 QingyuTheme 的深色白字
            // → 白字白底、内容不可读（页面层已由 QingyuPageTheme 兜住，壳这层是
            // 根因，此处一并修掉）。用 QingyuPageTheme 后页面里的同款包装成为
            // 重复但等价的一层，后续可逐页摘除。
            QingyuPageTheme { PagesShell() }
        }
    }

    /** 当前资源配置是否为深色。仅作首帧兜底，组合内以 isSystemInDarkTheme() 为准。 */
    private fun isNightMode(): Boolean =
        (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES

    /** 系统栏全透明，图标明暗跟随壳的明暗。 */
    private fun applyShellSystemBars(isDark: Boolean) {
        val transparent = android.graphics.Color.TRANSPARENT
        enableEdgeToEdge(
            statusBarStyle = if (isDark) {
                SystemBarStyle.dark(transparent)
            } else {
                SystemBarStyle.light(transparent, transparent)
            },
            navigationBarStyle = if (isDark) {
                SystemBarStyle.dark(transparent)
            } else {
                SystemBarStyle.light(transparent, transparent)
            },
        )
    }
}

@Composable
private fun PagesShell() {
    var slot by remember { mutableStateOf(DockSlot.TIMETABLE) }

    // dock 结构不是导航栈：非主屏时系统返回回课表主屏，而不是退出壳。
    BackHandler(enabled = slot != DockSlot.TIMETABLE) { slot = DockSlot.TIMETABLE }

    // 玻璃的背景采样源：整个内容区先被录进这个 layer，底栏再拿它当 backdrop。
    // 必须挂在**内容**上、而不是包住整个 Column —— 包住就会把底栏自己也录进去，
    // 底栏于是拿「含自己」的图去算模糊，展开动画里明暗会来回颤。
    val backdrop = rememberLayerBackdrop()
    val glassAvailable = isRuntimeShaderSupported()

    Box(modifier = Modifier.fillMaxSize()) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .layerBackdrop(backdrop),
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

        GlassDockNavigationBar(
            items = dockItems,
            selectedIndex = slot.ordinal,
            onSelect = { index -> slot = DockSlot.entries[index] },
            // 设备不支持 runtime shader 时别把 backdrop 传进去：
            // 传了也画不出模糊，反而会多录一层、白费一次采样。
            backdrop = if (glassAvailable) backdrop else null,
            modifier = Modifier.align(Alignment.BottomCenter),
        )
    }
}

/**
 * 三个槽位的图标。
 *
 * 选型理由：课表=日历格（`Months`）、日程=清单（`ListView`）、任务=勾选（`Tasks`）——
 * 与 Flutter 版玻璃坞的图标语义对齐；名字都取自 `miuix-icons` 的 extended 组，
 * 已确认存在（见 `MiuixIcons` 扩展属性）。
 */
private val dockItems: List<GlassDockItem>
    @Composable get() = listOf(
        GlassDockItem(
            icon = MiuixIcons.Months,
            label = DockSlot.TIMETABLE.label,
            contentDescription = DockSlot.TIMETABLE.label,
        ),
        GlassDockItem(
            icon = MiuixIcons.ListView,
            label = DockSlot.SCHEDULE.label,
            contentDescription = DockSlot.SCHEDULE.label,
        ),
        GlassDockItem(
            icon = MiuixIcons.Tasks,
            label = DockSlot.TASK.label,
            contentDescription = DockSlot.TASK.label,
        ),
    )

/** dock 槽位，对应原 App 玻璃坞的三个常驻入口。 */
private enum class DockSlot(val label: String) {
    TIMETABLE("课表"),
    SCHEDULE("日程"),
    TASK("任务"),
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
