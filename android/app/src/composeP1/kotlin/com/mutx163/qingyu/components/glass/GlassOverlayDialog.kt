package com.mutx163.qingyu.components.glass

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import top.yukonga.miuix.kmp.blur.blur
import top.yukonga.miuix.kmp.blur.colorControls
import top.yukonga.miuix.kmp.blur.drawBackdrop
import top.yukonga.miuix.kmp.blur.highlight.Highlight
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 玻璃弹窗（2026-11-03 弹窗材质批试点，用户批准）。
 *
 * ## 形态：官方容器 + 官方公开参数 + miuix-blur 官方效果
 *
 * 组件本体仍是官方 `OverlayDialog`（进场动画/返回键/遮罩/宿主机制全部官方），玻璃由三层叠成——
 * 绘制顺序与 NexioSchedule fork 在 `DialogContentLayout` 内部的做法等价：
 * 1. `modifier` 上挂 miuix-blur 的 [drawBackdrop]：`vibrancy + blur(24dp)` 实时模糊，
 *    采样 [LocalQingyuPageBackdrop]（顶栏毛玻璃同一条页面录像带，无第二份图层录制）；
 * 2. 官方 `backgroundColor` 传半透明压色（亮 0.78 / 暗 0.87），落在模糊层之上保证文字对比度
 *    ——两处绘制本就是官方容器同一节点的先后顺序（drawBackdrop 在 squircleSurface 之前）；
 * 3. miuix-blur 的 `Highlight.GlassStrokeMiddle*` 边缘高光（Nexio 的 edgeLight 对应物）。
 *
 * 形状零漂移：官方 `cornerRadius` 与玻璃面 `RoundedCornerShape` 由本封装**同一个常量**
 * （[QingyuDialogGlass.CORNER_RADIUS_DP]）显式锁定，不依赖官方内部推导。
 *
 * ## 降级与回退
 *
 * - 无页面录像带（`LocalQingyuPageBackdrop == null`）、设备不支持 `RuntimeShader`、
 *   或 [QingyuDialogGlass.enabled] 被关 → 整体回落官方实心 `OverlayDialog`（原观感，
 *   无半透明假玻璃——模糊不可用不挂半透明，对齐 Nexio 的降级原则）。
 * - 深色判定与官方一致：按 `colorScheme.background` 亮度，而非 `isSystemInDarkTheme`。
 *
 * 本封装只应由**试点调用点**使用（当前唯一：加课页「删除课程确认」）；其余弹窗铺开前
 * 须经用户看真机效果拍板——守卫 `QingyuGlassDialogGuardTest` 钉住调用点数量。
 *
 * @param show 显示开关（常驻组合、状态驱动，与官方口径一致）。
 * @param title 标题（官方槽，居中 Medium）。
 * @param summary 正文（官方槽，居中）。
 * @param insideMargin 内容内边距；本仓口径 16dp（与官方 `OverlayDialog` 同参数，显式透传）。
 * @param onDismissRequest 点遮罩 / 返回键回调。
 * @param content 弹窗内容。
 */
@Composable
fun GlassOverlayDialog(
    show: Boolean,
    title: String?,
    summary: String? = null,
    insideMargin: DpSize = DpSize(16.dp, 16.dp),
    onDismissRequest: () -> Unit,
    content: @Composable () -> Unit,
) {
    val backdrop = LocalQingyuPageBackdrop.current
    if (!QingyuDialogGlass.enabled || backdrop == null || !isRuntimeShaderSupported()) {
        // 实心回退分支：官方默认观感（实心 background），玻璃相关参数一个都不传。
        OverlayDialog(
            show = show,
            title = title,
            summary = summary,
            insideMargin = insideMargin,
            onDismissRequest = onDismissRequest,
            content = content,
        )
        return
    }

    val background = MiuixTheme.colorScheme.background
    // 与官方 DialogDefaults 同口径的深浅判定（fork 版 OverlayDialog 同款三行）。
    val dark = 0.299f * background.red + 0.587f * background.green + 0.114f * background.blue < 0.5f
    val corner: Shape = RoundedCornerShape(QingyuDialogGlass.CORNER_RADIUS_DP.dp)

    OverlayDialog(
        show = show,
        title = title,
        summary = summary,
        cornerRadius = QingyuDialogGlass.CORNER_RADIUS_DP.dp,
        // 玻璃层之上的压色：半透明保证文字对比度（亮 0.78 / 暗 0.87，Nexio dialog 档）。
        backgroundColor = background.copy(alpha = if (dark) QingyuDialogGlass.TINT_ALPHA_DARK else QingyuDialogGlass.TINT_ALPHA_LIGHT),
        insideMargin = insideMargin,
        onDismissRequest = onDismissRequest,
        modifier = Modifier.drawBackdrop(
            backdrop = backdrop,
            shape = { corner },
            effects = {
                // 通透感：饱和度增益。没有这一档玻璃会发灰；等价于社区常说的 vibrancy。
                colorControls(brightness = 0f, contrast = 1f, saturation = 1.5f)
                blur(QingyuDialogGlass.BLUR_RADIUS_DP.dp.toPx())
            },
            highlight = { if (dark) Highlight.GlassStrokeMiddleDark else Highlight.GlassStrokeMiddleLight },
        ),
        content = content,
    )
}
