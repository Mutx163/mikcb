package com.mutx163.qingyu.components.glass

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.pages.settings.LiquidGlassTuning
import top.yukonga.miuix.kmp.blur.highlight.BloomStroke
import top.yukonga.miuix.kmp.blur.highlight.Highlight
import top.yukonga.miuix.kmp.blur.highlight.LightPosition
import top.yukonga.miuix.kmp.blur.highlight.LightSource

/**
 * 全站玻璃边缘高光（specular）的**唯一来源**。
 *
 * 之前这份参数私有在 `GlassDockNavigationBar.kt` 里，只有底栏能用；课卡 / 日视图卡
 * 另起 `drawBackdrop` 时没传 `highlight`，于是「同一个材质参数」在底栏有边光、在卡片上
 * 没有（用户反馈：卡片静止时不像玻璃，只有动起来靠折射才看出一点）。
 * 提到共享件后，底栏与课卡引用的就是**同一份**参数，不再各写一套。
 *
 * 与 miuix 的 `Highlight.GlassStrokeMiddleLight` 不同：这里用 `dualPeak = true`
 * （两个 180° 对置的峰），所以**上下两条边同时**有高光，读起来更像一根玻璃棒
 * 而不是一块有厚度的板。这是 demo 为指示器单独调的预设，也是底栏在用的那一份。
 */
internal val GlassDockSpecular: Highlight = Highlight(
    width = 1.dp,
    alpha = 1f,
    style = BloomStroke(
        color = Color.White.copy(alpha = 0.12f),
        innerBlurRadius = 2.0.dp,
        primaryLight = LightSource(
            position = LightPosition(0.5f, -0.3f, -0.05f),
            color = Color.White,
            intensity = 1f,
        ),
        secondaryLight = LightSource(
            position = LightPosition(0.5f, 0.8f, -0.5f),
            color = Color.White,
            intensity = 0.4f,
        ),
        dualPeak = true,
    ),
)

/**
 * 边光强度：出厂 `liquidRimStrength = 0.2` 对应原来的 0.75 alpha；旋钮拉到 0 = 完全不要边光。
 *
 * 底栏与课卡**同一口径**（都取 `material.liquidRimStrength`）。`rimStrength == null`
 * （拿不到材质快照）时按出厂值走，即 0.75 —— 与原 `GlassDockNavigationBar` 的
 * `rimHighlightAlpha` 一字不差。
 */
internal fun glassRimAlpha(rimStrength: Float?): Float {
    val defaultRimStrength = LiquidGlassTuning.DEFAULT_RIM_STRENGTH.toFloat()
    return (0.75f * ((rimStrength ?: defaultRimStrength) / defaultRimStrength)).coerceIn(0f, 1f)
}
