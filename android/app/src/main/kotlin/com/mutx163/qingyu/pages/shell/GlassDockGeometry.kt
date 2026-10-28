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
 * 数值一致性由 `GlassDockGeometryTest` 逐条钉住，渲染层不许在 Compose 文件里另写字面量。
 *
 * ## 但"有测试"不等于"渲染层在用这些数"（2026-10-28 审核的教训）
 *
 * 本文件里现有**两套口径**，测试都很绿，只有一套是渲染层真在用的：
 *
 * | 口径 | 入口 | 生产调用 | 谁钉着它 |
 * |---|---|---|---|
 * | demo 口径（两侧各 4dp） | `glassSlotWidthPx` / `GlassInnerHeightDp` | **是**（`GlassDockNavigationBar` 的 onSizeChanged、各层高度） | `液态档…` 那 4 条 |
 * | miuix/Flutter 旧口径（两侧 8dp + 指示器外扩 5dp） | `slotWidth` / `itemLeft` / `indicatorLeftFor` / `indicatorBounds` / `dragTarget` / … | **否**（生产引用 0，只剩测试） | 上面那 20 条 |
 *
 * 也就是说：**旧的 20 条用例改坏会红，但界面不会变**；反过来改坏渲染层的接线，
 * 这 30 条一条也不会红（L0 只编 `src/main` + `src/test`，那个 Compose 文件不在 classpath）。
 * 处置见 `.agents/audit/glass-dock-2026-10-28/REPORT.md`（建议把旧口径挪走或删掉）。
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

    // ---------------------------------------------------------------------
    // 液态玻璃（2026-10-27 第二批：对照官方 demo 的四层结构补齐）
    //
    // 下面这一组数值全部取自官方 demo 的 `component/liquid/LiquidGlassNavigationBar.kt`
    // 与 `component/liquid/Lens.kt`。demo 是 vendored 只读副本
    // （`docs/reference/miuix-demo/`），不能直接引用，所以数值在这里登记一次，
    // 渲染层只从本对象取 —— 与上面那组「miuix GlassNavigationBarDefaults」同一条纪律。
    // ---------------------------------------------------------------------

    /**
     * 按下时**指示器**放大的倍数（demo 是 `78f / 56f` ≈ 1.39）。
     *
     * ⚠️ 注意方向与 [PressedContentAlpha] / [pressScale] **相反**：
     * 内容是「压暗 + 缩小」（miuix 口径），指示器是「放大」（iOS 液态玻璃口径）。
     * 两者同时发生才成立：手指按住时，玻璃里那块高亮被"挤"得更大，
     * 而玻璃上的字变小变暗 —— 这正是 demo 的观感，别统一成同一个方向。
     */
    const val IndicatorPressGrowScale: Float = 78f / 56f

    /** 玻璃外壳的折射带宽度（dp）。demo 取 24dp。 */
    const val RefractionHeightDp: Float = 24f

    /** 玻璃外壳的折射位移量（dp）。demo 取 24dp，与带宽度相等。 */
    const val RefractionAmountDp: Float = 24f

    /**
     * 玻璃外壳的模糊半径（dp）。**注意与降级档的 20dp 不是一回事**：
     *
     * * 液态档：4dp —— 因为已经有 [RefractionHeightDp] 的折射在塑形，
     *   模糊只需抹掉噪点。糊太狠会把折射出来的边缘细节吃掉，玻璃反而"平"了；
     * * 降级档（无采样源）：20dp —— 没有折射，只能靠模糊表达"这是玻璃"。
     */
    const val GlassBlurRadiusDp: Float = 4f

    /**
     * 采样层的额外留白（dp）：要覆盖「折射带 24dp」与「按压放大 16dp」两者的伸出量。
     *
     * 不加够会出现边缘一圈没采样到的透明/黑边（`lens()` 会自己把 padding 抬到
     * 至少 refractionAmount，但按压放大是 `layerBlock` 干的，它不抬 padding）。
     */
    const val SamplingPaddingReachDp: Float = 40f

    /** 指示器镜片的折射带宽度（dp）。比外壳小：它只在按下时才显形。 */
    const val IndicatorRefractionHeightDp: Float = 10f

    /** 指示器镜片的折射位移量（dp）。 */
    const val IndicatorRefractionAmountDp: Float = 14f

    /**
     * 指示器镜片的色散强度。
     *
     * `0.5` 是 demo 的取值，比文档建议的「Apple 药丸 0.2」更高 —— 因为指示器只在
     * 按下时可见（乘了 `pressProgress`），强一点才在短暂的那一下里读得出来。
     */
    const val IndicatorDispersion: Float = 0.5f

    /** 指示器内阴影的半径（dp）。同样乘按压进度，静止时为 0。 */
    const val IndicatorInnerShadowRadiusDp: Float = 8f

    /** 玻璃内容区四周的内边距（dp）。demo 取 4dp。 */
    const val GlassContentPaddingDp: Float = 4f

    /** 条目内部图标与文字之间的间距（dp）。 */
    const val IconLabelGapDp: Float = 1f

    /** 条目图标边长（dp）。液态档比 miuix 的 28 略小，因为栏内多了 4dp 内边距。 */
    const val GlassIconSizeDp: Float = 22f

    /**
     * 液态档内容区的高度：药丸高度减掉上下两条 [GlassContentPaddingDp]。
     *
     * demo 是 `64.dp` 的药丸 + `56.dp` 的指示器/折射副本；本仓药丸是 [HeightDp]（54），
     * 对应 46。**指示器不能直接用 [HeightDp]**：那样它与玻璃上下边齐平，四周没有留量，
     * 一放大就从边缘探出去（用户口径：「右边还超出了一点点背景」）。
     */
    const val GlassInnerHeightDp: Float = HeightDp - 2f * GlassContentPaddingDp

    // ---------------------------------------------------------------------
    // 液态档的槽位与指示器（2026-10-28 修正：照 demo 的算式，与上面那组旧口径无关）
    //
    // 上面 `slotWidth` / `itemLeft` / `indicatorLeftFor` 那一组是 **miuix/Flutter 旧口径**
    // （两侧各 [HorizontalPaddingDp]=8dp、指示器再外扩 [IndicatorOverhangDp]=5dp）。
    // 液态档照 demo 重写后，渲染层已**不再使用**那一组；它保留下来是因为
    // `GlassDockGeometryTest` 还钉着它、且迁移期还要拿它跟 Flutter 侧对拍。
    // **不要照旧口径写新代码**，液态档一律走下面这组 `glass*` 函数。
    //
    // 两套口径差在哪：旧口径槽宽 = (W - 16)/n，demo 口径 = (W - 8)/n。
    // 差 8/n dp/格 —— 渲染层如果用了 demo 的 4dp 内边距、却按"只减一侧"算槽宽
    // （`W - 4`），每格就偏大 4/n dp，末格右边界会正好压在玻璃右缘上（余量 0），
    // 首格却还留着 4dp：两端不对等，按下放大立刻从右端顶出去。
    // ---------------------------------------------------------------------

    /**
     * 液态档单个条目的宽度（**像素**）：`(栏宽 - 2 × 内容内边距) / 条目数`。
     *
     * @param containerWidthPx 药丸整宽（px）。**是药丸自身的宽度**，不是外面那层容器的宽度
     *   —— 两者相差两倍内边距，混用会让格子整体右偏、末格探出玻璃。
     * @param paddingPx 单侧内容内边距（px），取 [GlassContentPaddingDp] 的 px 值。
     */
    fun glassSlotWidthPx(containerWidthPx: Float, itemCount: Int, paddingPx: Float): Float {
        if (itemCount <= 0) return 0f
        return max(0f, containerWidthPx - paddingPx * 2f) / itemCount
    }

    /**
     * 液态档第 [index] 个条目/指示器的左边界（**像素**）：`padding + index × 槽宽`。
     *
     * ⚠️ 渲染层**不直接调用**它：指示器的水平基址由 Compose 的
     * `.padding(horizontal = GlassContentPaddingDp)` 结构给出，步进由
     * `translationX = dampedDrag.value * tabWidthPx` 给出。这两个值（以及下面的
     * [glassIndicatorSpan]）存在的意义是把「首格左边 4dp、末格右边 4dp」这条手推契约
     * 写成**可执行断言**（`GlassDockGeometryTest` 的 `液态档…` 那组）。
     *
     * 也因此：它**拦不住**「渲染层把 `.padding(horizontal)` 改成 `.padding(start)`」
     * 这类接线错误 —— 那类改动只有源码守卫或真机看得到（见
     * `.agents/audit/glass-dock-2026-10-28/REPORT.md` 的 C4）。
     */
    fun glassIndicatorLeftPx(
        index: Int,
        containerWidthPx: Float,
        itemCount: Int,
        paddingPx: Float,
    ): Float = paddingPx + index * glassSlotWidthPx(containerWidthPx, itemCount, paddingPx)

    /** [glassSlotWidthPx] 的 dp 版（内边距取 [GlassContentPaddingDp]），给单测与手推用。 */
    fun glassSlotWidth(containerWidthDp: Float, itemCount: Int): Float =
        glassSlotWidthPx(containerWidthDp, itemCount, GlassContentPaddingDp)

    /** [glassIndicatorLeftPx] 的 dp 版。 */
    fun glassIndicatorLeft(index: Int, containerWidthDp: Float, itemCount: Int): Float =
        glassIndicatorLeftPx(index, containerWidthDp, itemCount, GlassContentPaddingDp)

    /**
     * 液态档指示器的区间（dp 版）。
     *
     * 不变式：`第 0 格 left == GlassContentPaddingDp`、
     * `第 n-1 格 right == containerWidth - GlassContentPaddingDp` —— 两端各留 4dp，
     * 首末对等。少减一侧内边距时，末格 right 会变成 `containerWidth`（探出玻璃）。
     */
    fun glassIndicatorSpan(index: Int, containerWidthDp: Float, itemCount: Int): Bounds {
        val left = glassIndicatorLeft(index, containerWidthDp, itemCount)
        return Bounds(left, left + glassSlotWidth(containerWidthDp, itemCount))
    }

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
     * 单个条目的占位宽度（**旧 miuix/Flutter 口径**，两侧各 [HorizontalPaddingDp]=8dp）。
     *
     * 不是简单的 `containerWidth / count`：两侧各留 [HorizontalPaddingDp]，
     * 内容区才排得下。少减这 16，条目会整体往外顶、最后一个被裁掉。
     *
     * ⚠️ 液态档（demo 口径）**不用这个**，用 [glassSlotWidthPx]（两侧各 4dp）。
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
