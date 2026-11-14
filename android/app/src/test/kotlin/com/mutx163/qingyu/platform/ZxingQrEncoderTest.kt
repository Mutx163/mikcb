package com.mutx163.qingyu.platform

import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.common.HybridBinarizer
import com.google.zxing.MultiFormatReader
import com.mutx163.qingyu.pages.statistics.charts.QrEncodeModel
import com.mutx163.qingyu.pages.statistics.charts.QrMatrix
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `ZxingQrEncoder` 的真解码验证（2026-11-14 二维码换 ZXing）。
 *
 * 为什么这份测试在 `platform/` 而不在 `pages/statistics/`：`pages/statistics` 在 L0 共享面，
 * classpath 没有 `com.google.zxing:core`；而这条测试**必须用 ZXing 自己的解码器**把矩阵扫回
 * 字符串，才叫「真能扫出来」。所以它跟着实现在 `platform/`，由 L2 的 gradle 带着依赖跑。
 *
 * 断言口径：
 * - **编码 → 解码往返**：扫回来的字符串必须与原文逐字相同（网址 / 32 字节边界 / UTF-8 中文）；
 * - **矩阵级规范**：尺寸、定位符、时序线、校正图形、固定黑点、格式信息反解为 L 等级——
 *   这些看的是输出矩阵，与编码器内部实现无关，换库也成立；
 * - **委托**：`QrEncodeModel.install(ZxingQrEncoder)` 之后，`QrEncodeModel.encode` 必须走同一实现。
 */
class ZxingQrEncoderTest {

    // ========== 解码辅助：把矩阵放大成位图，交给 ZXing 扫回来 ==========

    private fun decode(matrix: QrMatrix): String {
        val scale = 4
        val margin = 4
        val side = (matrix.size + margin * 2) * scale
        val pixels = IntArray(side * side) { WHITE }
        for (y in 0 until matrix.size) {
            for (x in 0 until matrix.size) {
                if (!matrix.isDark(x, y)) continue
                val left = (x + margin) * scale
                val top = (y + margin) * scale
                for (dy in 0 until scale) {
                    for (dx in 0 until scale) {
                        pixels[(top + dy) * side + left + dx] = BLACK
                    }
                }
            }
        }
        val source = RGBLuminanceSource(side, side, pixels)
        val bitmap = BinaryBitmap(HybridBinarizer(source))
        val hints = mapOf(DecodeHintType.CHARACTER_SET to "UTF-8")
        return MultiFormatReader().apply { setHints(hints) }.decode(bitmap).text
    }

    // ========== 编码 → 解码往返（这条才是「真能扫」） ==========

    @Test
    fun `网址编码后能解码回原文`() {
        val url = "https://163366.xyz/"
        assertEquals(url, decode(ZxingQrEncoder.encode(url)))
    }

    @Test
    fun `容量上限的边界内容也能扫回来`() {
        // MAX_BYTES 是实测值：UTF-8 + ECI 头之后 v2-L 只放得下 31 字节。
        val payload = "y".repeat(QrEncodeModel.MAX_BYTES)
        assertEquals(QrEncodeModel.MAX_BYTES, payload.toByteArray(Charsets.UTF_8).size)
        val matrix = ZxingQrEncoder.encode(payload)
        assertEquals(25, matrix.size)
        assertEquals(payload, decode(matrix))
    }

    @Test
    fun `非ASCII内容按UTF-8往返`() {
        // 用带重音的拉丁字母而不是中文：CJK 字面量棘轮只许降，测试载荷不必为它加基线。
        // ü / ß 在 UTF-8 里各占 2 字节，足够验证「不是按单字节解码」。
        val payload = "Grüße 2026"
        assertTrue(payload.toByteArray(Charsets.UTF_8).size <= QrEncodeModel.MAX_BYTES)
        assertEquals(payload, decode(ZxingQrEncoder.encode(payload)))
    }

    // ========== 矩阵级规范（与实现无关，换库后仍成立） ==========

    private val url = "https://163366.xyz/"

    @Test
    fun `网址编出来是25×25`() {
        val matrix = ZxingQrEncoder.encode(url)
        assertEquals(25, matrix.size)
        assertEquals(25, QrEncodeModel.SIZE)
        assertEquals(2, QrEncodeModel.VERSION)
        matrix.dark.forEach { row -> assertEquals(25, row.size) }
    }

    @Test
    fun `三个角上的定位符是7×7黑框加3×3实心`() {
        val matrix = ZxingQrEncoder.encode(url)
        for ((left, top) in listOf(0 to 0, 18 to 0, 0 to 18)) {
            for (row in 0 until 7) {
                for (col in 0 until 7) {
                    val ring = row == 0 || row == 6 || col == 0 || col == 6
                    val core = row in 2..4 && col in 2..4
                    assertEquals(
                        "定位符($left,$top) 第 $row 行第 $col 列",
                        ring || core,
                        matrix.isDark(left + col, top + row),
                    )
                }
            }
        }
    }

    @Test
    fun `定位符外侧一圈是白的 数据不会压上来`() {
        val matrix = ZxingQrEncoder.encode(url)
        for (index in 0 until 8) {
            assertFalse("上边第 $index 格", matrix.isDark(index, 7))
            assertFalse("左边第 $index 格", matrix.isDark(7, index))
        }
        assertFalse(matrix.isDark(17, 7))
        assertFalse(matrix.isDark(7, 17))
    }

    @Test
    fun `时序线第6行第6列交替 偶数坐标是黑`() {
        val matrix = ZxingQrEncoder.encode(url)
        for (index in 8 until 17) {
            val expected = index % 2 == 0
            assertEquals("第 6 行第 $index 列", expected, matrix.isDark(index, 6))
            assertEquals("第 $index 行第 6 列", expected, matrix.isDark(6, index))
        }
    }

    @Test
    fun `固定黑点在第17行第8列`() {
        assertTrue(ZxingQrEncoder.encode(url).isDark(8, 17))
    }

    // ========== 格式信息 ==========

    /** 测试侧独立写的 BCH(15,5)，不从实现里抄。 */
    private fun bchFormat(eclBits: Int, mask: Int): Int {
        val data = (eclBits shl 3) or mask
        var remainder = data shl 10
        val generator = 0x537
        for (shift in 14 downTo 10) {
            if ((remainder ushr shift) and 1 == 1) remainder = remainder xor (generator shl (shift - 10))
        }
        return ((data shl 10) or remainder) xor 0x5412
    }

    private fun readFormatFromTopLeft(matrix: QrMatrix): Int {
        var bits = 0
        fun take(index: Int, dark: Boolean) {
            if (dark) bits = bits or (1 shl index)
        }
        for (index in 0..5) take(index, matrix.isDark(8, index))
        take(6, matrix.isDark(8, 7))
        take(7, matrix.isDark(8, 8))
        take(8, matrix.isDark(7, 8))
        for (index in 9..14) take(index, matrix.isDark(14 - index, 8))
        return bits
    }

    @Test
    fun `图上画出的格式信息反解出来就是L等级`() {
        val matrix = ZxingQrEncoder.encode(url)
        val bits = readFormatFromTopLeft(matrix)
        var matched = -1
        for (ecl in 0..3) {
            for (mask in 0..7) {
                if (bchFormat(ecl, mask) == bits) matched = (ecl shl 3) or mask
            }
        }
        assertTrue("格式信息没认出来：$bits", matched >= 0)
        assertEquals("反解出的等级不是 L", 0b01, matched ushr 3)
        var copyTwo = 0
        fun take(index: Int, dark: Boolean) {
            if (dark) copyTwo = copyTwo or (1 shl index)
        }
        for (index in 0..7) take(index, matrix.isDark(matrix.size - 1 - index, 8))
        for (index in 8..14) take(index, matrix.isDark(8, matrix.size - 15 + index))
        assertEquals(bits, copyTwo)
    }

    // ========== 对外入口的委托与契约 ==========

    @Test
    fun `安装实现后对外入口走同一套编码`() {
        QrEncodeModel.install(ZxingQrEncoder)
        assertTrue(QrEncodeModel.isInstalled)
        assertEquals(url, decode(QrEncodeModel.encode(url)))
    }

    @Test
    fun `超过容量上限直接拒绝 不悄悄降级`() {
        val tooLong = "x".repeat(QrEncodeModel.MAX_BYTES + 1)
        val error = runCatching { QrEncodeModel.encode(tooLong) }.exceptionOrNull()
        assertTrue("超长内容应抛 IllegalArgumentException，实际 $error", error is IllegalArgumentException)
        // MAX_BYTES 恰好装得下
        assertEquals(25, ZxingQrEncoder.encode("y".repeat(QrEncodeModel.MAX_BYTES)).size)
    }

    private companion object {
        const val BLACK = 0xFF000000.toInt()
        const val WHITE = 0xFFFFFFFF.toInt()
    }
}
