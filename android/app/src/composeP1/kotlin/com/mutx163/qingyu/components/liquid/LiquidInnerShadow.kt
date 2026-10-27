// Copyright 2026, compose-miuix-ui contributors
// SPDX-License-Identifier: Apache-2.0

package com.mutx163.qingyu.components.liquid

// Adapted from Kyant0/AndroidLiquidGlass — https://github.com/Kyant0/AndroidLiquidGlass (Apache 2.0).
//
// 同 [lens]：miuix 0.9.4 发布物里没有 `innerShadow`，只在官方 demo 里。

import androidx.compose.runtime.Immutable
import androidx.compose.runtime.Stable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.BlurEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Paint
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.drawOutline
import androidx.compose.ui.graphics.drawscope.ContentDrawScope
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.layer.CompositingStrategy
import androidx.compose.ui.graphics.layer.GraphicsLayer
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.node.DrawModifierNode
import androidx.compose.ui.node.ModifierNodeElement
import androidx.compose.ui.node.invalidateDraw
import androidx.compose.ui.node.requireGraphicsContext
import androidx.compose.ui.platform.InspectorInfo
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp

/**
 * 玻璃的**内阴影**：从内侧边缘往里压一圈暗色，做出「这块玻璃有厚度」的感觉。
 *
 * 与普通阴影的区别：普通 `shadow` 画在形状**外面**（投影到背景上），
 * 内阴影画在形状**里面**（边缘往里收）。玻璃是透明介质，光从边缘进入时会在
 * 内壁衰减 —— 没有这一层，玻璃就是一个纯平的色块。
 */
@Immutable
data class InnerShadow(
    val radius: Dp = 24.dp,
    val offset: DpOffset = DpOffset(0.dp, radius),
    val color: Color = Color.Black.copy(alpha = 0.15f),
    val alpha: Float = 1f,
    val blendMode: BlendMode = DrawScope.DefaultBlendMode,
) {
    companion object {
        @Stable
        val Default: InnerShadow = InnerShadow()
    }
}

/**
 * 给任意形状加内阴影。
 *
 * 实现是「离屏图层 + Clear 混合挖洞 + 模糊」：先按形状画一层实心色，再用
 * `BlendMode.Clear` 把**平移过的同一形状**挖掉，剩下的环形边缘模糊后贴回形状内。
 *
 * @param shape 轮廓形状。内阴影严格裁剪在这个形状内。
 * @param shadow 每帧求值（返回 `null` 表示这一帧不画）。用 lambda 是为了让
 *   按压进度驱动的内阴影能逐帧变而不必重建 Modifier。
 */
fun Modifier.innerShadow(
    shape: Shape,
    shadow: () -> InnerShadow?,
): Modifier = this then InnerShadowElement(shape, shadow)

private class InnerShadowElement(
    val shape: Shape,
    val shadow: () -> InnerShadow?,
) : ModifierNodeElement<InnerShadowNode>() {

    override fun create(): InnerShadowNode = InnerShadowNode(shape, shadow)

    override fun update(node: InnerShadowNode) {
        node.shape = shape
        node.shadow = shadow
        node.invalidateDraw()
    }

    override fun InspectorInfo.inspectableProperties() {
        name = "innerShadow"
        properties["shape"] = shape
        properties["shadow"] = shadow
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is InnerShadowElement) return false
        if (shape != other.shape) return false
        if (shadow != other.shadow) return false
        return true
    }

    override fun hashCode(): Int {
        var result = shape.hashCode()
        result = 31 * result + shadow.hashCode()
        return result
    }
}

private class InnerShadowNode(
    var shape: Shape,
    var shadow: () -> InnerShadow?,
) : Modifier.Node(),
    DrawModifierNode {

    override val shouldAutoInvalidate: Boolean = false

    private var shadowLayer: GraphicsLayer? = null
    private val paint = Paint()
    private val clipPath = Path()
    private var prevRadius = Float.NaN

    override fun ContentDrawScope.draw() {
        drawContent()

        val shadow = shadow() ?: return
        val layer = shadowLayer ?: return

        val radius = shadow.radius.toPx()
        val offsetX = shadow.offset.x.toPx()
        val offsetY = shadow.offset.y.toPx()

        val outline = shape.createOutline(size, layoutDirection, this)
        clipPath.reset()
        when (outline) {
            is Outline.Rectangle -> clipPath.addRect(outline.rect)
            is Outline.Rounded -> clipPath.addRoundRect(outline.roundRect)
            is Outline.Generic -> clipPath.addPath(outline.path)
        }

        paint.color = shadow.color
        layer.alpha = shadow.alpha
        layer.blendMode = shadow.blendMode
        if (prevRadius != radius) {
            layer.renderEffect = if (radius > 0f) BlurEffect(radius, radius, TileMode.Decal) else null
            prevRadius = radius
        }

        layer.record {
            drawContext.canvas.let { canvas ->
                canvas.save()
                canvas.clipPath(clipPath)
                canvas.drawOutline(outline, paint)
                canvas.translate(offsetX, offsetY)
                canvas.drawOutline(outline, ShadowMaskPaint)
                canvas.translate(-offsetX, -offsetY)
                canvas.restore()
            }
        }

        drawContext.canvas.let { canvas ->
            canvas.save()
            canvas.clipPath(clipPath)
            drawLayer(layer)
            canvas.restore()
        }
    }

    override fun onAttach() {
        shadowLayer = requireGraphicsContext().createGraphicsLayer().apply {
            compositingStrategy = CompositingStrategy.Offscreen
        }
    }

    override fun onDetach() {
        shadowLayer?.let { layer ->
            requireGraphicsContext().releaseGraphicsLayer(layer)
            shadowLayer = null
        }
    }
}

/** 挖洞用的画笔：`Clear` 混合把平移后的形状从图层里擦掉，剩下的就是环。 */
private val ShadowMaskPaint: Paint = Paint().apply {
    blendMode = BlendMode.Clear
}
