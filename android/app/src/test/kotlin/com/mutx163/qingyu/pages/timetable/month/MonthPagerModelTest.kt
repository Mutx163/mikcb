package com.mutx163.qingyu.pages.timetable.month

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

/**
 * 月视图横向翻月的页号账与卡片高度判据。
 *
 * 期望值全部对齐 Dart 原件：
 * `lib/screens/month_view_screen.dart` 的 `_pageFor` / `_monthForPage` /
 * `_baseYear = 2000` / `_pageCount = 200 * 12`，以及
 * `lib/domain/month_grid_collapse.dart:151-163` 的 `monthGridCardRowCount`。
 */
class MonthPagerModelTest {

    @Test
    fun 页号以_2000_年_1_月为第零页() {
        assertEquals(0, MonthPagerModel.pageOf(2000, 1))
        assertEquals(11, MonthPagerModel.pageOf(2000, 12))
        assertEquals(12, MonthPagerModel.pageOf(2001, 1))
        assertEquals(MonthPagerModel.PAGE_COUNT - 1, MonthPagerModel.pageOf(2199, 12))
    }

    @Test
    fun 页号反解与越界钳制() {
        assertEquals(2000 to 1, MonthPagerModel.monthOfPage(0))
        assertEquals(2008 to 5, MonthPagerModel.monthOfPage(100))
        assertEquals(2199 to 12, MonthPagerModel.monthOfPage(MonthPagerModel.PAGE_COUNT - 1))
        // 回弹可能把浮点页号推到边界外：钳进合法范围，不抛也不给出 13 月。
        assertEquals(2000 to 1, MonthPagerModel.monthOfPage(-3))
        assertEquals(2199 to 12, MonthPagerModel.monthOfPage(MonthPagerModel.PAGE_COUNT + 5))
    }

    @Test
    fun 翻页进度取小数部分并钳在零到一() {
        assertEquals(0.0, MonthPagerModel.pageFraction(120.0), 1e-9)
        assertEquals(0.5, MonthPagerModel.pageFraction(120.5), 1e-9)
        assertEquals(0.25, MonthPagerModel.pageFraction(120.25), 1e-9)
        assertEquals(0.0, MonthPagerModel.pageFraction(121.0), 1e-9)
        // 临近下一页（0.999999）不能被进位成 1.0 后再被当成整页 0。
        assertEquals(0.999999, MonthPagerModel.pageFraction(120.999999), 1e-6)
    }

    @Test
    fun 取整页号沿用年份进位() {
        assertEquals(12, MonthPagerModel.pagerPage(12.0))
        assertEquals(12, MonthPagerModel.pagerPage(12.4))
        assertEquals(0, MonthPagerModel.pagerPage(-0.2))
        assertEquals(MonthPagerModel.PAGE_COUNT - 1, MonthPagerModel.pagerPage(MonthPagerModel.PAGE_COUNT + 0.6))
    }

    @Test
    fun 卡片高度静止时等于本页行数() {
        val rows = mapOf(5 to 5, 6 to 6)
        assertEquals(5, MonthPagerModel.cardRowCount(5.0) { rows[it] ?: 6 })
        assertEquals(6, MonthPagerModel.cardRowCount(6.0) { rows[it] ?: 6 })
    }

    @Test
    fun 卡片高度滑动中取跨着两页的较大行数() {
        // 5 行月 → 6 行月：滑到一半就必须按 6 行算，否则高那页最后一行被裁。
        assertEquals(6, MonthPagerModel.cardRowCount(5.5) { if (it == 5) 5 else 6 })
        // 6 行月 → 5 行月：反向同样取大值。
        assertEquals(6, MonthPagerModel.cardRowCount(5.5) { if (it == 5) 6 else 5 })
        // 刚过整页一点点（0.1）也要算上相邻页。
        assertEquals(6, MonthPagerModel.cardRowCount(5.1) { if (it == 5) 5 else 6 })
        // 反向回弹（-0.1）跨的是 4 与 5；取大值。
        assertEquals(5, MonthPagerModel.cardRowCount(4.9) { if (it == 4) 4 else 5 })
    }

    @Test
    fun 卡片高度在末页不越界() {
        val lastPage = MonthPagerModel.PAGE_COUNT - 1
        assertEquals(5, MonthPagerModel.cardRowCount(lastPage.toDouble()) { if (it == lastPage) 5 else 6 })
        // 末页回弹 0.4 页：上界钳到末页本身，不会去查 PAGE_COUNT。
        assertEquals(5, MonthPagerModel.cardRowCount(lastPage + 0.4) { if (it == lastPage) 5 else 4 })
        assertEquals(5.0, MonthPagerModel.cardRows(lastPage + 0.4) { if (it == lastPage) 5 else 4 }, 1e-9)
    }

    /**
     * 卡高连续插值：拖拽过程中不再在「手指刚动」或「落定」时整行跳变。
     *
     * 旧 `cardRowCount` 是两页取大：4→6 行时手指刚动 ε 就从 4 跳到 6（91dp），
     * 6→4 行时则在落定瞬间缩回去。新 `cardRows` 按页进度线性过渡。
     */
    @Test
    fun 卡片高度连续插值_不存在整行跳变() {
        val rows = mapOf(5 to 5, 6 to 6)
        assertEquals(5.0, MonthPagerModel.cardRows(5.0) { rows[it] ?: 6 }, 1e-9)
        assertEquals(5.5, MonthPagerModel.cardRows(5.5) { rows[it] ?: 6 }, 1e-9)
        assertEquals(6.0, MonthPagerModel.cardRows(6.0) { rows[it] ?: 6 }, 1e-9)

        // 反向 6 → 5：中点同样是 5.5，旧实现会一直停在 6 直到落定。
        assertEquals(5.5, MonthPagerModel.cardRows(5.5) { if (it == 5) 6 else 5 }, 1e-9)

        // 相邻 10% 的增量不超过 0.1 行；任何整行跳变都会在这里被抓住。
        var previous = MonthPagerModel.cardRows(5.0) { rows[it] ?: 6 }
        for (step in 1..10) {
            val current = MonthPagerModel.cardRows(5.0 + step / 10.0) { rows[it] ?: 6 }
            assertTrue(
                "页进度 10% 内卡高跳了 ${abs(current - previous)} 行",
                abs(current - previous) <= 0.1 + 1e-9,
            )
            previous = current
        }
    }
}
