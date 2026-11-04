package com.mutx163.qingyu.core

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 统一玻璃口径的纯函数契约（2026-11-03）。
 *
 * 验收判据来自用户原话：把两处参数设成完全相同的值 ⇒ 各处拿到的 sigma / 压色 /
 * vibrancy / 高光 / 折射作用带与位移、色散必须逐字段相同。
 * [GlassSpecResolver.resolve] 的签名里没有任何「表面」入参，这条断言就是把
 * 「同一参数两套解释」挡在类型层的最后一道闸。
 */
class GlassSurfaceSpecTest {

    @Test
    fun `same tuning always resolves to the same spec`() {
        val tuning = GlassTuning(
            blurSigmaDp = 15f,
            tintAlpha = 0.70f,
            vibrancy = 1.5f,
            rimStrength = 0.2f,
            rimWidthDp = 1f,
            refractionBandDp = 11f,
            refractionAmountDp = 8f,
            dispersion = 0.35f,
        )
        val dockSpec = GlassSpecResolver.resolve(tuning)
        val cardSpec = GlassSpecResolver.resolve(tuning.copy())
        assertEquals(dockSpec, cardSpec)
        assertEquals(15f, dockSpec.blurSigmaDp, 0f)
        assertEquals(0.70f, dockSpec.tintAlpha, 0f)
        assertEquals(1.5f, dockSpec.vibrancy, 0f)
        assertEquals(0.2f, dockSpec.rimStrength, 0f)
        assertEquals(11f, dockSpec.refractionBandDp, 0f)
        assertEquals(8f, dockSpec.refractionAmountDp, 0f)
        assertEquals(0.35f, dockSpec.dispersion, 0f)
    }

    @Test
    fun `out of range values clamp to the unified limits`() {
        val spec = GlassSpecResolver.resolve(
            GlassTuning(
                blurSigmaDp = 99f,
                tintAlpha = 1.4f,
                vibrancy = 3f,
                rimStrength = -0.5f,
                rimWidthDp = 9f,
                refractionBandDp = 99f,
                refractionAmountDp = -1f,
                dispersion = 1.2f,
            ),
        )
        assertEquals(GlassSpecLimits.BlurSigmaMaxDp, spec.blurSigmaDp, 0f)
        assertEquals(1f, spec.tintAlpha, 0f)
        assertEquals(2f, spec.vibrancy, 0f)
        assertEquals(0f, spec.rimStrength, 0f)
        assertEquals(GlassSpecLimits.RimWidthMaxDp, spec.rimWidthDp, 0f)
        assertEquals(GlassSpecLimits.RefractionBandMaxDp, spec.refractionBandDp, 0f)
        assertEquals(0f, spec.refractionAmountDp, 0f)
        assertEquals(1f, spec.dispersion, 0f)
    }

    @Test
    fun `band height stays constant while the collapse fraction stays in one band`() {
        val expandedPx = 300f
        val limitPx = -150f
        // 展开档内：current 与 offset 互补变化，并叠加 ±1px 的布局取整/浮点误差。
        val samples = listOf(
            0f to 0f,
            -10f to 0.6f,
            -40f to -0.6f,
            -70f to 0.4f,
            -74f to -0.4f,
        )
        val heights = samples.map { (offset, error) ->
            TopBarGlassBand.resolveBandHeightPx(
                currentHeightPx = expandedPx + offset + error,
                heightOffsetPx = offset,
                heightOffsetLimitPx = limitPx,
            )
        }
        assertEquals(1, heights.toSet().size)
        assertEquals(TopBarGlassBand.resolveBandHeightPx(expandedPx, 0f, limitPx), heights.first())
    }

    /**
     * 单档化（2026-11-04）：整段折叠范围（含跨 0.5）模糊带高度都恒等于展开高度。
     *
     * 这是顶栏抖动 / 闪烁修复的核心回归锚点：**一旦有人把 `resolveBandHeightPx` 改回
     * 「展开 / 折叠两档」**（跨 0.5 换档），下面 `assertEquals(atTop, h)` 在折叠半程起
     * 就会拿到 `collapsedPx` ⇒ 本条必红。咬合探针见本条 KDoc 末尾。
     *
     * 探针：把 `TopBarGlassBand.resolveBandHeightPx` 恢复成旧的离散两档实现 →
     * `band height is constant across the whole collapse range` 红 → 还原即绿。
     */
    @Test
    fun `band height is constant across the whole collapse range`() {
        val expandedPx = 300f
        val limitPx = -150f
        val atTop = TopBarGlassBand.resolveBandHeightPx(
            currentHeightPx = expandedPx,
            heightOffsetPx = 0f,
            heightOffsetLimitPx = limitPx,
        )
        val atFullCollapse = TopBarGlassBand.resolveBandHeightPx(
            currentHeightPx = expandedPx + limitPx,
            heightOffsetPx = limitPx,
            heightOffsetLimitPx = limitPx,
        )
        assertEquals("单档：完全折叠也不得换档，恒等于展开高度", atTop, atFullCollapse)
        // 折叠全程（0 → 1，含 0.5 阈值两侧）每一档都必须与展开高度相同（回退两档时红）。
        // offset = limit * f 为负（合法），current = expanded + limit * f 随折叠收缩。
        listOf(0f, 0.25f, 0.49f, 0.5f, 0.51f, 0.75f, 1f).forEach { f ->
            val h = TopBarGlassBand.resolveBandHeightPx(
                currentHeightPx = expandedPx + limitPx * f,
                heightOffsetPx = limitPx * f,
                heightOffsetLimitPx = limitPx,
            )
            assertEquals("折叠比例 $f 处模糊带高度不应变化", atTop, h)
        }
    }

    @Test
    fun `non collapsing bars keep one band`() {
        val height = TopBarGlassBand.resolveBandHeightPx(
            currentHeightPx = 150f,
            heightOffsetPx = 0f,
            heightOffsetLimitPx = 0f,
        )
        assertEquals(TopBarGlassBand.resolveBandHeightPx(150f, 0f, 0f), height)
    }
}
