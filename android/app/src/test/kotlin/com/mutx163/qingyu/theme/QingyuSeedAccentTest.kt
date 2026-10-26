package com.mutx163.qingyu.theme

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

/**
 * seed 派生逻辑测试。
 *
 * Dart 源：`lib/utils/theme_seed_accent.dart:17-141`。
 * 期望值人推：亮模式所见即所得、暗模式近黑回落、lerp 混比 0.7/0.45/0.35、
 * 墨水阈值 luminance>0.5、禁用墨 4.5:1。容差只给 lerp 舍入 ±2/通道。
 */
class QingyuSeedAccentTest {

    private fun channel(argb: Int, shift: Int): Int = (argb shr shift) and 0xFF

    private fun assertChannelsNear(expected: Int, actual: Int, tolerance: Int = 2) {
        for (shift in listOf(16, 8, 0)) {
            val diff = abs(channel(expected, shift) - channel(actual, shift))
            assertTrue("channel shift=$shift diff=$diff > $tolerance", diff <= tolerance)
        }
        assertEquals(expected ushr 24, actual ushr 24)
    }

    // --- hex 解析：与 Dart tryParseHexColor 同口径（6 位、无 alpha） ---

    @Test fun `parseHex大小写井号空白`() {
        assertEquals(0xFF3482FFL.toInt(), QingyuSeedAccent.parseHex("#3482FF"))
        assertEquals(0xFF3482FFL.toInt(), QingyuSeedAccent.parseHex("3482FF"))
        assertEquals(0xFF3482FFL.toInt(), QingyuSeedAccent.parseHex("  #3482ff  "))
    }

    @Test fun `parseHex非法回落null`() {
        assertNull(QingyuSeedAccent.parseHex(null))
        assertNull(QingyuSeedAccent.parseHex(""))
        assertNull(QingyuSeedAccent.parseHex("   "))
        assertNull(QingyuSeedAccent.parseHex("12345"))
        assertNull(QingyuSeedAccent.parseHex("1234567"))
        assertNull(QingyuSeedAccent.parseHex("#ZZZZZZ"))
        // 8 位含 alpha 的 Dart 侧同样拒收（hex.length != 6）。
        assertNull(QingyuSeedAccent.parseHex("FF3482FF"))
    }

    // --- luminance / 墨水 ---

    @Test fun `相对亮度黑白端点`() {
        assertEquals(1.0, QingyuSeedAccent.relativeLuminance(0xFFFFFFFFL.toInt()), 1e-9)
        assertEquals(0.0, QingyuSeedAccent.relativeLuminance(0xFF000000L.toInt()), 1e-9)
    }

    @Test fun `onAccentInk亮黄黑墨深蓝白墨`() {
        assertEquals(
            0xFF000000L.toInt(),
            QingyuSeedAccent.onAccentInk(0xFFFCC800L.toInt()),
        )
        assertEquals(
            0xFFFFFFFFL.toInt(),
            QingyuSeedAccent.onAccentInk(0xFF171717L.toInt()),
        )
        // 默认 Miuix 蓝偏暗 → 白墨（与 Flutter 现行为一致）。
        assertEquals(
            0xFFFFFFFFL.toInt(),
            QingyuSeedAccent.onAccentInk(0xFF3482FFL.toInt()),
        )
    }

    @Test fun `黑白对比度21`() {
        assertEquals(
            21.0,
            QingyuSeedAccent.contrastRatio(0xFF000000L.toInt(), 0xFFFFFFFFL.toInt()),
            1e-9,
        )
    }

    // --- seed 解析：所见即所得 + 暗近黑回落 ---

    @Test fun `亮模式亮黄原样返回`() {
        assertEquals(
            0xFFFCC800L.toInt(),
            QingyuSeedAccent.resolveSeedAccent("#FCC800", dark = false),
        )
    }

    @Test fun `暗模式近黑回落null`() {
        // 中性灰/锌灰/石板灰三档 luminance 均 < 0.08。
        assertNull(QingyuSeedAccent.resolveSeedAccent("#171717", dark = true))
        assertNull(QingyuSeedAccent.resolveSeedAccent("#18181B", dark = true))
        assertNull(QingyuSeedAccent.resolveSeedAccent("#0F172B", dark = true))
    }

    @Test fun `暗模式亮色仍原样`() {
        assertEquals(
            0xFFFCC800L.toInt(),
            QingyuSeedAccent.resolveSeedAccent("#FCC800", dark = true),
        )
    }

    @Test fun `缺失非法回落null`() {
        assertNull(QingyuSeedAccent.resolveSeedAccent(null, dark = false))
        assertNull(QingyuSeedAccent.resolveSeedAccent("oops", dark = true))
    }

    // --- 承载面：暗近黑向白提亮 0.45 ---

    @Test fun `承载面亮原样暗近黑提亮`() {
        assertEquals(
            0xFFFCC800L.toInt(),
            QingyuSeedAccent.resolveSeedSurface("#FCC800", dark = false),
        )
        val lifted = QingyuSeedAccent.resolveSeedSurface("#171717", dark = true)
        assertNotNull(lifted)
        // 向白 0.45：#171717(23,23,23) → 约 (126,126,126)，明显亮于原色。
        assertChannelsNear(0xFF7E7E7EL.toInt(), lifted!!, tolerance = 3)
        assertTrue(QingyuSeedAccent.relativeLuminance(lifted) > 0.15)
    }

    // --- 禁用底：向白/暗底混 0.7（与包默认自洽，±2 容差） ---

    @Test fun `禁用底默认蓝接近包默认值`() {
        val accent = 0xFF3482FFL.toInt()
        // 亮：lerp(#3482FF, 白, 0.7) = (194,217,255)，与包默认 #C2D9FF 逐通道一致。
        assertChannelsNear(
            0xFFC2D9FFL.toInt(),
            QingyuSeedAccent.resolveSeedDisabled(accent, dark = false)!!,
        )
        // 暗：seed 是单值（此处沿用亮蓝 #3482FF），lerp(#3482FF, #242424, 0.7)
        // = (41,64,102)；包默认 #253E64 是按暗 primary 派生的，两者同源、差数格，
        // 故此处不断言包默认、断言手算值（r=52-11.2→41、g=130-65.8→64、b=255-153.3→102）。
        assertChannelsNear(
            0xFF294066L.toInt(),
            QingyuSeedAccent.resolveSeedDisabled(accent, dark = true)!!,
        )
    }

    @Test fun `禁用底null输入回落null`() {
        assertNull(QingyuSeedAccent.resolveSeedDisabled(null, dark = false))
        assertNull(QingyuSeedAccent.resolveSeedDisabled(null, dark = true))
    }

    // --- 禁用墨：浅近白、深混 0.35；且与包默认值区分 ---

    @Test fun `禁用墨浅恒近白`() {
        val accent = 0xFF3482FFL.toInt()
        assertEquals(
            0xFFFCFCFCL.toInt(),
            QingyuSeedAccent.resolveSeedDisabledInk(accent, dark = false),
        )
    }

    @Test fun `禁用墨深为强调色混色且亮于禁用底`() {
        val accent = 0xFF3482FFL.toInt()
        val ink = QingyuSeedAccent.resolveSeedDisabledInk(accent, dark = true)!!
        val base = QingyuSeedAccent.resolveSeedDisabled(accent, dark = true)!!
        // 约 lerp(#3482FF, #242424, 0.35) ≈ (47,99,179)。
        assertChannelsNear(0xFF2F63B3L.toInt(), ink, tolerance = 3)
        assertTrue(QingyuSeedAccent.relativeLuminance(ink) > QingyuSeedAccent.relativeLuminance(base))
    }

    // --- disabledInkOn：4.5:1 刚好达标 ---

    @Test fun `禁用墨在灰底上达标且带主题色相`() {
        val background = 0xFFBFBFBFL.toInt()
        val ink = QingyuSeedAccent.disabledInkOn(background)
        assertTrue(QingyuSeedAccent.contrastRatio(ink, background) >= 4.5)
    }

    @Test fun `禁用墨在纯黑底上给出亮墨`() {
        val ink = QingyuSeedAccent.disabledInkOn(0xFF000000L.toInt())
        assertTrue(QingyuSeedAccent.contrastRatio(ink, 0xFF000000L.toInt()) >= 4.5)
        // 最小可行混比：首个达标灰约 (117,117,117)/lum≈0.18，不是纯白——
        // 上界 0.3 钉住「刚好达标」这条性质（取纯白就说明算法丢了最小性）。
        val lum = QingyuSeedAccent.relativeLuminance(ink)
        assertTrue("lum=$lum", lum > 0.15 && lum < 0.3)
    }

    @Test fun `lerp端点与中点`() {
        val a = 0xFF000000L.toInt()
        val b = 0xFFFFFFFFL.toInt()
        assertEquals(a, QingyuSeedAccent.lerpArgb(a, b, 0.0))
        assertEquals(b, QingyuSeedAccent.lerpArgb(a, b, 1.0))
        assertEquals(0xFF808080L.toInt(), QingyuSeedAccent.lerpArgb(a, b, 0.5))
    }
}
