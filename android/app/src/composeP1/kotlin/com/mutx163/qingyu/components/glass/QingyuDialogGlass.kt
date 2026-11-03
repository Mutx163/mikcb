package com.mutx163.qingyu.components.glass

import androidx.compose.runtime.staticCompositionLocalOf
import top.yukonga.miuix.kmp.blur.LayerBackdrop

/**
 * 弹窗玻璃材质的总开关与共享参数（2026-11-03 弹窗材质批，用户批准试点）。
 *
 * ## 一键回退
 *
 * [enabled] 置 `false`：所有 [GlassOverlayDialog] 调用点原样回落官方实心 `OverlayDialog`
 * （玻璃分支整体不组合），不需要改任何调用点。默认 `true`——用户看过真机效果决定铺开或回退。
 *
 * ## backdrop 从哪来
 *
 * 弹窗浮在 `MiuixPopupHost` 层，采样的「背景」是页面内容：[LocalQingyuPageBackdrop] 由
 * `QingyuPageScaffold` 用既有的 `rememberQingyuBlurBackdrop`（顶栏毛玻璃同一条录像带）提供。
 * 拿不到（非 Scaffold 页面 / 能力门控关闭）时 [GlassOverlayDialog] 自动走实心分支——
 * 与顶栏共用同一 backdrop，不产生第二份图层录制（无双重采样）。
 *
 * ## 玻璃配方（对齐 NexioSchedule 的 dialog 档）
 *
 * `vibrancy`（去灰）+ `blur`（24dp 面板档）+ 半透明压色（亮 0.78 / 暗 0.87，玻璃层上保证
 * 文字对比度）+ `Highlight.GlassStrokeMiddle*` 边缘高光。半径锁 32dp（官方贴底下限 /
 * 居中档默认），容器与玻璃面同值防漂移。深层材质参照 `docs/plans/2026-11-02-compose-dialog-full-audit.md`
 * 「材质对照」节。
 */
object QingyuDialogGlass {

    /** 一键回退开关：`false` = 全部玻璃弹窗回到官方实心板。 */
    @Volatile
    var enabled: Boolean = true

    /** 玻璃模糊半径（NexioSchedule 面板档；对话/弹层类玻璃的上限档，旗舰机可扛）。 */
    const val BLUR_RADIUS_DP: Float = 24f

    /** 玻璃层上的压色 alpha：亮色 0.78 / 深色 0.87（NexioSchedule dialog 档原值）。 */
    const val TINT_ALPHA_LIGHT: Float = 0.78f
    const val TINT_ALPHA_DARK: Float = 0.87f

    /** 玻璃面圆角：与官方容器 `cornerRadius` 显式同值（官方贴底下限 / 居中档默认）。 */
    const val CORNER_RADIUS_DP: Float = 32f
}

/**
 * 页面级「录像带」，由 `QingyuPageScaffold` 提供；弹窗玻璃靠它采样被弹窗遮住的页面内容。
 * 默认 `null`（非 Scaffold 页面 / 模糊能力门控关闭）→ 玻璃自动降级为官方实心弹窗。
 */
val LocalQingyuPageBackdrop = staticCompositionLocalOf<LayerBackdrop?> { null }
