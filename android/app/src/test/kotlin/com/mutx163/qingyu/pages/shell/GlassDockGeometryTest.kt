package com.mutx163.qingyu.pages.shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 玻璃导航栏几何与动效参数的**契约测试**（2026-10-27）。
 *
 * ## 期望值从哪来
 *
 * 全部手推自 miuix 的源端口径，**不是**从 [GlassDockGeometry] 的实现里抄的：
 *
 * * 几何：`miuix_glass_navigation_bar.dart` 的 `leftOf()` / `_slot` /
 *   `miuixGlassNavigationIndicatorBounds()` / `miuixGlassNavigationDragTarget()`；
 * * 动效：`miuix_glass_motion.dart` 的 `folmeSpring`（`stiffness = (2π/response)²`）。
 *
 * 所以「实现改错了」这些用例会红；反过来「用例跟着实现改」就该被 review 拦下。
 *
 * ## 这些数为什么值得单独钉
 *
 * 用户对底栏的抱怨是「点起来不对」。拆开来就是三件事：
 * 指示器偏了半个身位（少减 5）、拖拽拉伸甩出栏外（漏钳 60px）、
 * 按下没有反馈（直接用 Material 涟漪代替了透明度）。
 * 三件都是纯算术，能在 0.2 秒内证伪，不必装机看。
 */
class GlassDockGeometryTest {

    // 400dp 宽、3 个条目：slot = (400 - 16) / 3 = 128。
    // 三个数都是整除，故意选它让手推值无小数误差。
    private val w = 400f
    private val n = 3
    private val slot = 128f

    @Test
    fun `slotWidth 两侧各留 8，不是直接除`() {
        assertEquals(slot, GlassDockGeometry.slotWidth(w, n), 1e-4f)
        // 直接 400/3 = 133.33 是错的：那样内容区会被两侧留白顶出去。
        assertEquals(false, GlassDockGeometry.slotWidth(w, n) == w / n)
        // 条目数为 0 时不能除零崩。
        assertEquals(0f, GlassDockGeometry.slotWidth(w, 0), 1e-4f)
    }

    @Test
    fun `itemLeft 从 8 起按 slot 递增`() {
        assertEquals(8f, GlassDockGeometry.itemLeft(0, w, n), 1e-4f)
        assertEquals(136f, GlassDockGeometry.itemLeft(1, w, n), 1e-4f)
        assertEquals(264f, GlassDockGeometry.itemLeft(2, w, n), 1e-4f)
    }

    @Test
    fun `itemLeft 在 RTL 下镜像`() {
        // 视觉位置从上文反过来：index 2 落到最左（8），index 0 落到最右（264）。
        assertEquals(8f, GlassDockGeometry.itemLeft(2, w, n, rtl = true), 1e-4f)
        assertEquals(264f, GlassDockGeometry.itemLeft(0, w, n, rtl = true), 1e-4f)
    }

    @Test
    fun `指示器左边界比条目再左让 5`() {
        // 关键那 5：少减它，指示器就比图标偏右半个身位（用户的「点起来不对」之一）。
        assertEquals(3f, GlassDockGeometry.indicatorLeftFor(0, w, n), 1e-4f)
        assertEquals(131f, GlassDockGeometry.indicatorLeftFor(1, w, n), 1e-4f)
        assertEquals(259f, GlassDockGeometry.indicatorLeftFor(2, w, n), 1e-4f)
        assertEquals(
            GlassDockGeometry.itemLeft(1, w, n) - 5f,
            GlassDockGeometry.indicatorLeftFor(1, w, n),
            1e-4f,
        )
    }

    @Test
    fun `指示器宽度是 slot 加两侧外扩，不是 slot`() {
        val span = GlassDockGeometry.indicatorSpanFor(1, w, n)
        assertEquals(131f, span.left, 1e-4f)
        assertEquals(269f, span.right, 1e-4f)
        // 128 + 10 = 138。写成 slot（128）会让指示器比条目窄一圈，选中态看起来「没包住」图标。
        assertEquals(slot + 10f, span.width, 1e-4f)
    }

    @Test
    fun `indicatorBounds 两端各留 3，并把过冲截回栏内`() {
        // 正常区间：原样返回。
        val normal = GlassDockGeometry.indicatorBounds(131f, 269f, w)
        assertEquals(131f, normal.left, 1e-4f)
        assertEquals(269f, normal.right, 1e-4f)

        // 弹簧过冲：左界为负 → 截到 3（不是 0，两端要留缝）。
        val overshootLeft = GlassDockGeometry.indicatorBounds(-40f, 120f, w)
        assertEquals(3f, overshootLeft.left, 1e-4f)

        // 右界过冲 → 截到 width - 3 = 397。
        val overshootRight = GlassDockGeometry.indicatorBounds(300f, 999f, w)
        assertEquals(397f, overshootRight.right, 1e-4f)

        // 区间自身反了（left > right）时，right 至少等于 left，不能出负宽度。
        val flipped = GlassDockGeometry.indicatorBounds(300f, 100f, w)
        assertTrue("宽度不能为负：$flipped", flipped.width >= 0f)
    }

    @Test
    fun `indicatorBounds 在极窄容器上不会翻转`() {
        // ## 这条用例为什么必须有具体数值（2026-10-27 咬合探针实证）
        //
        // 初版只断言「宽度不为负」。把实现里 `lo` 的上界从 `width/2` 放宽到 `width`
        // （即去掉「两端各留一半」那道钳）后，**用例照样全绿** ——
        // 宽度 4 / inset 3 时两种写法都得到 0，探针打不响，等于这条用例是摆设。
        //
        // 换成能分辨的那组输入：宽度 10、inset 8（inset 大于半宽）。
        // * 正确实现：lo = clamp(8, 0, 5) = 5，hi = max(5, 5) = 5 → 两端都在 5，
        //   指示器缩成一条竖线而不是负宽度；
        // * 缺了半宽钳：lo = 8，hi = max(8, 2) = 8 → 两端都在 8，右界跑到容器外。
        // 所以这里断言的是**具体端点**，不是「>= 0」。
        val tiny = GlassDockGeometry.indicatorBounds(-30f, 40f, 10f, inset = 8f)
        assertEquals(5f, tiny.left, 1e-4f)
        assertEquals(5f, tiny.right, 1e-4f)
        assertEquals(0f, tiny.width, 1e-4f)

        // 正中间那条也算边界：容器 10、inset 5 时两端重合在 5。
        val mid = GlassDockGeometry.indicatorBounds(-30f, 40f, 10f, inset = 5f)
        assertEquals(5f, mid.left, 1e-4f)
        assertEquals(5f, mid.right, 1e-4f)

        // 正常宽度下两端各留 inset（5、100 → 右界 95），与上面那条同一条式子。
        val normal = GlassDockGeometry.indicatorBounds(5f, 100f, 100f, inset = 5f)
        assertEquals(5f, normal.left, 1e-4f)
        assertEquals(95f, normal.right, 1e-4f)
    }

    @Test
    fun `itemAt 落在边界上归左边那个条目`() {
        // 8 是第一格起点；135.9 仍在第 0 格；136 正好是第 1 格起点 → 归 1。
        assertEquals(0, GlassDockGeometry.itemAt(8f, w, n))
        assertEquals(0, GlassDockGeometry.itemAt(135.9f, w, n))
        assertEquals(1, GlassDockGeometry.itemAt(136f, w, n))
        assertEquals(2, GlassDockGeometry.itemAt(390f, w, n))
    }

    @Test
    fun `itemAt 在栏外也钳住，不返回负数或越界`() {
        assertEquals(0, GlassDockGeometry.itemAt(-500f, w, n))
        assertEquals(n - 1, GlassDockGeometry.itemAt(9999f, w, n))
        assertEquals(0, GlassDockGeometry.itemAt(50f, w, 0))
    }

    @Test
    fun `itemAt 与 RTL 镜像互逆`() {
        // RTL 下最左那一格是最后一个条目。
        assertEquals(n - 1, GlassDockGeometry.itemAt(8f, w, n, rtl = true))
        assertEquals(0, GlassDockGeometry.itemAt(390f, w, n, rtl = true))
    }

    @Test
    fun `拖拽向右时只拉左边界，上限 60 逻辑像素`() {
        // left=131（第 1 格）、width=138、delta=10 向右、未换格。
        // trail = min(10 * 4, 60 / 1) = 40 → 左边界 131 - 40 = 91，右边界不动。
        val t = GlassDockGeometry.dragTarget(
            left = 131f,
            width = 138f,
            containerWidth = w,
            delta = 10f,
            changedItem = false,
        )
        assertEquals(91f, t.left, 1e-4f)
        assertEquals(269f, t.right, 1e-4f)
        assertTrue("跟手中：指示器应随手指一起动", t.following)
        assertTrue("向右拖：方向判据为真", t.movingRight)
    }

    @Test
    fun `拖拽向左时只拉右边界`() {
        val t = GlassDockGeometry.dragTarget(
            left = 131f,
            width = 138f,
            containerWidth = w,
            delta = -10f,
            changedItem = false,
        )
        assertEquals(131f, t.left, 1e-4f)
        assertEquals(309f, t.right, 1e-4f)
        assertFalse(t.movingRight)
    }

    @Test
    fun `换到新条目的那一帧不拉伸`() {
        // changedItem=true → trail 归零：此刻指示器该直接落位（弹簧还在跑），
        // 再叠拉伸会看起来像两层在抖。
        val t = GlassDockGeometry.dragTarget(
            left = 131f,
            width = 138f,
            containerWidth = w,
            delta = 10f,
            changedItem = true,
        )
        assertEquals(131f, t.left, 1e-4f)
        assertEquals(269f, t.right, 1e-4f)
        assertFalse("换格那一帧不算跟手", t.following)
    }

    @Test
    fun `拉伸上限按物理像素算，高 DPR 下要缩回逻辑像素`() {
        // dpr=3：cap = 60 / 3 = 20，小于 10 * 4 = 40 → trail 取 20。
        val t = GlassDockGeometry.dragTarget(
            left = 131f,
            width = 138f,
            containerWidth = w,
            delta = 10f,
            changedItem = false,
            devicePixelRatio = 3f,
        )
        assertEquals(111f, t.left, 1e-4f)
    }

    @Test
    fun `拖到栏边时左界不越界`() {
        val t = GlassDockGeometry.dragTarget(
            left = -50f,
            width = 138f,
            containerWidth = w,
            delta = 30f,
            changedItem = false,
        )
        assertEquals(0f, t.left, 1e-4f)
        assertEquals(138f, t.right, 1e-4f)
    }

    @Test
    fun `右边界贴栏时不再向右拉伸`() {
        // start = 262（400 - 138），此时 end = 400，向右拖不拉伸。
        val t = GlassDockGeometry.dragTarget(
            left = 262f,
            width = 138f,
            containerWidth = w,
            delta = 10f,
            changedItem = false,
        )
        assertEquals(262f, t.left, 1e-4f)
        assertEquals(400f, t.right, 1e-4f)
    }

    @Test
    fun `按压缩放按内收缩 10，小控件统一落 090`() {
        // (s - 10) / s >= 0.9 只在 s >= 100 时成立；底栏那颗 54dp 的药丸与 56dp 圆钮
        // 都会落到下限 0.9 —— 这是 miuix 的原口径，不是算错。
        assertEquals(0.9f, GlassDockGeometry.pressScale(56f), 1e-4f)
        assertEquals(0.9f, GlassDockGeometry.pressScale(54f), 1e-4f)
        assertEquals(0.9f, GlassDockGeometry.pressScale(80f), 1e-4f)
        // 大块才看得出差别：(200 - 10) / 200 = 0.95。
        assertEquals(0.95f, GlassDockGeometry.pressScale(200f), 1e-4f)
        // 非法输入不崩、不缩放。
        assertEquals(1f, GlassDockGeometry.pressScale(0f), 1e-4f)
        assertEquals(1f, GlassDockGeometry.pressScale(-5f), 1e-4f)
    }

    @Test
    fun `弹簧刚度按 folme 口径从响应时长推`() {
        // navIndicator: response = 0.4s → (2π / 0.4)² = 15.7079…² ≈ 246.7401
        assertEquals(
            246.74f,
            GlassDockGeometry.springStiffness(GlassDockGeometry.IndicatorSpringResponse),
            0.02f,
        )
        // navDragFollow: response = 0.15s → (2π / 0.15)² ≈ 1754.596
        assertEquals(
            1754.60f,
            GlassDockGeometry.springStiffness(GlassDockGeometry.DragSpringResponse),
            0.05f,
        )
        // response 更短 ⇒ 刚度更大（这是「跟手」比「落位」快的原因）。
        assertTrue(
            GlassDockGeometry.springStiffness(GlassDockGeometry.DragSpringResponse) >
                GlassDockGeometry.springStiffness(GlassDockGeometry.IndicatorSpringResponse),
        )
        assertEquals(0f, GlassDockGeometry.springStiffness(0f), 1e-4f)
        assertEquals(0f, GlassDockGeometry.springStiffness(-1f), 1e-4f)
    }

    @Test
    fun `大字号档按系统字体缩放切换`() {
        assertEquals(
            GlassDockGeometry.LabelSizeSp,
            GlassDockGeometry.labelSizeSp(1.0f),
            1e-4f,
        )
        // 阈值 1.6 是「含等于」的：正好 1.6 就该切大档，否则大字号用户会卡在 15.9 那档。
        assertEquals(
            GlassDockGeometry.LargeLabelSizeSp,
            GlassDockGeometry.labelSizeSp(1.6f),
            1e-4f,
        )
        assertEquals(
            GlassDockGeometry.LargeLabelSizeSp,
            GlassDockGeometry.labelSizeSp(2.0f),
            1e-4f,
        )
        assertEquals(
            GlassDockGeometry.LabelSizeSp,
            GlassDockGeometry.labelSizeSp(1.59f),
            1e-4f,
        )
    }

    @Test
    fun `三格布局正好铺满内容区`() {
        // 首格起点 8、末格终点 = 264 + 128 = 392 = 400 - 8，两边留白对等。
        val first = GlassDockGeometry.itemLeft(0, w, n)
        val lastEnd = GlassDockGeometry.itemLeft(n - 1, w, n) + GlassDockGeometry.slotWidth(w, n)
        assertEquals(first, w - lastEnd, 1e-4f)
        assertEquals(w - 2 * GlassDockGeometry.HorizontalPaddingDp, lastEnd - first, 1e-4f)
    }
}
