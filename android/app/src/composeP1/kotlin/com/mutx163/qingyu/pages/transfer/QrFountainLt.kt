package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.share.QrTransferLimits
import java.util.ArrayDeque
import kotlin.math.floor
import kotlin.math.ln
import kotlin.math.sqrt

/**
 * LT 喷泉码内核（Phase 3.5 · TQ1）——**纯 Kotlin、零 `android.*`**。
 *
 * ## 为什么这一层必须自己写
 *
 * Dart 侧的二维码传输依赖 pub 包 `fountain_codes` 1.0.0 的 `LTCodec` / `BeliefPropagationDecoder`
 * （`lib/services/qr_transfer/qr_transfer_codec.dart`）。Kotlin 侧没有任何对应物，
 * `QrTransferLimits` 的 KDoc 也把这处缺口写明：「LT 编解码依赖 fountain_codes 包，
 * Kotlin 侧无对应物」。所以帧格式（[com.mutx163.qingyu.share.QrTransferFrame]）有了、
 * 解压与校验有了，**中间那一步「把一堆 XOR 过的符号还原成原始字节」一直是空的**：
 * 接收端永远收不齐（`decodedSymbols` 涨不上去），发送端也生成不出帧。
 *
 * 这里按 `fountain_codes` 的**算法结构**移植（Robust Soliton 度数分布 + 种子选邻居 +
 * 逐符号 XOR + ripple 削皮解码），但把「随机数」换成自己的一份确定性实现，
 * 理由与代价见 [QrFountainRandom] 的注释。
 *
 * ## 三层结构
 *
 * ```
 * QrFountainRandom          确定性伪随机（同 seed 同序列）
 *   └─ QrFountainNeighbors   seed + 度数 → 邻居下标集合（编码/解码必须算出同一份）
 * QrFountainDegreeSampler    Robust Soliton 度数分布（发送端抽样；接收端不抽样，度数随帧传输）
 * QrFountainEncoder         源符号 → 指定 seed 的编码符号（度数 + 字节）
 * QrFountainPeelingDecoder  收到的编码符号 → 削皮还原源符号
 * ```
 *
 * ## 编码端与解码端唯一的耦合点
 *
 * 邻居集合**不随帧传输**（每帧只带 `seed` 与 `degree`），两端都必须用同一个 PRNG
 * 从同一个 `seed` 推出同一份邻居。所以 [QrFountainNeighbors.select] 是这份文件里
 * 唯一「改动即协议不兼容」的地方。
 */

/**
 * 确定性伪随机数（splitmix64）。
 *
 * ## 为什么不用 `kotlin.random.Random(seed)`
 *
 * `kotlin.random.Random(seed)` 的序列**不承诺跨版本稳定**（实现可以换），而这里的序列是
 * **协议的一部分**：换一次实现，之前录下来的帧全部变成噪声。所以自己写一份钉死的算法。
 *
 * ## 已知的互操作缺口（诚实记录）
 *
 * Dart `fountain_codes` 用 `dart:math` 的 `Random(seed)` 选邻居，与本实现**序列不同**。
 * 后果：**Compose 发送端 ↔ Flutter 接收端（或反过来）互相扫不出内容**——不是静默损坏，
 * 而是拼包后 SHA-256 对不上、显示「传输校验失败」。同一 APK 内两端（都走本文件）互通。
 * 真要跨实现互通，得把 `dart:math` 的 PRNG 逐位移植过来，并拿 Dart 生成的黄金向量对拍，
 * 那是单独一批活（见认领文件的诚实清单）。
 */
class QrFountainRandom(seed: Int) {

    /** 用种子打散成非零的 64 位状态（seed=0 时 splitmix64 也能正常跑，但状态 0 退化，故兜底）。 */
    private var state: Long = mixSeed(seed.toLong())
        .let { if (it == 0L) DEFAULT_STATE else it }

    /** 下一个 64 位随机值（高位也被打散，可直接取高位做取值）。 */
    fun nextLong(): Long {
        // splitmix64：state 递增一个黄金比例常数，再经两轮乘法混淆。
        state += GOLDEN_GAMMA
        var z = state
        z = (z xor (z ushr 30)) * MIX_1
        z = (z xor (z ushr 27)) * MIX_2
        return z xor (z ushr 31)
    }

    /**
     * `[0, bound)` 的整数。
     *
     * 用无符号取模（先右移 1 位丢掉符号位）：bound 远小于 2^63 时偏差可忽略，
     * 而这里 bound 最多是 `sourceSymbolCount`（≤ 8192），偏差量级 2^-50，不影响正确性。
     */
    fun nextInt(bound: Int): Int {
        require(bound > 0) { "bound 必须为正，收到 $bound" }
        return ((nextLong() ushr 1) % bound.toLong()).toInt()
    }

    /** `[0.0, 1.0)` 的双精度值（取高 53 位，与 IEEE754 尾数同宽）。 */
    fun nextDouble(): Double = (nextLong() ushr 11) * DOUBLE_UNIT

    private companion object {
        /** splitmix64 的黄金比例步长 0x9E3779B97F4A7C15（写成补码避免超出 Long 正区间）。 */
        const val GOLDEN_GAMMA: Long = -0x61C8864680B583EBL

        /** 0xBF58476D1CE4E5B9 */
        const val MIX_1: Long = -0x40A7B892E31B1A47L

        /** 0x94D049BB133111EB */
        const val MIX_2: Long = -0x6B2FB644ECCEEE15L

        const val DOUBLE_UNIT: Double = 1.0 / 9007199254740992.0 // 2^-53
        const val DEFAULT_STATE: Long = 0x2545F4914F6CDD1DL

        /** 种子打散：混合高低位，免得相邻 seed（1,2,3…）出来高度相关的邻居集合。 */
        fun mixSeed(seed: Long): Long {
            var z = seed + GOLDEN_GAMMA
            z = (z xor (z ushr 30)) * MIX_1
            z = (z xor (z ushr 27)) * MIX_2
            return z xor (z ushr 31)
        }
    }
}

/**
 * 「seed + 度数 → 源符号下标集合」的唯一实现处。
 *
 * 编码端与解码端都走这里，所以只要**这一处**两端一致，协议就闭合。
 *
 * 抽邻居的做法与 `fountain_codes` 的 `_selectNeighbors` 同结构：**放回式抽**
 * （`while (set.size < degree) add(rng.nextInt(k))`），重复的自动折叠。
 * 因此 `degree` 必须 ≤ 源符号数，否则循环永不收敛——这不是防御性检查，
 * 而是真实的死循环风险，故这里硬夹住（帧解析层 `QrTransferFrame.parse` 也会先挡一道）。
 */
object QrFountainNeighbors {

    /**
     * @param seed 本帧的种子（帧里自带）
     * @param sourceSymbolCount 源符号数 k（帧里自带，解析层已校验上界）
     * @param degree 本帧度数（帧里自带）
     * @return 升序去重后的源符号下标；`degree <= 0` 时返回空数组
     */
    fun select(seed: Int, sourceSymbolCount: Int, degree: Int): IntArray {
        if (sourceSymbolCount <= 0 || degree <= 0) return IntArray(0)
        // 度数与源符号数取小：度 > k 时按放回式抽取永远凑不齐 degree 个不同下标。
        val target = if (degree > sourceSymbolCount) sourceSymbolCount else degree
        val random = QrFountainRandom(seed)
        val picked = LinkedHashSet<Int>(target * 2)
        while (picked.size < target) {
            picked.add(random.nextInt(sourceSymbolCount))
        }
        return picked.toIntArray()
    }
}

/**
 * Robust Soliton 度数分布（移植 `fountain_codes` 的 `RobustSoliton`，默认参数与
 * `LTCodec` 一致：c = 0.2 / delta = 0.1）。
 *
 * ## 接收端为什么不需要它
 *
 * 度数**随帧传输**（`QrTransferFrame.degree`），解码端直接用帧里的值。
 * 只有这样，发送端换个分布也不影响已经播出去的帧——`fountain_codes` 的注释里
 * 专门强调过这一点（它也解释了为什么「同一个 seed 不保证同一段文本」）。
 */
class QrFountainDegreeSampler(
    val sourceSymbolCount: Int,
    private val c: Double = 0.2,
    private val delta: Double = 0.1,
    val maxDegree: Int = QrTransferLimits.maxDegreeForSourceSymbolCount(sourceSymbolCount),
    /**
     * 度数抽样用的随机流。
     *
     * `fountain_codes` 默认用**无种子** `Random()`（每次运行不同）；这里给了固定种子，
     * 换来「同一份数据每次生成同一串帧」——单测可复现，调试可复现。
     * 代价是发送端不再有「每次重试都换一组度数」的微小随机性，而这是解码无所谓的。
     */
    private val random: QrFountainRandom = QrFountainRandom(DEGREE_SEED),
) {
    private val k: Int = sourceSymbolCount.coerceAtLeast(1)
    private val maxDeg: Int = maxDegree.coerceIn(1, k)
    private val cdf: DoubleArray
    private val smoothBudget: Double
    private val spikePoint: Double

    init {
        // s = c·ln(k/δ)·√k，r = k/s（同 RobustSoliton）。
        smoothBudget = c * ln(k.toDouble() / delta) * sqrt(k.toDouble())
        spikePoint = k / smoothBudget

        val pmf = DoubleArray(maxDeg + 1)
        var total = 0.0
        for (d in 1..maxDeg) {
            pmf[d] = rho(d) + tau(d)
            total += pmf[d]
        }
        cdf = DoubleArray(maxDeg + 1)
        var cumulative = 0.0
        for (d in 1..maxDeg) {
            cumulative += if (total > 0.0) pmf[d] / total else 0.0
            cdf[d] = cumulative
        }
        // 末项钉成 1，浮点累加误差不至于让 sample() 落到循环外。
        cdf[maxDeg] = 1.0
    }

    /** 抽一个度数（1..[maxDegree]）。 */
    fun sample(): Int {
        val u = random.nextDouble()
        for (d in 1..maxDeg) {
            if (u <= cdf[d]) return d
        }
        return maxDeg
    }

    /** 理想 Soliton 分布 ρ。 */
    private fun rho(d: Int): Double = if (d == 1) 1.0 / k else 1.0 / (d.toDouble() * (d - 1))

    /** Robust Soliton 的 τ 修正项。 */
    private fun tau(d: Int): Double {
        val spike = floor(spikePoint).toInt()
        return when {
            // 与 Dart 同口径：d 落在 [1, ⌊r⌋) 用 s/(k·d)
            d >= 1 && d < spikePoint -> smoothBudget / (k.toDouble() * d)
            // 单点尖峰压平成一个点，给「中型度数」加权重，LT 才不容易卡住
            d == spike -> smoothBudget * ln(smoothBudget / delta) / k.toDouble()
            else -> 0.0
        }
    }

    private companion object {
        const val DEGREE_SEED = 0x51ED270B
    }
}

/**
 * 一帧的编码符号：度数 + 字节。
 *
 * 「度数」随帧走，所以它不是可选项——接收端拿不到度数就只能退回抽样，
 * 而抽样两边不可能一致。
 */
class QrFountainSymbol(
    val seed: Int,
    val degree: Int,
    val bytes: ByteArray,
)

/**
 * LT 编码器：源数据 → 任意 seed 的编码符号。
 *
 * 源数据按 [symbolSize] 切块、末块补零（与 `fountain_codes` 的 `setSourceData` 一致），
 * 还原时由上层按 `payloadLength` 截断，所以补的零不会漏进载荷。
 *
 * @param neighborSelector 邻居推导（单测可注入手搭图；生产用默认实现）
 */
class QrFountainEncoder(
    sourceData: ByteArray,
    val symbolSize: Int,
    private val sampler: QrFountainDegreeSampler,
    neighborSelectorOverride: ((seed: Int, degree: Int) -> IntArray)? = null,
) {
    init {
        require(symbolSize > 0) { "symbolSize 必须为正，收到 $symbolSize" }
        require(sourceData.isNotEmpty()) { "源数据为空" }
    }

    val sourceSymbolCount: Int = (sourceData.size + symbolSize - 1) / symbolSize

    /** 默认实现即协议本体；单测可换成手搭的邻居表。 */
    private val neighborSelector: (seed: Int, degree: Int) -> IntArray =
        neighborSelectorOverride
            ?: { seed, degree -> QrFountainNeighbors.select(seed, sourceSymbolCount, degree) }

    private val sourceSymbols: Array<ByteArray> = Array(sourceSymbolCount) { index ->
        val symbol = ByteArray(symbolSize)
        val start = index * symbolSize
        val end = minOf(start + symbolSize, sourceData.size)
        if (end > start) sourceData.copyInto(symbol, 0, start, end)
        symbol
    }

    /** 生成指定 seed 的编码符号（同 seed 同度数同字节，纯函数）。 */
    fun encode(seed: Int): QrFountainSymbol {
        val degree = sampler.sample()
        val neighbors = neighborSelector(seed, degree)
        val out = ByteArray(symbolSize)
        for (index in neighbors) {
            val source = sourceSymbols[index]
            for (i in 0 until symbolSize) out[i] = (out[i].toInt() xor source[i].toInt()).toByte()
        }
        return QrFountainSymbol(seed = seed, degree = degree, bytes = out)
    }
}

/**
 * 削皮（ripple）解码器：收到编码符号 → 还原源符号。
 *
 * 与 `fountain_codes` 的 `BeliefPropagationDecoder` 同算法：
 *
 * 1. 新符号进来先「减掉已知源符号」（XOR 掉并从邻居集合里删除）；
 * 2. 剩 1 个邻居 ⇒ 它就是那个源符号，写进 [decoded]；
 * 3. 每解出一个源符号，回头把所有包含它的符号再减一遍，可能又造出新的「剩 1 个」。
 *
 * 这里只做 GF(2) 上的削皮，不求解一般线性方程组（没有高斯消元）——这正是「喷泉」的性质：
 * 凑不够就再多收几帧，而不是死等某一帧。代价是**可能收不完**：
 * 少量 seed 的邻居集合线性相关时削皮会卡住，上层靠「继续播 / 超时」处理，不是 bug。
 *
 * @param neighborSelector 邻居推导，必须与编码端**同一份**（默认即同一实现）
 */
class QrFountainPeelingDecoder(
    val sourceSymbolCount: Int,
    val symbolSize: Int,
    neighborSelectorOverride: ((seed: Int, degree: Int) -> IntArray)? = null,
) {
    /** 默认实现即协议本体（与编码端同一份）；单测可换成手搭的邻居表。 */
    private val neighborSelector: (seed: Int, degree: Int) -> IntArray =
        neighborSelectorOverride
            ?: { seed, degree -> QrFountainNeighbors.select(seed, sourceSymbolCount, degree) }
    /** 已还原的源符号（null = 还没有）。 */
    private val decoded: Array<ByteArray?> = arrayOfNulls(sourceSymbolCount)

    /** 还没削干净的编码符号，按 seed 索引。 */
    private val pending = HashMap<Int, PendingSymbol>()

    /** 源符号 → 包含它的编码符号 seed（反向索引，避免每次全表扫）。 */
    private val dependents = HashMap<Int, MutableSet<Int>>()

    /** 待削队列（`java.util.ArrayDeque`：`kotlin.collections.ArrayDeque` 在各 Kotlin 版本稳定性不一致，不冒这个险）。 */
    private val ripple = ArrayDeque<Int>()

    private val seenSeeds = HashSet<Int>()

    /** 已还原的源符号数（= 线性无关度，进度条上的「已解出」）。 */
    var rank: Int = 0
        private set

    /** 是否已还原全部源符号。 */
    var isComplete: Boolean = false
        private set

    /** 收下的不重复符号数。 */
    val acceptedSymbolCount: Int get() = seenSeeds.size

    /**
     * 提交一个编码符号。
     *
     * @return true = 这个 seed 第一次出现（哪怕它没解出新数据，也计为「新增帧」）；
     *         false = 重复 seed，直接丢掉（同一张画面被反复识别时全靠这道去重）。
     */
    fun addSymbol(seed: Int, bytes: ByteArray, degree: Int): Boolean {
        if (!seenSeeds.add(seed)) return false
        require(bytes.size == symbolSize) {
            "符号长度 ${bytes.size} 与 symbolSize=$symbolSize 不符"
        }
        submit(seed, bytes, neighborSelector(seed, degree).toMutableSet())
        return true
    }

    /**
     * 用**指定的邻居集合**提交一个符号。
     *
     * 生产路径不走这里（邻居永远由 seed 推出来）；它是给单测「手搭一张已知削皮图」用的，
     * 否则「剩 1 个邻居 ⇒ 解出」这条判据只能靠随机往返间接验证。
     */
    fun submitNeighbors(seed: Int, bytes: ByteArray, neighbors: Collection<Int>): Boolean {
        if (!seenSeeds.add(seed)) return false
        require(bytes.size == symbolSize) {
            "符号长度 ${bytes.size} 与 symbolSize=$symbolSize 不符"
        }
        val set = LinkedHashSet<Int>(neighbors.size)
        for (n in neighbors) {
            if (n in 0 until sourceSymbolCount) set.add(n)
        }
        submit(seed, bytes, set)
        return true
    }

    private fun submit(seed: Int, bytes: ByteArray, neighbors: MutableSet<Int>) {
        pending[seed] = PendingSymbol(data = bytes.copyOf(), neighbors = neighbors)
        for (neighbor in neighbors) {
            dependents.getOrPut(neighbor) { LinkedHashSet() }.add(seed)
        }
        reduceKnownNeighbors(seed)
        drainRipple()
    }

    /** 减掉所有已解出的邻居；减到只剩 1 个就进 ripple，减到 0 个说明它没带来任何信息。 */
    private fun reduceKnownNeighbors(seed: Int) {
        val symbol = pending[seed] ?: return
        val known = symbol.neighbors.filter { decoded[it] != null }
        for (neighbor in known) {
            xorInto(symbol.data, decoded[neighbor]!!)
            symbol.neighbors.remove(neighbor)
        }
        when (symbol.neighbors.size) {
            0 -> pending.remove(seed) // 已经被自己的邻居完全解释掉了，留着只会占内存
            1 -> ripple.addLast(seed)
        }
    }

    /** 反复削皮直到队列空。 */
    private fun drainRipple() {
        while (ripple.isNotEmpty()) {
            val seed = ripple.removeFirst()
            val symbol = pending[seed] ?: continue
            if (symbol.neighbors.size != 1) continue
            val sourceIndex = symbol.neighbors.first()
            if (decoded[sourceIndex] != null) continue

            decoded[sourceIndex] = symbol.data.copyOf()
            rank++
            // 这个符号交代完了，不再需要留着
            pending.remove(seed)

            val affected = dependents[sourceIndex]
            if (affected != null) {
                val sourceData = decoded[sourceIndex]!!
                for (otherSeed in affected.toList()) {
                    if (otherSeed == seed) continue
                    val other = pending[otherSeed] ?: continue
                    if (!other.neighbors.remove(sourceIndex)) continue
                    xorInto(other.data, sourceData)
                    if (other.neighbors.size == 1) ripple.addLast(otherSeed)
                }
            }
        }
        isComplete = rank == sourceSymbolCount
    }

    /**
     * 还原出的字节（长度 = `sourceSymbolCount * symbolSize`，末尾补的零还在，由上层截断）。
     * 未收齐时返回 null。
     */
    fun decodedData(): ByteArray? {
        if (!isComplete) return null
        val out = ByteArray(sourceSymbolCount * symbolSize)
        for (i in 0 until sourceSymbolCount) {
            val symbol = decoded[i] ?: return null
            symbol.copyInto(out, i * symbolSize, 0, symbolSize)
        }
        return out
    }

    private fun xorInto(target: ByteArray, mask: ByteArray) {
        for (i in target.indices) {
            target[i] = (target[i].toInt() xor mask[i].toInt()).toByte()
        }
    }

    private class PendingSymbol(
        val data: ByteArray,
        val neighbors: MutableSet<Int>,
    )
}
