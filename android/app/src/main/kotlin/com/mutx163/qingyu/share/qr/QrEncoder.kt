package com.mutx163.qingyu.share.qr

/**
 * 二维码编码器（纯 Kotlin，零第三方依赖）。
 *
 * ## 为什么有它
 *
 * Dart 发送页用 pub `qr` 3.0.2 的 `QrCode.fromData(data, errorCorrectLevel: L)`
 * （见 `lib/services/qr_transfer/qr_transfer_frame_worker.dart`）。Kotlin 侧原本**没有任何
 * 编码器**，所以发送页的二维码一直是空槽位（目录里标着「暂不可用：缺宿主槽位」）。
 *
 * 这里把 `qr` 3.0.2 的编码路径**逐行移植**成 Kotlin，目标是**逐位对拍**：
 * 同一个字符串 → 完全相同的模块矩阵。逐位一致比「扫得出」更强——它保证与 Dart 版像素级相同。
 *
 * ## 几个必须照抄的细节（差一处矩阵就不同）
 *
 * - **版本选择**：`QrCode.fromData` 从版本 1 起找第一个放得下的（字节模式、指定纠错等级），
 *   到版本 39 都放不下就取 40；
 * - **掩码选择**：沿用 `qr`（qrcode.js 血统）的 `_lostPoint` 罚分，**不是** ISO 那套规则。
 *   罚分用 double 计算，并列时保留**低编号**掩码；
 * - **补码**：数据位之后若还剩 ≥4 位补 4 位终止符，再补 0 到整字节，剩余用 `0xEC`/`0x11`
 *   交替填满；跨块按标准交织。
 * - 罚分用的候选图是 `test=true` 的：格式信息 / 版本信息 / 固定暗模块此时都填**亮**，
 *   真实矩阵才写真实格式位。这一点也照抄，否则选出的掩码会不同。
 *
 * ## 支持范围
 *
 * 字节模式（UTF-8）、纠错等级 L/M/Q/H、版本 1–40（自动或显式）。
 * 项目实际只用「字节模式 + 显式纠错等级」，已全覆盖。
 */

/** 纠错等级。数值对齐 `qr` 包的 `QrErrorCorrectLevel`：L=1 / M=0 / Q=3 / H=2。 */
enum class QrErrorCorrectionLevel(val wire: Int) {
    L(1),
    M(0),
    Q(3),
    H(2),
}

/**
 * 编好的二维码矩阵。
 *
 * @property size 边长（模块数），版本 V 时为 `17 + 4 * V`
 * @property dark `dark[y][x]`，`true` = 黑块；第 0 行在最上面（与屏幕坐标一致）
 */
class QrMatrix(
    val size: Int,
    val dark: Array<BooleanArray>,
) {
    init {
        require(dark.size == size) { "dark.size=${dark.size} 与 size=$size 不符" }
        dark.forEach { row -> require(row.size == size) { "行宽 ${row.size} 与 size=$size 不符" } }
    }

    fun isDark(x: Int, y: Int): Boolean = dark[y][x]

    /** 黑块个数（单测断言用）。 */
    val darkCount: Int get() = dark.sumOf { row -> row.count { it } }

    /** 按行优先压成 4bit/字符的十六进制串（末尾不足 4bit 的位补 0），便于与参考值逐位比对。 */
    fun toHexString(): String {
        val sb = StringBuilder(size * size)
        for (y in 0 until size) for (x in 0 until size) sb.append(if (dark[y][x]) '1' else '0')
        while (sb.length % 4 != 0) sb.append('0')
        val out = StringBuilder(sb.length / 4)
        var i = 0
        while (i < sb.length) {
            var value = 0
            for (k in 0 until 4) value = (value shl 1) or (if (sb[i + k] == '1') 1 else 0)
            out.append(HEX[value])
            i += 4
        }
        return out.toString()
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is QrMatrix) return false
        if (size != other.size) return false
        for (y in 0 until size) if (!dark[y].contentEquals(other.dark[y])) return false
        return true
    }

    override fun hashCode(): Int = 31 * size + dark.fold(0) { acc, row -> 31 * acc + row.contentHashCode() }

    private companion object {
        const val HEX = "0123456789abcdef"
    }
}

/** 二维码编码入口。 */
object QrEncoder {

    /**
     * 把 [text]（UTF-8）编成二维码，自动选版本（与 Dart `QrCode.fromData` 同口径）。
     *
     * @throws IllegalArgumentException 文本长到版本 40 也放不下
     */
    fun encode(text: String, ec: QrErrorCorrectionLevel = QrErrorCorrectionLevel.L): QrMatrix {
        val bytes = text.toByteArray(Charsets.UTF_8)
        val type = calculateTypeNumber(ec.wire, bytes)
        return encodeToMatrix(type, ec.wire, bytes)
    }

    /**
     * 用**显式版本**（1–40）编码，行为对齐 `QrCode(version, ec)..addData`。
     *
     * @throws IllegalArgumentException 版本越界，或文本放不进该版本
     */
    fun encode(text: String, ec: QrErrorCorrectionLevel, version: Int): QrMatrix {
        require(version in 1..40) { "版本必须在 1..40，收到 $version" }
        val bytes = text.toByteArray(Charsets.UTF_8)
        return encodeToMatrix(version, ec.wire, bytes)
    }

    private fun encodeToMatrix(type: Int, ecWire: Int, bytes: ByteArray): QrMatrix {
        val dataCache = createData(type, ecWire, bytes)
        val builder = QrImageBuilder(type, ecWire, dataCache)
        var minLostPoint = 0.0
        var bestMask = -1
        for (mask in 0..7) {
            builder.makeImpl(mask, test = true)
            val lostPoint = lostPoint(builder.modules, builder.moduleCount)
            if (mask == 0 || minLostPoint > lostPoint) {
                minLostPoint = lostPoint
                bestMask = mask
            }
        }
        val dark = builder.build(bestMask)
        return QrMatrix(type * 4 + 17, dark)
    }

    // ======================================================================
    // 版本选择 / 码字生成（port of qr_code.dart）
    // ======================================================================

    private const val MODE_8BIT_BYTE = 1 shl 2
    private const val PAD0 = 0xEC
    private const val PAD1 = 0x11

    private fun calculateTypeNumber(ecWire: Int, bytes: ByteArray): Int {
        for (type in 1 until 40) {
            val rsBlocks = QrRsBlocks.get(type, ecWire)
            val buffer = QrBitBuffer()
            var totalDataCount = 0
            for (block in rsBlocks) totalDataCount += block.dataCount
            buffer.put(MODE_8BIT_BYTE, 4)
            buffer.put(bytes.size, lengthInBits(MODE_8BIT_BYTE, type))
            for (byte in bytes) buffer.put(byte.toInt() and 0xFF, 8)
            if (buffer.length <= totalDataCount * 8) return type
        }
        return 40
    }

    private fun lengthInBits(mode: Int, type: Int): Int {
        require(mode == MODE_8BIT_BYTE) { "本编码器只支持字节模式，收到 mode=$mode" }
        return when {
            type in 1..9 -> 8
            type in 10..40 -> 16
            else -> throw IllegalArgumentException("type:$type")
        }
    }

    private fun createData(type: Int, ecWire: Int, bytes: ByteArray): IntArray {
        val rsBlocks = QrRsBlocks.get(type, ecWire)
        val buffer = QrBitBuffer()
        buffer.put(MODE_8BIT_BYTE, 4)
        buffer.put(bytes.size, lengthInBits(MODE_8BIT_BYTE, type))
        for (byte in bytes) buffer.put(byte.toInt() and 0xFF, 8)

        var totalDataCount = 0
        for (block in rsBlocks) totalDataCount += block.dataCount
        val totalByteCount = totalDataCount * 8
        require(buffer.length <= totalByteCount) {
            "内容过长：数据位 ${buffer.length} 超过容量 $totalByteCount（版本 $type，纠错等级 wire=$ecWire）"
        }

        // 终止符（若有 ≥4 位空间）
        if (buffer.length + 4 <= totalByteCount) buffer.put(0, 4)
        // 补到整字节
        while (buffer.length % 8 != 0) buffer.putBit(false)
        // 0xEC / 0x11 交替填满
        val bitDataCount = totalDataCount * 8
        var padCount = 0
        while (buffer.length < bitDataCount) {
            buffer.put(if (padCount % 2 == 0) PAD0 else PAD1, 8)
            padCount++
        }
        return createBytes(buffer, rsBlocks)
    }

    private fun createBytes(buffer: QrBitBuffer, rsBlocks: List<QrRsBlock>): IntArray {
        var offset = 0
        var maxDcCount = 0
        var maxEcCount = 0
        val dcData = arrayOfNulls<IntArray>(rsBlocks.size)
        val ecData = arrayOfNulls<IntArray>(rsBlocks.size)

        for (r in rsBlocks.indices) {
            val dcCount = rsBlocks[r].dataCount
            val ecCount = rsBlocks[r].totalCount - dcCount
            maxDcCount = maxOf(maxDcCount, dcCount)
            maxEcCount = maxOf(maxEcCount, ecCount)

            val dcItem = IntArray(dcCount)
            for (i in dcItem.indices) dcItem[i] = 0xFF and buffer.getByte(i + offset)
            offset += dcCount

            val rsPoly = errorCorrectPolynomial(ecCount)
            val rawPoly = QrPolynomial.of(dcItem, rsPoly.length - 1)
            val modPoly = rawPoly.mod(rsPoly)
            val ecItem = IntArray(rsPoly.length - 1)
            for (i in ecItem.indices) {
                val modIndex = i + modPoly.length - ecItem.size
                ecItem[i] = if (modIndex >= 0) modPoly[modIndex] else 0
            }
            dcData[r] = dcItem
            ecData[r] = ecItem
        }

        val data = ArrayList<Int>()
        for (i in 0 until maxDcCount) {
            for (r in rsBlocks.indices) {
                val block = dcData[r]!!
                if (i < block.size) data.add(block[i])
            }
        }
        for (i in 0 until maxEcCount) {
            for (r in rsBlocks.indices) {
                val block = ecData[r]!!
                if (i < block.size) data.add(block[i])
            }
        }
        return data.toIntArray()
    }

    private fun errorCorrectPolynomial(errorCorrectLength: Int): QrPolynomial {
        var a = QrPolynomial.of(intArrayOf(1), 0)
        for (i in 0 until errorCorrectLength) {
            a = a.multiply(QrPolynomial.of(intArrayOf(1, QrGalois.gexp(i)), 0))
        }
        return a
    }

    // ======================================================================
    // 矩阵绘制 / 掩码 / 罚分（port of qr_image.dart）
    // ======================================================================

    private class QrImageBuilder(
        private val typeNumber: Int,
        private val ecWire: Int,
        private val dataCache: IntArray,
    ) {
        val moduleCount: Int = typeNumber * 4 + 17
        var modules: Array<Array<Boolean?>> = emptyArray()
            private set

        fun build(maskPattern: Int): Array<BooleanArray> {
            makeImpl(maskPattern, test = false)
            return Array(moduleCount) { row -> BooleanArray(moduleCount) { col -> modules[row][col]!! } }
        }

        fun makeImpl(maskPattern: Int, test: Boolean) {
            resetModules()
            setupPositionProbePattern(0, 0)
            setupPositionProbePattern(moduleCount - 7, 0)
            setupPositionProbePattern(0, moduleCount - 7)
            setupPositionAdjustPattern()
            setupTimingPattern()
            setupTypeInfo(maskPattern, test)
            if (typeNumber >= 7) setupTypeNumber(test)
            mapData(dataCache, maskPattern)
        }

        private fun resetModules() {
            modules = Array(moduleCount) { arrayOfNulls<Boolean>(moduleCount) }
        }

        private fun setupPositionProbePattern(row: Int, col: Int) {
            for (r in -1..7) {
                if (row + r <= -1 || moduleCount <= row + r) continue
                for (c in -1..7) {
                    if (col + c <= -1 || moduleCount <= col + c) continue
                    val dark = (0 <= r && r <= 6 && (c == 0 || c == 6)) ||
                        (0 <= c && c <= 6 && (r == 0 || r == 6)) ||
                        (2 <= r && r <= 4 && 2 <= c && c <= 4)
                    modules[row + r][col + c] = dark
                }
            }
        }

        private fun setupPositionAdjustPattern() {
            val pos = QrUtil.patternPosition(typeNumber)
            for (i in pos.indices) {
                for (j in pos.indices) {
                    val row = pos[i]
                    val col = pos[j]
                    if (modules[row][col] != null) continue
                    for (r in -2..2) {
                        for (c in -2..2) {
                            modules[row + r][col + c] =
                                r == -2 || r == 2 || c == -2 || c == 2 || (r == 0 && c == 0)
                        }
                    }
                }
            }
        }

        private fun setupTimingPattern() {
            for (r in 8 until moduleCount - 8) {
                if (modules[r][6] != null) continue
                modules[r][6] = r % 2 == 0
            }
            for (c in 8 until moduleCount - 8) {
                if (modules[6][c] != null) continue
                modules[6][c] = c % 2 == 0
            }
        }

        private fun setupTypeInfo(maskPattern: Int, test: Boolean) {
            val data = (ecWire shl 3) or maskPattern
            val bits = QrUtil.bchTypeInfo(data)
            // 竖排
            for (i in 0..14) {
                val mod = !test && ((bits ushr i) and 1) == 1
                when {
                    i < 6 -> modules[i][8] = mod
                    i < 8 -> modules[i + 1][8] = mod
                    else -> modules[moduleCount - 15 + i][8] = mod
                }
            }
            // 横排
            for (i in 0..14) {
                val mod = !test && ((bits ushr i) and 1) == 1
                when {
                    i < 8 -> modules[8][moduleCount - i - 1] = mod
                    i == 8 -> modules[8][15 - i - 1 + 1] = mod
                    else -> modules[8][15 - i - 1] = mod
                }
            }
            // 固定暗模块
            modules[moduleCount - 8][8] = !test
        }

        private fun setupTypeNumber(test: Boolean) {
            val bits = QrUtil.bchTypeNumber(typeNumber)
            for (i in 0..17) {
                val mod = !test && ((bits ushr i) and 1) == 1
                modules[i / 3][i % 3 + moduleCount - 8 - 3] = mod
            }
            for (i in 0..17) {
                val mod = !test && ((bits ushr i) and 1) == 1
                modules[i % 3 + moduleCount - 8 - 3][i / 3] = mod
            }
        }

        private fun mapData(data: IntArray, maskPattern: Int) {
            var inc = -1
            var row = moduleCount - 1
            var bitIndex = 7
            var byteIndex = 0

            var col = moduleCount - 1
            while (col > 0) {
                if (col == 6) col -= 1
                while (true) {
                    for (c in 0..1) {
                        if (modules[row][col - c] == null) {
                            var dark = false
                            if (byteIndex < data.size) {
                                dark = ((data[byteIndex] ushr bitIndex) and 1) == 1
                            }
                            if (maskFn(maskPattern, row, col - c)) dark = !dark
                            modules[row][col - c] = dark
                            bitIndex--
                            if (bitIndex == -1) {
                                byteIndex++
                                bitIndex = 7
                            }
                        }
                    }
                    row += inc
                    if (row < 0 || moduleCount <= row) {
                        row -= inc
                        inc = -inc
                        break
                    }
                }
                col -= 2
            }
        }
    }

    private fun maskFn(maskPattern: Int, i: Int, j: Int): Boolean = when (maskPattern) {
        0 -> (i + j) % 2 == 0
        1 -> i % 2 == 0
        2 -> j % 3 == 0
        3 -> (i + j) % 3 == 0
        4 -> (i / 2 + j / 3) % 2 == 0
        5 -> (i * j) % 2 + (i * j) % 3 == 0
        6 -> ((i * j) % 2 + (i * j) % 3) % 2 == 0
        7 -> ((i * j) % 3 + (i + j) % 2) % 2 == 0
        else -> throw IllegalArgumentException("bad maskPattern:$maskPattern")
    }

    private fun lostPoint(m: Array<Array<Boolean?>>, moduleCount: Int): Double {
        var lostPoint = 0.0

        // LEVEL1：3×3 邻域同色计数（qrcode.js 口径，不是 ISO 连续段）
        for (row in 0 until moduleCount) {
            for (col in 0 until moduleCount) {
                var sameCount = 0
                val dark = m[row][col]!!
                for (r in -1..1) {
                    if (row + r < 0 || moduleCount <= row + r) continue
                    for (c in -1..1) {
                        if (col + c < 0 || moduleCount <= col + c) continue
                        if (r == 0 && c == 0) continue
                        if (dark == m[row + r][col + c]!!) sameCount++
                    }
                }
                if (sameCount > 5) lostPoint += (3 + sameCount - 5).toDouble()
            }
        }

        // LEVEL2：2×2 全黑或全白，各 3 分
        for (row in 0 until moduleCount - 1) {
            for (col in 0 until moduleCount - 1) {
                var count = 0
                if (m[row][col]!!) count++
                if (m[row + 1][col]!!) count++
                if (m[row][col + 1]!!) count++
                if (m[row + 1][col + 1]!!) count++
                if (count == 0 || count == 4) lostPoint += 3.0
            }
        }

        // LEVEL3：横向 / 纵向出现 1011101，各 40 分
        for (row in 0 until moduleCount) {
            for (col in 0 until moduleCount - 6) {
                if (m[row][col]!! &&
                    !m[row][col + 1]!! &&
                    m[row][col + 2]!! &&
                    m[row][col + 3]!! &&
                    m[row][col + 4]!! &&
                    !m[row][col + 5]!! &&
                    m[row][col + 6]!!
                ) {
                    lostPoint += 40.0
                }
            }
        }
        for (col in 0 until moduleCount) {
            for (row in 0 until moduleCount - 6) {
                if (m[row][col]!! &&
                    !m[row + 1][col]!! &&
                    m[row + 2][col]!! &&
                    m[row + 3][col]!! &&
                    m[row + 4][col]!! &&
                    !m[row + 5][col]!! &&
                    m[row + 6][col]!!
                ) {
                    lostPoint += 40.0
                }
            }
        }

        // LEVEL4：黑块比例偏离 50%
        var darkCount = 0
        for (col in 0 until moduleCount) {
            for (row in 0 until moduleCount) {
                if (m[row][col]!!) darkCount++
            }
        }
        val ratio = kotlin.math.abs(100.0 * darkCount / moduleCount / moduleCount - 50.0) / 5.0
        return lostPoint + ratio * 10.0
    }
}

// ======================================================================
// GF(256) 与多项式（port of math.dart / polynomial.dart）
// ======================================================================

private object QrGalois {
    val expTable = IntArray(256)
    val logTable = IntArray(256)

    init {
        for (i in 0..7) expTable[i] = 1 shl i
        for (i in 8..255) expTable[i] = expTable[i - 4] xor expTable[i - 5] xor expTable[i - 6] xor expTable[i - 8]
        for (i in 0 until 255) logTable[expTable[i]] = i
    }

    fun glog(n: Int): Int {
        require(n >= 1) { "glog($n)" }
        return logTable[n]
    }

    fun gexp(n: Int): Int = expTable[((n % 255) + 255) % 255]
}

private class QrPolynomial private constructor(private val values: IntArray) {
    operator fun get(index: Int): Int = values[index]
    val length: Int get() = values.size

    fun multiply(other: QrPolynomial): QrPolynomial {
        val result = IntArray(length + other.length - 1)
        for (i in 0 until length) {
            for (j in 0 until other.length) {
                result[i + j] = result[i + j] xor QrGalois.gexp(QrGalois.glog(this[i]) + QrGalois.glog(other[j]))
            }
        }
        return of(result, 0)
    }

    fun mod(other: QrPolynomial): QrPolynomial {
        if (length - other.length < 0) return this
        val ratio = QrGalois.glog(this[0]) - QrGalois.glog(other[0])
        val value = IntArray(length)
        for (i in 0 until length) value[i] = this[i]
        for (i in 0 until other.length) value[i] = value[i] xor QrGalois.gexp(QrGalois.glog(other[i]) + ratio)
        return of(value, 0).mod(other)
    }

    companion object {
        /** port of `QrPolynomial` 工厂：先剥掉前导 0，再在末尾追加 `shift` 个 0。 */
        fun of(thing: IntArray, shift: Int): QrPolynomial {
            var offset = 0
            while (offset < thing.size && thing[offset] == 0) offset++
            val values = IntArray(thing.size - offset + shift)
            for (i in 0 until thing.size - offset) values[i] = thing[i + offset]
            return QrPolynomial(values)
        }
    }
}

// ======================================================================
// 位缓冲（port of bit_buffer.dart）
// ======================================================================

private class QrBitBuffer {
    private val buffer = ArrayList<Int>()

    var length = 0
        private set

    fun getByte(index: Int): Int = buffer[index]

    fun put(number: Int, length: Int) {
        for (i in 0 until length) {
            val bit = ((number ushr (length - i - 1)) and 1) == 1
            putBit(bit)
        }
    }

    fun putBit(bit: Boolean) {
        val bufIndex = length / 8
        if (buffer.size <= bufIndex) buffer.add(0)
        if (bit) buffer[bufIndex] = buffer[bufIndex] or (0x80 ushr (length % 8))
        length++
    }
}

// ======================================================================
// 纠错块表（port of rs_block.dart）
// ======================================================================

private class QrRsBlock(val totalCount: Int, val dataCount: Int)

private object QrRsBlocks {
    fun get(typeNumber: Int, ecWire: Int): List<QrRsBlock> {
        val row = TABLE[(typeNumber - 1) * 4 + levelIndex(ecWire)]
        val list = ArrayList<QrRsBlock>()
        var i = 0
        while (i < row.size) {
            val count = row[i]
            val totalCount = row[i + 1]
            val dataCount = row[i + 2]
            repeat(count) { list.add(QrRsBlock(totalCount, dataCount)) }
            i += 3
        }
        return list
    }

    private fun levelIndex(ecWire: Int): Int = when (ecWire) {
        1 -> 0 // L
        0 -> 1 // M
        3 -> 2 // Q
        2 -> 3 // H
        else -> throw IllegalArgumentException("bad errorCorrectLevel:$ecWire")
    }

    // 每版本 4 行，顺序 L / M / Q / H。数值照抄 qr 3.0.2 的 _rsBlockTable。
    private val TABLE: Array<IntArray> = arrayOf(
        // 1
        intArrayOf(1, 26, 19), intArrayOf(1, 26, 16), intArrayOf(1, 26, 13), intArrayOf(1, 26, 9),
        // 2
        intArrayOf(1, 44, 34), intArrayOf(1, 44, 28), intArrayOf(1, 44, 22), intArrayOf(1, 44, 16),
        // 3
        intArrayOf(1, 70, 55), intArrayOf(1, 70, 44), intArrayOf(2, 35, 17), intArrayOf(2, 35, 13),
        // 4
        intArrayOf(1, 100, 80), intArrayOf(2, 50, 32), intArrayOf(2, 50, 24), intArrayOf(4, 25, 9),
        // 5
        intArrayOf(1, 134, 108), intArrayOf(2, 67, 43), intArrayOf(2, 33, 15, 2, 34, 16), intArrayOf(2, 33, 11, 2, 34, 12),
        // 6
        intArrayOf(2, 86, 68), intArrayOf(4, 43, 27), intArrayOf(4, 43, 19), intArrayOf(4, 43, 15),
        // 7
        intArrayOf(2, 98, 78), intArrayOf(4, 49, 31), intArrayOf(2, 32, 14, 4, 33, 15), intArrayOf(4, 39, 13, 1, 40, 14),
        // 8
        intArrayOf(2, 121, 97), intArrayOf(2, 60, 38, 2, 61, 39), intArrayOf(4, 40, 18, 2, 41, 19), intArrayOf(4, 40, 14, 2, 41, 15),
        // 9
        intArrayOf(2, 146, 116), intArrayOf(3, 58, 36, 2, 59, 37), intArrayOf(4, 36, 16, 4, 37, 17), intArrayOf(4, 36, 12, 4, 37, 13),
        // 10
        intArrayOf(2, 86, 68, 2, 87, 69), intArrayOf(4, 69, 43, 1, 70, 44), intArrayOf(6, 43, 19, 2, 44, 20), intArrayOf(6, 43, 15, 2, 44, 16),
        // 11
        intArrayOf(4, 101, 81), intArrayOf(1, 80, 50, 4, 81, 51), intArrayOf(4, 50, 22, 4, 51, 23), intArrayOf(3, 36, 12, 8, 37, 13),
        // 12
        intArrayOf(2, 116, 92, 2, 117, 93), intArrayOf(6, 58, 36, 2, 59, 37), intArrayOf(4, 46, 20, 6, 47, 21), intArrayOf(7, 42, 14, 4, 43, 15),
        // 13
        intArrayOf(4, 133, 107), intArrayOf(8, 59, 37, 1, 60, 38), intArrayOf(8, 44, 20, 4, 45, 21), intArrayOf(12, 33, 11, 4, 34, 12),
        // 14
        intArrayOf(3, 145, 115, 1, 146, 116), intArrayOf(4, 64, 40, 5, 65, 41), intArrayOf(11, 36, 16, 5, 37, 17), intArrayOf(11, 36, 12, 5, 37, 13),
        // 15
        intArrayOf(5, 109, 87, 1, 110, 88), intArrayOf(5, 65, 41, 5, 66, 42), intArrayOf(5, 54, 24, 7, 55, 25), intArrayOf(11, 36, 12),
        // 16
        intArrayOf(5, 122, 98, 1, 123, 99), intArrayOf(7, 73, 45, 3, 74, 46), intArrayOf(15, 43, 19, 2, 44, 20), intArrayOf(3, 45, 15, 13, 46, 16),
        // 17
        intArrayOf(1, 135, 107, 5, 136, 108), intArrayOf(10, 74, 46, 1, 75, 47), intArrayOf(1, 50, 22, 15, 51, 23), intArrayOf(2, 42, 14, 17, 43, 15),
        // 18
        intArrayOf(5, 150, 120, 1, 151, 121), intArrayOf(9, 69, 43, 4, 70, 44), intArrayOf(17, 50, 22, 1, 51, 23), intArrayOf(2, 42, 14, 19, 43, 15),
        // 19
        intArrayOf(3, 141, 113, 4, 142, 114), intArrayOf(3, 70, 44, 11, 71, 45), intArrayOf(17, 47, 21, 4, 48, 22), intArrayOf(9, 39, 13, 16, 40, 14),
        // 20
        intArrayOf(3, 135, 107, 5, 136, 108), intArrayOf(3, 67, 41, 13, 68, 42), intArrayOf(15, 54, 24, 5, 55, 25), intArrayOf(15, 43, 15, 10, 44, 16),
        // 21
        intArrayOf(4, 144, 116, 4, 145, 117), intArrayOf(17, 68, 42), intArrayOf(17, 50, 22, 6, 51, 23), intArrayOf(19, 46, 16, 6, 47, 17),
        // 22
        intArrayOf(2, 139, 111, 7, 140, 112), intArrayOf(17, 74, 46), intArrayOf(7, 54, 24, 16, 55, 25), intArrayOf(34, 37, 13),
        // 23
        intArrayOf(4, 151, 121, 5, 152, 122), intArrayOf(4, 75, 47, 14, 76, 48), intArrayOf(11, 54, 24, 14, 55, 25), intArrayOf(16, 45, 15, 14, 46, 16),
        // 24
        intArrayOf(6, 147, 117, 4, 148, 118), intArrayOf(6, 73, 45, 14, 74, 46), intArrayOf(11, 54, 24, 16, 55, 25), intArrayOf(30, 46, 16, 2, 47, 17),
        // 25
        intArrayOf(8, 132, 106, 4, 133, 107), intArrayOf(8, 75, 47, 13, 76, 48), intArrayOf(7, 54, 24, 22, 55, 25), intArrayOf(22, 45, 15, 13, 46, 16),
        // 26
        intArrayOf(10, 142, 114, 2, 143, 115), intArrayOf(19, 74, 46, 4, 75, 47), intArrayOf(28, 50, 22, 6, 51, 23), intArrayOf(33, 46, 16, 4, 47, 17),
        // 27
        intArrayOf(8, 152, 122, 4, 153, 123), intArrayOf(22, 73, 45, 3, 74, 46), intArrayOf(8, 53, 23, 26, 54, 24), intArrayOf(12, 45, 15, 28, 46, 16),
        // 28
        intArrayOf(3, 147, 117, 10, 148, 118), intArrayOf(3, 73, 45, 23, 74, 46), intArrayOf(4, 54, 24, 31, 55, 25), intArrayOf(11, 45, 15, 31, 46, 16),
        // 29
        intArrayOf(7, 146, 116, 7, 147, 117), intArrayOf(21, 73, 45, 7, 74, 46), intArrayOf(1, 53, 23, 37, 54, 24), intArrayOf(19, 45, 15, 26, 46, 16),
        // 30
        intArrayOf(5, 145, 115, 10, 146, 116), intArrayOf(19, 75, 47, 10, 76, 48), intArrayOf(15, 54, 24, 25, 55, 25), intArrayOf(23, 45, 15, 25, 46, 16),
        // 31
        intArrayOf(13, 145, 115, 3, 146, 116), intArrayOf(2, 74, 46, 29, 75, 47), intArrayOf(42, 54, 24, 1, 55, 25), intArrayOf(23, 45, 15, 28, 46, 16),
        // 32
        intArrayOf(17, 145, 115), intArrayOf(10, 74, 46, 23, 75, 47), intArrayOf(10, 54, 24, 35, 55, 25), intArrayOf(19, 45, 15, 35, 46, 16),
        // 33
        intArrayOf(17, 145, 115, 1, 146, 116), intArrayOf(14, 74, 46, 21, 75, 47), intArrayOf(29, 54, 24, 19, 55, 25), intArrayOf(11, 45, 15, 46, 46, 16),
        // 34
        intArrayOf(13, 145, 115, 6, 146, 116), intArrayOf(14, 74, 46, 23, 75, 47), intArrayOf(44, 54, 24, 7, 55, 25), intArrayOf(59, 46, 16, 1, 47, 17),
        // 35
        intArrayOf(12, 151, 121, 7, 152, 122), intArrayOf(12, 75, 47, 26, 76, 48), intArrayOf(39, 54, 24, 14, 55, 25), intArrayOf(22, 45, 15, 41, 46, 16),
        // 36
        intArrayOf(6, 151, 121, 14, 152, 122), intArrayOf(6, 75, 47, 34, 76, 48), intArrayOf(46, 54, 24, 10, 55, 25), intArrayOf(2, 45, 15, 64, 46, 16),
        // 37
        intArrayOf(17, 152, 122, 4, 153, 123), intArrayOf(29, 74, 46, 14, 75, 47), intArrayOf(49, 54, 24, 10, 55, 25), intArrayOf(24, 45, 15, 46, 46, 16),
        // 38
        intArrayOf(4, 152, 122, 18, 153, 123), intArrayOf(13, 74, 46, 32, 75, 47), intArrayOf(48, 54, 24, 14, 55, 25), intArrayOf(42, 45, 15, 32, 46, 16),
        // 39
        intArrayOf(20, 147, 117, 4, 148, 118), intArrayOf(40, 75, 47, 7, 76, 48), intArrayOf(43, 54, 24, 22, 55, 25), intArrayOf(10, 45, 15, 67, 46, 16),
        // 40
        intArrayOf(19, 148, 118, 6, 149, 119), intArrayOf(18, 75, 47, 31, 76, 48), intArrayOf(34, 54, 24, 34, 55, 25), intArrayOf(20, 45, 15, 61, 46, 16),
    )
}

// ======================================================================
// 校正图形位置 / BCH（port of util.dart）
// ======================================================================

private object QrUtil {
    private val PATTERN_POSITION: Array<IntArray> = arrayOf(
        intArrayOf(),
        intArrayOf(6, 18),
        intArrayOf(6, 22),
        intArrayOf(6, 26),
        intArrayOf(6, 30),
        intArrayOf(6, 34),
        intArrayOf(6, 22, 38),
        intArrayOf(6, 24, 42),
        intArrayOf(6, 26, 46),
        intArrayOf(6, 28, 50),
        intArrayOf(6, 30, 54),
        intArrayOf(6, 32, 58),
        intArrayOf(6, 34, 62),
        intArrayOf(6, 26, 46, 66),
        intArrayOf(6, 26, 48, 70),
        intArrayOf(6, 26, 50, 74),
        intArrayOf(6, 30, 54, 78),
        intArrayOf(6, 30, 56, 82),
        intArrayOf(6, 30, 58, 86),
        intArrayOf(6, 34, 62, 90),
        intArrayOf(6, 28, 50, 72, 94),
        intArrayOf(6, 26, 50, 74, 98),
        intArrayOf(6, 30, 54, 78, 102),
        intArrayOf(6, 28, 54, 80, 106),
        intArrayOf(6, 32, 58, 84, 110),
        intArrayOf(6, 30, 58, 86, 114),
        intArrayOf(6, 34, 62, 90, 118),
        intArrayOf(6, 26, 50, 74, 98, 122),
        intArrayOf(6, 30, 54, 78, 102, 126),
        intArrayOf(6, 26, 52, 78, 104, 130),
        intArrayOf(6, 30, 56, 82, 108, 134),
        intArrayOf(6, 34, 60, 86, 112, 138),
        intArrayOf(6, 30, 58, 86, 114, 142),
        intArrayOf(6, 34, 62, 90, 118, 146),
        intArrayOf(6, 30, 54, 78, 102, 126, 150),
        intArrayOf(6, 24, 50, 76, 102, 128, 154),
        intArrayOf(6, 28, 54, 80, 106, 132, 158),
        intArrayOf(6, 32, 58, 84, 110, 136, 162),
        intArrayOf(6, 26, 54, 82, 110, 138, 166),
        intArrayOf(6, 30, 58, 86, 114, 142, 170),
    )

    private const val G15 = (1 shl 10) or (1 shl 8) or (1 shl 5) or (1 shl 4) or (1 shl 2) or (1 shl 1) or (1 shl 0)
    private const val G18 = (1 shl 12) or (1 shl 11) or (1 shl 10) or (1 shl 9) or (1 shl 8) or
        (1 shl 5) or (1 shl 2) or (1 shl 0)
    private const val G15_MASK = (1 shl 14) or (1 shl 12) or (1 shl 10) or (1 shl 4) or (1 shl 1)

    fun patternPosition(typeNumber: Int): IntArray = PATTERN_POSITION[typeNumber - 1]

    fun bchTypeInfo(data: Int): Int {
        var d = data shl 10
        while (bchDigit(d) - bchDigit(G15) >= 0) {
            d = d xor (G15 shl (bchDigit(d) - bchDigit(G15)))
        }
        return ((data shl 10) or d) xor G15_MASK
    }

    fun bchTypeNumber(data: Int): Int {
        var d = data shl 12
        while (bchDigit(d) - bchDigit(G18) >= 0) {
            d = d xor (G18 shl (bchDigit(d) - bchDigit(G18)))
        }
        return (data shl 12) or d
    }

    private fun bchDigit(data0: Int): Int {
        var data = data0
        var digit = 0
        while (data != 0) {
            digit++
            data = data ushr 1
        }
        return digit
    }
}
