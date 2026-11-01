package com.mutx163.qingyu.pages.timetable

import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.IntSize
import kotlin.math.roundToInt

/**
 * 把首页顶栏玻璃带的玻璃节点摆到盒子之外：尺寸 = [bandSize] 加两侧 [overdrawXPx]、
 * 加顶部 [overdrawPx]，左上角落在 (-[overdrawXPx], -[overdrawPx])，**父布局仍按
 * [bandSize] 排**（节点报 0 增量）。
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
 * ## 为什么放在这里
 *
 * 周视图（`TimetableWeekPage`）与日视图（`day/DayViewPage`）的顶栏是**同一条带**，
 * 外溢几何必须逐像素一致，否则两条带在屏幕边上的折射观感会对不上。2026-11-01 之前
 * 它只是周视图文件里的一个 private 函数，日视图补带时把这份搬到这里，两处共用一份。
 *
 * @param bandSize 带子自身量到的尺寸（px）。
 * @param overdrawXPx 左右各往屏幕外推多少（px）。
 * @param overdrawPx 顶部往屏幕外推多少（px）。
 */
internal fun Modifier.bandGlassOverhang(
    bandSize: IntSize,
    overdrawXPx: Float,
    overdrawPx: Float,
): Modifier = layout { measurable, _ ->
    // 入参是 px 浮点（由 dp 换算而来），布局约束只吃整数像素 —— 这里一次性取整，
    // 免得调用方各自 `roundToInt` 出现两份口径。
    val overdrawX = overdrawXPx.roundToInt()
    val overdrawY = overdrawPx.roundToInt()
    val placeable = measurable.measure(
        Constraints.fixed(
            width = bandSize.width + overdrawX * 2,
            height = bandSize.height + overdrawY,
        ),
    )
    layout(0, 0) {
        placeable.place(-overdrawX, -overdrawY)
    }
}
