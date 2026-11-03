package com.mutx163.qingyu.components.glass

import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.liquid.lens
import com.mutx163.qingyu.components.liquid.vibrancy
import com.mutx163.qingyu.core.GlassSpec
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.blur.BlurColors
import top.yukonga.miuix.kmp.blur.drawBackdrop
import top.yukonga.miuix.kmp.blur.blur
import top.yukonga.miuix.kmp.blur.highlight.Highlight
import top.yukonga.miuix.kmp.blur.progressiveTextureBlurEffect
import top.yukonga.miuix.kmp.blur.ProgressiveBlur

/**
 * 全站玻璃面的**唯一渲染实现**（2026-11-03）。
 *
 * ## 规矩
 *
 * 除本文件外，任何页面 / 组件都不得直接调用 `drawBackdrop`、`blur`、`lens`、
 * `vibrancy`、`progressiveTextureBlurEffect`。调用方只给：
 *
 * 1. [spec]：口径唯一来源（`GlassSpecResolver.resolve` 的产物）；
 * 2. [backdrop]：采样源（全站统一为「页面内容合成层」）；
 * 3. 形状与几何（形状差异属几何，不是配方）。
 *
 * 这样「同一份参数 ⇒ 同一效果」才有落地点：参数只在 [spec] 里被解释一次。
 *
 * ## 两种模式
 *
 * - [progressive] = null：均匀模糊（坞 / 浮钮 / 卡片这一档）；
 * - [progressive] != null：官方渐进档（子页顶栏带），顶强底清。
 *
 * ## 降级
 *
 * 调用方在设备不支持 RuntimeShader 时不应传 [backdrop]（传了也画不出），
 * 而是直接画压色 + 描边——见各调用点的统一退化分支。
 */
@Composable
fun QingyuGlassSurface(
    backdrop: Backdrop,
    spec: GlassSpec,
    modifier: Modifier = Modifier,
    shape: Shape = RectangleShape,
    progressive: ProgressiveBlur? = null,
    tintBrush: Brush? = null,
    highlight: Highlight? = null,
    onDrawSurface: (DrawScope.() -> Unit)? = null,
    content: @Composable () -> Unit = {},
) {
    val density = LocalDensity.current
    val blurRadiusPx = with(density) { spec.blurSigmaDp.dp.toPx() }
    val refractionBandPx = with(density) { spec.refractionBandDp.dp.toPx() }
    val refractionAmountPx = with(density) { spec.refractionAmountDp.dp.toPx() }
    Box(
        modifier = modifier.drawBackdrop(
            backdrop = backdrop,
            shape = { shape },
            effects = {
                if (spec.blurSigmaDp > 0f) {
                    if (progressive != null) {
                        // 渐进档用 miuix 自带的 colorControls 通道表达鲜活度（1 = 原样）。
                        progressiveTextureBlurEffect(
                            blurRadiusX = spec.blurSigmaDp,
                            gradient = progressive,
                            colors = BlurColors(saturation = spec.vibrancy),
                        )
                    } else {
                        blur(blurRadiusPx)
                        if (spec.vibrancy > 1f) vibrancy(spec.vibrancy)
                    }
                }
                if (refractionBandPx > 0f && refractionAmountPx > 0f) {
                    lens(
                        refractionHeight = refractionBandPx,
                        refractionAmount = refractionAmountPx,
                        chromaticAberration = spec.dispersion,
                    )
                }
            },
            highlight = if (highlight != null) {
                { highlight }
            } else {
                null
            },
            onDrawSurface = when {
                tintBrush != null -> {
                    { drawRect(tintBrush) }
                }
                onDrawSurface != null -> onDrawSurface
                else -> null
            },
            progressiveGradient = progressive,
        ),
    ) {
        content()
    }
}
