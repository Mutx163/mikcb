// Copyright 2026, compose-miuix-ui contributors
// SPDX-License-Identifier: Apache-2.0

package com.mutx163.qingyu.components.liquid

// Adapted from Kyant0/AndroidLiquidGlass — https://github.com/Kyant0/AndroidLiquidGlass (Apache 2.0).
//
// 同 [lens]：miuix 0.9.4 发布物里没有 `CombinedBackdrop`，只在官方 demo 里。

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.GraphicsLayerScope
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.glass.QingyuGlassSurface
import com.mutx163.qingyu.core.GlassSpec
import com.mutx163.qingyu.core.GlassSpecResolver
import com.mutx163.qingyu.core.HomeMaterialRenderSpec
import com.mutx163.qingyu.core.dockGlassTuning
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import top.yukonga.miuix.kmp.theme.MiuixTheme

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

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-10 组件预览补齐批）：一屏档 400×900、预览名中文。
// 两块采样源各录一层（页面内容 / 栏底色），合成后交给玻璃面采样——只给 IDE 看形态。
// ─────────────────────────────────────────────────────────────────────────────

private val PreviewCombinedGlassSpec: GlassSpec =
    GlassSpecResolver.resolve(HomeMaterialRenderSpec().dockGlassTuning())

@Suppress("unused")
@Preview(name = "1 双层合成采样", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun LiquidCombinedBackdropPreview() {
    QingyuPageTheme {
        val pageBackground = Color(QingyuTheme.scaffoldBackground(false))
        val pageLayer = rememberLayerBackdrop {
            drawRect(pageBackground)
            drawContent()
        }
        val tintLayer = rememberLayerBackdrop { drawContent() }
        val combined = rememberCombinedBackdrop(pageLayer, tintLayer)
        Box(modifier = Modifier.fillMaxSize()) {
            Column(
                modifier = Modifier
                    .matchParentSize()
                    .layerBackdrop(pageLayer)
                    .padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                repeat(4) { index ->
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(96.dp)
                            .background(
                                Color(QingyuTheme.primary(dark = false)).copy(alpha = 0.16f + index * 0.07f),
                            ),
                    )
                }
            }
            Box(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .height(72.dp)
                    .layerBackdrop(tintLayer)
                    .background(
                        Color(QingyuTheme.surfaceContainerHighest(false)).copy(alpha = 0.6f),
                    ),
            )
            QingyuGlassSurface(
                backdrop = combined,
                spec = PreviewCombinedGlassSpec,
                modifier = Modifier
                    .align(Alignment.Center)
                    .fillMaxWidth()
                    .padding(horizontal = 32.dp)
                    .height(140.dp),
                shape = RoundedCornerShape(24.dp),
                tintBrush = SolidColor(Color.White.copy(alpha = 0.2f)),
            ) {
                Box(modifier = Modifier.padding(16.dp)) {
                    Text(text = "双层合成采样", style = MiuixTheme.textStyles.body2)
                }
            }
        }
    }
}
