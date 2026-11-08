package com.mutx163.qingyu.pages.timetable

import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.Constraints

/**
 * 周网格「钻进顶栏玻璃带底下」的两件几何夹具（2026-11-08）。
 *
 * ## 为什么需要它
 *
 * 2026-11-08 之前，星期栏那条带和下面的网格是**上下两块**：带子在 `Column` 上半段，
 * 网格装在 `weight(1f)` 的盒子里。网格视口的上边界就是带子的下边界，滚动容器把内容
 * 裁在那条线上 —— 课卡滑到星期栏下沿就被硬切掉，从来没有一帧画进带子区域，
 * 于是「滑进去被玻璃糊住」这件事根本不可能发生（连带折射也谈不上）。
 *
 * 现在的做法：
 *
 * 1. [bandUnderlap] 让网格**多量出带子那一截高度**、并向上平移同样的量 ——
 *    自己报给父布局的尺寸不变（`weight(1f)` 的视口不动，日/月视图叠加层几何不动），
 *    但网格内容从屏幕 y = 0 开始画，于是能滑进带子底下；
 * 2. 网格滚动内容顶部补一个等高 `Spacer`（`underlapHeightDp`），第 1 节仍然停在
 *    带子下沿 —— 观感与改前一致，只是「滑上去以后」不再被硬切；
 * 3. 带子按 `zIndex` 画在网格**之后**，玻璃盖住钻进去的那部分；
 * 4. 玻璃带第二遍采样「课卡录像层」，只录带子那一条
 *    （[timetableBandStripPx]），不整屏离屏重画。
 *
 * ## 录制条带为什么比带子高一点
 *
 * 玻璃采样不是只在带盒内取样：`blur` 的高斯核和 `lens` 的折射位移都会朝形状外多读
 * 一圈（miuix 内部叫 `padding`，等于模糊半径 / 折射位移）。条带正好卡在带子高度时，
 * 带子下沿那一圈会采到空像素，读成一条发黑的边。多录 [TIMETABLE_BAND_STRIP_MARGIN_DP]
 * 就是给这圈采样留料。
 */
const val TIMETABLE_BAND_STRIP_MARGIN_DP = 24f

/**
 * 计算「课卡录像层」要录多高（px）。
 *
 * @param bandHeightPx 玻璃带自身高度（px，含状态栏留白 / 标题行 / 星期栏）。
 * @param marginPx 下沿余量（px，见 [TIMETABLE_BAND_STRIP_MARGIN_DP]）。
 * @param contentHeightPx 录制节点自身高度（px）——条带不许超出它，否则录不到。
 * @return 要录的高度（px）；带子还没量出来（0）时返回 0 = 这一帧不录。
 */
fun timetableBandStripPx(
    bandHeightPx: Int,
    marginPx: Int,
    contentHeightPx: Int,
): Int {
    if (bandHeightPx <= 0) return 0
    val wanted = bandHeightPx.toLong() + marginPx.coerceAtLeast(0).toLong()
    return wanted.coerceAtMost(contentHeightPx.coerceAtLeast(0).toLong()).toInt()
}

/**
 * 让内容「向上顶进带子底下」：多量 [overlapPx] 的高度、并向上平移同样的量。
 *
 * 关键约束（别改成 `offset`）：
 *
 * - **上报尺寸不变**：父布局（`weight(1f)` 的视口）看到的仍是原高度，所以下面的
 *   日视图 / 月视图叠加层、滚动余量、`weekSectionHeight` 的可用高度都不受牵连；
 *   `offset` 不改测量结果，会留下一条同高的空隙，所以不用它。
 * - **必须挂在 `matchParentSize()` 的盒子上**：这个修饰符只吃 `overlapPx`，
 *   尺寸来自布局约束（`min == max`）。节点上报 `constraints.maxWidth × maxHeight`，
 *   与 `matchParentSize` 写入的 `Alignment.Center` 对齐算出的偏移恒为 `(0, 0)`。
 * - `overlapPx` 每次测量重新读：带子高度是 `onSizeChanged` 回填的状态，首帧为 0
 *   （这一帧不下穿），下一帧测量就带上真值。
 */
internal fun Modifier.bandUnderlap(overlapPx: () -> Int): Modifier = layout { measurable, constraints ->
    val overlap = if (constraints.hasBoundedHeight) {
        overlapPx().coerceIn(0, constraints.maxHeight)
    } else {
        0
    }
    if (overlap <= 0 || !constraints.hasBoundedWidth) {
        val placeable = measurable.measure(constraints)
        layout(placeable.width, placeable.height) { placeable.place(0, 0) }
    } else {
        val placeable = measurable.measure(
            Constraints.fixed(
                width = constraints.maxWidth,
                height = constraints.maxHeight + overlap,
            ),
        )
        layout(constraints.maxWidth, constraints.maxHeight) {
            placeable.place(0, -overlap)
        }
    }
}
