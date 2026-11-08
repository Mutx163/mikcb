package com.mutx163.qingyu.pages.timetable.day

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 日视图「短日纵向补白」的算术单测（2026-11-08）。
 *
 * 判据本身是纯函数，L0 直接跑；真机手感（补完能不能滑、会不会多出大块空白）
 * 仍然要用户在设备上看一眼 —— 这里只钉住「算得对」。
 */
class DayViewScrollTailTest {

    /** 一台常见手机的日视图视口高（px，约 700dp × 2.75）。用它好读。 */
    private val viewport = 2000

    @Test
    fun `不足一屏的日子补到视口五分之一的范围`() {
        // 内容 1000、视口 2000：原本范围 −1000（一像素都滚不动）。
        val tail = DayViewScrollTail.tailHeightPx(
            viewportHeightPx = viewport,
            contentHeightPx = 1000,
        )
        assertEquals(1400, tail)
        // 补完以后总长 2400 ⇒ 可滚 400 = 视口 × 1/5。
        assertEquals(
            (viewport * DayViewScrollTail.MIN_RANGE_FRACTION).toInt(),
            1000 + tail - viewport,
        )
    }

    @Test
    fun `只差一点就到一屏的日子也补到下限`() {
        // 内容 2010、视口 2000：原本只滚得动 10px，一次上滑就见底
        //（用户报的「只能下滑，下滑回来又能上滑」）。
        assertEquals(390, DayViewScrollTail.tailHeightPx(2000, 2010))
    }

    @Test
    fun `内容本来够长的日子一点不补`() {
        assertEquals(0, DayViewScrollTail.tailHeightPx(2000, 4000))
        // 刚好等于下限（范围 400）：不算「不够」，也不补。
        assertEquals(0, DayViewScrollTail.tailHeightPx(2000, 2400))
    }

    @Test
    fun `视口或内容高还没量到时不补`() {
        assertEquals(0, DayViewScrollTail.tailHeightPx(0, 1000))
        assertEquals(0, DayViewScrollTail.tailHeightPx(2000, 0))
        assertEquals(0, DayViewScrollTail.tailHeightPx(2000, -10))
    }

    @Test
    fun `停在顶部且真实末项可见时才认这个内容高`() {
        // 4 项 = 顶部留缝 + 摘要卡 + 一张卡 + 补白自己 ⇒ 真实末项 index = 2。
        assertEquals(
            900,
            DayViewScrollTail.naturalContentPx(
                firstVisibleItemIndex = 0,
                totalItemsCount = 4,
                lastRealVisibleIndex = 2,
                lastRealVisibleBottomPx = 900,
            ),
        )
    }

    @Test
    fun `滚到中途不重算内容高`() {
        // 滚下去以后，末项的 offset+size 只是「贴着视口底边」的位置，不是内容真高；
        // 照它算会给长列表凭空补白，而且每滚一次补一段。
        assertNull(
            DayViewScrollTail.naturalContentPx(
                firstVisibleItemIndex = 1,
                totalItemsCount = 4,
                lastRealVisibleIndex = 2,
                lastRealVisibleBottomPx = 900,
            ),
        )
    }

    @Test
    fun `末项没露出来的长列表不认`() {
        assertNull(
            DayViewScrollTail.naturalContentPx(
                firstVisibleItemIndex = 0,
                totalItemsCount = 40,
                lastRealVisibleIndex = 8,
                lastRealVisibleBottomPx = 1900,
            ),
        )
    }

    @Test
    fun `树里只有补白自己时不认`() {
        assertNull(
            DayViewScrollTail.naturalContentPx(
                firstVisibleItemIndex = 0,
                totalItemsCount = 1,
                lastRealVisibleIndex = null,
                lastRealVisibleBottomPx = 0,
            ),
        )
    }

    @Test
    fun `下限就是五分之一屏`() {
        assertEquals(0.2f, DayViewScrollTail.MIN_RANGE_FRACTION, 0.0001f)
    }
}

/**
 * 接线守卫：判据算得对 ≠ 列表真的用上了（composeP1 不进 L0 编译单元，
 * 只能在源码文本上钉）。
 *
 * 钉三件事，任何一件丢了「短日补白」就等于没做：
 * 1. 列表末尾真的挂了 `DayViewScrollTail.KEY` 这一项；
 * 2. 列表量到了自己的视口高（`onSizeChanged`）——不然算式没有分母；
 * 3. 补白高度仍然来自 [DayViewScrollTail.tailHeightPx]，没人把它写死成常量。
 */
class DayViewShortListScrollWiringGuardTest {

    private val content =
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewScrollContent.kt"

    @Test
    fun `日视图列表必须挂短日补白`() {
        val source = readSource(content)
        assertTrue(
            "$content 没有挂 `DayViewScrollTail.KEY` 这一项：短日子（一节课 / 没课）" +
                "内容比视口矮，可滚范围是 0，上下滑一动不动。",
            source.contains("item(key = DayViewScrollTail.KEY)"),
        )
        assertTrue(
            "$content 没有量视口高（`onSizeChanged`）：补白算式需要「视口高 − 内容高」这个分母。",
            source.contains("onSizeChanged"),
        )
        assertTrue(
            "$content 没有调用 `DayViewScrollTail.tailHeightPx(`：" +
                "把补白写死成常量就会在长日上凭空多出一段空白。",
            source.contains("DayViewScrollTail.tailHeightPx("),
        )
    }

    /** 从工作目录向上找仓库根再定位文件；找不到仍判失败，不静默跳过。 */
    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }
}
