package com.mutx163.qingyu.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.core.PreviewCutoutGeometry
import com.mutx163.qingyu.pages.settings.consumeAllPointerEvents
import kotlin.math.roundToInt

/**
 * 预览挖洞件：把**真实组件**按内容设计尺寸 1:1 排进一个圆角窗口里，初始露出上半部分，
 * 窗口内可上下滚动，但内容一律不可操作、读屏也不聚焦。
 *
 * ## 与外观编辑页的关系（同一套做法，只有一份实现）
 *
 * 做法与 `AppearanceEditorPreviewStage` 逐字同源：内容按 [contentWidth] × [contentHeight]
 * 固定约束 1:1 排版（[Constraints.fixed]），绘制层 `graphicsLayer` 按「窗口宽 / 内容宽」
 * 缩进窗口（[PreviewCutoutGeometry.scale]），钉在左上角。禁交互复用外观编辑页的
 * [consumeAllPointerEvents]——「预览不可操作」全站只有这一处真源，本组件不另写一套。
 *
 * 差异只有一条：外观编辑页的卡片把整屏塞进去且整体禁滚；这里按任务口径**窗口自己可滚**——
 * 初始露出内容上半部分，向下滚看后半部分。
 *
 * ## 滚动与点击为什么互不干扰（手势归属）
 *
 * 窗口里两层：
 *
 * 1. **底层 = 真实内容**：[consumeAllPointerEvents] + [clearAndSetSemantics]，点击 /
 *    长按 / 内部滚动全死，读屏也进不去（不是「盖一层透明 View 吃手势」，内容本身就是
 *    不可命中的）；
 * 2. **顶层 = 透明滚动手势层**：一个 `verticalScroll` 的空盒（`Spacer` 撑出缩放后的
 *    内容总高）。它盖满窗口，命中测试永远先落在它身上——滚动（拖动 + 惯性 +
 *    平台过度滚动）全部归它，内容层连事件都收不到。
 *
 * 于是「滚动保留、点击不透传」不需要任何自研手势代码：两层都是官方原语。
 *
 * ## 为什么不用 `requiredSize`
 *
 * 内容（整屏）比窗口大，`requiredSize` 遇到「内容超出父约束」会把上报尺寸收缩到父约束
 * 并把超出内容**居中**——窗口只剩整页右下角一块（外观编辑页 2026-11-01 真机事故，
 * 见 `AppearanceEditorPreviewStage.fullScreenPageScaled` 的注释）。这里用
 * [layout] 自己上报「缩放后尺寸」、`place(0, 0)` 钉左上角，同一条修法。
 *
 * @param contentWidth 内容设计宽（预览真实页面时 = 整屏宽，与外观编辑页同口径
 *   `LocalConfiguration.current.screenWidthDp.dp`）。
 * @param contentHeight 内容设计高（同上，整屏高）。
 * @param cornerRadius 窗口圆角；默认 16dp，与设置组卡片同族。
 * @param content 真实内容。内部交互与语义会被本组件整体关掉，调用方无需（也不应）
 *   再自己包一层禁交互。
 */
@Composable
fun QingyuPreviewCutout(
    contentWidth: Dp,
    contentHeight: Dp,
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 16.dp,
    /**
     * 按框自适应模式（2026-11-04 初版；**当前两个设置页已不用**，都走 1:1 裁窗 + 框内滚动）：
     * 内容直接按窗口尺寸排版、不缩放、也不提供滚动；内容超出框会被裁掉且看不到。
     * 只适合「内容本来就按框排版」的调用方；正常挖洞仍走 false。
     */
    fitToBox: Boolean = false,
    /** 框内初始滚动位置（px）。默认 0 ⇒ 每次进页都从顶部（星期栏）开始，不沿用上一次滚到的位置。 */
    initialScroll: Int = 0,
    content: @Composable () -> Unit,
) {
    if (fitToBox) {
        Box(modifier = modifier.fillMaxSize().clip(RoundedCornerShape(cornerRadius))) {
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .consumeAllPointerEvents()
                    .clearAndSetSemantics { },
            ) {
                content()
            }
        }
        return
    }
    BoxWithConstraints(modifier = modifier.fillMaxSize().clip(RoundedCornerShape(cornerRadius))) {
        val scale = PreviewCutoutGeometry.scale(maxWidth.value, contentWidth.value)
        val scaledContentHeight = PreviewCutoutGeometry
            .scaledContentHeight(contentHeight.value, scale)
            .dp
        val scrollState = rememberScrollState(initialScroll)

        // ── 底层：真实内容，1:1 排版 + 绘制层缩放，交互与语义全关 ──
        // 关键：内容随滚动状态**真实位移**（`offset{-scroll}`）——旧实现只滚了顶层空白
        // Spacer、内容本身没动，等于滚不动；这里补上位移，框内拖动能真的滚起来。
        Box(
            modifier = Modifier
                .previewContentScaled(
                    scale = scale,
                    contentWidth = contentWidth,
                    contentHeight = contentHeight,
                )
                .offset { IntOffset(0, -scrollState.value) }
                .consumeAllPointerEvents()
                .clearAndSetSemantics { },
        ) {
            content()
        }

        // ── 顶层：透明滚动手势层，盖满窗口（后声明的子项命中测试在前）──
        // Spacer 只负责把「缩放后的内容总高」撑成可滚范围，不画任何东西。
        Box(
            modifier = Modifier
                .matchParentSize()
                .verticalScroll(scrollState),
        ) {
            Spacer(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(scaledContentHeight),
            )
        }
    }
}

/**
 * 内容按 [contentWidth] × [contentHeight] 固定约束 1:1 排版，上报**缩放后**尺寸、
 * 绘制层按 [scale] 绕左上角缩进窗口。
 *
 * 上报缩放后尺寸（而不是像外观编辑页那样上报父给尺寸）是本组件与它的唯一布局差异：
 * 这里的窗口要拿「内容总高 − 窗口高」当滚动范围，滚动层必须能看到内容的真实占高。
 */
private fun Modifier.previewContentScaled(
    scale: Float,
    contentWidth: Dp,
    contentHeight: Dp,
): Modifier = layout { measurable, _ ->
    val widthPx = contentWidth.roundToPx()
    val heightPx = contentHeight.roundToPx()
    val placeable = measurable.measure(Constraints.fixed(widthPx, heightPx))
    layout(
        width = (widthPx * scale).roundToInt(),
        height = (heightPx * scale).roundToInt(),
    ) {
        placeable.place(0, 0)
    }
}.graphicsLayer {
    scaleX = scale
    scaleY = scale
    transformOrigin = TransformOrigin(0f, 0f)
}
