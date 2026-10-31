package com.mutx163.qingyu.pages.shell

import androidx.compose.ui.graphics.vector.ImageVector
import com.mutx163.qingyu.pages.SHELL_PAGE_INDEX_TITLE
import com.mutx163.qingyu.pages.settings.SettingsGlassDockEditorPage
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
 * ——宁可模糊，不给错暗示。日/周两个视图动作分别用「带日号的日历」(`Th1`)
 * 与「周历」(`Weeks`)，对应 Dart 的 `Icons.today_rounded` / `Icons.calendar_view_week_rounded`。
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

    /** 「更多」菜单一个条目（`TimetableMenuItem` 只描述界面，不认路由）。 */
    fun menuItem(id: String): TimetableMenuItem = TimetableMenuItem(
        id = id,
        label = labelOf(id),
        icon = iconOf(id),
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
