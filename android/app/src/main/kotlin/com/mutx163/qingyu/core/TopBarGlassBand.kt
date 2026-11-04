package com.mutx163.qingyu.core

import kotlin.math.roundToInt

/**
 * 子页顶栏渐进模糊带的**恒定高度**（2026-11-04 单档化）。
 *
 * ## 修的是什么
 *
 * 大标题 [top.yukonga.miuix.kmp.basic.TopAppBar] 的高度 = 常量高度 - `heightOffset`，
 * 而 `heightOffset` 由滚动逐帧写入（拖动与 fling 都是）。模糊层此前尺寸跟着它逐帧变：
 *
 * - `progressiveTextureBlurEffect` 的缓存键含 `paddedW/paddedH`，尺寸一变就重建
 *   RenderEffect（原生分配 + uniform 上传）；
 * - 多级合成层的 `recordLayer(size=…)` 尺寸一变就重新分配纹理；
 *
 * 于是「糊的东西一直在抖 / 闪」——不是参数跳，是结构每帧重建。
 *
 * ## 口径（单档）
 *
 * 不再离散成两档、也不随 `heightOffset` 换档：**恒取展开高度**
 * （`currentHeight - heightOffset`，两者互补抵消 = 常量）。整段滚动期模糊层的尺寸、σ、
 * 采样矩形全都不变，只有外层 `clipToBounds` 随**真实栏高**逐帧变——裁剪发生在 draw 期，
 * **不触发模糊层重建**。
 *
 * 早先（2026-11-03）用的是「展开 / 折叠两档、跨 0.5 换档」：档内虽恒定，但跨阈值那一帧
 * 高度仍会跳变、重建一次；单档化把这一帧也消掉。
 *
 * 高度取整到整数像素（[roundToInt]），避免 dp→px 的小数抖动进入缓存键。
 */
object TopBarGlassBand {

    /**
     * @param currentHeightPx 顶栏当前实测高度（px，含系统栏 inset）。
     * @param heightOffsetPx `TopAppBarState.heightOffset`（px，范围 [limit, 0]）。
     * @param heightOffsetLimitPx 保留参数：单档化后不再参与计算，仅为既有调用点签名稳定。
     * @return 模糊带高度（4px 栅格上的整数 px），整段滚动期恒定 = 展开高度。
     */
    @Suppress("UNUSED_PARAMETER")
    fun resolveBandHeightPx(
        currentHeightPx: Float,
        heightOffsetPx: Float,
        heightOffsetLimitPx: Float,
    ): Int {
        if (currentHeightPx <= 0f) return 0
        // 展开高度 = 当前高度 - 当前偏移（heightOffset 为负），两者相加是常量。
        val expandedPx = currentHeightPx - heightOffsetPx
        return quantize(expandedPx)
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
