package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.app.HomeNavigationForm
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.ScheduleRecurrence
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.pages.shell.HomeDockNavModel
import com.mutx163.qingyu.pages.shell.HomeGlassDock
import com.mutx163.qingyu.pages.timetable.day.DayViewDataAssembler
import com.mutx163.qingyu.pages.timetable.day.DayViewPage
import com.mutx163.qingyu.pages.timetable.day.dayViewPageDataOf
import com.mutx163.qingyu.pages.timetable.month.MonthText
import com.mutx163.qingyu.pages.timetable.month.MonthViewHost
import java.time.LocalDateTime

// ─────────────────────────────────────────────────────────────────────────────
// 首页「整屏」预览（周 / 日 / 月三态）
//
// ## 与页面文件里那些 @Preview 的分工
//
// · 页面文件里的预览是**组件级**：只铺页面自己的布局，没有坞，也看不到「另一层画的那条
//   顶栏」。月视图尤其容易看错：真机上它是周页里的第三种页内态，顶栏（含月份角格）与
//   星期栏都由周页画，`MonthViewPage` 自己那条只是独立形态。
// · 本文件是**首页级**：把真机首页那一层壳也画进来 —— 顶栏 / 星期栏 + 玻璃坞 + 页面，
//   用来核对「三态切换时 chrome 是否对齐、坞有没有压住内容」这类只有整屏才看得出的问题。
//
// 为什么单开一个文件：三段内容分属三个文件（周页 / 日页 / 月页），而坞不属于任何单个页面
// （它挂在壳层，`PagesShellActivity`）。放在某一页的预览里就等于让那一页替另外两页画坞。
//
// ## 数据
//
// 全部是预览夹具（学期 2026-09-07 开学、今天 2026-11-08 周日 · 第 9 周），但走的都是真组件、
// 真装配（`DayViewDataAssembler` / `MonthViewHost`），只把仓储换成了常量。
//
// ## 看不到的
//
// 周 ↔ 日展开动画、周 ↔ 月横向滑入、坞的液态折射（预览没有壁纸，按实体面画）。这些要验
// 靠 Studio 交互模式或真机。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用学期：2026-09-07（周一）开学 ⇒ 2026-11-08 落在第 9 周。 */
private val previewShellSemesterStart: LocalDateTime = LocalDateTime.of(2026, 9, 7, 0, 0)

/** 预览用「此刻」：2026-11-08（周日）10:00——今天高亮、当前周、考试过期都按它判。 */
private val previewShellNow: LocalDateTime = LocalDateTime.of(2026, 11, 8, 10, 0)

/** 预览用作息表：直接用内置模板，课程钟点由节次从这份表里取。 */
private val previewShellSections: List<SectionTime> = TimetableSettings.DEFAULT_SECTIONS

/** 预览用课表设置：只给开学日与周数，其余走构造默认值（与真机「刚配好学期」同形）。 */
private val previewShellSettings: TimetableSettings = TimetableSettings(
    sections = previewShellSections,
    semesterWeekCount = 20,
    semesterStartDate = previewShellSemesterStart,
)

/** 预览用一门课：起止钟点由节次从 [previewShellSections] 取，保证「第几节 = 几点」同源。 */
private fun previewShellCourse(
    name: String,
    teacher: String,
    location: String,
    dayOfWeek: Int,
    startSection: Int,
    endSection: Int,
    color: String,
): Course = Course(
    id = "preview-shell-$dayOfWeek-$startSection",
    name = name,
    teacher = teacher,
    location = location,
    dayOfWeek = dayOfWeek,
    startSection = startSection,
    endSection = endSection,
    startTime = previewShellSections[startSection - 1].startTime,
    endTime = previewShellSections[endSection - 1].endTime,
    color = color,
    startWeek = 1,
    endWeek = 18,
)

/** 周一到周五都有课：周视图一眼能看出「格子铺满」，日视图取周四内容最密的一天。 */
private val previewShellCourses: List<Course> = listOf(
    previewShellCourse("高等数学", "张明", "示例大学 A101", 1, 1, 2, "#3B82F6"),
    previewShellCourse("大学英语", "李颖", "示例大学 B204", 1, 3, 4, "#F59E0B"),
    previewShellCourse("大学物理", "李海", "示例大学 B203", 2, 3, 4, "#8B5CF6"),
    previewShellCourse("线性代数", "王静", "示例大学 A108", 3, 1, 2, "#10B981"),
    previewShellCourse("程序设计基础", "陈晨", "实验楼 C301", 4, 5, 6, "#F97316"),
    previewShellCourse("数据结构", "陈晨", "实验楼 C302", 4, 9, 10, "#06B6D4"),
    previewShellCourse("中国近现代史纲要", "赵敏", "示例大学 A201", 5, 3, 4, "#EC4899"),
)

/** 预览用考试：本周四（11-05）一场 + 下周四（11-19）一场，星期栏圆点与日议程都要用。 */
private val previewShellExams: List<Exam> = listOf(
    Exam(
        id = "preview-shell-exam-math",
        courseId = "preview-shell-1-1",
        name = "高等数学 · 期中考试",
        dateTime = LocalDateTime.of(2026, 11, 5, 0, 0),
        startTime = "10:00",
        endTime = "11:40",
        location = "教三 305",
        createdAt = previewShellNow,
        updatedAt = previewShellNow,
    ),
    Exam(
        id = "preview-shell-exam-physics",
        courseId = "preview-shell-2-3",
        name = "大学物理 · 期中考试",
        dateTime = LocalDateTime.of(2026, 11, 19, 0, 0),
        startTime = "14:00",
        endTime = "15:40",
        location = "教二 201",
        createdAt = previewShellNow,
        updatedAt = previewShellNow,
    ),
)

/** 预览用日程：每周四 19:00 的组会（与「数据结构」同钟点）+ 周六上午的自习。 */
private val previewShellSchedule: List<ScheduleItem> = listOf(
    ScheduleItem(
        id = "preview-shell-schedule-meeting",
        title = "实验室组会",
        location = "实验楼 C305",
        startDate = LocalDateTime.of(2026, 9, 17, 0, 0),
        endDate = LocalDateTime.of(2026, 12, 31, 0, 0),
        startTime = "19:00",
        endTime = "20:00",
        color = "#8E44AD",
        createdAt = previewShellNow,
        updatedAt = previewShellNow,
        recurrence = ScheduleRecurrence.WEEKLY,
    ),
    ScheduleItem(
        id = "preview-shell-schedule-library",
        title = "图书馆自习",
        location = "图书馆 4 层",
        startDate = LocalDateTime.of(2026, 11, 7, 0, 0),
        endDate = LocalDateTime.of(2026, 11, 7, 0, 0),
        startTime = "09:00",
        endTime = "12:00",
        color = "#0EA5E9",
        createdAt = previewShellNow,
        updatedAt = previewShellNow,
    ),
)

/** 月视图那一档注入给 `MonthViewHost` 的仓储快照（与上面几个夹具同一份数据）。 */
private val previewShellSnapshot: TimetableSnapshot = TimetableSnapshot(
    courses = previewShellCourses,
    scheduleItems = previewShellSchedule,
    settings = previewShellSettings,
    currentWeek = 9,
    semesterStartEpochDay = previewShellSemesterStart.toLocalDate().toEpochDay(),
)

/**
 * 坞的设置：**只改导航形态这一项**（默认是经典底栏，不改的话坞根本不组合）。
 * 其余键保持构造默认值 —— 预览要验的是「坞在不在、排得对不对」，不是某套自定义配色。
 */
private val previewShellDockSettings: TimetableSettingsModel = TimetableSettingsModel(
    homeNavigationForm = HomeNavigationForm.GLASS_DOCK,
)

/**
 * 一档预览的公共身体：页面内容 + 外壳坞。
 *
 * 坞与壳走同一个组件（[HomeGlassDock]），所以条目的排列 / 高亮 / 圆钮 / 材质都按同一份设置解析；
 * 只有两处是预览专有：`overWallpaper = false`（没有壁纸，按实体面判墨色）与底部那 12dp
 * （真机上是手势条安全区，预览没有安全区，手动留一条免得药丸贴边）。
 */
@Composable
private fun PreviewHomeShell(
    dockSelectedId: String,
    dark: Boolean = false,
    textScale: Float = 1f,
    content: @Composable () -> Unit,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        Box(modifier = Modifier.fillMaxSize()) {
            content()
            HomeGlassDock(
                settingsModel = previewShellDockSettings,
                selectedId = dockSelectedId,
                isNavigable = { true },
                onSelect = {},
                onRoundButton = {},
                overWallpaper = false,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 12.dp),
            )
        }
    }
}

@Suppress("unused")
@Preview(name = "1 周视图 · 整屏", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewHomeShellWeek() {
    PreviewHomeShell(dockSelectedId = HomeDockNavModel.ACTION_WEEK) {
        TimetableWeekPage(
            courses = previewShellCourses,
            settings = previewShellSettings,
            currentWeek = 9,
            totalWeeks = 20,
            initialWeek = 9,
            exams = previewShellExams,
            scheduleItems = previewShellSchedule,
            now = previewShellNow,
            todayDate = previewShellNow.toLocalDate(),
        )
    }
}

@Suppress("unused")
@Preview(name = "2 日视图 · 整屏", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewHomeShellDay() {
    PreviewHomeShell(dockSelectedId = HomeDockNavModel.ACTION_DAY) {
        // 周四（11-05）：考试 + 下午课 + 晚上的课与组会，日视图那一列内容最全。
        DayViewPage(
            initialWeek = 9,
            initialDayOfWeek = 4,
            totalWeeks = 20,
            semesterStartDate = previewShellSemesterStart.toLocalDate(),
            realCurrentWeek = 9,
            todayDate = previewShellNow.toLocalDate(),
            hasWallpaper = false,
            onCloseToWeekView = {},
            dataProvider = { week, dayOfWeek ->
                dayViewPageDataOf(
                    DayViewDataAssembler.build(
                        week = week,
                        dayOfWeek = dayOfWeek,
                        courses = previewShellCourses,
                        settings = previewShellSettings,
                        currentWeek = 9,
                        scheduleItems = previewShellSchedule,
                        exams = previewShellExams,
                        now = previewShellNow,
                    ),
                )
            },
        )
    }
}

@Suppress("unused")
@Preview(name = "3 月视图 · 整屏", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewHomeShellMonth() {
    // 月视图在真机上是周页的第三种页内态：顶栏（含月份角格）与星期栏都由周页画，
    // 正文由 `MonthViewHost(embedded = true)` 铺在下面。这里照这条链原样拼。
    PreviewHomeShell(dockSelectedId = HomeDockNavModel.ACTION_WEEK) {
        TimetableWeekPage(
            courses = previewShellCourses,
            settings = previewShellSettings,
            currentWeek = 9,
            totalWeeks = 20,
            initialWeek = 9,
            exams = previewShellExams,
            scheduleItems = previewShellSchedule,
            now = previewShellNow,
            todayDate = previewShellNow.toLocalDate(),
            monthMode = true,
            monthLabel = MonthText.monthLabel(11),
            monthSelectedDate = LocalDateTime.of(2026, 11, 5, 0, 0),
            monthContent = {
                MonthViewHost(
                    snapshot = previewShellSnapshot,
                    now = previewShellNow,
                    exams = previewShellExams,
                    scheduleItems = previewShellSchedule,
                    embedded = true,
                )
            },
        )
    }
}
