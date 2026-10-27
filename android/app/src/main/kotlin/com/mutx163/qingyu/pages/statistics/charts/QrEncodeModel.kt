package com.mutx163.qingyu.pages.statistics.charts

/**
 * 导出长图品牌条右下角的二维码（Dart 用第三方包 `qr_flutter` 的 `QrImageView`）。
 *
 * 为什么自己写：`qr_flutter` 在 Kotlin 侧没有对应物，仓库也**不能**新增依赖
 * （`build.gradle` 属 Lead 专属）。而品牌条若只剩图标和文字、右下角空一块，
 * 导出长图就和 Dart 版不一样了。
 *
 * 范围刻意收窄到「够用且好验证」：
 * - 固定 **版本 2**（25×25 模块）、**纠错等级 L**、字节模式——这正是 `qr_flutter`
 *   给 `https://163366.xyz/`（20 字节）挑的规格（20 字节塞不进版本 1-L 的 17 字节）；
 * - 版本 2-L 只有一个块（34 个数据码字 + 10 个纠错码字），所以**不需要交织**；
 * - 最多 32 字节，超了直接抛异常，不会悄悄降级成半张图。
 *
 * 正确性怎么证明（见 `QrEncodeModelTest`）：
 * - 纠错码字用**综合式**独立校验：把整串码字当多项式在每个 α^i 处求值，必须为 0。
 *   这是解码器那一侧的性质，不是把编码器的中间结果抄一遍；
 * - 格式信息用**穷举反解**：32 种 (纠错等级, 掩码) 全算一遍，与图上那 15 位比对，
 *   反解出来的必须是 L 等级；另有一条对着规范表里的已知值（L + 掩码 0 → 0x77C4）钉死；
 * - 功能图形（三个定位符、时序线、校正图形、固定黑点）逐格钉住。
 */
data class QrMatrix(
    val size: Int,
    /** `dark[y][x]`，true = 黑块；第 0 行在最上面（与屏幕坐标一致）。 */
    val dark: Array<BooleanArray>,
) {
    fun isDark(x: Int, y: Int): Boolean = dark[y][x]

    /** 黑块个数（单测断言与覆盖率用）。 */
    val darkCount: Int get() = dark.sumOf { row -> row.count { it } }
}

object QrEncodeModel {

    /** 固定版本 2。 */
    const val VERSION = 2

    /** 版本 2 = 17 + 4 × 2 = 25 个模块。 */
    const val SIZE = 17 + 4 * VERSION

    /** 版本 2-L：34 个数据码字。 */
    const val DATA_CODEWORDS = 34

    /** 版本 2-L：10 个纠错码字（单块，无需交织）。 */
    const val EC_CODEWORDS = 10

    /** 272 位数据减去 4 位模式 + 8 位长度 = 260 位 → 最多 32 字节。 */
    const val MAX_BYTES = 32

    /** 字节模式指示符 0100。 */
    const val MODE_BYTE = 0b0100

    /** 版本 1~9 的字节模式长度字段是 8 位。 */
    const val COUNT_BITS = 8

    /** 版本 2 的校正图形中心坐标；落在定位符范围里的那几个要跳过。 */
    private val ALIGNMENT_CENTERS = intArrayOf(6, 18)

    /** 固定黑点：第 `4 × 版本 + 9` = 17 行、第 8 列（规范 `(8, 4V + 9)` 的坐标对写作 列、行）。 */
    const val DARK_MODULE_ROW = 4 * VERSION + 9
    const val DARK_MODULE_COL = 8

    /** 格式化信息固定掩码。 */
    const val FORMAT_MASK = 0x5412

    /** BCH(15,5) 生成多项式 `10100110111`。 */
    const val FORMAT_GENERATOR = 0x537

    /** 纠错等级 L 在格式信息里的两位编码。 */
    const val ECL_L_BITS = 0b01

    /**
     * 编成二维码矩阵（8 种掩码各试一遍，取罚分最低的）。
     *
     * @throws IllegalArgumentException 文本超过 [MAX_BYTES] 字节
     */
    fun encode(text: String): QrMatrix {
        val codewords = codewords(text.toByteArray(Charsets.UTF_8))
        val base = baseMatrix()
        var best: Array<BooleanArray>? = null
        var bestPenalty = Int.MAX_VALUE
        for (mask in 0..7) {
            val candidate = placeData(base, codewords, mask)
            val score = penalty(candidate)
            if (score < bestPenalty) {
                bestPenalty = score
                best = candidate
            }
        }
        return QrMatrix(SIZE, requireNotNull(best) { "掩码选择失败" })
    }

    // ========== 码字 ==========

    /** 数据位流 → 补白 → 前面 34 个数据码字 + 后面 10 个纠错码字。 */
    fun codewords(data: ByteArray): IntArray {
        require(data.size <= MAX_BYTES) {
            "固定版本 2-L 最多 $MAX_BYTES 字节，实际 ${data.size} 字节"
        }
        val bits = mutableListOf<Int>()
        appendBits(bits, MODE_BYTE, 4)
        appendBits(bits, data.size, COUNT_BITS)
        for (byte in data) appendBits(bits, byte.toInt() and 0xFF, 8)

        val capacityBits = DATA_CODEWORDS * 8
        // 终止符最多 4 个 0，剩余空间不够就少补
        repeat(minOf(4, capacityBits - bits.size)) { bits.add(0) }
        // 补到整字节
        while (bits.size % 8 != 0) bits.add(0)

        val result = IntArray(DATA_CODEWORDS + EC_CODEWORDS)
        for (index in bits.indices step 8) {
            var value = 0
            for (offset in 0 until 8) value = (value shl 1) or bits[index + offset]
            result[index / 8] = value
        }
        // 剩余位置用 0xEC / 0x11 交替填满
        var pad = 0xEC
        for (index in bits.size / 8 until DATA_CODEWORDS) {
            result[index] = pad
            pad = if (pad == 0xEC) 0x11 else 0xEC
        }
        rsRemainder(result.copyOf(DATA_CODEWORDS), EC_CODEWORDS)
            .copyInto(result, DATA_CODEWORDS)
        return result
    }

    private fun appendBits(target: MutableList<Int>, value: Int, length: Int) {
        for (shift in length - 1 downTo 0) target.add((value ushr shift) and 1)
    }

    // ========== GF(256) 与 Reed-Solomon ==========

    private val EXP = IntArray(512)
    private val LOG = IntArray(256)

    init {
        var value = 1
        for (index in 0 until 255) {
            EXP[index] = value
            LOG[value] = index
            value = value shl 1
            if (value and 0x100 != 0) value = value xor 0x11D
        }
        for (index in 255 until 512) EXP[index] = EXP[index - 255]
    }

    /** GF(256) 乘法（本原多项式 0x11D）。 */
    fun gfMul(left: Int, right: Int): Int =
        if (left == 0 || right == 0) 0 else EXP[LOG[left] + LOG[right]]

    /** α 的幂（超过 255 自动回绕）。 */
    fun gfExp(power: Int): Int = EXP[((power % 255) + 255) % 255]

    /** 生成多项式，次数 [degree]；返回数组含全部系数，最高次系数是 1。 */
    fun rsGenerator(degree: Int): IntArray {
        var generator = intArrayOf(1)
        for (index in 0 until degree) {
            val root = gfExp(index)
            val next = IntArray(generator.size + 1)
            for (position in generator.indices) {
                next[position] = next[position] xor generator[position]
                next[position + 1] = next[position + 1] xor gfMul(generator[position], root)
            }
            generator = next
        }
        return generator
    }

    /** 数据码字的 RS 余数，就是纠错码字。 */
    fun rsRemainder(data: IntArray, degree: Int): IntArray {
        val generator = rsGenerator(degree)
        val remainder = IntArray(degree)
        for (byte in data) {
            val factor = (byte xor remainder[0]) and 0xFF
            for (index in 0 until degree - 1) remainder[index] = remainder[index + 1]
            remainder[degree - 1] = 0
            if (factor != 0) {
                for (index in 0 until degree) {
                    remainder[index] = remainder[index] xor gfMul(generator[index + 1], factor)
                }
            }
        }
        return remainder
    }

    // ========== 矩阵底版（功能图形） ==========

    /** 画出与数据无关的功能图形。 */
    fun baseMatrix(): Array<BooleanArray> {
        val matrix = Array(SIZE) { BooleanArray(SIZE) }
        drawFinder(matrix, 0, 0)
        drawFinder(matrix, SIZE - 7, 0)
        drawFinder(matrix, 0, SIZE - 7)
        // 时序线：第 6 行 / 第 6 列交替，偶数坐标是黑的
        for (index in 8 until SIZE - 8) {
            val dark = index % 2 == 0
            matrix[6][index] = dark
            matrix[index][6] = dark
        }
        // 校正图形：版本 2 只有 (18, 18) 一个不压在定位符上
        for (rowCenter in ALIGNMENT_CENTERS) {
            for (colCenter in ALIGNMENT_CENTERS) {
                if (overlapsFinder(rowCenter, colCenter)) continue
                drawAlignment(matrix, rowCenter, colCenter)
            }
        }
        matrix[DARK_MODULE_ROW][DARK_MODULE_COL] = true
        return matrix
    }

    /** 5×5 的校正图形会不会压在某个定位符（含白边）上。 */
    fun overlapsFinder(rowCenter: Int, colCenter: Int): Boolean {
        val corners = arrayOf(
            0 to 0,
            (SIZE - 8) to 0,
            0 to (SIZE - 8),
        )
        for ((top, left) in corners) {
            val rowHit = rowCenter - 2 <= top + 7 && rowCenter + 2 >= top
            val colHit = colCenter - 2 <= left + 7 && colCenter + 2 >= left
            if (rowHit && colHit) return true
        }
        return false
    }

    private fun drawFinder(matrix: Array<BooleanArray>, left: Int, top: Int) {
        for (row in 0 until 7) {
            for (col in 0 until 7) {
                val ring = row == 0 || row == 6 || col == 0 || col == 6
                val core = row in 2..4 && col in 2..4
                matrix[top + row][left + col] = ring || core
            }
        }
    }

    private fun drawAlignment(matrix: Array<BooleanArray>, rowCenter: Int, colCenter: Int) {
        for (rowOffset in -2..2) {
            for (colOffset in -2..2) {
                val edge = kotlin.math.abs(rowOffset) == 2 || kotlin.math.abs(colOffset) == 2
                matrix[rowCenter + rowOffset][colCenter + colOffset] = edge
            }
        }
    }

    /** 该格是否被功能图形 / 格式信息占用（数据不能落在这里）。 */
    fun isReserved(x: Int, y: Int): Boolean {
        // 三个定位符连同白边：8×8
        if (x <= 7 && y <= 7) return true
        if (x >= SIZE - 8 && y <= 7) return true
        if (x <= 7 && y >= SIZE - 8) return true
        // 时序线
        if (x == 6 || y == 6) return true
        // 校正图形（版本 2 唯一一个，18±2）
        if (x in 16..20 && y in 16..20) return true
        // 格式信息两份副本
        if (y == 8 && (x <= 8 || x >= SIZE - 8)) return true
        if (x == 8 && (y <= 8 || y >= SIZE - 7)) return true
        // 固定黑点（第 17 行第 8 列；它不属于上面两段格式信息副本）
        if (x == DARK_MODULE_COL && y == DARK_MODULE_ROW) return true
        return false
    }

    // ========== 数据落位 ==========

    /**
     * 把码字按之字形铺进矩阵，再整张施加掩码、回写格式信息。
     *
     * @param base 带功能图形的底版（不会被修改）
     * @param mask 0~7
     */
    fun placeData(
        base: Array<BooleanArray>,
        codewords: IntArray,
        mask: Int,
    ): Array<BooleanArray> {
        val matrix = Array(SIZE) { base[it].copyOf() }
        var bitIndex = 0
        val totalBits = codewords.size * 8
        var upward = true
        var right = SIZE - 1
        while (right >= 1) {
            if (right == 6) right -= 1 // 第 6 列是时序线，整列跳过
            for (step in 0 until SIZE) {
                val y = if (upward) SIZE - 1 - step else step
                for (columnOffset in 0..1) {
                    val x = right - columnOffset
                    if (isReserved(x, y)) continue
                    var dark = false
                    if (bitIndex < totalBits) {
                        val byte = codewords[bitIndex / 8]
                        dark = (byte ushr (7 - (bitIndex % 8))) and 1 == 1
                        bitIndex++
                    }
                    if (maskApplies(mask, x, y)) dark = !dark
                    matrix[y][x] = dark
                }
            }
            upward = !upward
            right -= 2
        }
        writeFormat(matrix, mask)
        return matrix
    }

    /** 规范里的 8 种掩码公式。 */
    fun maskApplies(mask: Int, x: Int, y: Int): Boolean = when (mask) {
        0 -> (x + y) % 2 == 0
        1 -> y % 2 == 0
        2 -> x % 3 == 0
        3 -> (x + y) % 3 == 0
        4 -> (y / 2 + x / 3) % 2 == 0
        5 -> (x * y) % 2 + (x * y) % 3 == 0
        6 -> ((x * y) % 2 + (x * y) % 3) % 2 == 0
        7 -> ((x + y) % 2 + (x * y) % 3) % 2 == 0
        else -> error("掩码只可能是 0~7，收到 $mask")
    }

    /**
     * 格式信息 15 位：5 位数据（等级 2 位 + 掩码 3 位）、10 位 BCH 校验，最后异或 [FORMAT_MASK]。
     *
     * 已知对照：等级 L + 掩码 0 → `0x77C4`（规范表里的 111011111000100）。
     */
    fun formatBits(mask: Int): Int {
        val data = (ECL_L_BITS shl 3) or (mask and 0b111)
        var remainder = data
        repeat(10) { remainder = (remainder shl 1) xor ((remainder ushr 9) * FORMAT_GENERATOR) }
        return ((data shl 10) or (remainder and 0x3FF)) xor FORMAT_MASK
    }

    /** 格式信息两处副本（规范要求画两遍，扫码器任取其一）。 */
    private fun writeFormat(matrix: Array<BooleanArray>, mask: Int) {
        val bits = formatBits(mask)
        fun bit(index: Int) = (bits ushr index) and 1 == 1
        // 第一份：围着左上定位符
        for (index in 0..5) matrix[index][8] = bit(index)
        matrix[7][8] = bit(6)
        matrix[8][8] = bit(7)
        matrix[8][7] = bit(8)
        for (index in 9..14) matrix[8][14 - index] = bit(index)
        // 第二份：右上 + 左下
        for (index in 0..7) matrix[8][SIZE - 1 - index] = bit(index)
        for (index in 8..14) matrix[SIZE - 15 + index][8] = bit(index)
        // 固定黑点必须保持是黑的
        matrix[DARK_MODULE_ROW][DARK_MODULE_COL] = true
    }

    // ========== 罚分（选掩码用） ==========

    /** 四类罚分之和，越小越好。 */
    fun penalty(matrix: Array<BooleanArray>): Int {
        val size = matrix.size
        var total = 0
        // 规则 1：连续同色 ≥5 个，3 + (长度 − 5)
        for (row in 0 until size) total += penaltyRuns(BooleanArray(size) { matrix[row][it] })
        for (col in 0 until size) total += penaltyRuns(BooleanArray(size) { matrix[it][col] })
        // 规则 2：2×2 同色，每块 3 分
        for (row in 0 until size - 1) {
            for (col in 0 until size - 1) {
                val value = matrix[row][col]
                if (value == matrix[row][col + 1] &&
                    value == matrix[row + 1][col] &&
                    value == matrix[row + 1][col + 1]
                ) {
                    total += 3
                }
            }
        }
        // 规则 3：像定位符的 11 位序列，每处 40 分
        for (row in 0 until size) total += penaltyFinderLike(BooleanArray(size) { matrix[row][it] })
        for (col in 0 until size) total += penaltyFinderLike(BooleanArray(size) { matrix[it][col] })
        // 规则 4：黑块占比偏离 50%，每 5% 扣 10 分
        var darkCount = 0
        for (row in matrix) for (cell in row) if (cell) darkCount++
        val percent = darkCount * 100 / (size * size)
        total += (kotlin.math.abs(percent - 50) / 5) * 10
        return total
    }

    /** 一行 / 一列里连续同色的罚分。 */
    fun penaltyRuns(line: BooleanArray): Int {
        var total = 0
        var runLength = 1
        for (index in 1 until line.size) {
            if (line[index] == line[index - 1]) {
                runLength++
            } else {
                total += if (runLength >= 5) 3 + (runLength - 5) else 0
                runLength = 1
            }
        }
        return total + if (runLength >= 5) 3 + (runLength - 5) else 0
    }

    /** 规范里两条「像定位符」的 11 位序列。 */
    private val FINDER_LIKE_LEFT = booleanArrayOf(
        true, false, true, true, true, false, true, false, false, false, false,
    )
    private val FINDER_LIKE_RIGHT = booleanArrayOf(
        false, false, false, false, true, false, true, true, true, false, true,
    )

    /** 一条线里出现这两条序列的次数 × 40。 */
    fun penaltyFinderLike(line: BooleanArray): Int {
        var total = 0
        for (start in line.indices) {
            if (matchesAt(line, start, FINDER_LIKE_LEFT)) total += 40
            if (matchesAt(line, start, FINDER_LIKE_RIGHT)) total += 40
        }
        return total
    }

    private fun matchesAt(line: BooleanArray, start: Int, pattern: BooleanArray): Boolean {
        if (start + pattern.size > line.size) return false
        for (offset in pattern.indices) {
            if (line[start + offset] != pattern[offset]) return false
        }
        return true
    }
}
