package com.mutx163.qingyu.pages.shell

/**
 * 首页底栏（玻璃坞）**槽位排列**的解析 —— 纯 Kotlin，不含 Compose 依赖。
 *
 * ## 它解决的是什么
 *
 * Flutter 版的底栏按钮是用户可编排的（设置 → 首页与导航 → 自定义底栏按钮，
 * `lib/screens/settings/settings_home_navigation.dart`），底栏渲染时走
 * `resolveGlassDockActionIds(settings)`（`lib/widgets/home_menu_catalog.dart:536-556`）：
 * 读 `glassDockActions`、丢掉不可见/未知 id、去重保序、空表回退
 * `HomeDockMenu.defaultActions`（`timetable_settings_enums.dart:219` = `['day','week','tasks']`）。
 *
 * Compose 壳此前把底栏写死成「课表 / 日程 / 任务 / 设置」四项
 * （`PagesShellActivity.dockItems`），于是设置里改底栏**一点效果都没有**
 * —— 这正是本轮审核要修的 P0。本对象是那段解析逻辑在 Kotlin 侧的**唯一落点**：
 * 渲染层只负责把 id 画成图标和文字，顺序与取舍全在这里。
 *
 * ## 为什么「可跳转」由调用方注入
 *
 * Dart 侧判断一个 id 能不能留在底栏，靠 `homeMenuEntryById(id)` 在目录里查得到
 * 且 `visible()` 为真。Kotlin 侧的目录在设置模型（`SettingsGlassDockEditorPage.catalog`）
 * 与壳页面映射（`shellTimetableMenuPageId`）两处，都在 `main` 源集里。
 * 本对象属于 `pages/shell`，L0 单测只编这个目录 + 共享模型目录，直接 import
 * 那两个目录会让模块单测编不过（要么加 `-ExtraSources`，要么把验证面缩小）。
 * 所以把「这个 id 有没有去处」做成一个谓词参数：单测注入假表就能把取舍规则
 * 全部钉住，生产侧传壳里那一张真表。
 *
 * ## 和 Dart 的一处**有意差异**
 *
 * Dart 的底栏条目一旦在目录里就保留，点击时再决定「内嵌切换」还是「推路由」。
 * 本仓当前只有 4 个可在主屏内切换的宿主（周 / 日 / 任务 / 设置），其余目录页
 * 都靠推路由打开（底栏让位）。所以本对象**不丢弃**这些 id（它们仍然可用），
 * 只保证顺序与上限，内嵌 / 推页的分流交给 [isRootCapable]。
 */
object HomeDockNavModel {

    /** `kGlassDockActionDay`（`home_menu_catalog.dart:534`）：切到日课表视图。 */
    const val ACTION_DAY = "day"

    /** `kGlassDockActionWeek`（`home_menu_catalog.dart:535`）：切到周课表视图。 */
    const val ACTION_WEEK = "week"

    /** 圆钮默认绑定的动作（`glassDockButtonEntryId` 缺省值）。 */
    const val ACTION_ADD_COURSE = "addCourse"

    /**
     * **开发壳专属**的「页面索引」条目 id —— 不是 Dart 的目录项。
     *
     * 索引页（`ShellPageIndexScreen`）是 L4 逐页对照的入口：78 屏里有一批页
     * 不在任何用户菜单路径上，没有它就是「真机上一个都点不到」
     * （`docs/plans/2026-10-27-compose-phase3-l4-checklist.md`）。
     *
     * 它只在**用户还没自定义过底栏**（`glassDockActions` 为空）时追加到排列末尾：
     * 一旦用户动过底栏，就完全按存档来，不把开发件混进用户的排列。
     * 拆壳（R2）时连同 `PagesShellActivity` 一起删。
     */
    const val DEV_INDEX_ID = "index"

    /** `HomeDockMenu.maxSlots`（`timetable_settings_enums.dart:217`）。 */
    const val MAX_SLOTS = 5

    /**
     * `HomeDockMenu.defaultActions`（`timetable_settings_enums.dart:219`）。
     *
     * 空排列（没改过、或用户把 key 清掉）时回退到这一份，与 Dart 完全一致。
     */
    val DEFAULT_IDS: List<String> = listOf(ACTION_DAY, ACTION_WEEK, "tasks")

    /** 视图动作（不是页面）：点它切首页内容，不推路由。 */
    val VIEW_ACTION_IDS: Set<String> = setOf(ACTION_DAY, ACTION_WEEK)

    /** 两个视图动作也算「有去处」（它们由首页自己处理，不走页面映射表）。 */
    fun isViewAction(id: String): Boolean = id in VIEW_ACTION_IDS

    /**
     * 主屏内可直接切换内容、**底栏保留**的 id。
     *
     * 对应 Dart `kInlineDockPages` 里本仓已经具备宿主的那几条
     * （`lib/screens/home_menu_route_registry.dart:83-135`：`tasks` / `settings` / …）。
     * 这里只列**当前壳真能当根内容渲染**的：任务列表、日程列表、设置主页。
     * 其余目录页仍可排进底栏，但点开是推一层页面（底栏让位），差异已写进审核文档。
     */
    val ROOT_CAPABLE_IDS: Set<String> = setOf("tasks", "scheduleList", "settings")

    /** 是否作为**主屏内容**渲染（底栏保留），否则走推路由。 */
    fun isRootCapable(id: String): Boolean = id in ROOT_CAPABLE_IDS

    /**
     * 底栏条目点下去，是**替换主屏内容**（底栏保留）还是**推一层页面**（底栏让位）。
     *
     * 三类走前者：视图动作（`day` / `week`，切首页视图）、[ROOT_CAPABLE_IDS] 里那几个
     * 真能当根内容渲染的宿主页、以及开发壳的页面索引（它自己就是栈底内容）。
     * 其余目录页（外观编辑器、统计、考试……）一律推一层。
     *
     * 为什么要单独抽出来：壳里 `selectRoot` 原先**不分流**，任何底栏条目都直接替换栈底，
     * 于是把「外观编辑器」排进底栏后，底栏会一直压在它上面（`atRoot` 仍为 true），
     * 既不参与页面的入场动画、也不让位（2026-11-01 用户报「底栏没跟着缩小、留在原位」）。
     * 这条判据是纯逻辑，单测可钉；壳只负责按结果调 `pushPage` / 换栈底。
     */
    fun rendersAsRoot(id: String): Boolean =
        isViewAction(id) || isRootCapable(id) || id == DEV_INDEX_ID

    /**
     * 解析底栏排列：去重保序 → 丢掉**没有去处**的 id → 截断到 [MAX_SLOTS]
     * → 空表回退 [DEFAULT_IDS]（回退值同样要过一遍谓词，避免把坏 id 塞回来）。
     *
     * @param raw 用户存档里的 `glassDockActions`（可能为空、可能含旧版本残留 id）。
     * @param isNavigable 「这个 id 点得开吗」。视图动作不必过这条（由内部先放行）。
     */
    fun resolveIds(
        raw: List<String>,
        isNavigable: (String) -> Boolean,
    ): List<String> {
        val kept = ArrayList<String>(raw.size)
        for (item in raw) {
            if (item.isBlank() || kept.contains(item)) continue
            if (!isViewAction(item) && !isNavigable(item)) continue
            kept.add(item)
            if (kept.size >= MAX_SLOTS) break
        }
        if (kept.isNotEmpty()) return kept

        val fallback = ArrayList<String>(DEFAULT_IDS.size)
        for (id in DEFAULT_IDS) {
            if (!isViewAction(id) && !isNavigable(id)) continue
            fallback.add(id)
        }
        return fallback
    }

    /**
     * 当前该高亮第几格。
     *
     * @param ids 解析后的排列。
     * @param activeId 当前主屏内容对应的 id（`week` / `day` / `tasks` …）。
     * @return 下标；排列里没有这一项时返回 **-1**（整栏不亮），而不是硬亮第 0 格
     *   —— 亮一格「根本没打开」的视图会让用户以为点错了（Dart `_dockSelectedIndex`
     *   在同一条判据上返回 -1，`timetable_home_page_assembly.dart:394-406`）。
     */
    fun selectedIndex(ids: List<String>, activeId: String?): Int {
        if (activeId == null) return -1
        val index = ids.indexOf(activeId)
        return index
    }

    /**
     * 圆钮（右侧独立按钮）点下去要做什么。
     *
     * Dart `handleRoundButtonTap`（`lib/controllers/home_menu_controller.dart:306-333`）：
     * 绑的是 `addCourse` 或空 ⇒ 直接开加课；绑了别的入口 ⇒ 打开那个入口；
     * 旧版本残留的、已撤掉的 id ⇒ 回退成加课（**不能显示一个没反应的按钮**）。
     *
     * @return `addCourse` 表示开加课流程；其他返回原 id（调用方按目录页打开）。
     */
    fun roundButtonAction(entryId: String?): String {
        val id = entryId?.trim().orEmpty()
        if (id.isEmpty() || id == ACTION_ADD_COURSE) return ACTION_ADD_COURSE
        return id
    }
}
