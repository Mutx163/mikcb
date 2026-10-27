// Copyright 2026, compose-miuix-ui contributors
// SPDX-License-Identifier: Apache-2.0

package com.mutx163.qingyu.components.liquid

// Adapted from Kyant0/AndroidLiquidGlass — https://github.com/Kyant0/AndroidLiquidGlass (Apache 2.0).
//
// 同 [lens]：miuix 0.9.4 发布物里没有 `CombinedBackdrop`，只在官方 demo 里。

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.GraphicsLayerScope
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.unit.Density
import top.yukonga.miuix.kmp.blur.Backdrop

/**
 * 把两个 [Backdrop] 按顺序叠成一个采样源：先画 [first]，再画 [second]。
 *
 * ## 用途（为什么不能只用一个）
 *
 * 液态玻璃的**滑动指示器**要同时采到两样东西：
 *
 * 1. 底下的页面内容（`first` = 页面的 layer backdrop）；
 * 2. 玻璃栏自己那层半透明底色与图标（`second` = 把同一份 tabs 内容录进来的
 *    "tinted tabs" 图层）。
 *
 * 只采 ①，指示器滑过时看不到栏本身的底，颜色会比周围亮一块；
 * 只采 ②，指示器里没有背景，等于一块纯色药丸。
 *
 * 叠成**一个** backdrop 之后，指示器只需要一次 `drawBackdrop` + 一次 `lens()`，
 * 折射对两层的效果是连续的 —— 分两次画会在交界处出现一条缝。
 */
@Stable
class CombinedBackdrop(
    val first: Backdrop,
    val second: Backdrop,
) : Backdrop {

    override val isCoordinatesDependent: Boolean =
        first.isCoordinatesDependent || second.isCoordinatesDependent

    override val offsetResidualX: Float get() = first.offsetResidualX
    override val offsetResidualY: Float get() = first.offsetResidualY

    override fun DrawScope.drawBackdrop(
        density: Density,
        coordinates: LayoutCoordinates?,
        layerBlock: (GraphicsLayerScope.() -> Unit)?,
        downscaleFactor: Int,
    ) {
        with(first) { drawBackdrop(density, coordinates, layerBlock, downscaleFactor) }
        with(second) { drawBackdrop(density, coordinates, layerBlock, downscaleFactor) }
    }
}

/** 记住一个 [CombinedBackdrop]；两个输入不变时不重建。 */
@Composable
fun rememberCombinedBackdrop(first: Backdrop, second: Backdrop): Backdrop =
    remember(first, second) { CombinedBackdrop(first, second) }
