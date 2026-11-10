package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
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
import com.mutx163.qingyu.pages.shell.HomeBackdropScope
import com.mutx163.qingyu.pages.shell.HomeBackdropSnapshot
import com.mutx163.qingyu.pages.shell.HomeDockNavModel
import com.mutx163.qingyu.pages.shell.HomeGlassDock
import com.mutx163.qingyu.pages.shell.HomeWallpaperBackdrop
import com.mutx163.qingyu.pages.timetable.day.DayViewDataAssembler
import com.mutx163.qingyu.pages.timetable.day.DayViewPage
import com.mutx163.qingyu.pages.timetable.day.dayViewPageDataOf
import com.mutx163.qingyu.pages.timetable.month.MonthText
import com.mutx163.qingyu.pages.timetable.month.MonthViewHost
import java.io.File
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
// ## 看不到的（七条极限，2026-11-10 扩）
//
// 1. **液态玻璃折射/模糊**：预览里坞传 `backdrop = null`，按实体面画；真机药丸的折射/毛玻璃
//    观感看不到（`RuntimeShader` 在 Studio 预览里不稳，不能拿它当验收判据）。
// 2. **真机壁纸**：样例图来自仓库 `docs/screenshots`（见 `PREVIEW_WALLPAPER_RELATIVE`），
//    按「拷到 cacheDir 再把路径喂给 `HomeBackdropSnapshot`」的方式注入；换图只换那个常量。
// 3. **系统状态栏是「模拟」的**：「整壳·带状态栏」那一档用 `showSystemUi = true` 拉出模拟状态栏，
//    时间/信号/电池图标都不是真机值；它只能验**遮挡与 WindowInsets**，不能验状态栏图标/壁纸的
//    真实对比度。
// 4. **实时时间**：夹具固定 `previewShellNow`（2026-11-08 10:00）；今天/当前周/进行中课程都按它判，
//    与手机当下不同（代价换来可复现）。
// 5. **动画与手势**：周↔日展开、周↔月横滑、坞的按压/折射、滚动惯性都不跑（Pager 是静态的）。
// 6. **字体栅格化**：预览用宿主字体回退，中文观感接近但非真机同款字重/字距。
// 7. **半透明与壁纸采样**：没有真实图层录制，顶栏/坞的半透明白只呈纯色混合，不是真机那张壁纸的
//    模糊采样结果；月视图正文（`MonthViewHost(embedded = true)`）自己画的实色面也不透壁纸。
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
        PreviewWeekPageWithMonth()
    }
}

// ═════════════════════════════════════════════════════════════════════════════
// 壁纸版 + 无底栏 A/B + 带状态栏专项档（2026-11-10 整壳预览第二批）
//
// ## 样例壁纸从哪来
//
// 不加新资源、不加包体：直接用仓库里现成的截图（`docs/screenshots`），预览期把它拷进
// `context.cacheDir`，再把绝对路径喂给 [HomeBackdropSnapshot]——与真机「壁纸是一个文件路径」
// 同一条链路。换样例只改 [PREVIEW_WALLPAPER_RELATIVE] 一个常量，代码不动。
// 找不到仓库时（例如把预览文件单独拷出去）自动退化成「无壁纸版」，不崩。
//
// ## 墨色口径
//
// 坞与页面都拿固定亮度 `PREVIEW_WALLPAPER_LUMINANCE`（样例图偏亮 ⇒ 深墨），而不是去量真实
// 像素：预览要的是「排版与层级对不对」，不是墨色算法（那条有 `HomeBackgroundModel` 的单测）。
// ═════════════════════════════════════════════════════════════════════════════

/** 预览样例壁纸：仓库里现成的一张（换成别的只要改这一行）。 */
private const val PREVIEW_WALLPAPER_RELATIVE = "docs/screenshots/05-weather-integration.png"

/** 样例图偏亮（浅色 UI 截图）⇒ 按亮壁纸给深墨。 */
private const val PREVIEW_WALLPAPER_LUMINANCE = 0.6

/** 预览解码宽度：与真机 400dp 宽设备接近，够看清构图。 */
private const val PREVIEW_WALLPAPER_DECODE_WIDTH_PX = 1080

/**
 * 壁纸版坞设置：只把导航形态设成玻璃坞，其余走默认。
 * （无底栏 A 档另用它把形态切成 [HomeNavigationForm.CLASSIC]。）
 */
private val previewShellWallpaperDockSettings: TimetableSettingsModel = TimetableSettingsModel(
    homeNavigationForm = HomeNavigationForm.GLASS_DOCK,
)

/** 无底栏 A 档：经典底栏形态（坞内部据此不画玻璃药丸）。 */
private val previewShellClassicDockSettings: TimetableSettingsModel = TimetableSettingsModel(
    homeNavigationForm = HomeNavigationForm.CLASSIC,
)

/**
 * 取预览用壁纸路径：把仓库里的样例图拷进 cacheDir（同进程只拷一次）。
 *
 * @return 绝对路径；仓库图不存在 / 拷贝失败时 null（调用方退化成无壁纸版）。
 */
@Composable
private fun rememberPreviewWallpaperPath(): String? {
    val context = LocalContext.current
    return remember(context) {
        runCatching {
            val source = findRepoFile(PREVIEW_WALLPAPER_RELATIVE) ?: return@runCatching null
            val target = File(context.cacheDir, "preview-home-shell/${source.name}")
            if (!target.isFile || target.length() != source.length()) {
                target.parentFile?.mkdirs()
                source.copyTo(target, overwrite = true)
            }
            target.absolutePath
        }.getOrNull()
    }
}

/** 从 `user.dir` 向上找仓库根（L0/Gradle/Studio 三种工作目录都试得到）。 */
private fun findRepoFile(relative: String): File? {
    var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
    repeat(10) {
        val candidate = File(dir, relative)
        if (candidate.isFile) return candidate
        dir = dir?.parentFile
    }
    return null
}

/** 壁纸版壳：壁纸铺底 + 页面 + 坞（坞 `backdrop = null` 走实体面，见文件头「看不到的」第 1 条）。 */
@Composable
private fun PreviewHomeShellWallpaper(
    dockSelectedId: String?,
    dockForm: HomeNavigationForm = HomeNavigationForm.GLASS_DOCK,
    showDock: Boolean = true,
    dark: Boolean = false,
    content: @Composable (hasWallpaper: Boolean) -> Unit,
) {
    val wallpaperPath = rememberPreviewWallpaperPath()
    // 无壁纸 / 解码失败时的页底色（真机来自主题；预览这里取白，避免透明穿透到 Studio 背景）。
    val fallbackPageColor = androidx.compose.ui.graphics.Color.White.toArgb()
    val snapshot = remember(wallpaperPath, fallbackPageColor) {
        wallpaperPath?.let { path ->
            HomeBackdropSnapshot(
                wallpaperPath = path,
                alignX = 0.5,
                alignY = 0.5,
                scale = 1.0,
                blurSigma = 0.0,
                decodeWidthPx = PREVIEW_WALLPAPER_DECODE_WIDTH_PX,
                scope = HomeBackdropScope.DEFAULT,
                pageColorArgb = fallbackPageColor,
                followsWeekPager = false,
            )
        }
    }
    val hasWallpaper = snapshot != null
    QingyuPageTheme(isDark = dark) {
        Box(modifier = Modifier.fillMaxSize()) {
            if (snapshot != null) {
                HomeWallpaperBackdrop(snapshot = snapshot) {
                    content(hasWallpaper)
                }
            } else {
                content(false)
            }
            if (showDock) {
                HomeGlassDock(
                    settingsModel = if (dockForm == HomeNavigationForm.GLASS_DOCK) {
                        previewShellWallpaperDockSettings
                    } else {
                        previewShellClassicDockSettings
                    },
                    selectedId = dockSelectedId,
                    isNavigable = { true },
                    onSelect = {},
                    onRoundButton = {},
                    backdrop = null,
                    overWallpaper = hasWallpaper,
                    wallpaperLuminance = PREVIEW_WALLPAPER_LUMINANCE,
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = 12.dp),
                )
            }
        }
    }
}

/** 周页（壁纸版）；`hasBackdrop` 让页面区域透出壁纸。 */
@Composable
private fun PreviewWeekPageWithWallpaper(hasWallpaper: Boolean) {
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
        hasBackdrop = hasWallpaper,
        pageColorArgb = if (hasWallpaper) null else androidx.compose.ui.graphics.Color.White.toArgb(),
    )
}

/** 月视图那一档（壁纸版）：仍是「周页 + 内嵌月正文」这条真链。 */
@Composable
private fun PreviewWeekPageWithMonth(wallpaper: Boolean = false) {
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
        hasBackdrop = wallpaper,
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

@Suppress("unused")
@Preview(name = "4 周视图 · 壁纸整屏", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewHomeShellWeekWallpaper() {
    PreviewHomeShellWallpaper(dockSelectedId = HomeDockNavModel.ACTION_WEEK) { hasWallpaper ->
        PreviewWeekPageWithWallpaper(hasWallpaper)
    }
}

@Suppress("unused")
@Preview(name = "5 日视图 · 壁纸整屏", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewHomeShellDayWallpaper() {
    PreviewHomeShellWallpaper(dockSelectedId = HomeDockNavModel.ACTION_DAY) { hasWallpaper ->
        DayViewPage(
            initialWeek = 9,
            initialDayOfWeek = 4,
            totalWeeks = 20,
            semesterStartDate = previewShellSemesterStart.toLocalDate(),
            realCurrentWeek = 9,
            todayDate = previewShellNow.toLocalDate(),
            hasWallpaper = hasWallpaper,
            pageColorArgb = if (hasWallpaper) {
                null
            } else {
                androidx.compose.ui.graphics.Color.White.toArgb()
            },
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
@Preview(name = "6 月视图 · 壁纸整屏", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewHomeShellMonthWallpaper() {
    PreviewHomeShellWallpaper(dockSelectedId = HomeDockNavModel.ACTION_WEEK) {
        PreviewWeekPageWithMonth(wallpaper = true)
    }
}

@Suppress("unused")
@Preview(name = "7 无底栏 · 经典底栏", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewHomeShellClassicBar() {
    // A 档：不画玻璃药丸，走经典底栏形态（坞内部按 homeNavigationForm 自己切）。
    PreviewHomeShellWallpaper(
        dockSelectedId = HomeDockNavModel.ACTION_WEEK,
        dockForm = HomeNavigationForm.CLASSIC,
    ) { hasWallpaper ->
        PreviewWeekPageWithWallpaper(hasWallpaper)
    }
}

@Suppress("unused")
@Preview(name = "8 无底栏 · 彻底无坞", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewHomeShellNoDock() {
    // B 档：一点导航都不画，验「内容铺到底 + 底部手势条避让」（看最后一节课卡是否被系统条压住）。
    PreviewHomeShellWallpaper(showDock = false, dockSelectedId = null) { hasWallpaper ->
        PreviewWeekPageWithWallpaper(hasWallpaper)
    }
}

@Suppress("unused")
@Preview(
    name = "9 带状态栏 · 周视图",
    // device 与 widthDp/heightDp 是两个尺寸来源：Studio 以 device 为准（Pixel 7 = 412×915dp），
    // 所以本档的验收口径是 **412×915 带系统栏**，不是 400×900。若哪天 Studio 反过来以宽高为准，
    // 按实际渲染二选一保留（见 2026-11-10 拍板：冲突按实际渲染并写进 KDoc）。
    device = "id:pixel_7",
    showSystemUi = true,
    showBackground = true,
)
@Composable
private fun PreviewHomeShellWithSystemBar() {
    // 专项档：只用来验「系统栏/刘海有没有压住顶栏、WindowInsets 吃对没有」。
    // 模拟状态栏的时间/图标不是真机值，不能拿来验图标或壁纸的对比度。
    PreviewHomeShellWallpaper(dockSelectedId = HomeDockNavModel.ACTION_WEEK) { hasWallpaper ->
        PreviewWeekPageWithWallpaper(hasWallpaper)
    }
}
