package com.mutx163.qingyu.components.glass

import androidx.compose.runtime.staticCompositionLocalOf
import top.yukonga.miuix.kmp.blur.LayerBackdrop

/**
 * 页面级「录像带」，由 `QingyuPageScaffold` 用既有的 `rememberQingyuBlurBackdrop`
 * （顶栏毛玻璃同一条录制）提供：录的是**页面内容合成层**，不含顶栏与弹层本身。
 *
 * ## 谁在用
 *
 * - 弹窗材质（本地 fork 的 `DialogContentLayout` 玻璃分支）从它采样被遮住的页面内容；
 * - 与顶栏共用同一份录制，不产生第二份全屏图层（无双重采样）。
 *
 * 默认 `null`（非 Scaffold 页面 / RuntimeShader 能力门控关闭 / 用户关玻璃）→
 * 消费方自动降级为官方实心面板。
 */
val LocalQingyuPageBackdrop = staticCompositionLocalOf<LayerBackdrop?> { null }
