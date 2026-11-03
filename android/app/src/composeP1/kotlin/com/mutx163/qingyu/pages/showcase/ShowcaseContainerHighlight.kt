// Copyright 2026, compose-miuix-ui contributors
// SPDX-License-Identifier: Apache-2.0
//
// 照抄自官方 demo 两份文件，仅改包名并合并到一个文件：
// - component/highlight/HighlightConfig.kt（按容器尺寸×主题选 Highlight 预设）
// - component/highlight/ContainerHighlight.kt（rememberContainerHighlight：
//   传感器倾灯接线。注意两处工程细节：① Composable 不能条件调用，所以传感器
//   必须无条件接线，Disabled 时用占位 style 喂传感器、最后再 gate 成 null；
//   ② 主光 sensitivity 0.15 / 副光 0.12 是官方调好的值）

package com.mutx163.qingyu.pages.showcase

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import top.yukonga.miuix.kmp.blur.highlight.BloomStroke
import top.yukonga.miuix.kmp.blur.highlight.Highlight
import top.yukonga.miuix.kmp.blur.highlight.rememberTiltLight

internal object HighlightConfig {

    enum class Container(val displayName: String) {
        Disabled("Disabled"),
        Large("Large Container"),
        Medium("Medium Container"),
        Small("Small Container"),
    }

    fun get(container: Container, isDark: Boolean): Highlight? = when (container) {
        Container.Disabled -> null
        Container.Large -> if (!isDark) Highlight.GlassStrokeBigLight else Highlight.GlassStrokeBigDark
        Container.Medium -> if (!isDark) Highlight.GlassStrokeMiddleLight else Highlight.GlassStrokeMiddleDark
        Container.Small -> if (!isDark) Highlight.GlassStrokeSmallLight else Highlight.GlassStrokeSmallDark
    }
}

/**
 * Resolves a [Highlight] for the given [container] and theme, optionally driving its two
 * light sources from the device tilt sensor.
 *
 * Returns `null` when [container] is [HighlightConfig.Container.Disabled]. The tilt sensors
 * are always wired (composables cannot be conditionally invoked) — when the container is
 * disabled, a placeholder style feeds the sensors and the resulting highlight is gated to
 * null before reaching the caller.
 */
@Composable
internal fun rememberContainerHighlight(
    container: HighlightConfig.Container,
    isDark: Boolean,
    tiltDriven: Boolean,
    primarySensitivity: Float = 0.15f,
    secondarySensitivity: Float = 0.12f,
): Highlight? {
    val highlightBase = HighlightConfig.get(container, isDark)
    val baseStyle = (highlightBase?.style as? BloomStroke) ?: BloomStroke.GlassStrokeMiddleLight

    val tiltPrimary = rememberTiltLight(
        basePosition = baseStyle.primaryLight.position,
        color = baseStyle.primaryLight.color,
        intensity = baseStyle.primaryLight.intensity,
        sensitivity = primarySensitivity,
    )
    val tiltSecondary = rememberTiltLight(
        basePosition = baseStyle.secondaryLight.position,
        color = baseStyle.secondaryLight.color,
        intensity = baseStyle.secondaryLight.intensity,
        sensitivity = secondarySensitivity,
    )

    return remember(highlightBase, baseStyle, tiltDriven, tiltPrimary, tiltSecondary) {
        when {
            highlightBase == null -> null

            tiltDriven -> highlightBase.copy(
                style = baseStyle.copy(
                    primaryLight = tiltPrimary,
                    secondaryLight = tiltSecondary,
                ),
            )

            else -> highlightBase
        }
    }
}
