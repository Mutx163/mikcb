package com.mutx163.qingyu.pages.shell

import java.time.LocalDate
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

    /**
     * 内嵌页集合 = Dart `_inlineDockPageDescriptors`（`home_menu_route_registry.dart:83-173`）。
     * 2026-11-01 之前这里只有三个，用户把统计/考试排进底栏后点开底栏就没了。
     */
    @Test
    fun `内嵌页集合对齐 Dart 的内嵌表`() {
        // Dart 内嵌表里有、本仓也具备页面的条目。
        for (id in listOf(
            "overview", "pickupCode", "statistics", "exams", "tasks", "scheduleList",
            "courseConflict", "locationTimeMatch", "scheduleDateRule", "icsExport",
            "timeSchemes", "profiles", "more", "update", "memoryStats",
            "dataTransfer", "cloudSync", "lanEdit", "coupleTimetable",
            "settings", "statisticsSettings", "support", "changelog", "userGuide",
            "feedback", "openSourceLicenses",
        )) {
            assertTrue("$id 应是内嵌页（底栏常驻）", HomeDockNavModel.isRootCapable(id))
        }
        // Dart 侧是推入路由页 / 表单页：不内嵌。
        assertTrue(!HomeDockNavModel.isRootCapable("appearanceEditor"))
        assertTrue(!HomeDockNavModel.isRootCapable("addCourse"))
        assertTrue(!HomeDockNavModel.isRootCapable("addExam"))
        assertTrue(!HomeDockNavModel.isRootCapable("generalSettings"))
        assertTrue(!HomeDockNavModel.isRootCapable("day"))
    }

    /**
     * 底栏条目 → 「替换主屏内容（底栏保留）」还是「推一层页面（底栏让位）」。
     *
     * 2026-11-01 用户报：把外观编辑器排进底栏后，底栏一直压在页面上、不参与页面入场动画。
     * 根因就是壳里不分流（任何条目都替换栈底）。这条判据钉住分流口径。
     */
    @Test
    fun `视图动作与内嵌页走根内容 表单与外观编辑器推页`() {
        // 视图动作：切首页视图，底栏保留（月视图在 Dart 也是底栏内嵌页）。
        assertTrue(HomeDockNavModel.rendersAsRoot(HomeDockNavModel.ACTION_DAY))
        assertTrue(HomeDockNavModel.rendersAsRoot(HomeDockNavModel.ACTION_WEEK))
        assertTrue(HomeDockNavModel.rendersAsRoot("monthView"))
        assertTrue(HomeDockNavModel.isViewAction("monthView"))
        // 内嵌页（Dart 的 inlineDockPages）：底栏常驻。
        assertTrue(HomeDockNavModel.rendersAsRoot("tasks"))
        assertTrue(HomeDockNavModel.rendersAsRoot("scheduleList"))
        assertTrue(HomeDockNavModel.rendersAsRoot("settings"))
        assertTrue(HomeDockNavModel.rendersAsRoot("statistics"))
        assertTrue(HomeDockNavModel.rendersAsRoot("exams"))
        // 开发壳的页面索引本身就在栈底。
        assertTrue(HomeDockNavModel.rendersAsRoot(HomeDockNavModel.DEV_INDEX_ID))
        // 其余：推一层，底栏让位。
        assertTrue(!HomeDockNavModel.rendersAsRoot("appearanceEditor"))
        assertTrue(!HomeDockNavModel.rendersAsRoot("addCourse"))
        assertTrue(!HomeDockNavModel.rendersAsRoot("generalSettings"))
    }

    /**
     * 「首页缩放」档：目前只有外观编辑页（Dart `HomeMenuEntry.zoomTransition` 同口径）。
     *
     * 这一档的页面自己会把整个首页缩进预览卡，所以壳必须**瞬时切换、不叠侧滑** ——
     * 叠上去就是用户 2026-11-01 报的「从右边滑进来，而不是首页缩放」。
     */
    @Test
    fun `只有外观编辑页走首页缩放档`() {
        assertTrue(HomeDockNavModel.zoomsFromHome("b.appearanceEditor"))
        assertTrue(!HomeDockNavModel.zoomsFromHome("b.appearance"))
        assertTrue(!HomeDockNavModel.zoomsFromHome("b.general"))
        assertTrue(!HomeDockNavModel.zoomsFromHome("e.statistics"))
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

    // ---------------------------------------------------------------- 周视图「开学第几周」

    // 2026-09-07 是周一（本机日历）；以它为开学日，往后 14 天 = 第 3 周的周一。
    private val semesterStartMonday = LocalDate.of(2026, 9, 7)
    private val week3Monday = LocalDate.of(2026, 9, 21)

    @Test
    fun `学期内返回开学第几周`() {
        assertEquals(
            3,
            HomeDockNavModel.dockWeekNumber(week3Monday, semesterStartMonday, 20),
        )
        // 开学当周 = 第 1 周。
        assertEquals(
            1,
            HomeDockNavModel.dockWeekNumber(semesterStartMonday, semesterStartMonday, 20),
        )
        // 正好落在最后一周（= 学期周数）仍算在范围内。
        assertEquals(
            3,
            HomeDockNavModel.dockWeekNumber(week3Monday, semesterStartMonday, 3),
        )
    }

    @Test
    fun `开学日不是周一时按所在周的周一锚定`() {
        // 开学日 2026-09-09（周三），归到同周周一 09-07；今天 09-21 仍是第 3 周。
        assertEquals(
            3,
            HomeDockNavModel.dockWeekNumber(
                week3Monday,
                LocalDate.of(2026, 9, 9),
                20,
            ),
        )
    }

    @Test
    fun `还没开学返回 null 保持原图标`() {
        // 今天早于开学日：getWeekIndex 返回 null。
        assertEquals(
            null,
            HomeDockNavModel.dockWeekNumber(LocalDate.of(2026, 9, 1), semesterStartMonday, 20),
        )
    }

    @Test
    fun `学期已过返回 null 保持原图标`() {
        // 第 3 周但学期只有 2 周 ⇒ 超出范围。
        assertEquals(
            null,
            HomeDockNavModel.dockWeekNumber(week3Monday, semesterStartMonday, 2),
        )
    }

    @Test
    fun `没有学期数据返回 null 保持原图标`() {
        // 没设开学日。
        assertEquals(null, HomeDockNavModel.dockWeekNumber(week3Monday, null, 20))
        // 周数非正（视为无有效学期）。
        assertEquals(null, HomeDockNavModel.dockWeekNumber(week3Monday, semesterStartMonday, 0))
    }
}
