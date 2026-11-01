package com.mutx163.qingyu.pages.shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 底栏排列 / 「更多」菜单排列的解析规则单测（L0，纯 JVM）。
 *
 * ## 期望值从哪来
 *
 * 全部**手推自 Dart 源码**，不从实现抄：
 * - 底栏：`lib/widgets/home_menu_catalog.dart:536-556`（`resolveGlassDockActionIds`）
 *   + `lib/models/settings/timetable_settings_enums.dart:215-235`（`HomeDockMenu`）
 * - 菜单：`lib/widgets/home_menu_catalog.dart:499-533`（`resolveHomeGridMenuEntries`）
 *   + `lib/models/settings/timetable_settings_enums.dart:160-213`（`HomeGridMenu`）
 *
 * 咬合探针（反向验证）已经做过：把 `MAX_SLOTS` 从 5 改成 6 时
 * 「超过五个截断」这条会红；把「只剩钉住项」那条自愈删掉时菜单用例会红。
 */
class HomeNavModelTest {

    // ---------------------------------------------------------------- 底栏排列

    @Test
    fun `空排列回退到 day week tasks`() {
        assertEquals(
            listOf("day", "week", "tasks"),
            HomeDockNavModel.resolveIds(emptyList()) { true },
        )
    }

    @Test
    fun `用户排列保持顺序并去重`() {
        val raw = listOf("tasks", "day", "tasks", "week")
        assertEquals(
            listOf("tasks", "day", "week"),
            HomeDockNavModel.resolveIds(raw) { true },
        )
    }

    @Test
    fun `视图动作即使没有页面映射也保留`() {
        // 谓词恒 false：day/week 不走页面表，仍必须在。
        assertEquals(
            listOf("day", "week"),
            HomeDockNavModel.resolveIds(listOf("day", "week")) { false },
        )
    }

    @Test
    fun `没有去处的 id 被丢弃`() {
        val raw = listOf("day", "courseRecolor", "week")
        val kept = HomeDockNavModel.resolveIds(raw) { it != "courseRecolor" }
        assertEquals(listOf("day", "week"), kept)
    }

    @Test
    fun `超过五个槽位截断`() {
        val raw = listOf("day", "week", "tasks", "settings", "exams", "statistics", "overview")
        val kept = HomeDockNavModel.resolveIds(raw) { true }
        assertEquals(5, kept.size)
        assertEquals(listOf("day", "week", "tasks", "settings", "exams"), kept)
    }

    @Test
    fun `全部无效时回退默认且回退值也过谓词`() {
        // 只有视图动作有去处：tasks 不在默认回退里出现。
        val kept = HomeDockNavModel.resolveIds(listOf("nope", "alsonope")) { false }
        assertEquals(listOf("day", "week"), kept)
    }

    @Test
    fun `全空字符串不会占槽位`() {
        assertEquals(
            listOf("day", "week", "tasks"),
            HomeDockNavModel.resolveIds(listOf("", "  ", "day", "week", "tasks")) { true },
        )
    }

    // ---------------------------------------------------------------- 高亮下标

    @Test
    fun `高亮落在当前内容对应的槽位`() {
        val ids = listOf("day", "week", "tasks")
        assertEquals(0, HomeDockNavModel.selectedIndex(ids, "day"))
        assertEquals(1, HomeDockNavModel.selectedIndex(ids, "week"))
        assertEquals(2, HomeDockNavModel.selectedIndex(ids, "tasks"))
    }

    @Test
    fun `当前内容不在排列里时整栏不亮`() {
        assertEquals(-1, HomeDockNavModel.selectedIndex(listOf("day", "week"), "tasks"))
        assertEquals(-1, HomeDockNavModel.selectedIndex(listOf("day", "week"), null))
    }

    // ---------------------------------------------------------------- 圆钮

    @Test
    fun `圆钮缺省与空串都回退加课`() {
        assertEquals(HomeDockNavModel.ACTION_ADD_COURSE, HomeDockNavModel.roundButtonAction(null))
        assertEquals(HomeDockNavModel.ACTION_ADD_COURSE, HomeDockNavModel.roundButtonAction("   "))
        assertEquals(
            HomeDockNavModel.ACTION_ADD_COURSE,
            HomeDockNavModel.roundButtonAction("addCourse"),
        )
    }

    @Test
    fun `圆钮绑了别的入口时返回那个入口`() {
        assertEquals("statistics", HomeDockNavModel.roundButtonAction("statistics"))
    }

    // ---------------------------------------------------------------- 根内容判定

    @Test
    fun `只有任务 日程 设置可作为根内容`() {
        assertTrue(HomeDockNavModel.isRootCapable("tasks"))
        assertTrue(HomeDockNavModel.isRootCapable("scheduleList"))
        assertTrue(HomeDockNavModel.isRootCapable("settings"))
        assertTrue(!HomeDockNavModel.isRootCapable("statistics"))
        assertTrue(!HomeDockNavModel.isRootCapable("day"))
    }

    /**
     * 底栏条目 → 「替换主屏内容（底栏保留）」还是「推一层页面（底栏让位）」。
     *
     * 2026-11-01 用户报：把外观编辑器排进底栏后，底栏一直压在页面上、不参与页面入场动画。
     * 根因就是壳里不分流（任何条目都替换栈底）。这条判据钉住分流口径。
     */
    @Test
    fun `视图动作与内嵌宿主走根内容 其余目录页推页`() {
        // 视图动作：切首页视图，底栏保留。
        assertTrue(HomeDockNavModel.rendersAsRoot(HomeDockNavModel.ACTION_DAY))
        assertTrue(HomeDockNavModel.rendersAsRoot(HomeDockNavModel.ACTION_WEEK))
        // 真能当根内容渲染的宿主页。
        assertTrue(HomeDockNavModel.rendersAsRoot("tasks"))
        assertTrue(HomeDockNavModel.rendersAsRoot("scheduleList"))
        assertTrue(HomeDockNavModel.rendersAsRoot("settings"))
        // 开发壳的页面索引本身就在栈底。
        assertTrue(HomeDockNavModel.rendersAsRoot(HomeDockNavModel.DEV_INDEX_ID))
        // 其余目录页：推一层，底栏让位。
        assertTrue(!HomeDockNavModel.rendersAsRoot("appearanceEditor"))
        assertTrue(!HomeDockNavModel.rendersAsRoot("statistics"))
        assertTrue(!HomeDockNavModel.rendersAsRoot("exams"))
    }

    // ---------------------------------------------------------------- 更多菜单

    @Test
    fun `菜单空排列回退默认八项`() {
        assertEquals(
            listOf(
                "overview", "statistics", "addCourse", "exams",
                "tasks", "importCourses", "settings", "support",
            ),
            HomeMenuNavModel.resolveIds(emptyList()) { true },
        )
    }

    @Test
    fun `只剩钉住项时视作未配置并回退默认`() {
        assertEquals(
            HomeMenuNavModel.DEFAULT_IDS,
            HomeMenuNavModel.resolveIds(listOf("settings")) { true },
        )
    }

    @Test
    fun `两项以上时按用户顺序`() {
        val raw = listOf("support", "settings", "overview")
        assertEquals(
            listOf("support", "settings", "overview"),
            HomeMenuNavModel.resolveIds(raw) { true },
        )
    }

    @Test
    fun `菜单里不支持的 id 丢弃且不影响顺序`() {
        val raw = listOf("support", "courseRecolor", "settings")
        assertEquals(
            listOf("support", "settings"),
            HomeMenuNavModel.resolveIds(raw) { it != "courseRecolor" },
        )
    }

    @Test
    fun `菜单超过八项截断`() {
        val raw = HomeMenuNavModel.DEFAULT_IDS + listOf("profiles", "monthView")
        assertEquals(
            HomeMenuNavModel.DEFAULT_IDS,
            HomeMenuNavModel.resolveIds(raw) { true },
        )
    }

    @Test
    fun `菜单去重保序`() {
        val raw = listOf("overview", "overview", "support")
        assertEquals(
            listOf("overview", "support"),
            HomeMenuNavModel.resolveIds(raw) { true },
        )
    }
}
