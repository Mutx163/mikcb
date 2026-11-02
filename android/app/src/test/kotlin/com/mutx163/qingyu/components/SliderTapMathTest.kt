package com.mutx163.qingyu.components

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * [SliderTapMath] 的契约测试：把「点轨道 → 值」的换算钉死在 miuix `Slider.kt`
 * 的同一口径上（拇指半径 = 轨道高的一半；有档位先量化；没档位才磁吸；否则线性）。
 *
 * 为什么值得单独测：这段数学决定了「点出来的值」和「拖出来的值」是否落在同一格。
 * 两边口径一旦漂开，滑杆会出现「点完自己抖一下」的观感问题，而 Compose 手势本身
 * 在纯 JVM 测试里跑不起来 —— 只能把换算抽成纯函数来钉。
 */
class SliderTapMathTest {

    private val continuous = 0f..100f

    private fun tap(
        tapX: Float,
        trackWidth: Float = 200f,
        trackHeight: Float = 40f,
        range: ClosedFloatingPointRange<Float> = continuous,
        steps: Int = 0,
        keyPoints: List<Float>? = null,
        magnetThreshold: Float = 0.02f,
        reverse: Boolean = false,
    ): Float = SliderTapMath.valueForTap(
        tapX = tapX,
        trackWidthPx = trackWidth,
        trackHeightPx = trackHeight,
        valueRange = range,
        steps = steps,
        keyPoints = keyPoints,
        magnetThreshold = magnetThreshold,
        reverseDirection = reverse,
    )

    @Test
    fun `点击轨道最左与最右分别是两端值`() {
        // 拇指半径 = 40/2 = 20；可用宽度 = 200-40 = 160。
        assertEquals(0f, tap(tapX = 20f), 0.0001f)
        assertEquals(100f, tap(tapX = 180f), 0.0001f)
    }

    @Test
    fun `拇指半径以内被夹到端点`() {
        assertEquals(0f, tap(tapX = 0f), 0.0001f)
        assertEquals(0f, tap(tapX = 19.9f), 0.0001f)
        assertEquals(100f, tap(tapX = 200f), 0.0001f)
    }

    @Test
    fun `正中间点击拿到区间中点`() {
        assertEquals(50f, tap(tapX = 100f), 0.0001f)
    }

    @Test
    fun `反向滑杆点击左侧拿到上限`() {
        assertEquals(100f, tap(tapX = 20f, reverse = true), 0.0001f)
        assertEquals(0f, tap(tapX = 180f, reverse = true), 0.0001f)
    }

    @Test
    fun `有档位时量化到最近的档`() {
        // 0..10、steps=9 = 10 个区间：0.54 → 5，0.56 → 6。
        assertEquals(5f, tap(tapX = 20f + 160f * 0.54f, range = 0f..10f, steps = 9), 0.0001f)
        assertEquals(6f, tap(tapX = 20f + 160f * 0.56f, range = 0f..10f, steps = 9), 0.0001f)
        // 端点仍然精确落在两端。
        assertEquals(0f, tap(tapX = 20f, range = 0f..10f, steps = 9), 0.0001f)
        assertEquals(10f, tap(tapX = 180f, range = 0f..10f, steps = 9), 0.0001f)
    }

    @Test
    fun `无档位时关键点在阈值内磁吸`() {
        // 阈值 0.02（2%）；0.49 距 0.50 只有 1% → 吸到 50。
        assertEquals(
            50f,
            tap(tapX = 20f + 160f * 0.49f, keyPoints = listOf(0f, 50f, 100f)),
            0.0001f,
        )
        // 0.45 距最近的 0.50 有 5% → 不吸，保留线性值 45。
        assertEquals(
            45f,
            tap(tapX = 20f + 160f * 0.45f, keyPoints = listOf(0f, 50f, 100f)),
            0.0001f,
        )
    }

    @Test
    fun `有档位时关键点不参与磁吸`() {
        // miuix 的取值分支里 steps > 0 会先返回，keyPoints 磁吸走不到。
        // 0.49 距 keyPoint 5.05 只有 1.5%（阈值内，若误走磁吸会得 5.05）；
        // 正常量化到 5 档应得 5.0。
        assertEquals(
            5f,
            tap(
                tapX = 20f + 160f * 0.49f,
                range = 0f..10f,
                steps = 9,
                keyPoints = listOf(0f, 5.05f, 10f),
            ),
            0.0001f,
        )
    }

    @Test
    fun `轨道宽度小于两个拇指半径时退回起始值`() {
        assertEquals(0f, tap(tapX = 10f, trackWidth = 30f, trackHeight = 40f), 0.0001f)
    }
}
