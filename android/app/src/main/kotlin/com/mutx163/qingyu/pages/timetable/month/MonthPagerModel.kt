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
     * 拖拽行程与版面预算用的**整数**行数：当前跨着的两页里取较大值。
     *
     * 静止时 `floor == ceil` ⇒ 等于聚焦月自己的行数；水平滑动途中两页共存 ⇒ 取大值，
     * 否则 5 行月挨着 6 行月时行程会用少一行的口径，走不满。
     *
     * ⚠️ **不要拿它定卡高**：它在手指刚动 ε 时会从 5 跳到 6（或落定瞬间缩回），
     * 卡高要用连续插值的 [cardRows]。
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

    /**
     * 日历卡高度的**连续**行数：当前页与下一页之间线性插值。
     *
     * 为什么不再用 [cardRowCount] 直接定卡高：它是「两页取大」，在拖拽起点
     * 从 4 行月滑向 6 行月时，手指刚动 ε 卡高就从 4 行跳到 6 行（91dp）；
     * 反向则在落定瞬间缩回去。卡高应该在整段手势里连续变化，而不是在两端各跳一次。
     *
     * 静止时 `frac = 0` ⇒ 等于聚焦月自己的行数；滑动中两页的高度按进度过渡。
     * 代价是较高的那一页在过渡前半段会被卡底裁掉一点——页面本来就在横向移动，
     * 这比整张卡瞬跳一行自然得多。
     */
    fun cardRows(page: Double, rowsOfPage: (Int) -> Int): Double {
        val clamped = page.coerceIn(0.0, (PAGE_COUNT - 1).toDouble())
        val lower = floor(clamped).toInt().coerceIn(0, PAGE_COUNT - 1)
        val upper = (lower + 1).coerceAtMost(PAGE_COUNT - 1)
        val lowerRows = rowsOfPage(lower).toDouble()
        if (upper == lower) return lowerRows
        val fraction = (clamped - lower).coerceIn(0.0, 1.0)
        return lowerRows + (rowsOfPage(upper) - lowerRows) * fraction
    }
}
