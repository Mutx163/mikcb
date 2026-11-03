package com.mutx163.qingyu.core

import kotlin.math.roundToInt

/**
 * 子页顶栏渐进模糊带的**离散高度**（2026-11-03）。
 *
 * ## 修的是什么
 *
 * 大标题 [top.yukonga.miuix.kmp.basic.TopAppBar] 的高度 = 常量高度 - `heightOffset`，
 * 而 `heightOffset` 由滚动逐帧写入（拖动与 fling 都是）。模糊层此前用
 * `matchParentSize()`，尺寸跟着它逐帧变：
 *
 * - `progressiveTextureBlurEffect` 的缓存键含 `paddedW/paddedH`，尺寸一变就重建
 *   RenderEffect（原生分配 + uniform 上传）；
 * - 多级合成层的 `recordLayer(size=…)` 尺寸一变就重新分配纹理；
 *
 * 于是「糊的东西一直在抖」——不是参数跳，是结构每帧重建。
 *
 * ## 口径
 *
 * 把连续高度离散成**两档**（展开 / 折叠），档内高度恒定，跨 0.5 才换档。
 * 于是静止与滚动期间 spec、采样矩形、层尺寸全部不变，只有 backdrop 内容在动。
 * 跨档那一帧高度跳变发生在 ramp 底端（接近透明），读不出来。
 *
 * 高度取整到整数像素（[roundToInt]），避免 dp→px 的小数抖动进入缓存键。
 */
object TopBarGlassBand {

    /** 展开/折叠的切换阈值（折叠比例）。 */
    const val CollapseThreshold = 0.5f

    /**
     * @param currentHeightPx 顶栏当前实测高度（px，含系统栏 inset）。
     * @param heightOffsetPx `TopAppBarState.heightOffset`（px，范围 [limit, 0]）。
     * @param heightOffsetLimitPx `TopAppBarState.heightOffsetLimit`（px，非正；0 = 不折叠）。
     * @return 模糊带高度（4px 栅格上的整数 px），档内恒定。
     */
    fun resolveBandHeightPx(
        currentHeightPx: Float,
        heightOffsetPx: Float,
        heightOffsetLimitPx: Float,
    ): Int {
        if (currentHeightPx <= 0f) return 0
        // 展开高度 = 当前高度 - 当前偏移（heightOffset 为负），两者相加是常量。
        val expandedPx = currentHeightPx - heightOffsetPx
        if (heightOffsetLimitPx >= 0f) {
            // 小标题档 / 不折叠：只有一档。
            return quantize(expandedPx)
        }
        val collapsedPx = expandedPx + heightOffsetLimitPx
        val fraction = (heightOffsetPx / heightOffsetLimitPx).coerceIn(0f, 1f)
        val target = if (fraction >= CollapseThreshold) collapsedPx else expandedPx
        return quantize(target)
    }

    /**
     * 量化到 [GridPx] 栅格：布局整数 px 与滚动 float 偏移之间可能有 ±1px 的互补误差，
     * 直接 round 会让结果在相邻整数间来回跳，进而让模糊层每帧重建。
     */
    private fun quantize(px: Float): Int {
        val grid = (px / GridPx).roundToInt() * GridPx
        return grid.coerceAtLeast(GridPx)
    }

    private const val GridPx = 4
}
