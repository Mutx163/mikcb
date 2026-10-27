package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 首页与导航设置页（`lib/screens/settings/settings_home_navigation.dart`）结构测试。
 *
 * 期望值来源：Dart 源（4 个区块 / 条件分支 / 选项表）+ ARB（文案），不从实现倒推。
 *
 * 本页最容易写错的三处，每个都有独立用例：
 * 1. 玻璃坞专属区块（底栏按钮编排）只在 `glassDock` 下出现；
 * 2. 右上角菜单区块**不属于**玻璃坞判断，两种形态都在（:230-287 在 `if` 之外）；
 * 3. 「圆钮功能」下拉的当前值走 `_effectiveGlassDockButtonEntryId`（:40-47），
 *    不是直接读存储值。
 */
class SettingsHomeNavigationPageTest {

    private fun spec(state: SettingsHomeNavigationState = SettingsHomeNavigationState()) =
        SettingsHomeNavigationPage.spec(state)

    // ------------------------------------------------------------ 页面骨架

    @Test
    fun `页面标题取自 homeNavigationTitle`() {
        val page = spec()
        assertEquals("settings-home-navigation", page.id)
        assertEquals("homeNavigationTitle", page.titleKey)
        assertEquals("首页与导航", page.title)
        // settings_home_navigation.dart:73 `title: Text(l10n.homeNavigationTitle)`
    }

    @Test
    fun `经典形态时的顶层区块顺序`() {
        // 区块 0 `HyperosSettingsBlock(应用形态)`（:92-119，label + 组，无前导空档）
        // 区块 1 `HyperosSectionGap` + `HyperosSettingsBlock(右上角菜单)`（:230-287）
        // 区块 2 `HyperosSectionGap` + `HyperosSettingsBlock(首页标题)`（:291-319）
        // 区块 3 `SettingsResetTile`（:320-323，自带一个 gap，settings_reset.dart:209）
        assertEquals(
            listOf(
                "homeNavigation.form.label",
                "homeNavigation.form",
                "homeNavigation.gap.menu",
                "homeNavigation.menu.label",
                "homeNavigation.menu",
                "homeNavigation.gap.homeTitle",
                "homeNavigation.homeTitle.label",
                "homeNavigation.homeTitle",
                "homeNavigation.gap.reset",
                "homeNavigation.reset",
            ),
            spec().topLevelIds(),
        )
    }

    @Test
    fun `玻璃坞形态多出底栏编排区块`() {
        // settings_home_navigation.dart:128-229 整块包在 `if (isGlassDock)` 里，
        // 且自带一个前导空档（:129）
        val ids = spec(SettingsHomeNavigationState(navigationForm = "glassDock")).topLevelIds()
        assertEquals(
            listOf(
                "homeNavigation.form.label",
                "homeNavigation.form",
                "homeNavigation.gap.chrome",
                "homeNavigation.dock.label",
                "homeNavigation.dock",
                "homeNavigation.gap.menu",
                "homeNavigation.menu.label",
                "homeNavigation.menu",
                "homeNavigation.gap.homeTitle",
                "homeNavigation.homeTitle.label",
                "homeNavigation.homeTitle",
                "homeNavigation.gap.reset",
                "homeNavigation.reset",
            ),
            ids,
        )
    }

    @Test
    fun `右上角菜单区块两种形态都在`() {
        // Dart :230-287 的 SettingsBlock(右上角菜单) 在 `if (isGlassDock)` 之外
        for (form in listOf("classic", "glassDock")) {
            val page = spec(SettingsHomeNavigationState(navigationForm = form))
            assertEquals(
                "形态 $form 下都必须有右上角菜单行",
                listOf("homeNavigation.menuStyle", "homeNavigation.menuCustomize"),
                page.group("homeNavigation.menu").childRowIds(),
            )
        }
    }

    // ------------------------------------------------------------ 区块 0 形态

    @Test
    fun `应用形态下拉两档与当前值`() {
        // settings_home_navigation.dart:92-113
        val row = spec().row("homeNavigation.form")
        assertEquals(MiuixRowComponent.DROPDOWN, row.component)
        assertEquals("homeNavigationFormLabel", row.titleKey)
        assertEquals("应用形态", row.title)
        assertEquals(listOf("classic", "glassDock"), row.options.map { it.id })
        assertEquals(listOf("经典形态", "玻璃坞"), row.options.map { it.label })
        // 默认 classic（timetable_settings.dart:803）
        assertEquals("classic", row.selectedOptionId)
        assertEquals(
            "glassDock",
            spec(SettingsHomeNavigationState(navigationForm = "glassDock"))
                .row("homeNavigation.form").selectedOptionId,
        )
    }

    @Test
    fun `形态行的副标题跟随当前形态而不是固定一句`() {
        // Dart :98-103 的 switch：副标题描述的是「当前这一档」会带来什么
        assertEquals("homeNavigationFormClassicSubtitle", spec().row("homeNavigation.form").subtitleKey)
        assertEquals("保持现有的页面与导航方式", spec().row("homeNavigation.form").subtitle)
        val glass = spec(SettingsHomeNavigationState(navigationForm = "glassDock")).row("homeNavigation.form")
        assertEquals("homeNavigationFormGlassDockSubtitle", glass.subtitleKey)
        assertEquals("悬浮玻璃底栏，切换日/周课表", glass.subtitle)
    }

    // ------------------------------------------------------- 区块 1 底栏编排

    @Test
    fun `底栏区块标题与圆钮显隐开关`() {
        // settings_home_navigation.dart:130-146
        val page = spec(SettingsHomeNavigationState(navigationForm = "glassDock"))
        val labels = page.flatten().filterIsInstance<SettingsLabel>()
        assertEquals("glassDockCustomizeSectionTitle", labels[1].textKey)
        assertEquals("底部导航栏", labels[1].text)
        val row = page.row("homeNavigation.showAddButton")
        assertEquals(MiuixRowComponent.SWITCH, row.component)
        assertEquals("glassDockShowAddButtonTitle", row.titleKey)
        assertEquals("显示圆钮", row.title)
        assertEquals("glassDockShowAddButtonSubtitle", row.subtitleKey)
        assertEquals("在药丸右侧单独显示", row.subtitle)
        // 默认 false（timetable_settings.dart:812）
        assertEquals(false, row.switchValue)
    }

    @Test
    fun `圆钮关掉后功能与图标两行一起消失`() {
        // Dart :174-225 包在 `if (_draft.glassDockShowAddButton)` 里
        val off = spec(
            SettingsHomeNavigationState(navigationForm = "glassDock", showAddButton = false),
        )
        assertEquals(
            listOf(
                "homeNavigation.showAddButton",
                "homeNavigation.dockCustomize",
            ),
            off.group("homeNavigation.dock").childRowIds(),
        )
        val on = spec(
            SettingsHomeNavigationState(navigationForm = "glassDock", showAddButton = true),
        )
        assertEquals(
            listOf(
                "homeNavigation.showAddButton",
                "homeNavigation.dockCustomize",
                "homeNavigation.dockButtonEntry",
                "homeNavigation.dockButtonIcon",
            ),
            on.group("homeNavigation.dock").childRowIds(),
        )
    }

    @Test
    fun `自定义底栏按钮行显示已启用数量`() {
        // Dart :147-152 `details: homeGridCustomizeDetails(resolveGlassDockActionIds(_draft).length, HomeDockMenu.maxSlots)`
        val row = spec(
            SettingsHomeNavigationState(
                navigationForm = "glassDock",
                dockActionIds = listOf("day", "week", "tasks"),
            ),
        ).row("homeNavigation.dockCustomize")
        assertEquals(MiuixRowComponent.ARROW, row.component)
        assertEquals("自定义底栏按钮", row.title)
        assertEquals("已启用 3/5 个", row.details)
        assertEquals("homeGridCustomizeDetails", row.detailsKey)
        assertEquals(SettingsAction.NAVIGATE, row.action)
        assertEquals("/settings/glass-dock", row.actionTarget)
    }

    @Test
    fun `底栏空排列回落默认三档`() {
        // home_menu_catalog.dart:539-556：空排列回退 HomeDockMenu.defaultActions
        val row = spec(
            SettingsHomeNavigationState(navigationForm = "glassDock", dockActionIds = emptyList()),
        ).row("homeNavigation.dockCustomize")
        assertEquals("已启用 3/5 个", row.details)
        assertEquals(listOf("day", "week", "tasks"), SettingsHomeNavigationPage.resolveDockActionIds(emptyList()))
    }

    @Test
    fun `底栏排列丢弃未知与重复 id`() {
        // home_menu_catalog.dart:539-556：只留 day/week 或目录内可见条目，去重保序
        assertEquals(
            listOf("day", "overview", "week"),
            SettingsHomeNavigationPage.resolveDockActionIds(
                listOf("day", "no-such-entry", "overview", "day", "week", "overview"),
            ),
        )
    }

    @Test
    fun `圆钮功能下拉第一项是添加入口`() {
        // Dart :175-188：显式给出 homeMenuAddCourseTitle: 'addCourse'，再接目录条目
        val page = spec(
            SettingsHomeNavigationState(navigationForm = "glassDock", showAddButton = true),
        )
        val row = page.row("homeNavigation.dockButtonEntry")
        assertEquals(MiuixRowComponent.DROPDOWN, row.component)
        assertEquals("glassDockRoundActionLabel", row.titleKey)
        assertEquals("圆钮功能", row.title)
        assertEquals("addCourse", row.options.first().id)
        assertEquals("添加", row.options.first().label)
        assertEquals("homeMenuAddCourseTitle", row.options.first().labelKey)
        // 其后按目录声明顺序接上，且目录里的 addCourse 与显式首项同名同值、
        // 只保留一项（Dart 用「文案→值」的 Map 构造，同名覆盖）
        assertEquals(
            listOf("addCourse", "update", "pickupCode", "overview", "statistics"),
            row.options.map { it.id }.take(5),
        )
        assertEquals(
            "「添加」在同一份下拉里不能出现两次",
            1,
            row.options.count { it.id == "addCourse" },
        )
    }

    @Test
    fun `圆钮功能当前值走有效值兜底`() {
        // Dart :40-47 `_effectiveGlassDockButtonEntryId`：
        // 空串 / 'addCourse' → 'addCourse'；未知或不可见条目 → 'addCourse'
        fun selected(id: String?): String? = spec(
            SettingsHomeNavigationState(
                navigationForm = "glassDock",
                showAddButton = true,
                dockButtonEntryId = id,
            ),
        ).row("homeNavigation.dockButtonEntry").selectedOptionId

        assertEquals("addCourse", selected(""))
        assertEquals("addCourse", selected(null))
        assertEquals("addCourse", selected("addCourse"))
        assertEquals("overview", selected("overview"))
        assertEquals("addCourse", selected("no-such-entry"))
        // 调试专属条目在正式版不可见 → 回落到「添加」
        assertEquals("addCourse", selected("memoryStats"))
        assertEquals(
            "memoryStats",
            spec(
                SettingsHomeNavigationState(
                    navigationForm = "glassDock",
                    showAddButton = true,
                    dockButtonEntryId = "memoryStats",
                    diagnosticsBuild = true,
                ),
            ).row("homeNavigation.dockButtonEntry").selectedOptionId,
        )
    }

    @Test
    fun `圆钮图标行显示当前图标名或默认`() {
        // Dart :189-224：details = glassDockButtonIconName ?? glassDockButtonIconDefault
        val unset = spec(
            SettingsHomeNavigationState(navigationForm = "glassDock", showAddButton = true),
        ).row("homeNavigation.dockButtonIcon")
        assertEquals(MiuixRowComponent.ARROW, unset.component)
        assertEquals("圆钮图标", unset.title)
        assertEquals("glassDockButtonIconDefault", unset.detailsKey)
        assertEquals("默认 加号", unset.details)
        assertEquals("/settings/glass-dock-icon", unset.actionTarget)

        val set = spec(
            SettingsHomeNavigationState(
                navigationForm = "glassDock",
                showAddButton = true,
                dockButtonIconName = "plus",
            ),
        ).row("homeNavigation.dockButtonIcon")
        // 图标名是用户选择值，不来自 ARB：键是 NON_ARB_TEXT 空串（对照测试跳过空键）
        assertEquals("", set.detailsKey)
        assertEquals("plus", set.details)
    }

    // ------------------------------------------------------ 区块 1 右上角菜单

    @Test
    fun `右上角菜单样式两档`() {
        // settings_home_navigation.dart:238-248
        val row = spec().row("homeNavigation.menuStyle")
        assertEquals(MiuixRowComponent.DROPDOWN, row.component)
        assertEquals("homeMenuStyleLabel", row.titleKey)
        assertEquals("右上角菜单样式", row.title)
        assertEquals(listOf("list", "grid"), row.options.map { it.id })
        assertEquals(listOf("列表菜单", "八宫格菜单"), row.options.map { it.label })
        // 默认 list（timetable_settings.dart:804）
        assertEquals("list", row.selectedOptionId)
    }

    @Test
    fun `自定义菜单按钮行显示已启用数量`() {
        // Dart :251-256 `resolveHomeGridMenuEntries(_draft).length`
        val row = spec().row("homeNavigation.menuCustomize")
        assertEquals("自定义菜单按钮", row.title)
        // 默认排列 8 项（HomeGridMenu.defaultActions，timetable_settings_enums.dart:173-182）
        assertEquals("已启用 8/8 个", row.details)
        assertEquals(SettingsAction.NAVIGATE, row.action)
        assertEquals("/settings/home-menu", row.actionTarget)

        val custom = spec(
            SettingsHomeNavigationState(gridMenuActions = listOf("overview", "settings")),
        ).row("homeNavigation.menuCustomize")
        assertEquals("已启用 2/8 个", custom.details)
    }

    // -------------------------------------------------------- 区块 2 首页标题

    @Test
    fun `首页标题区块含预览与样式下拉`() {
        // settings_home_navigation.dart:291-319
        val page = spec()
        val label = page.flatten().filterIsInstance<SettingsLabel>()
            .first { it.textKey == "homeTitleSectionTitle" }
        assertEquals("首页标题", label.text)
        assertEquals(
            listOf("homeNavigation.homeTitle.preview", "homeNavigation.homeTitleStyle"),
            page.group("homeNavigation.homeTitle").childIds(),
        )
        val preview = page.flatten().filterIsInstance<SettingsInline>()
            .first { it.id == "homeNavigation.homeTitle.preview" }
        assertEquals(InlineKind.PREVIEW_CARD, preview.kind)
        assertEquals(listOf("homeTitleStyleClassicLabel", "homeTitleStyleBrandLabel"),
            SettingsHomeNavigationPage.homeTitleStyleOptions().map { it.labelKey })

        val row = page.row("homeNavigation.homeTitleStyle")
        assertEquals(MiuixRowComponent.DROPDOWN, row.component)
        assertEquals("homeTitleStyleLabel", row.titleKey)
        assertEquals("标题样式", row.title)
        assertEquals(listOf("classic", "brand"), row.options.map { it.id })
        assertEquals(listOf("经典文字", "大 Logo"), row.options.map { it.label })
        assertEquals("classic", row.selectedOptionId)
    }

    @Test
    fun `首页标题预览文案随应用标题与默认课表名`() {
        // settings_appearance.dart:871-909：classic 只显示 appTitle；
        // brand 显示大 Logo（appTitle）+ 小课表名（defaultTimetablePreviewName）
        val classic = spec().flatten().filterIsInstance<SettingsInline>()
            .first { it.id == "homeNavigation.homeTitle.preview" }
        assertEquals(listOf("轻屿课表"), classic.texts.map { it.text })

        val brand = spec(SettingsHomeNavigationState(titleStyle = "brand"))
            .flatten().filterIsInstance<SettingsInline>()
            .first { it.id == "homeNavigation.homeTitle.preview" }
        assertEquals(
            listOf("轻屿课表", "默认课表"),
            brand.texts.map { it.text },
        )
    }

    // ------------------------------------------------------------- 恢复默认

    @Test
    fun `恢复默认作用于 homeNavigation 且不加作用域说明`() {
        // settings_reset.dart:162-174（scope）+ :226-233（只有两页带说明）
        val row = spec().row("homeNavigation.reset.row")
        assertEquals(MiuixRowComponent.ARROW, row.component)
        assertEquals("恢复默认设置", row.title)
        assertTrue(row.destructive)
        assertEquals(SettingsAction.RESET_SCOPE, row.action)
        assertEquals("homeNavigation", row.actionTarget)
        assertNull(row.subtitle)
    }

    @Test
    fun `两种形态下恢复默认都在最后`() {
        for (form in listOf("classic", "glassDock")) {
            val ids = spec(SettingsHomeNavigationState(navigationForm = form)).topLevelIds()
            assertEquals("homeNavigation.reset", ids.last())
        }
    }

    // ------------------------------------------------------------ 纯函数行为

    @Test
    fun `候选目录顺序与分类与 Dart 目录一致`() {
        // catalog() 返回全表（含当前构建不可见的条目）；可见性由 visible() 门控，
        // 这与 Dart 侧 homeMenuEntryById（全表）+ resolve*（门控）的分工一致。
        val catalog = SettingsHomeNavigationPage.catalog(diagnosticsBuild = false)
        assertEquals(
            listOf(
                "update", "pickupCode", "overview", "statistics", "addCourse", "exams",
                "importCourses", "courseRecolor", "shareTimetable", "tasks", "addExam",
                "addTask", "addScheduleItem", "scheduleList", "courseConflict",
                "locationTimeMatch", "scheduleDateRule", "icsExport", "monthView",
                "timeSchemes", "profiles", "quickSwitchTimetable", "more", "dataTransfer",
                "cloudSync", "lanEdit", "coupleTimetable", "settings", "homeNavigation",
                "statisticsSettings", "support", "aboutApp", "changelog", "userGuide",
                "feedback", "openSourceLicenses", "memoryStats",
            ),
            catalog.map { it.id },
        )
        // 正式版可见的少一个 memoryStats
        assertEquals(
            36,
            catalog.count { it.visible(diagnosticsBuild = false) },
        )
        assertEquals(
            catalog.size,
            catalog.count { it.visible(diagnosticsBuild = true) },
        )
    }

    @Test
    fun `调试专属条目只在诊断构建里可见`() {
        // home_menu_catalog.dart:448 `visible: () => MemoryStatsService.isDiagnosticsBuildCached`
        val notVisible = SettingsHomeNavigationPage.catalog(diagnosticsBuild = false)
            .filterNot { it.visible(diagnosticsBuild = false) }
            .map { it.id }
        assertEquals(listOf("memoryStats"), notVisible)
        assertTrue(
            SettingsHomeNavigationPage.catalog(diagnosticsBuild = true)
                .all { it.visible(diagnosticsBuild = true) },
        )
    }
}
