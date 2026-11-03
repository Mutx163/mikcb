package com.mutx163.qingyu.pages.shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 底栏左右滑转场的**纯逻辑**单测（2026-11-03）。
 *
 * 钉三件事：
 * 1. 页映射：day/week 归一成同一页（课表宿主的两种展开态），推页型条目不占页，
 *    冷启动恢复条目不在排列里时补末尾；
 * 2. 方向：目标页在右为 +1（新页从右滑入）、在左为 -1、同页（含周↔日互点）为 0；
 * 3. 降级：系统动画缩放 ≤ 0 时直接落定不播滑动。
 *
 * 咬合探针（2026-11-03 已做）：把 [DockPagerMotion.slideStep] 的 `to.compareTo(from)`
 * 临时改成 `from.compareTo(to)` → 方向两例必红；把 [DockPagerMotion.reducedMotion] 的
 * `<= 0f` 临时改成 `< 0f` → 降级缩放 0 一例必红；还原后全绿。
 */
class DockPagerMotionTest {

    // ------------------------------------------------------------- 页映射

    @Test
    fun `day与week归一成同一页`() {
        assertEquals("week", DockPagerMotion.normalizePageKey("day"))
        assertEquals("week", DockPagerMotion.normalizePageKey("week"))
        assertEquals("tasks", DockPagerMotion.normalizePageKey("tasks"))
        assertEquals("monthView", DockPagerMotion.normalizePageKey("monthView"))
    }

    @Test
    fun `默认排列三格归一成两页`() {
        // 默认底栏 = day / week / tasks：前两格是同一课表页，加上任务页共 2 页。
        val items = DockPagerMotion.pageItemIds(
            listOf(HomeDockNavModel.ACTION_DAY, HomeDockNavModel.ACTION_WEEK, "tasks"),
            ensureItemId = HomeDockNavModel.ACTION_WEEK,
        )
        assertEquals(listOf(HomeDockNavModel.ACTION_WEEK, "tasks"), items)
    }

    @Test
    fun `推页型条目不占pager页`() {
        // appearanceEditor 是推页型（rendersAsRoot 为 false），不得出现在页列表里。
        val items = DockPagerMotion.pageItemIds(
            listOf(HomeDockNavModel.ACTION_WEEK, "appearanceEditor", "tasks"),
            ensureItemId = HomeDockNavModel.ACTION_WEEK,
        )
        assertEquals(listOf(HomeDockNavModel.ACTION_WEEK, "tasks"), items)
    }

    @Test
    fun `冷启动恢复条目不在排列里时补到末尾`() {
        // 存档停在月视图、底栏没排月视图格：页列表补上 monthView，恢复才有页可停。
        val items = DockPagerMotion.pageItemIds(
            listOf(HomeDockNavModel.ACTION_DAY, "tasks"),
            ensureItemId = "monthView",
        )
        assertEquals(listOf(HomeDockNavModel.ACTION_WEEK, "tasks", "monthView"), items)
    }

    @Test
    fun `恢复条目已在排列里不重复补`() {
        val items = DockPagerMotion.pageItemIds(
            listOf(HomeDockNavModel.ACTION_WEEK, "tasks"),
            ensureItemId = HomeDockNavModel.ACTION_DAY,
        )
        assertEquals(listOf(HomeDockNavModel.ACTION_WEEK, "tasks"), items)
    }

    @Test
    fun `页下标按归一键查找`() {
        val items = listOf(HomeDockNavModel.ACTION_WEEK, "tasks", "monthView")
        assertEquals(0, DockPagerMotion.indexOfPage(items, HomeDockNavModel.ACTION_DAY))
        assertEquals(0, DockPagerMotion.indexOfPage(items, HomeDockNavModel.ACTION_WEEK))
        assertEquals(1, DockPagerMotion.indexOfPage(items, "tasks"))
        assertNull(DockPagerMotion.indexOfPage(items, "appearanceEditor"))
    }

    // --------------------------------------------------------------- 方向

    @Test
    fun `目标在右为正一`() {
        val items = listOf(HomeDockNavModel.ACTION_WEEK, "tasks", "monthView")
        assertEquals(1, DockPagerMotion.slideStep(HomeDockNavModel.ACTION_WEEK, "tasks", items))
        assertEquals(2, DockPagerMotion.slideStep(HomeDockNavModel.ACTION_WEEK, "monthView", items))
        // 隔页滑动仍是同号（Pager 一次滑两页，方向不变）。
        assertTrue(DockPagerMotion.slideStep(HomeDockNavModel.ACTION_WEEK, "monthView", items) > 0)
    }

    @Test
    fun `目标在左为负一`() {
        val items = listOf(HomeDockNavModel.ACTION_WEEK, "tasks", "monthView")
        assertEquals(-1, DockPagerMotion.slideStep("tasks", HomeDockNavModel.ACTION_WEEK, items))
        assertEquals(-2, DockPagerMotion.slideStep("monthView", HomeDockNavModel.ACTION_WEEK, items))
    }

    @Test
    fun `同页与周日语义为0`() {
        val items = listOf(HomeDockNavModel.ACTION_WEEK, "tasks", "monthView")
        // week 与 day 互点 = 同一课表页：不走 Pager 滑动，留给页内展开动画。
        assertEquals(0, DockPagerMotion.slideStep(HomeDockNavModel.ACTION_WEEK, HomeDockNavModel.ACTION_DAY, items))
        // day 起点与 week 同页：day → tasks 的方向与 week → tasks 一致。
        assertEquals(1, DockPagerMotion.slideStep(HomeDockNavModel.ACTION_DAY, "tasks", items))
        assertEquals(0, DockPagerMotion.slideStep("tasks", "tasks", items))
        // 不在列表里的条目（推页型）也判 0：调用方不做滑动、走推页分支。
        assertEquals(0, DockPagerMotion.slideStep("tasks", "appearanceEditor", items))
    }

    // --------------------------------------------------------------- 降级

    @Test
    fun `系统关动画时直接落定`() {
        // ANIMATOR_DURATION_SCALE == 0（开发者选项三档全关）。
        assertTrue(DockPagerMotion.reducedMotion(0f))
        assertTrue(DockPagerMotion.reducedMotion(-1f))
    }

    @Test
    fun `系统开着动画时不降级`() {
        assertFalse(DockPagerMotion.reducedMotion(1f)) // 系统默认
        assertFalse(DockPagerMotion.reducedMotion(0.5f)) // 调慢仍是动画
        assertFalse(DockPagerMotion.reducedMotion(2.5f)) // 调快同理
    }
}
