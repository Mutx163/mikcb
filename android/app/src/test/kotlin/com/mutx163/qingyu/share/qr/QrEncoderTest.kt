package com.mutx163.qingyu.share.qr

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * 二维码编码器测试。
 *
 * 两类证据：
 * 1. **逐位对拍**（[QR_GOLDEN_CASES]）：参考矩阵由 Dart 侧 pub `qr` 3.0.2 现场生成，
 *    与被测 Kotlin 编码器完全独立；覆盖空串 / 1 字节 / 5 字节 / 20 字节 / 60 字节 /
 *    UTF-8 中文 / 150 字节（版本 7，含版本信息位）/ 240 字节（版本 10，16 位长度字段）/ 800 字节。
 * 2. **手推结构**（`A 在版本1-L...`）：定位符 / 时序线 / 固定暗模块 / 格式信息校验码
 *    都是按 QR 规范从矩阵上量出来的固定图形，不是从实现里抄的。
 */
class QrEncoderTest {

    @Test
    fun `与 Dart qr 包逐位对拍`() {
        for (case in QR_GOLDEN_CASES) {
            val matrix = QrEncoder.encode(case.input, QrErrorCorrectionLevel.L)
            assertEquals("尺寸 @${case.label}", case.count, matrix.size)
            assertEquals("黑块数 @${case.label}", case.dark, matrix.darkCount)
            assertEquals("模块矩阵 @${case.label}", case.hex, matrix.toHexString())
        }
    }

    @Test
    fun `A 在版本1-L 的定位符时序线与校验码是手推的固定图形`() {
        val matrix = QrEncoder.encode("A", QrErrorCorrectionLevel.L)
        assertEquals(21, matrix.size)

        // 三个 7×7 定位符：外环黑、中间白环、3×3 黑核。
        assertFinder(matrix, top = 0, left = 0)
        assertFinder(matrix, top = 0, left = 14)
        assertFinder(matrix, top = 14, left = 0)

        // 时序线：第 6 行 / 第 6 列在 [8, 12] 内，偶数坐标黑、奇数白。
        for (i in 8..12) {
            assertEquals("第6行时序 @$i", i % 2 == 0, matrix.isDark(i, 6))
            assertEquals("第6列时序 @$i", i % 2 == 0, matrix.isDark(6, i))
        }

        // 固定暗模块：row = size-8 = 13，col = 8。
        assertTrue("固定暗模块应为黑", matrix.isDark(8, 13))

        // 格式信息校验码：L + 掩码 0 → 规范值 0x77C4（从左上角那份副本按位还原）。
        assertEquals(0x77C4, formatBitsFromMatrix(matrix))
    }

    @Test
    fun `显式版本可用且尺寸正确`() {
        val v5 = QrEncoder.encode("A", QrErrorCorrectionLevel.L, version = 5)
        assertEquals(37, v5.size) // 17 + 4*5
    }

    @Test
    fun `内容放不进指定版本会抛异常`() {
        try {
            QrEncoder.encode("x".repeat(100), QrErrorCorrectionLevel.L, version = 1)
            fail("版本 1-L 只有 17 字节容量，100 字节应抛异常")
        } catch (expected: IllegalArgumentException) {
            // 期望
        }
    }

    @Test
    fun `超过版本40容量会抛异常`() {
        try {
            QrEncoder.encode("x".repeat(3200), QrErrorCorrectionLevel.L)
            fail("3200 字节超过版本 40-L 容量，应抛异常")
        } catch (expected: IllegalArgumentException) {
            // 期望
        }
    }

    // ---- helpers ----

    /** 断言 (top,left) 处是标准 7×7 定位符。坐标用 (行=top, 列=left)。 */
    private fun assertFinder(matrix: QrMatrix, top: Int, left: Int) {
        for (r in 0 until 7) {
            for (c in 0 until 7) {
                val ring = r == 0 || r == 6 || c == 0 || c == 6
                val core = r in 2..4 && c in 2..4
                assertEquals(
                    "定位符($top,$left) 格($r,$c)",
                    ring || core,
                    matrix.isDark(left + c, top + r),
                )
            }
        }
    }

    /** 从左上角那份格式信息副本按位还原成 15 位整数（bit0 在最低位）。 */
    private fun formatBitsFromMatrix(matrix: QrMatrix): Int {
        var bits = 0
        for (i in 0..5) if (matrix.isDark(8, i)) bits = bits or (1 shl i)
        if (matrix.isDark(8, 7)) bits = bits or (1 shl 6)
        if (matrix.isDark(8, 8)) bits = bits or (1 shl 7)
        if (matrix.isDark(7, 8)) bits = bits or (1 shl 8)
        for (i in 9..14) {
            val col = 14 - i
            if (matrix.isDark(col, 8)) bits = bits or (1 shl i)
        }
        return bits
    }
}
