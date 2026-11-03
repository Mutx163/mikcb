// Copyright 2026, compose-miuix-ui contributors
// SPDX-License-Identifier: Apache-2.0

package com.mutx163.qingyu.components.liquid

// Adapted from Kyant0/AndroidLiquidGlass — https://github.com/Kyant0/AndroidLiquidGlass (Apache 2.0).
//
// 同 [lens]：miuix 0.9.4 发布物里没有它，只在官方 demo 的 `component/animation/` 下。

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.VectorConverter
import androidx.compose.animation.core.VisibilityThreshold
import androidx.compose.animation.core.spring
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.blur.RuntimeShader
import top.yukonga.miuix.kmp.blur.asBrush
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported

/**
 * 指尖光斑：手指按在玻璃上时，按下点亮起一小团光并跟着手指走。
 *
 * 这是「玻璃」与「塑料」在触觉上的分界 —— 玻璃会把光聚在受力点上。
 * 光斑由 `BlendMode.Plus` 叠加，所以只加亮、不会盖住底下的内容。
 *
 * 松手时不是直接消失，而是**弹回按下点**再淡出（`release()` 里位置 animate 回
 * `startPosition`），读起来像"光收拢回原点"。
 *
 * @param animationScope 承载动画的协程作用域（通常来自 `rememberCoroutineScope()`）。
 * @param position 把"手指位置"映射成"光斑中心"，默认恒等。给某些形状做偏移时用。
 */
internal class InteractiveHighlight(
    private val animationScope: CoroutineScope,
    private val position: (size: Size, offset: Offset) -> Offset = { _, offset -> offset },
) {

    private val pressProgressAnimationSpec = spring(0.5f, 300f, 0.001f)
    private val positionAnimationSpec = spring(0.5f, 300f, Offset.VisibilityThreshold)

    private val pressProgressAnimation = Animatable(0f, 0.001f)
    private val positionAnimation =
        Animatable(Offset.Zero, Offset.VectorConverter, Offset.VisibilityThreshold)
    private var startPosition = Offset.Zero

    /**
     * 形变位移，独立于高光位置。
     *
     * 高光松手时弹回按下点、若形变也读它就会跟着"滑回去"；所以形变单跟一根动画，
     * 松手回弹到 0。只有需要「按着拖、整块玻璃跟手形变」的调用方会读 [offset]。
     */
    private val dragOffsetAnimation =
        Animatable(Offset.Zero, Offset.VectorConverter, Offset.VisibilityThreshold)

    /** 当前按压进度（0..1）。宿主可据此做缩放等派生动效。 */
    val pressProgress: Float get() = pressProgressAnimation.value

    /** 当前拖动位移（相对按下点），松手回弹到 [Offset.Zero]。 */
    val offset: Offset get() = dragOffsetAnimation.value

    // 平滑阶跃的光斑；不支持 runtime shader 时退化成 radialGradient 近似
    // （线性衰减而非 S 曲线，肉眼几乎看不出差别，但不能不画 —— 不画就没有光斑）。
    private val spotShader: RuntimeShader? =
        if (isRuntimeShaderSupported()) RuntimeShader(SPOT_SHADER) else null

    val modifier: Modifier = Modifier.drawWithContent {
        val progress = pressProgressAnimation.value
        if (progress > 0f) {
            // 整块均匀提亮：让"按下去"这件事在整个玻璃面上都成立，
            // 而不是只有指尖那一小圈有反应。
            drawRect(
                color = Color.White.copy(alpha = 0.06f * progress),
                blendMode = BlendMode.Plus,
            )
            val pos = position(size, positionAnimation.value)
            val radius = (size.minDimension * 1.2f).coerceAtLeast(1f)
            val center = Offset(
                x = pos.x.coerceIn(0f, size.width),
                y = pos.y.coerceIn(0f, size.height),
            )
            val spotColor = Color.White.copy(alpha = 0.12f * progress)
            if (spotShader != null) {
                spotShader.setColorUniform("color", spotColor)
                spotShader.setFloatUniform("radius", radius)
                spotShader.setFloatUniform("position", center.x, center.y)
                drawRect(
                    brush = spotShader.asBrush(),
                    blendMode = BlendMode.Plus,
                )
            } else {
                drawRect(
                    brush = Brush.radialGradient(
                        colorStops = arrayOf(
                            0.0f to spotColor,
                            0.5f to spotColor,
                            1.0f to Color.White.copy(alpha = 0f),
                        ),
                        center = center,
                        radius = radius,
                    ),
                    blendMode = BlendMode.Plus,
                )
            }
        }
        drawContent()
    }

    val gestureModifier: Modifier = Modifier.pointerInput(animationScope) {
        inspectDragGestures(
            onDragStart = { down ->
                startPosition = down.position
                animationScope.launch {
                    launch { pressProgressAnimation.animateTo(1f, pressProgressAnimationSpec) }
                    launch { positionAnimation.snapTo(startPosition) }
                    launch { dragOffsetAnimation.snapTo(Offset.Zero) }
                }
            },
            onDragEnd = { release() },
            onDragCancel = { release() },
        ) { change, _ ->
            animationScope.launch {
                positionAnimation.snapTo(change.position)
                dragOffsetAnimation.snapTo(change.position - startPosition)
            }
        }
    }

    /** 松手：光斑弹回按下点，形变回弹到零，同时淡出。 */
    private fun release() {
        animationScope.launch {
            launch { pressProgressAnimation.animateTo(0f, pressProgressAnimationSpec) }
            launch { positionAnimation.animateTo(startPosition, positionAnimationSpec) }
            launch { dragOffsetAnimation.animateTo(Offset.Zero, positionAnimationSpec) }
        }
    }
}

// 光斑着色器：半径一半以内实心，往边缘走平滑阶跃衰减（比线性更像光）。
private const val SPOT_SHADER = """
    layout(color) uniform half4 color;
    uniform float radius;
    uniform float2 position;

    half4 main(float2 coord) {
        float dist = distance(coord, position);
        float intensity = smoothstep(radius, radius * 0.5, dist);
        return color * intensity;
    }"""
