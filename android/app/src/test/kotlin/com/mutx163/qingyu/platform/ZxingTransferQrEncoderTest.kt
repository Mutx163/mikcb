package com.mutx163.qingyu.platform

import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.MultiFormatReader
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.common.HybridBinarizer
import com.mutx163.qingyu.share.qr.QrEncoder
import com.mutx163.qingyu.share.qr.QrErrorCorrectionLevel
import com.mutx163.qingyu.share.qr.QrMatrix
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * 局域网页二维码的 ZXing 实现（2026-11-14 换库后）。
 *
 * 为什么在 `platform/` 测试目录：`share` 是 L0 共享面，classpath 没有 zxing jar；而这条
 * 测试必须用 ZXing 自己的解码器把矩阵扫回字符串。L0 不收本目录，由 L2 的 gradle 带依赖跑。
 *
 * 旧 `QrEncoderTest` 的两类证据这样处理：
 * - **保留（矩阵级规范）**：尺寸、定位符、时序线、固定暗模块、格式信息反解出纠错等级；
 * - **删除（Dart 逐位对拍）**：`QR_GOLDEN_CASES` 里 9 组矩阵是 Dart `qr` 3.0.2 生成的参考值。
 *   换 ZXing 后掩码选择用另一套罚分实现，矩阵不再逐位相同——这不是回归，是「与 Dart 对拍」
 *   这个立项理由本身已经不存在（Dart 层 P4-D 已删）。留着它只能选择「永远红」或「把 ZXing
 *   的输出抄成新 gold」，后者是对着实现抄答案，没有证据价值。
 * - **新增**：编码 → 解码往返（ZXing `MultiFormatReader` 真解码）。
 */
class ZxingTransferQrEncoderTest {

    // ========== 解码辅助 ==========

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
        val hints = mapOf(DecodeHintType.CHARACTER_SET to "UTF-8")
        return MultiFormatReader().apply { setHints(hints) }
            .decode(BinaryBitmap(HybridBinarizer(RGBLuminanceSource(side, side, pixels))))
            .text
    }

    // ========== 编码 → 解码往返 ==========

    @Test
    fun `局域网地址编码后能解码回原文`() {
        val address = "http://192.168.1.23:8765/"
        assertEquals(address, decode(ZxingTransferQrEncoder.encode(address, QrErrorCorrectionLevel.L, null)))
    }

    @Test
    fun `非ASCII内容按UTF-8往返`() {
        val payload = "Grüße 2026"
        assertEquals(payload, decode(ZxingTransferQrEncoder.encode(payload, QrErrorCorrectionLevel.L, null)))
    }

    @Test
    fun `显式版本的产物也能扫回来`() {
        val payload = "http://192.168.1.23:8765/a"
        val matrix = ZxingTransferQrEncoder.encode(payload, QrErrorCorrectionLevel.M, version = 5)
        assertEquals(37, matrix.size)
        assertEquals(payload, decode(matrix))
    }

    // ========== 矩阵级规范（与编码器内部实现无关） ==========

    @Test
    fun `A 在版本1-L 的定位符时序线与固定暗模块是规范图形`() {
        val matrix = ZxingTransferQrEncoder.encode("A", QrErrorCorrectionLevel.L, null)
        assertEquals(21, matrix.size)

        assertFinder(matrix, top = 0, left = 0)
        assertFinder(matrix, top = 0, left = 14)
        assertFinder(matrix, top = 14, left = 0)

        for (i in 8..12) {
            assertEquals("第6行时序 @$i", i % 2 == 0, matrix.isDark(i, 6))
            assertEquals("第6列时序 @$i", i % 2 == 0, matrix.isDark(6, i))
        }

        // 固定暗模块：版本 1 时 (8, size-8) = (8, 13)
        assertTrue("固定暗模块应为黑", matrix.isDark(8, 13))
    }

    @Test
    fun `格式信息反解出来是L等级`() {
        val matrix = ZxingTransferQrEncoder.encode("A", QrErrorCorrectionLevel.L, null)
        val bits = formatBitsFromMatrix(matrix)
        var matched = -1
        for (ecl in 0..3) {
            for (mask in 0..7) if (bchFormat(ecl, mask) == bits) matched = (ecl shl 3) or mask
        }
        assertTrue("格式信息没认出来：$bits", matched >= 0)
        assertEquals("反解出的等级不是 L", 0b01, matched ushr 3)
    }

    // ========== 拒绝语义（与旧实现一致） ==========

    @Test
    fun `内容放不进指定版本会抛异常`() {
        try {
            ZxingTransferQrEncoder.encode("x".repeat(100), QrErrorCorrectionLevel.L, version = 1)
            fail("版本 1-L 只有 17 字节容量，100 字节应抛异常")
        } catch (expected: IllegalArgumentException) {
            // 期望
        }
    }

    @Test
    fun `超过版本40容量会抛异常`() {
        try {
            ZxingTransferQrEncoder.encode("x".repeat(3200), QrErrorCorrectionLevel.L, null)
            fail("3200 字节超过版本 40-L 容量，应抛异常")
        } catch (expected: IllegalArgumentException) {
            // 期望
        }
    }

    @Test
    fun `自动版本会随内容增长`() {
        assertEquals(21, ZxingTransferQrEncoder.encode("A", QrErrorCorrectionLevel.L, null).size)
        val longer = ZxingTransferQrEncoder.encode("x".repeat(100), QrErrorCorrectionLevel.L, null)
        assertTrue("100 字节不该还挤在版本 1（尺寸 ${longer.size}）", longer.size > 21)
        // 尺寸必须符合 17 + 4 × 版本
        assertEquals(0, (longer.size - 17) % 4)
    }

    @Test
    fun `安装实现后对外入口走同一套编码`() {
        QrEncoder.install(ZxingTransferQrEncoder)
        assertTrue(QrEncoder.isInstalled)
        val direct = ZxingTransferQrEncoder.encode("http://192.168.1.23:8765/", QrErrorCorrectionLevel.L, null)
        assertEquals(direct, QrEncoder.encode("http://192.168.1.23:8765/"))
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

    private companion object {
        const val BLACK = 0xFF000000.toInt()
        const val WHITE = 0xFFFFFFFF.toInt()
    }
}
