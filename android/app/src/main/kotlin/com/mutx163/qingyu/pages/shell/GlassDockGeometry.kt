package com.mutx163.qingyu.pages.shell

import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow

/**
 * 底部玻璃导航栏（药丸）的几何与动效参数——**纯算术，不含任何 Compose 依赖**。
 *
 * ## 这份数从哪来（可复算，别自己编）
 *
 * 全部取自 miuix 的 `GlassNavigationBarDefaults` / `GlassMotion` / `GlassPress`。
 * 本仓没有 Kotlin 侧的玻璃导航栏可用（miuix 0.9.4 的 `NavigationBar` 是纯色
 * `squircleBackground(color = surface)`，`Glass` 一族只在 Flutter 的移植里），所以
 * 渲染层是按**同一套数值**重写的，参数不能各写一份：
 *
 * * Flutter 移植：`flutter_miuix` 1.2.0 `lib/src/theme/miuix/components/miuix_glass_navigation_bar.dart`
 *   与 `lib/src/theme/miuix/glass/{miuix_glass_motion,miuix_glass_navigation_geometry}.dart`
 * * 上游：`compose-miuix-ui/miuix` 的 `GlassNavigationBar.kt` / `NavigationDragTarget.kt`
 *
 * 数值一致性由 `GlassDockGeometryTest` 逐条钉住（那份测试是唯一的定义处，
 * 渲染层只允许从这里取数，不许在 Compose 文件里另写字面量）。
 *
 * ## 为什么几何必须抽出来单独测
 *
 * 「点击效果不对」这类抱怨，绝大多数不是配色问题，而是**指示器算错了位置**：
 * 少减那 5、少加那 10，选中态就会比图标偏左半个身位；拖拽拉伸没钳在 60px，
 * 快速滑动时药丸会甩出栏外。这些都是纯算术，能在 0.2 秒内证伪，
 * 不需要装机看。
 */
object GlassDockGeometry {

    /** 药丸高度。md3 底部导航普遍 80，这里 54 是 miuix 的紧凑档。 */
    const val HeightDp: Float = 54f

    /** 图标边长。 */
    const val IconSizeDp: Float = 28f

    /** 标签字号。 */
    const val LabelSizeSp: Float = 11f

    /** 大字号档（系统字体放大 ≥1.6 倍时切到这一档，与 miuix 同判据）。 */
    const val LargeLabelSizeSp: Float = 16f

    /** 系统字体缩放到这个倍数及以上时用大标签。 */
    const val LargeLabelScaleThreshold: Float = 1.6f

    /** 药丸左右内边距（内容区因此是 `containerWidth - 2 * 8`）。 */
    const val HorizontalPaddingDp: Float = 8f

    /** 单个条目内部的上下留白。 */
    const val ContentVerticalPaddingDp: Float = 6f

    /** 指示器相对药丸上下边各缩进多少。 */
    const val IndicatorPaddingVerticalDp: Float = 3f

    /**
     * 指示器比条目宽出来的量（左右各一半）。
     *
     * 条目宽度是 `slot`，指示器是 `slot + 2 * overhang = slot + 10`；
     * 它的左边界因此是 `itemLeft - overhang`，这一点在 [indicatorLeftFor] 里也成立。
     */
    const val IndicatorOverhangDp: Float = 5f

    /** 按下时内容的透明度。miuix 用它代替 Material 的涟漪——**没有 ripple**。 */
    const val PressedContentAlpha: Float = 0.6f

    /** 拖拽跟手时圆角拉伸的上限（**物理像素**，所以要除 devicePixelRatio）。 */
    const val MaxDragStretchPx: Float = 60f

    /** 跟手拉伸系数：位移的 4 倍，再钳到上限。 */
    const val DragStretchFactor: Float = 4f

    /** 按压缩放的下限（`pressScale` 的钳位）。 */
    const val PressScaleMin: Float = 0.9f

    /** 按压缩放的「收进去」量。 */
    const val PressInsetDp: Float = 10f

    /** 选中态内容（图标/文字）切换时长。 */
    const val ContentSwitchDurationMs: Int = 150

    /** 指示器滑动弹簧：阻尼比（miuix `navIndicator = springOf(.7, .4)`）。 */
    const val IndicatorSpringDamping: Float = 0.7f

    /** 指示器滑动弹簧：响应时长（秒）。刚度由 [springStiffness] 推出。 */
    const val IndicatorSpringResponse: Float = 0.4f

    /** 拖拽跟手弹簧：阻尼比（`navDragFollow = springOf(1, .15)`）。 */
    const val DragSpringDamping: Float = 1f

    /** 拖拽跟手弹簧：响应时长（秒）。 */
    const val DragSpringResponse: Float = 0.15f

    /** 一段区间。用 data class 是为了让测试能整体比对，不必逐字段。 */
    data class Bounds(val left: Float, val right: Float) {
        val width: Float get() = right - left
        fun contains(x: Float): Boolean = x >= left && x <= right
        override fun toString(): String = "Bounds($left..$right)"
    }

    /** 一次拖拽的目标区间 + 两个判据（是否跟手、移动方向）。 */
    data class DragTarget(
        val left: Float,
        val right: Float,
        val following: Boolean,
        val movingRight: Boolean,
    )

    /**
     * 单个条目的占位宽度。
     *
     * 不是简单的 `containerWidth / count`：两侧各留 [HorizontalPaddingDp]，
     * 内容区才排得下。少减这 16，条目会整体往外顶、最后一个被裁掉。
     */
    fun slotWidth(containerWidth: Float, itemCount: Int): Float {
        if (itemCount <= 0) return 0f
        return max(0f, containerWidth - HorizontalPaddingDp * 2f) / itemCount
    }

    /**
     * 第 [index] 个条目内容区的左边界（**不含**指示器外扩）。
     *
     * `8 + index * slot`。右侧语言由 [rtl] 决定镜像。
     */
    fun itemLeft(index: Int, containerWidth: Float, itemCount: Int, rtl: Boolean = false): Float {
        if (itemCount <= 0) return HorizontalPaddingDp
        val slot = slotWidth(containerWidth, itemCount)
        val visual = if (rtl) itemCount - 1 - index else index
        return HorizontalPaddingDp + visual * slot
    }

    /**
     * 指示器（那颗会滑动的高亮药丸）的左边界：条目左边界再向左让出 [IndicatorOverhangDp]。
     *
     * 这是「少减 5 就偏左半个身位」的那一处，单独留一个具名函数，
     * 免得渲染层又把它内联成 `itemLeft - 5`。
     */
    fun indicatorLeftFor(
        index: Int,
        containerWidth: Float,
        itemCount: Int,
        rtl: Boolean = false,
    ): Float = itemLeft(index, containerWidth, itemCount, rtl) - IndicatorOverhangDp

    /**
     * 指示器区间：左边界 + 条目宽 + 两侧外扩。
     *
     * 注意是 `slot + 2 * overhang`（= slot + 10），不是 `slot`。
     */
    fun indicatorSpanFor(
        index: Int,
        containerWidth: Float,
        itemCount: Int,
        rtl: Boolean = false,
    ): Bounds {
        val left = indicatorLeftFor(index, containerWidth, itemCount, rtl)
        return Bounds(left, left + slotWidth(containerWidth, itemCount) + IndicatorOverhangDp * 2f)
    }

    /**
     * 把指示器区间**限制在绘制范围内**（不截断弹簧速度，只截断画出来的宽度）。
     *
     * miuix 的口径：`min = inset.clamp(0, width / 2)`，两端各留 [inset]，重叠时取中点。
     * 为什么要钳：弹簧在快速滑动时允许过冲到栏外，直接画会在圆角处漏出一条。
     */
    fun indicatorBounds(
        left: Float,
        right: Float,
        containerWidth: Float,
        inset: Float = IndicatorPaddingVerticalDp,
    ): Bounds {
        val lo = inset.coerceIn(0f, max(0f, containerWidth) / 2f)
        val hi = max(lo, containerWidth - lo)
        val start = left.coerceIn(lo, hi)
        return Bounds(start, right.coerceIn(start, hi))
    }

    /**
     * 屏幕 x 落在第几个条目上。
     *
     * 判据与 [itemLeft] 互逆；`0..count-1` 钳住（手指划出栏外时仍给最近那个）。
     */
    fun itemAt(x: Float, containerWidth: Float, itemCount: Int, rtl: Boolean = false): Int {
        if (itemCount <= 0) return 0
        val slot = slotWidth(containerWidth, itemCount)
        if (slot <= 0f) return 0
        val raw = floor((x - HorizontalPaddingDp) / slot).toInt().coerceIn(0, itemCount - 1)
        return if (rtl) itemCount - 1 - raw else raw
    }

    /**
     * 拖拽中的指示器目标：跟手时左右各拉伸一点，做出「圆角被拽住」的粘连感。
     *
     * ## 为什么 `following` 与「拉伸」互斥
     *
     * 跨到新条目那一刻 `changedItem = true`，`trail` 归零——因为此时指示器应该
     * **直接落位**（还有弹簧在跑），再叠加拉伸会看起来像两层在抖。
     *
     * ## 为什么末端要多夹一次（与上游不同，故意的）
     *
     * 上游只判「另一头有没有撞到边」，**没管拉伸出去的那一头**：
     * 指示器本来就贴在栏首（start = 0）时往右拖，左边界会变成 `0 - 60 = -60`，
     * 药丸左边就漏出一块尖角压在圆角外面。这里对拉伸后的两端各再夹一次
     * `[0, containerWidth]`；上游那条判据保留（它管「该不该拉」，夹紧管「拉到哪儿为止」）。
     *
     * @param left 未经钳制的候选左边界。
     * @param width 指示器宽度（`slot + 2 * overhang`）。
     * @param delta 本次指针位移（正 = 向右）。
     * @param changedItem 这一帧是否刚换到新条目。
     * @param devicePixelRatio 拉伸上限按**物理像素**给，所以要除回逻辑像素。
     */
    fun dragTarget(
        left: Float,
        width: Float,
        containerWidth: Float,
        delta: Float,
        changedItem: Boolean,
        devicePixelRatio: Float = 1f,
    ): DragTarget {
        val maxStart = max(0f, containerWidth - width)
        val start = left.coerceIn(0f, maxStart)
        val end = start + width
        val trail = if (changedItem) {
            0f
        } else {
            val cap = if (devicePixelRatio > 0f) MaxDragStretchPx / devicePixelRatio else MaxDragStretchPx
            min(abs(delta) * DragStretchFactor, cap)
        }
        val stretchedLeft = if (delta > 0f && end < containerWidth) start - trail else start
        val stretchedRight = if (delta < 0f && start > 0f) end + trail else end
        val limit = max(0f, containerWidth)
        return DragTarget(
            left = stretchedLeft.coerceIn(0f, limit),
            right = stretchedRight.coerceIn(0f, limit),
            following = !changedItem,
            movingRight = delta > 0f,
        )
    }

    /**
     * 按压缩放比：把一个边长 [shorterSideDp] 的块向内收 [PressInsetDp]，不低于 [PressScaleMin]。
     *
     * 为什么不是固定 0.96：块越小，同样的内收量占比越大；固定比例会让小图标
     * 「几乎不动」、大圆钮「抖一大下」。
     */
    fun pressScale(shorterSideDp: Float): Float {
        if (shorterSideDp <= 0f) return 1f
        return max((shorterSideDp - PressInsetDp) / shorterSideDp, PressScaleMin)
    }

    /**
     * folme 弹簧刚度：`stiffness = (2π / response)²`，mass 恒为 1。
     *
     * 这是 miuix 动效那套「用响应时长而不是刚度」的口径；Compose 的
     * `spring()` 直接收 stiffness + dampingRatio，所以在这里换算，
     * 渲染层不再各转一次。
     */
    fun springStiffness(responseSeconds: Float): Float {
        if (responseSeconds <= 0f) return 0f
        val omega = 2f * kotlin.math.PI.toFloat() / responseSeconds
        return omega.pow(2)
    }

    /** 系统字体放大后该用哪一档标签字号。 */
    fun labelSizeSp(fontScale: Float): Float =
        if (fontScale >= LargeLabelScaleThreshold) LargeLabelSizeSp else LabelSizeSp
}
