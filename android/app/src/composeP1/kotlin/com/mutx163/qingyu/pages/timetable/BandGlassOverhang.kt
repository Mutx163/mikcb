package com.mutx163.qingyu.pages.timetable

import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp

/**
 * 把首页顶栏玻璃带的玻璃节点摆到盒子之外：尺寸 = 带子尺寸加两侧 [overdrawDp]、
 * 加顶部 [overdrawDp]，左上角落在 (-[overdrawDp], -[overdrawDp])，**父布局仍按带子尺寸排**
 * （节点报 0 增量）。
 *
 * ## 为什么非推不可
 *
 * `lens()`（`components/liquid/LiquidLens.kt`）只在**形状边界**附近把采样点朝外推。
 * 带子的上 / 左 / 右三条边正好压在屏幕边上（y = 0、x = 0、x = 屏宽），朝外推就落到
 * 可采内容之外，那几像素会读成「没有背景」——真机是一条淡竖边。把这三条边推到屏幕外
 * 之后，可见区里离边界的深度处处 ≥ 作用带，着色器直接走 `-sd >= refractionHeight`
 * 的提前返回，**只有底边在折射**。
 *
 * Dart 同病同治（`home_page_region_blur.dart:34-133` 的 `homePageChromeGlassEdgeOverdraw` /
 * `homePageChromeGlassVerticalOverhang`），取值理由见
 * [com.mutx163.qingyu.pages.settings.SettingsMaterialModel.bandGlassOverdrawDp]。
 *
 * 用 `layout` 而不是 `offset`：`offset` 不改测量结果，盒子会跟着长高、把下面的网格顶下去。
 *
 * ## 尺寸必须来自**同一次布局**（2026-11-08）
 *
 * 这个修饰符只收外溢量，带子尺寸直接读 `constraints` —— 调用方必须挂
 * `Modifier.matchParentSize()`（`Box` 会先定下父盒子的最终尺寸，再用 `min == max`
 * 的固定约束量这个子节点）。**不要再加回「尺寸参数 + `onSizeChanged` 回填」**：
 * 那条路的状态初值恒为 `IntSize.Zero`，首帧没有任何几何可用，液态档只能先不画 ⇒
 * 进外观编辑页时预览卡是一棵新树，星期栏那条带会裸透一帧再变回玻璃
 * （用户 2026-11-08 实报）。守卫：`BandGlassFirstFrameGuardTest`。
 *
 * ## 上报的尺寸必须**等于带子尺寸**（同日第二修）
 *
 * `matchParentSize()` 不是只管尺寸——它写入的父数据里 `alignment = Alignment.Center`
 *（foundation `BoxScopeInstance.matchParentSize`）。所以子节点**上报多少就被怎么摆**：
 * 上报 `0×0` 会被摆在盒子中心，玻璃从中心往右下画，观感就是「模糊跑到右半边、还向下偏」
 * （用户 2026-11-08 截图实报）。上报成带子尺寸后，任何对齐方式算出的偏移都是 `(0, 0)`，
 * 外溢层再从 `(-overdrawPx, -overdrawPx)` 画出去，位置才确定。
 *
 * 顺带一个好处：节点的 `LayoutCoordinates` 从此是真实带子矩形，miuix 拿它做背景采样时
 * 不再面对一个零尺寸盒子。
 *
 * ## 为什么放在这里
 *
 * 周视图（`TimetableWeekPage`）与日视图（`day/DayViewPage`）的顶栏是**同一条带**，
 * 外溢几何必须逐像素一致，否则两条带在屏幕边上的折射观感会对不上。2026-11-01 之前
 * 它只是周视图文件里的一个 private 函数，日视图补带时把这份搬到这里，两处共用一份。
 *
 * @param overdrawDp 左 / 右 / 顶部各往屏幕外推多少（逻辑 dp）。布局约束只吃整数像素，
 *   取整在这一处完成，调用方不再各自换算。
 */
internal fun Modifier.bandGlassOverhang(overdrawDp: Dp): Modifier = layout { measurable, constraints ->
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
        // 契约外的调用（没挂 `matchParentSize`，拿不到带子尺寸）：退回「不外溢」，
        // 至少照常上屏、不崩。正路见上面的 KDoc，守卫会钉住调用点。
        val placeable = measurable.measure(constraints)
        layout(placeable.width, placeable.height) { placeable.place(0, 0) }
    } else {
        val overdrawPx = overdrawDp.roundToPx()
        val placeable = measurable.measure(
            Constraints.fixed(
                width = constraints.maxWidth + overdrawPx * 2,
                height = constraints.maxHeight + overdrawPx,
            ),
        )
        // 上报**带子尺寸**（不是 0×0）：matchParentSize 的父数据带 Center 对齐，
        // 报小了会被居中摆放（模糊会跑到右半边、向下偏）。上报等量尺寸 ⇒ 偏移恒为 (0,0)；
        // 它是 matchParentSize 子节点，报多大都不影响父盒子的尺寸。
        layout(constraints.maxWidth, constraints.maxHeight) {
            placeable.place(-overdrawPx, -overdrawPx)
        }
    }
}
