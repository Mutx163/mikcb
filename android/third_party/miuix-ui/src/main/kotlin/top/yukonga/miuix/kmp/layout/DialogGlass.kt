// Copyright 2025, compose-miuix-ui contributors
// SPDX-License-Identifier: Apache-2.0
//
// 本仓 fork 新增（2026-11-03）：弹窗玻璃材质。上游 0.9.4 的 DialogContentLayout 只有实心
// squircleSurface，没有模糊/压色/边缘高光这一档。

package top.yukonga.miuix.kmp.layout

import androidx.compose.ui.unit.Dp
import top.yukonga.miuix.kmp.blur.Backdrop

/**
 * 弹窗玻璃材质参数（opt-in，默认不启用）。
 *
 * 只描述「采样谁、糊多狠、通透感多少」；**压色与圆角不走这里**——压色由调用方通过已有的
 * `DialogContentLayout` `backgroundColor` 传（半透明即可），圆角由容器内部推导的
 * `resolvedCornerRadius` 决定。这样玻璃面与官方容器的取色、形状天然同源，不会漂移。
 *
 * 降级口径（统一形态）：设备不支持 `RuntimeShader`，或 [backdrop] 为 `null`（页面没提供
 * 录像带）时，本类仍表示「要玻璃」，但容器改用**同一档压色 + 1dp 描边**——同一视觉家族，
 * 不出现「某台机器糊、另一台不糊又没边」。
 *
 * @property backdrop 采样源（页面侧提供的图层录像带）。弹窗自身所在窗口不能抓自己，
 *   必须由页面把 [Backdrop] 交上来；拿不到就降级，不假装玻璃。
 * @property blurRadius 模糊半径（面板档，dp）。
 * @property saturation 饱和度增益（>1 更通透；不设这一档玻璃会发灰）。
 * @property dark 深色主题标记，只用于挑边缘高光预设（不参与颜色推导）。
 */
data class DialogGlass(
    val backdrop: Backdrop?,
    val blurRadius: Dp,
    val saturation: Float = 1f,
    val dark: Boolean = false,
)
