package com.mutx163.qingyu.components.glass

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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.liquid.lens
import com.mutx163.qingyu.components.liquid.vibrancy
import com.mutx163.qingyu.core.GlassSpec
import com.mutx163.qingyu.core.GlassSpecResolver
import com.mutx163.qingyu.core.HomeMaterialRenderSpec
import com.mutx163.qingyu.core.dockGlassTuning
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.blur.BlurColors
import top.yukonga.miuix.kmp.blur.drawBackdrop
import top.yukonga.miuix.kmp.blur.blur
import top.yukonga.miuix.kmp.blur.highlight.Highlight
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.progressiveTextureBlurEffect
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import top.yukonga.miuix.kmp.blur.runtimeShaderEffect
import top.yukonga.miuix.kmp.blur.ProgressiveBlur
import top.yukonga.miuix.kmp.theme.MiuixTheme

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
 * - [progressive] = null：均匀模糊（坞 / 浮钮 / 卡片 / 顶栏这一档）；
 * - [progressive] != null：官方渐进档（顶强底清）。
 *
 * 顶栏的“渐变模糊”走 [fadeEndFraction]（`QingyuVerticalFade` 着色器，已登记为自研例外）：一次高斯模糊，
 * 用一条纵向 alpha 权重给**模糊本身**加权，顶浓底清；叠色（白纱）仍走 [onDrawSurface] 正常混合。
 *
 * ## 降级
 *
 * 调用方在设备不支持 RuntimeShader 时不应传 [backdrop]（传了也画不出），
 * 而是直接画压色 + 描边——见各调用点的统一退化分支。
 */
/**
 * 纵向权重着色器：模糊之后按 y 乘 alpha，**顶边 1.0 → `in_fadeEnd` 处 0**。
 *
 * ## 坐标方向（2026-11-08 修正，不要再翻回去）
 *
 * `coord` 的原点在图层**左上角**、`y` 向下增大（Skia / AGSL 的画布坐标）。miuix 自己的
 * `ProgressiveBlur.Top`（文档写“顶部最强、向下变清”）算出来的就是 `y = 0 满强度 → y = H 归零`
 * （`internal/BlurEffect.kt` 的 `projFull / projZero`），所以判断“顶 / 底”一律以 `y = 0` 为顶。
 *
 * 上一版按“原点在底部”写成 `1 - coord.y / in_maxY`，把权重整个**上下颠倒**：顶栏可见的那一半
 * 权重恒为 0（模糊几乎不出现，只剩白纱 → 用户实报“渐变模糊长得奇怪”），只有被裁掉的
 * 下半段才浓起来。
 *
 * ## 为什么要 `in_topY`
 *
 * 模糊层比玻璃面大一圈 `padding`（miuix 的 kernel reach），着色器看到的是**含 padding 的图层**；
 * 不减去这一段，整条渐变会比玻璃面顶边上移十几像素（归零点提前、底边残留一层模糊）。
 */
private const val QINGYU_VERTICAL_FADE_SHADER = """
uniform shader child;
uniform float in_topY;
uniform float in_maxY;
uniform float in_fadeEnd;

half4 main(float2 coord) {
    half4 c = child.eval(coord);
    // y = 0 是图层顶边（含 padding）：先减 in_topY 落到玻璃面顶边，再按面高归一化。
    float t = in_maxY > 0.0 ? clamp((coord.y - in_topY) / in_maxY, 0.0, 1.0) : 0.0;
    float w = 1.0 - clamp(t / max(in_fadeEnd, 0.0001), 0.0, 1.0);
    return c * w;
}
"""

@Composable
fun QingyuGlassSurface(
    backdrop: Backdrop,
    spec: GlassSpec,
    modifier: Modifier = Modifier,
    shape: Shape = RectangleShape,
    progressive: ProgressiveBlur? = null,
    /**
     * 可选：给**模糊结果**乘一条纵向 alpha 权重（顶 1.0 → 底 0，`y = 0` 是顶边）。
     *
     * 直接在模糊的 RenderEffect 链末端接一个小着色器（`runtimeShaderEffect`），
     * 所以它不会被框架忽略（模糊在跑，这条链一定在跑）；不做离屏层、不改层尺寸。
     * 返回“权重归零位置”（0..1，相对**玻璃面**高度，不是含 padding 的图层高度）。
     * null = 均匀模糊。
     */
    fadeEndFraction: (() -> Float)? = null,
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
                if (fadeEndFraction != null) {
                    // 纵向权重着色器：模糊之后按 y 乘 alpha（顶 1 → 底 0）。
                    // 失败（设备不支持 / 着色器编译失败）就静默退回均匀模糊，不崩。
                    val end = fadeEndFraction()
                    // 像素口径的 uniform 必须除以 downscaleFactor（着色器收到的是降采样后的
                    // 图层坐标）；padding 同理——它是 blur() 抬上来的真实像素。
                    val sf = downscaleFactor.coerceAtLeast(1).toFloat()
                    runCatching {
                        runtimeShaderEffect(
                            key = "QingyuVerticalFade",
                            shaderString = QINGYU_VERTICAL_FADE_SHADER,
                            uniformShaderName = "child",
                        ) {
                            setFloatUniform("in_topY", padding / sf)
                            setFloatUniform("in_maxY", size.height / sf)
                            setFloatUniform(
                                "in_fadeEnd",
                                (end * 0.94f).coerceIn(0.05f, 1f),
                            )
                        }
                    }
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

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-10 组件预览补齐批）：一屏档 400×900、预览名中文。
// 采样源用一层 layer backdrop（全站「页面内容合成层」的对位），只给 IDE 看玻璃面形态，
// 不进业务路径；真机由调用方按设备 shader 能力决定是否走玻璃。
// ─────────────────────────────────────────────────────────────────────────────

private val PreviewGlassSpec: GlassSpec =
    GlassSpecResolver.resolve(HomeMaterialRenderSpec().dockGlassTuning())

@Suppress("unused")
@Preview(name = "1 玻璃面", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun QingyuGlassSurfacePreview() {
    QingyuPageTheme {
        val pageBackground = Color(QingyuTheme.scaffoldBackground(false))
        val backdrop = rememberLayerBackdrop {
            drawRect(pageBackground)
            drawContent()
        }
        Box(modifier = Modifier.fillMaxSize()) {
            Column(
                modifier = Modifier
                    .matchParentSize()
                    .layerBackdrop(backdrop)
                    .padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                repeat(5) { index ->
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(88.dp)
                            .background(
                                Color(QingyuTheme.primary(dark = false)).copy(alpha = 0.15f + index * 0.06f),
                            ),
                    )
                }
            }
            QingyuGlassSurface(
                backdrop = backdrop,
                spec = PreviewGlassSpec,
                modifier = Modifier
                    .align(Alignment.Center)
                    .fillMaxWidth()
                    .padding(horizontal = 32.dp)
                    .height(160.dp),
                shape = RoundedCornerShape(24.dp),
                tintBrush = SolidColor(Color.White.copy(alpha = 0.25f)),
                highlight = GlassDockSpecular,
            ) {
                Box(modifier = Modifier.padding(16.dp)) {
                    Text(text = "玻璃面", style = MiuixTheme.textStyles.body2)
                }
            }
        }
    }
}
