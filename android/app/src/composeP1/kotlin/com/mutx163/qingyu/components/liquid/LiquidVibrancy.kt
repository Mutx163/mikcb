// Copyright 2026, compose-miuix-ui contributors
// SPDX-License-Identifier: Apache-2.0

package com.mutx163.qingyu.components.liquid

// Adapted from Kyant0/AndroidLiquidGlass — https://github.com/Kyant0/AndroidLiquidGlass (Apache 2.0).
//
// 同 [lens]：miuix 0.9.4 的发布物里没有 `vibrancy()`，只在官方 demo 的
// `component/liquid/` 下。按 Apache-2.0 整段搬入。

import top.yukonga.miuix.kmp.blur.BackdropEffectScope
import top.yukonga.miuix.kmp.blur.colorControls

/**
 * 玻璃的「鲜活度」：把采样到的背景**加饱和**。
 *
 * 为什么需要它：模糊本身会让颜色互相渗透、整体发灰。真玻璃透过来的颜色是
 * **更浓**而不是更淡的（光线被聚拢）。不加这一步，玻璃后面的壁纸会显得脏，
 * 这也是"看起来像蒙了一层灰塑料"的一个来源。
 *
 * 1.5 是官方 demo 的取值（Kyant 的 `vibrancy()` 轻量替代），不要随手改：
 * 再高会在高饱和壁纸上出现色块，再低就退回"发灰"。
 *
 * @param saturation 饱和度倍数。1 = 原样（等价不做）。默认 1.5 是历史口径；
 *   统一玻璃件按 `GlassSpec.vibrancy` 传入，让「一处参数一处解释」。
 */
fun BackdropEffectScope.vibrancy(saturation: Float = 1.5f) {
    colorControls(
        brightness = 0f,
        contrast = 1f,
        saturation = saturation,
    )
}
