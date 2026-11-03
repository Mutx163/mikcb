package com.mutx163.qingyu.pages.timetable.month

import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max

/**
 * 月视图**横向翻月**的页号账与卡片高度判据（纯 Kotlin，无 Compose 依赖）。
 *
 * 对齐 `lib/screens/month_view_screen.dart` 的三处静态方法
 * （`_pageFor` / `_monthForPage` / `_baseYear = 2000`、`_pageCount = 200 * 12`）
 * 与 `lib/domain/month_grid_collapse.dart:151-163` 的 `monthGridCardRowCount`。
 *
 * ## 为什么单独一文件
 *
 * 页号是「年月 ↔ 下标」的双射，卡片高度是「跨着两页取较大行数」的判据 ——
 * 两者都有明确的期望值（跨年、跨世纪、4/5/6 行相邻），埋在 Composable 里只能
 * 靠肉眼滑。放在这里就能用 JVM 单测钉住，渲染层只负责把 [pagerPage] 接到 pager。
 */
object MonthPagerModel {

    /** 页号基准年：2000-01 = 第 0 页（Dart `_baseYear`）。 */
    const val BASE_YEAR: Int = 2000

    /** 年份跨度：200 年（Dart `_pageCount = 200 * 12`），用户翻不到边界。 */
    const val YEAR_SPAN: Int = 200

    /** 总页数（2400）。 */
    const val PAGE_COUNT: Int = YEAR_SPAN * 12

    /** 给定年月得到页号。月份按 1 起；越界页在 [pagerPage] 里钳制。 */
    fun pageOf(year: Int, month: Int): Int =
        (year - BASE_YEAR) * 12 + (month - 1)

    /**
     * 反解页号 → `(年, 月)`，越界页钳到 `[0, PAGE_COUNT-1]`。
     *
     * 钳制与 Dart `_monthForPage` 的 `page.clamp(0, _pageCount - 1)` 同口径：
     * pager 的回弹（越界 overscroll）也可能把浮点页号推到边界外。
     */
    fun monthOfPage(page: Int): Pair<Int, Int> {
        val zeroBased = page.coerceIn(0, PAGE_COUNT - 1)
        return (BASE_YEAR + zeroBased / 12) to (zeroBased % 12 + 1)
    }

    /**
     * 某页在小数页号下的相对进度（0 = 该页完全在位，1 = 下一页完全进来）。
     *
     * 取 `page - floor(page)` 再钳到 `[0, 1]`：回弹时进度会越界，标题若跟着
     * 越界会飞出裁剪区。Dart `month_view_toolbar.dart:235-237` 同口径。
     */
    fun pageFraction(page: Double): Double {
        val frac = page - floor(page)
        return frac.coerceIn(0.0, 1.0)
    }

    /** [page] 取整后的页号（clamp 进合法范围），供工具栏标题与行数查询使用。 */
    fun pagerPage(page: Double): Int =
        floor(page).toInt().coerceIn(0, PAGE_COUNT - 1)

    /**
     * 日历卡高度该按几行算：**当前跨着的两页**里较多的行数。
     *
     * 静止时 `floor == ceil` ⇒ 等于聚焦月自己的行数（不多留空白）；水平滑动
     * 途中两页共存 ⇒ 取大值，否则 5 行月挨着 6 行月时高那一页的最后一行被裁掉
     *（Dart 2026-11 实测：2026-10 是 5 行、11 月是 6 行）。
     *
     * @param page 小数页号（`pagerState.currentPage + currentPageOffsetFraction`）。
     * @param rowsOfPage 给定整页号返回该月真实行数（4~6，[MonthGrid.rowsInMonth]）。
     */
    fun cardRowCount(page: Double, rowsOfPage: (Int) -> Int): Int {
        val lower = pagerPage(page)
        val lowerRows = rowsOfPage(lower)
        val upper = ceil(page).toInt().coerceIn(0, PAGE_COUNT - 1)
        if (upper == lower) return lowerRows
        return max(lowerRows, rowsOfPage(upper))
    }
}
