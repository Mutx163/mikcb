package com.mutx163.qingyu.components

import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * 「点轨道 → 值」的换算（[QingyuSlider] 的点击跳转用）。
 *
 * 口径逐条照抄 miuix 0.9.4 `miuix-ui/.../basic/Slider.kt`：
 * `horizontalVisualFraction`（拇指半径 = 轨道高度的一半，可用宽度 = 轨道宽度 − 2×拇指半径）
 * + `resolveValueFromFraction`（有 `steps` 先量化到档位；没档位才轮到 `keyPoints` 磁吸；
 * 都没有就是线性插值）。**两边必须同一口径**，否则「点出来的值」和「拖出来的值」
 * 会落在不同的格上，滑杆看起来会自己抖一下。
 *
 * 抽成纯函数是为了能在 JVM 单测里直接钉住换算结果 —— Compose 的 Composable
 * 在纯 JVM 测试里跑不起来，但这段数学可以。
 */
object SliderTapMath {

    /**
     * @param tapX 点击位置（相对轨道左沿，px）
     * @param trackWidthPx 轨道宽度（px）
     * @param trackHeightPx 轨道高度（px，= miuix 的 `height`）
     * @param reverseDirection 反向（RTL 或显式反向）时为 true
     */
    fun valueForTap(
        tapX: Float,
        trackWidthPx: Float,
        trackHeightPx: Float,
        valueRange: ClosedFloatingPointRange<Float>,
        steps: Int,
        keyPoints: List<Float>?,
        magnetThreshold: Float,
        reverseDirection: Boolean,
    ): Float {
        val thumbRadius = trackHeightPx / 2f
        val availableWidth = (trackWidthPx - 2f * thumbRadius).coerceAtLeast(0f)
        if (availableWidth <= 0f) {
            return valueRange.start
        }
        val visualFraction = ((tapX - thumbRadius) / availableWidth).coerceIn(0f, 1f)
        val fraction = if (reverseDirection) 1f - visualFraction else visualFraction
        return valueForFraction(fraction, valueRange, steps, keyPoints, magnetThreshold)
    }

    /** 已有归一化位置（0..1，左→右）时直接取值；拆分出来方便单测。 */
    fun valueForFraction(
        fraction: Float,
        valueRange: ClosedFloatingPointRange<Float>,
        steps: Int,
        keyPoints: List<Float>?,
        magnetThreshold: Float,
    ): Float {
        val f = fraction.coerceIn(0f, 1f)
        val start = valueRange.start
        val end = valueRange.endInclusive
        return when {
            // 与 miuix 一致：steps 存在时先量化，keyPoints 的磁吸分支走不到。
            steps > 0 -> {
                val stepCount = steps + 1
                val stepIndex = (f * stepCount).roundToInt().coerceIn(0, stepCount)
                val s = start.toDouble()
                val e = end.toDouble()
                (s + (e - s) * stepIndex / stepCount).toFloat()
            }

            !keyPoints.isNullOrEmpty() -> {
                var closest = keyPointFraction(keyPoints[0], valueRange)
                var bestDist = abs(closest - f)
                for (i in 1 until keyPoints.size) {
                    val candidate = keyPointFraction(keyPoints[i], valueRange)
                    val dist = abs(candidate - f)
                    if (dist < bestDist) {
                        bestDist = dist
                        closest = candidate
                    }
                }
                if (bestDist < magnetThreshold) lerp(start, end, closest) else lerp(start, end, f)
            }

            else -> lerp(start, end, f)
        }
    }

    private fun keyPointFraction(
        point: Float,
        valueRange: ClosedFloatingPointRange<Float>,
    ): Float = ((point - valueRange.start) / (valueRange.endInclusive - valueRange.start))
        .coerceIn(0f, 1f)

    /** 与 `androidx.compose.ui.util.lerp` 同式（`(1-t)·start + t·stop`）。 */
    private fun lerp(start: Float, stop: Float, fraction: Float): Float =
        (1f - fraction) * start + fraction * stop
}
