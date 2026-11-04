package com.mutx163.qingyu.pages.shell

import androidx.compose.ui.graphics.vector.ImageVector
import com.mutx163.qingyu.pages.SHELL_PAGE_INDEX_TITLE
import com.mutx163.qingyu.pages.settings.SettingsGlassDockEditorPage
import com.mutx163.qingyu.pages.timetable.TimetableMenuDefaults
import com.mutx163.qingyu.pages.timetable.TimetableMenuItem
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.AddCircle
import top.yukonga.miuix.kmp.icon.extended.Album
import top.yukonga.miuix.kmp.icon.extended.All
import top.yukonga.miuix.kmp.icon.extended.Create
import top.yukonga.miuix.kmp.icon.extended.Download
import top.yukonga.miuix.kmp.icon.extended.Favorites
import top.yukonga.miuix.kmp.icon.extended.File
import top.yukonga.miuix.kmp.icon.extended.GridView
import top.yukonga.miuix.kmp.icon.extended.Help
import top.yukonga.miuix.kmp.icon.extended.Import
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.Layers
import top.yukonga.miuix.kmp.icon.extended.Link
import top.yukonga.miuix.kmp.icon.extended.ListView
import top.yukonga.miuix.kmp.icon.extended.Location
import top.yukonga.miuix.kmp.icon.extended.Messages
import top.yukonga.miuix.kmp.icon.extended.Months
import top.yukonga.miuix.kmp.icon.extended.More
import top.yukonga.miuix.kmp.icon.extended.MoveFile
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.Play
import top.yukonga.miuix.kmp.icon.extended.Promotions
import top.yukonga.miuix.kmp.icon.extended.Report
import top.yukonga.miuix.kmp.icon.extended.Replace
import top.yukonga.miuix.kmp.icon.extended.Settings
import top.yukonga.miuix.kmp.icon.extended.Share
import top.yukonga.miuix.kmp.icon.extended.Sidebar
import top.yukonga.miuix.kmp.icon.extended.Tasks
import top.yukonga.miuix.kmp.icon.extended.Theme
import top.yukonga.miuix.kmp.icon.extended.Th1
import top.yukonga.miuix.kmp.icon.extended.Th2
import top.yukonga.miuix.kmp.icon.extended.Th3
import top.yukonga.miuix.kmp.icon.extended.Th4
import top.yukonga.miuix.kmp.icon.extended.Th5
import top.yukonga.miuix.kmp.icon.extended.Th6
import top.yukonga.miuix.kmp.icon.extended.Th7
import top.yukonga.miuix.kmp.icon.extended.Th8
import top.yukonga.miuix.kmp.icon.extended.Th9
import top.yukonga.miuix.kmp.icon.extended.Th10
import top.yukonga.miuix.kmp.icon.extended.Th11
import top.yukonga.miuix.kmp.icon.extended.Th12
import top.yukonga.miuix.kmp.icon.extended.Th13
import top.yukonga.miuix.kmp.icon.extended.Th14
import top.yukonga.miuix.kmp.icon.extended.Th15
import top.yukonga.miuix.kmp.icon.extended.Th16
import top.yukonga.miuix.kmp.icon.extended.Th17
import top.yukonga.miuix.kmp.icon.extended.Th18
import top.yukonga.miuix.kmp.icon.extended.Th19
import top.yukonga.miuix.kmp.icon.extended.Th20
import top.yukonga.miuix.kmp.icon.extended.Th21
import top.yukonga.miuix.kmp.icon.extended.Th22
import top.yukonga.miuix.kmp.icon.extended.Th23
import top.yukonga.miuix.kmp.icon.extended.Th24
import top.yukonga.miuix.kmp.icon.extended.Th25
import top.yukonga.miuix.kmp.icon.extended.Th26
import top.yukonga.miuix.kmp.icon.extended.Th27
import top.yukonga.miuix.kmp.icon.extended.Th28
import top.yukonga.miuix.kmp.icon.extended.Th29
import top.yukonga.miuix.kmp.icon.extended.Th30
import top.yukonga.miuix.kmp.icon.extended.Th31
import top.yukonga.miuix.kmp.icon.extended.Timer
import top.yukonga.miuix.kmp.icon.extended.Tune
import top.yukonga.miuix.kmp.icon.extended.Update
import top.yukonga.miuix.kmp.icon.extended.UploadCloud
import top.yukonga.miuix.kmp.icon.extended.Weeks

/**
 * 首页导航（底栏 + 右上「更多」菜单）的 **id → 文案 / 图标** 解析 —— 渲染层唯一落点。
 *
 * ## 为什么单独一个文件
 *
 * 目录 id 的集合归 `SettingsGlassDockEditorPage.catalog`（设置编辑器那一份，与 Dart
 * `kHomeMenuCatalog` 逐条对齐），排列取舍归 `HomeDockNavModel` / `HomeMenuNavModel`
 * （纯 Kotlin，L0 可测）。剩下「这条 id 长什么样」只有 Compose 能表达（`ImageVector`），
 * 所以落在这层。
 *
 * ## 图标选型口径
 *
 * 优先挑**语义最近**的官方 miuix 图标；同一语义族（如两个统计入口）允许复用，
 * 但不允许把「设置」画成「加号」这类误导。找不到贴切图标的走 [MiuixIcons.More]
 * ——宁可模糊，不给错暗示。日视图用「带日号的日历」（按今天几号选 `Th1`…`Th31`，
 * 见 [dayIconOf]），周视图用「周历」(`Weeks`)，对应 Dart 的
 * `Icons.today_rounded` / `Icons.calendar_view_week_rounded`。
 *
 * ## 文案从哪来
 *
 * 一律走 `SettingsGlassDockEditorPage.labelOf(id)`：那份表是 ARB 逐字的
 * （`glassDockTabDay` / `homeMenuOverviewTitle` …），本文件不写任何中文字面量
 * （守 `CjkLiteralGateTest`）。
 */
object HomeNavIcons {

    /** 底栏一个条目：图标 + 文案 + 无障碍名（有文案时不另给，免得读屏念两遍）。 */
    fun dockItem(id: String): GlassDockItem = GlassDockItem(
        icon = iconOf(id),
        label = labelOf(id),
    )

    /**
     * **日视图**底栏图标：按「今天几号」选 miuix 带日号的日历图标（[MiuixIcons.Th1]…[MiuixIcons.Th31]）。
     *
     * 底栏「日课表」那一格原先写死 [MiuixIcons.Th1] —— 日历中间永远是「1」，用户报
     * 「图标永远显示 1」。改成跟着**本机本地日期**走：`LocalDate.now().dayOfMonth` →
     * `Th{d}`。同族 1…31 逐日一套，外观与原 Th1 完全一致，纯 miuix 图标、零自绘。
     * `dayOfMonth` 恒为 1…31；越界（理论上不会发生）兜底 Th1，绝不返回空白。
     */
    fun dayIconOf(dayOfMonth: Int): ImageVector = when (dayOfMonth) {
        1 -> MiuixIcons.Th1
        2 -> MiuixIcons.Th2
        3 -> MiuixIcons.Th3
        4 -> MiuixIcons.Th4
        5 -> MiuixIcons.Th5
        6 -> MiuixIcons.Th6
        7 -> MiuixIcons.Th7
        8 -> MiuixIcons.Th8
        9 -> MiuixIcons.Th9
        10 -> MiuixIcons.Th10
        11 -> MiuixIcons.Th11
        12 -> MiuixIcons.Th12
        13 -> MiuixIcons.Th13
        14 -> MiuixIcons.Th14
        15 -> MiuixIcons.Th15
        16 -> MiuixIcons.Th16
        17 -> MiuixIcons.Th17
        18 -> MiuixIcons.Th18
        19 -> MiuixIcons.Th19
        20 -> MiuixIcons.Th20
        21 -> MiuixIcons.Th21
        22 -> MiuixIcons.Th22
        23 -> MiuixIcons.Th23
        24 -> MiuixIcons.Th24
        25 -> MiuixIcons.Th25
        26 -> MiuixIcons.Th26
        27 -> MiuixIcons.Th27
        28 -> MiuixIcons.Th28
        29 -> MiuixIcons.Th29
        30 -> MiuixIcons.Th30
        31 -> MiuixIcons.Th31
        else -> MiuixIcons.Th1
    }

    /**
     * **周视图**底栏图标：与日图标同族——`MiuixIcons.Th1`…`Th31`，把「开学第几周」这个数字
     * 直接作为日历主体内容显示（和 [dayIconOf] 同一套日历数字图标，纯 miuix、零自绘）。
     *
     * 不用通知角标（Badge）那种「角落红点」观感——用户反馈那看起来像「9 条未读消息」。
     * 越界 / 未开学 / 无学期数据时调用方不调用本函数，保持原 `MiuixIcons.Weeks` 图标。
     * 周数在 1..31 内（学期最多三十来周），直接复用 [dayIconOf] 的 1…31 映射。
     */
    fun weekIconOf(weekNumber: Int): ImageVector = dayIconOf(weekNumber)

    /**
     * 「更多」菜单一个条目（`TimetableMenuItem` 只描述界面，不认路由）。
     *
     * 二级子项（列表档里「添加」展开的课程 / 日程 / 考试三选）由
     * [TimetableMenuDefaults.childrenOf] 一处给出 —— 这里只按 id 取，不另写一份表。
     */
    fun menuItem(id: String): TimetableMenuItem = TimetableMenuItem(
        id = id,
        label = labelOf(id),
        icon = iconOf(id),
        children = TimetableMenuDefaults.childrenOf(id),
    )

    /**
     * 该 id 的展示名。
     *
     * 未登记的 id 由 `labelOf` 回退成 id 原文（`ArbText(NON_ARB_TEXT, id)`）——
     * 排在屏上至少还能看出是哪个键，不会变成空白按钮。
     *
     * 开发壳的「索引」条目（[HomeDockNavModel.DEV_INDEX_ID]）不是目录项，
     * 标题取自索引页自己的常量（`SHELL_PAGE_INDEX_TITLE`），两边不会各叫各的。
     */
    fun labelOf(id: String): String = when (id) {
        HomeDockNavModel.DEV_INDEX_ID -> SHELL_PAGE_INDEX_TITLE
        else -> SettingsGlassDockEditorPage.labelOf(id).zh
    }

    /** 该 id 的图标。未登记的一律 [MiuixIcons.More]。 */
    fun iconOf(id: String): ImageVector = when (id) {
        // 开发壳的页面索引（「全部」语义最接近）。
        HomeDockNavModel.DEV_INDEX_ID -> MiuixIcons.All
        // ── 视图动作（Dart `glassDockActionIcon`）──
        HomeDockNavModel.ACTION_DAY -> MiuixIcons.Th1
        HomeDockNavModel.ACTION_WEEK -> MiuixIcons.Weeks

        // ── 功能入口（`kHomeMenuCatalog` 功能组）──
        "update" -> MiuixIcons.Update
        "pickupCode" -> MiuixIcons.File
        "overview" -> MiuixIcons.GridView
        "statistics" -> MiuixIcons.Promotions
        "addCourse" -> MiuixIcons.Add
        "exams" -> MiuixIcons.Notes
        "importCourses" -> MiuixIcons.Import
        "courseRecolor" -> MiuixIcons.Theme
        "shareTimetable" -> MiuixIcons.Share
        "tasks" -> MiuixIcons.Tasks
        "addExam" -> MiuixIcons.AddCircle
        "addTask" -> MiuixIcons.AddCircle
        "addScheduleItem" -> MiuixIcons.AddCircle
        "scheduleList" -> MiuixIcons.ListView
        "courseConflict" -> MiuixIcons.Report
        "locationTimeMatch" -> MiuixIcons.Location
        "scheduleDateRule" -> MiuixIcons.Months
        "icsExport" -> MiuixIcons.Download
        "monthView" -> MiuixIcons.Months
        "timeSchemes" -> MiuixIcons.Timer
        "profiles" -> MiuixIcons.Layers
        "quickSwitchTimetable" -> MiuixIcons.Replace
        "more" -> MiuixIcons.More

        // ── 数据与同步 ──
        "dataTransfer" -> MiuixIcons.MoveFile
        "cloudSync" -> MiuixIcons.UploadCloud
        "lanEdit" -> MiuixIcons.Link
        "coupleTimetable" -> MiuixIcons.Favorites

        // ── 偏好设置 ──
        "settings" -> MiuixIcons.Settings
        "homeNavigation" -> MiuixIcons.Sidebar
        "generalSettings" -> MiuixIcons.Settings
        "appearanceSettings" -> MiuixIcons.Theme
        "appearanceEditor" -> MiuixIcons.Create
        "timetablePageSettings" -> MiuixIcons.Tune
        "courseCardSettings" -> MiuixIcons.Layers
        "weatherSettings" -> MiuixIcons.Th1
        "liveSettings" -> MiuixIcons.Play
        "holidaySettings" -> MiuixIcons.Album
        "homeWidgetSettings" -> MiuixIcons.GridView
        "diagnosticsSettings" -> MiuixIcons.Report
        "statisticsSettings" -> MiuixIcons.Promotions

        // ── 关于与支持 ──
        "support" -> MiuixIcons.Favorites
        "aboutApp" -> MiuixIcons.Info
        "changelog" -> MiuixIcons.Notes
        "userGuide" -> MiuixIcons.Help
        "feedback" -> MiuixIcons.Messages
        "openSourceLicenses" -> MiuixIcons.File
        "memoryStats" -> MiuixIcons.Layers

        else -> MiuixIcons.More
    }
}
