package com.mutx163.qingyu.pages.statistics.charts

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 品牌条二维码的编码器。
 *
 * 期望值来源（**都不是**从实现里抄的）：
 * - 版本 / 尺寸 / 数据模块数 / 剩余位：QR 规范里版本 2 的公开数值（25×25、359 个数据模块、7 个剩余位）；
 * - 格式信息：规范表里的已知值（等级 L + 掩码 0 → `0x77C4`），另用一份**测试侧独立写的**
 *   BCH 实现逐位对拍；
 * - 纠错码字：用**综合式**校验（把我写出的整串码字当多项式，在每个 α^i 处求值必须为 0）。
 *   乘法用「移位 + 约简」的逐位算法，和实现里的查表法是两条不同的路；
 * - 前两个码字：手推（模式 0100 + 长度 20 + 'h' 的比特流首 16 位 = `0x41 0x46`）。
 */
class QrEncodeModelTest {

    private val url = "https://163366.xyz/"

    // ========== 测试侧独立的 GF(256)（逐位移位算法，不用查表） ==========

    private fun mulSlow(left: Int, right: Int): Int {
        var a = left
        var b = right
        var result = 0
        while (b != 0) {
            if (b and 1 != 0) result = result xor a
            b = b ushr 1
            a = a shl 1
            if (a and 0x100 != 0) a = a xor 0x11D
        }
        return result
    }

    private fun expSlow(power: Int): Int {
        var result = 1
        repeat(power % 255) { result = mulSlow(result, 2) }
        return result
    }

    /** 整串码字在 α^i 处的取值；纠错码字正确时应恒为 0。 */
    private fun evaluateAt(codewords: IntArray, power: Int): Int {
        val alpha = expSlow(power)
        var acc = 0
        for (codeword in codewords) acc = mulSlow(acc, alpha) xor codeword
        return acc
    }

    // ========== 尺寸与结构 ==========

    @Test
    fun `网址编出来是25×25共359个数据模块`() {
        val matrix = QrEncodeModel.encode(url)
        assertEquals(25, matrix.size)
        assertEquals(25, QrEncodeModel.SIZE)

        var dataModules = 0
        for (y in 0 until matrix.size) {
            for (x in 0 until matrix.size) {
                if (!QrEncodeModel.isReserved(x, y)) dataModules++
            }
        }
        // 规范：版本 2 有 359 个数据模块，44 个码字占 352 位，剩 7 个剩余位
        assertEquals(359, dataModules)
        assertEquals(7, dataModules - 44 * 8)
    }

    @Test
    fun `三个角上的定位符是7×7黑框加3×3实心`() {
        val matrix = QrEncodeModel.encode(url)
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
        val matrix = QrEncodeModel.encode(url)
        for (index in 0 until 8) {
            assertFalse("上边第 $index 格", matrix.isDark(index, 7))
            assertFalse("左边第 $index 格", matrix.isDark(7, index))
        }
        assertFalse(matrix.isDark(17, 7))
        assertFalse(matrix.isDark(7, 17))
    }

    @Test
    fun `时序线第6行第6列交替 偶数坐标是黑`() {
        val matrix = QrEncodeModel.encode(url)
        for (index in 8 until 17) {
            val expected = index % 2 == 0
            assertEquals("第 6 行第 $index 列", expected, matrix.isDark(index, 6))
            assertEquals("第 $index 行第 6 列", expected, matrix.isDark(6, index))
        }
    }

    @Test
    fun `校正图形只在18、18一处`() {
        val matrix = QrEncodeModel.encode(url)
        for (rowOffset in -2..2) {
            for (colOffset in -2..2) {
                val edge = kotlin.math.abs(rowOffset) == 2 || kotlin.math.abs(colOffset) == 2
                assertEquals(
                    "校正图形($rowOffset,$colOffset)",
                    edge,
                    matrix.isDark(18 + colOffset, 18 + rowOffset),
                )
            }
        }
        // 压在定位符上的那几个中心不画（(6,6) 那块本来就是定位符）
        assertTrue(QrEncodeModel.overlapsFinder(6, 6))
        assertTrue(QrEncodeModel.overlapsFinder(6, 18))
        assertTrue(QrEncodeModel.overlapsFinder(18, 6))
        assertFalse(QrEncodeModel.overlapsFinder(18, 18))
    }

    @Test
    fun `固定黑点在第17行第8列`() {
        val matrix = QrEncodeModel.encode(url)
        assertTrue(matrix.isDark(8, 17))
        assertTrue(QrEncodeModel.isReserved(8, 17))
        assertEquals(17, QrEncodeModel.DARK_MODULE_ROW)
        assertEquals(8, QrEncodeModel.DARK_MODULE_COL)
    }

    // ========== 格式信息 ==========

    /** 测试侧独立写的 BCH(15,5)。 */
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
    fun `格式信息对上规范表里的已知值`() {
        // 纠错等级 L + 掩码 0 = 111011111000100
        assertEquals(0x77C4, QrEncodeModel.formatBits(0))
        assertEquals(0b111011111000100, QrEncodeModel.formatBits(0))
        for (mask in 0..7) {
            assertEquals("掩码 $mask", bchFormat(0b01, mask), QrEncodeModel.formatBits(mask))
        }
    }

    @Test
    fun `图上画出的格式信息反解出来就是L等级`() {
        val matrix = QrEncodeModel.encode(url)
        val bits = readFormatFromTopLeft(matrix)
        // 32 种 (等级, 掩码) 全算一遍，认出来是哪一个
        var matched = -1
        for (ecl in 0..3) {
            for (mask in 0..7) {
                if (bchFormat(ecl, mask) == bits) matched = (ecl shl 3) or mask
            }
        }
        assertTrue("格式信息没认出来：$bits", matched >= 0)
        assertEquals("反解出的等级不是 L", 0b01, matched ushr 3)
        // 两处副本必须一致
        var copyTwo = 0
        fun take(index: Int, dark: Boolean) {
            if (dark) copyTwo = copyTwo or (1 shl index)
        }
        for (index in 0..7) take(index, matrix.isDark(matrix.size - 1 - index, 8))
        for (index in 8..14) take(index, matrix.isDark(8, matrix.size - 15 + index))
        assertEquals(bits, copyTwo)
    }

    // ========== 码字与纠错 ==========

    @Test
    fun `前两个码字按比特流手推可得0x41和0x36`() {
        // 网址是 19 个字符："https://" 8 个 + "163366.xyz" 10 个 + "/" 1 个
        assertEquals(19, url.length)
        val codewords = QrEncodeModel.codewords(url.toByteArray(Charsets.UTF_8))
        // 0100(模式) 00010011(长度 19) 01101000('h' = 0x68)
        // → cw0 = 0100 0001 = 0x41，cw1 = 0011 0110 = 0x36
        assertEquals(0x41, codewords[0])
        assertEquals(0x36, codewords[1])
        assertEquals(44, codewords.size)
    }

    @Test
    fun `补白用0xEC和0x11交替填到第34个数据码字`() {
        val codewords = QrEncodeModel.codewords(url.toByteArray(Charsets.UTF_8))
        // 12 位头 + 19 字节 = 164 位，补 4 位终止符 = 168 位 = 21 个码字，从第 21 个开始填白
        assertEquals(0xEC, codewords[21])
        assertEquals(0x11, codewords[22])
        assertEquals(0xEC, codewords[23])
        // 21 开始交替，到第 33 个正好是 0xEC
        assertEquals(0xEC, codewords[33])
    }

    @Test
    fun `纠错码字让整串码字在每个α的幂处都为0`() {
        val codewords = QrEncodeModel.codewords(url.toByteArray(Charsets.UTF_8))
        for (power in 0 until QrEncodeModel.EC_CODEWORDS) {
            assertEquals("α^$power 处不为 0", 0, evaluateAt(codewords, power))
        }
    }

    @Test
    fun `综合式校验能抓到被改坏的码字`() {
        val codewords = QrEncodeModel.codewords(url.toByteArray(Charsets.UTF_8))
        // 把最后一个纠错码字翻一位，综合式必须立刻不为 0（证明上面那条不是永远绿的摆设）
        val broken = codewords.copyOf()
        broken[broken.size - 1] = broken[broken.size - 1] xor 0x01
        var detected = 0
        for (power in 0 until QrEncodeModel.EC_CODEWORDS) {
            if (evaluateAt(broken, power) != 0) detected++
        }
        assertTrue("改坏一个码字竟然没被测出来", detected > 0)
    }

    @Test
    fun `超过32字节直接拒绝 不悄悄降级`() {
        val tooLong = "x".repeat(33)
        val error = runCatching { QrEncodeModel.encode(tooLong) }.exceptionOrNull()
        assertTrue(error is IllegalArgumentException)
        // 32 字节刚好装得下
        assertEquals(25, QrEncodeModel.encode("y".repeat(32)).size)
    }

    // ========== 掩码与罚分 ==========

    @Test
    fun `八种掩码公式按规范取模`() {
        assertTrue(QrEncodeModel.maskApplies(0, 0, 0))
        assertFalse(QrEncodeModel.maskApplies(0, 1, 0))
        // 掩码 1：只看行号
        assertTrue(QrEncodeModel.maskApplies(1, 5, 2))
        assertFalse(QrEncodeModel.maskApplies(1, 5, 3))
        // 掩码 2：只看列号
        assertTrue(QrEncodeModel.maskApplies(2, 3, 7))
        assertFalse(QrEncodeModel.maskApplies(2, 4, 7))
        // 掩码 3：(x + y) % 3
        assertTrue(QrEncodeModel.maskApplies(3, 0, 0))
        assertFalse(QrEncodeModel.maskApplies(3, 1, 1))
        // 掩码 4：(y / 2 + x / 3) % 2
        assertTrue(QrEncodeModel.maskApplies(4, 3, 2))
        assertFalse(QrEncodeModel.maskApplies(4, 3, 0))
    }

    @Test
    fun `连续同色的罚分是3加超出5的部分`() {
        assertEquals(0, QrEncodeModel.penaltyRuns(BooleanArray(4) { true }))
        assertEquals(3, QrEncodeModel.penaltyRuns(BooleanArray(5) { true }))
        assertEquals(4, QrEncodeModel.penaltyRuns(BooleanArray(6) { true }))
        // 黑黑黑白黑黑黑黑黑 → 长跑只有最后 5 个 → 3
        val line = booleanArrayOf(true, true, true, false, true, true, true, true, true)
        assertEquals(3, QrEncodeModel.penaltyRuns(line))
        // 全交替没有长跑
        assertEquals(0, QrEncodeModel.penaltyRuns(BooleanArray(9) { it % 2 == 0 }))
    }

    @Test
    fun `像定位符的11位序列每处40分`() {
        // 1011101 + 0000 贴在行首
        val left = booleanArrayOf(
            true, false, true, true, true, false, true,
            false, false, false, false,
        )
        assertEquals(40, QrEncodeModel.penaltyFinderLike(left))
        // 0000 + 1011101
        val right = booleanArrayOf(
            false, false, false, false,
            true, false, true, true, true, false, true,
        )
        assertEquals(40, QrEncodeModel.penaltyFinderLike(right))
        // 正常的交替行不算
        assertEquals(0, QrEncodeModel.penaltyFinderLike(BooleanArray(15) { it % 2 == 0 }))
    }

    @Test
    fun `选中的掩码是八种里罚分最低的`() {
        val codewords = QrEncodeModel.codewords(url.toByteArray(Charsets.UTF_8))
        val base = QrEncodeModel.baseMatrix()
        val matrix = QrEncodeModel.encode(url)
        val chosen = QrEncodeModel.penalty(matrix.dark)
        for (mask in 0..7) {
            val candidate = QrEncodeModel.placeData(base, codewords, mask)
            assertTrue(
                "掩码 $mask 的罚分 $chosen 竟然低于选中值",
                QrEncodeModel.penalty(candidate) >= chosen,
            )
        }
    }

    @Test
    fun `落位时不会覆盖功能图形`() {
        val codewords = QrEncodeModel.codewords(url.toByteArray(Charsets.UTF_8))
        val base = QrEncodeModel.baseMatrix()
        for (mask in 0..7) {
            val placed = QrEncodeModel.placeData(base, codewords, mask)
            for (y in 0 until 25) {
                for (x in 0 until 25) {
                    if (!QrEncodeModel.isReserved(x, y)) continue
                    // 定位符与时序线是数据碰不到的地方，逐格对拍底版
                    val finder = (x <= 7 && y <= 7) || (x >= 17 && y <= 7) || (x <= 7 && y >= 17)
                    val timing = (x == 6 || y == 6) && x in 8..16 && y in 8..16
                    if (finder || timing) {
                        assertEquals(
                            "掩码 $mask 的 ($x,$y) 被数据覆盖了",
                            base[y][x],
                            placed[y][x],
                        )
                    }
                }
            }
        }
    }
}
