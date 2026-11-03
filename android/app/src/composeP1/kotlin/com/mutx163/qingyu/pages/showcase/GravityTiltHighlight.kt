// Copyright 2026, compose-miuix-ui contributors
// SPDX-License-Identifier: Apache-2.0
//
// 照抄自官方 demo component/liquid/LiquidGlassNavigationBar.kt:106-192 的重力倾灯段，
// 仅改包名与高亮常量名（iosIndicatorSpecular → showcaseIndicatorSpecular）。
// rememberDeviceTilt 来自 miuix-blur 库（top.yukonga.miuix.kmp.blur.sensor），非自研。
//
// 关键语义（照官方注释）：
// - 重力方向量化到 3°：更细的变化肉眼看不出；
// - 返回 State 而不是裸值：传感器 ~50Hz 无节流写入，组合期读会让整个调用方重组，
//   所以延迟到绘制期读（在 drawBackdrop 的 highlight lambda 里取 .value）；
// - 旋转副本按量化步缓存，只在跨步时重新分配对象。

package com.mutx163.qingyu.pages.showcase

import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import top.yukonga.miuix.kmp.blur.highlight.BloomStroke
import top.yukonga.miuix.kmp.blur.highlight.Highlight
import top.yukonga.miuix.kmp.blur.highlight.LightPosition
import top.yukonga.miuix.kmp.blur.highlight.LightSource
import top.yukonga.miuix.kmp.blur.sensor.rememberDeviceTilt
import kotlin.math.PI
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * G8 演示用的双峰（dualPeak）高亮：照抄官方滑动指示器专用描边
 * （LiquidGlassNavigationBar.kt:108-126），可直接当作「小米胶囊指示器」的描边配方。
 */
internal val showcaseIndicatorSpecular: Highlight = Highlight(
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

// Mirrors HighlightStyle.kt's LIGHT_REF — keep in sync.
private const val LIGHT_REF_X = 0.5f
private const val LIGHT_REF_Y = 0.7f
private const val GRAVITY_DIR_THRESHOLD_SQ = 0.01f // |g_xy| > 0.1, ≈ 6° tilt

// 3° quantization step for the gravity direction: finer changes are imperceptible.
private const val GRAVITY_ANGLE_STEP_RAD = (3.0 * PI / 180.0).toFloat()

/**
 * In-screen-plane gravity direction angle (radians, quantized to 3° steps).
 *
 * Returned as [State] so the read can be deferred to the draw phase: the sensor writes tilt
 * state unthrottled (~50Hz), and a composition-time read would recompose the whole caller
 * scope on every tick. The derivedStateOf equality check then drops draw invalidations to
 * quantization-step crossings.
 */
@Composable
private fun rememberQuantizedGravityAngle(): State<Float> {
    val tiltState = rememberDeviceTilt()
    return remember(tiltState) {
        derivedStateOf {
            val tilt = tiltState.value
            val gx = tilt.gravityX
            val gy = tilt.gravityY
            val gMagSq = gx * gx + gy * gy
            if (gMagSq > GRAVITY_DIR_THRESHOLD_SQ) {
                (atan2(gy, gx) / GRAVITY_ANGLE_STEP_RAD).roundToInt() * GRAVITY_ANGLE_STEP_RAD
            } else {
                // Near-flat: the in-plane gravity direction is unstable, pin to (0, -1).
                (-PI / 2).toFloat()
            }
        }
    }
}

/**
 * [base] with its `dualPeak` primary light rotated to the gravity angle plus [extraDegrees].
 * Read `.value` only at draw time (see [rememberQuantizedGravityAngle]); the rotated copy is
 * cached, re-allocating only when the angle crosses a quantization step.
 */
@Composable
internal fun rememberGravityRotatedHighlight(
    base: Highlight,
    extraDegrees: Float,
): State<Highlight> {
    val gravityAngle = rememberQuantizedGravityAngle()
    return remember(gravityAngle, base, extraDegrees) {
        derivedStateOf {
            val baseStyle = base.style as BloomStroke
            val basePrimary = baseStyle.primaryLight
            val rad = gravityAngle.value + (extraDegrees * PI / 180.0).toFloat()
            base.copy(
                style = baseStyle.copy(
                    primaryLight = basePrimary.copy(
                        position = LightPosition(
                            x = LIGHT_REF_X + cos(rad),
                            y = LIGHT_REF_Y + sin(rad),
                            z = basePrimary.position.z,
                        ),
                    ),
                ),
            )
        }
    }
}
