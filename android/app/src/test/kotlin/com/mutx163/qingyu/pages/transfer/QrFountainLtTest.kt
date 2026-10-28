package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.share.QrTransferLimits
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * LT 喷泉码内核的单测（Phase 3.5 · TQ1）。
 *
 * 期望值全部**手推**，不从实现里抄：
 * - 削皮图那一组是手写的三个源符号 `[1,1] [2,2] [4,4]` 与它们的 XOR 组合；
 * - 编码端的度数 1 / 度数 2 / 末块补零三组，期望字节是拿纸算出来的。
 */
class QrFountainLtTest {

    // ── 协议层：种子推导 ──────────────────────────────────────────

    @Test
    fun 同一个种子永远推出同一份邻居() {
        val first = QrFountainNeighbors.select(seed = 4242, sourceSymbolCount = 16, degree = 5)
        val second = QrFountainNeighbors.select(seed = 4242, sourceSymbolCount = 16, degree = 5)
        assertArrayEquals("邻居是协议的一部分，必须逐字节可复现", first, second)
    }

    @Test
    fun 邻居数量等于度数_去重且都在范围内() {
        val neighbors = QrFountainNeighbors.select(seed = 777, sourceSymbolCount = 10, degree = 4)
        assertEquals("degree=4 必须给出 4 个不同下标", 4, neighbors.size)
        assertEquals("放回式抽取可能抽重，去重后仍要足额", 4, neighbors.distinct().size)
        for (index in neighbors) {
            assertTrue("下标 $index 越界（k=10）", index in 0 until 10)
        }
    }

    @Test
    fun 度数大于源符号数时夹到源符号数_不能死循环() {
        // 放回式抽取永远凑不齐 k 个以上不同下标：不夹住就是死循环，所以这条是安全阀。
        val neighbors = QrFountainNeighbors.select(seed = 9, sourceSymbolCount = 3, degree = 99)
        assertEquals("最多只能有 k=3 个不同邻居", 3, neighbors.size)
        assertEquals("且必须覆盖全部下标", setOf(0, 1, 2), neighbors.toSet())
    }

    @Test
    fun 源符号数为1时邻居只能是0() {
        assertArrayEquals(
            "k=1 时无论种子是什么，唯一邻居只能是 0",
            intArrayOf(0),
            QrFountainNeighbors.select(seed = 123456, sourceSymbolCount = 1, degree = 1),
        )
    }

    @Test
    fun 度数为0时返回空邻居() {
        assertEquals(0, QrFountainNeighbors.select(seed = 1, sourceSymbolCount = 8, degree = 0).size)
    }

    // ── 随机数：确定性 ────────────────────────────────────────────

    @Test
    fun 同一个种子前五个取值完全一致() {
        val a = QrFountainRandom(20261028)
        val b = QrFountainRandom(20261028)
        repeat(5) { assertEquals("第 $it 次取值必须相同", a.nextInt(1000), b.nextInt(1000)) }
    }

    @Test
    fun 不同种子的序列不同() {
        val a = QrFountainRandom(1)
        val b = QrFountainRandom(2)
        val aValues = (1..8).map { a.nextInt(1000) }
        val bValues = (1..8).map { b.nextInt(1000) }
        assertTrue("相邻种子必须打散，否则邻居集合会高度相关", aValues != bValues)
    }

    @Test
    fun nextInt的取值恒在界内() {
        val rng = QrFountainRandom(-1)
        repeat(200) {
            val value = rng.nextInt(7)
            assertTrue("nextInt(7) 给出 $value", value in 0 until 7)
        }
        assertEquals("bound=1 只能是 0", 0, rng.nextInt(1))
    }

    @Test
    fun nextDouble落在0到1之间() {
        val rng = QrFountainRandom(99)
        repeat(200) {
            val value = rng.nextDouble()
            assertTrue("nextDouble 给出 $value", value >= 0.0 && value < 1.0)
        }
    }

    // ── 编码端 ────────────────────────────────────────────────────

    @Test
    fun 度数为1的符号就是它唯一那个源符号() {
        val data = byteArrayOf(11, 22, 33, 44)
        val encoder = QrFountainEncoder(
            sourceData = data,
            symbolSize = 2,
            sampler = QrFountainDegreeSampler(sourceSymbolCount = 2),
            neighborSelectorOverride = { _, _ -> intArrayOf(1) },
        )
        assertArrayEquals(
            "邻居={1} ⇒ 输出就是第 2 个源符号 [33,44]",
            byteArrayOf(33, 44),
            encoder.encode(seed = 1).bytes,
        )
    }

    @Test
    fun 度数为2的符号是两个源符号的异或() {
        val data = byteArrayOf(1, 2, 3, 4)
        val encoder = QrFountainEncoder(
            sourceData = data,
            symbolSize = 2,
            sampler = QrFountainDegreeSampler(sourceSymbolCount = 2),
            neighborSelectorOverride = { _, _ -> intArrayOf(0, 1) },
        )
        // [1,2] xor [3,4] = [1^3, 2^4] = [2, 6]
        assertArrayEquals(byteArrayOf(2, 6), encoder.encode(seed = 1).bytes)
    }

    @Test
    fun 末块不足一个符号时补零() {
        val data = byteArrayOf(1, 2, 3, 4, 5) // 5 字节 / 4 = 2 个源符号，末块补 3 个零
        val encoder = QrFountainEncoder(
            sourceData = data,
            symbolSize = 4,
            sampler = QrFountainDegreeSampler(sourceSymbolCount = 2),
            neighborSelectorOverride = { _, _ -> intArrayOf(1) },
        )
        assertEquals(2, encoder.sourceSymbolCount)
        assertArrayEquals(
            "第 2 个源符号只能是 [5,0,0,0]",
            byteArrayOf(5, 0, 0, 0),
            encoder.encode(seed = 1).bytes,
        )
    }

    // ── 削皮解码：手搭一张已知图 ──────────────────────────────────

    @Test
    fun 削皮链条_解出一个能带出下一个() {
        // 源符号（symbolSize=2）：s0=[1,1]  s1=[2,2]  s2=[4,4]
        // 手推的编码符号：
        //   seed=1 → 邻居{0,1} → s0^s1 = [3,3]
        //   seed=2 → 邻居{0}   → s0     = [1,1]
        //   seed=3 → 邻居{0,1,2} → s0^s1^s2 = [7,7]
        val decoder = QrFountainPeelingDecoder(sourceSymbolCount = 3, symbolSize = 2)

        assertTrue(decoder.submitNeighbors(1, byteArrayOf(3, 3), listOf(0, 1)))
        assertEquals("两个邻居都还没解出，削不动", 0, decoder.rank)

        assertTrue(decoder.submitNeighbors(2, byteArrayOf(1, 1), listOf(0)))
        // s0 解出 ⇒ 回头把 seed1 削成 [3^1,3^1]=[2,2]、邻居只剩 {1} ⇒ 顺手把 s1 也解出来。
        // 这就是「反向索引」的价值：早到的符号不会白收。
        assertEquals("解出 s0 的同时应该把 seed1 削成 s1", 2, decoder.rank)
        assertNull("3 个源符号只解出 2 个，还不能给数据", decoder.decodedData())

        assertTrue(decoder.submitNeighbors(3, byteArrayOf(7, 7), listOf(0, 1, 2)))
        // seed3 的 {0,1} 都已知 ⇒ 减成 [4,4] 邻居{2} ⇒ 解出 s2
        assertEquals("最后一个源符号解出", 3, decoder.rank)
        assertTrue(decoder.isComplete)
        assertArrayEquals(
            "还原结果必须逐字节等于 [s0|s1|s2]",
            byteArrayOf(1, 1, 2, 2, 4, 4),
            decoder.decodedData()!!,
        )
    }

    @Test
    fun 先到的大度数符号不会白收_后面解出的会回头削它() {
        // 源符号：s0=[5,5] s1=[9,9]
        val decoder = QrFountainPeelingDecoder(sourceSymbolCount = 2, symbolSize = 2)
        // 先来 s0^s1=[12,12]，此时一个都解不出（rank 0，但符号留着）
        assertTrue(decoder.submitNeighbors(1, byteArrayOf(12, 12), listOf(0, 1)))
        assertEquals(0, decoder.rank)
        // 再来 s0=[5,5]：解出 s0 后回头把 seed1 削成 [12^5,12^5]=[9,9]，剩下的唯一邻居是 1 ⇒ s1
        assertTrue(decoder.submitNeighbors(2, byteArrayOf(5, 5), listOf(0)))
        assertEquals("反向索引必须让它回头削掉早到的符号", 2, decoder.rank)
        assertArrayEquals(byteArrayOf(5, 5, 9, 9), decoder.decodedData()!!)
    }

    @Test
    fun 重复种子不再参与削皮() {
        val decoder = QrFountainPeelingDecoder(sourceSymbolCount = 2, symbolSize = 2)
        assertTrue(decoder.submitNeighbors(7, byteArrayOf(1, 1), listOf(0)))
        assertFalse("同一个 seed 第二次提交必须被拒", decoder.submitNeighbors(7, byteArrayOf(1, 1), listOf(0)))
        assertEquals(1, decoder.rank)
    }

    @Test
    fun 未收齐时decodedData为null() {
        val decoder = QrFountainPeelingDecoder(sourceSymbolCount = 3, symbolSize = 2)
        decoder.submitNeighbors(1, byteArrayOf(1, 1), listOf(0))
        assertNull("只解出 1/3 不能算数据到手", decoder.decodedData())
        assertFalse(decoder.isComplete)
    }

    @Test
    fun 完全相关的符号不增长rank() {
        // 两个符号都是 s0 本身：第二个不会带来新信息（rank 仍是 1）。
        val decoder = QrFountainPeelingDecoder(sourceSymbolCount = 2, symbolSize = 1)
        decoder.submitNeighbors(1, byteArrayOf(7), listOf(0))
        decoder.submitNeighbors(2, byteArrayOf(7), listOf(0))
        assertEquals(1, decoder.rank)
        assertFalse(decoder.isComplete)
    }

    // ── 编码 → 解码往返（真实协议的端到端自洽） ──────────────────

    @Test
    fun 编码解码往返_同一份实现自己一定对得上() {
        val raw = kotlin.random.Random(2026).nextBytes(300)
        val symbolSize = 64
        val sourceSymbolCount = (raw.size + symbolSize - 1) / symbolSize
        val encoder = QrFountainEncoder(
            sourceData = raw,
            symbolSize = symbolSize,
            sampler = QrFountainDegreeSampler(sourceSymbolCount),
        )
        val decoder = QrFountainPeelingDecoder(sourceSymbolCount, symbolSize)

        var seeds = 0
        while (!decoder.isComplete && seeds < sourceSymbolCount * 40) {
            seeds++
            val symbol = encoder.encode(seeds)
            assertTrue(decoder.addSymbol(symbol.seed, symbol.bytes, symbol.degree))
        }

        assertTrue("$seeds 帧内必须收齐（k=$sourceSymbolCount）", decoder.isComplete)
        val decoded = decoder.decodedData()
        assertNotNull(decoded)
        assertArrayEquals(
            "补零部分在末尾，前 raw.size 字节必须原样",
            raw,
            decoded!!.copyOf(raw.size),
        )
    }

    @Test
    fun 度数分布抽样恒在1到上限之间() {
        val sampler = QrFountainDegreeSampler(sourceSymbolCount = 50)
        repeat(300) {
            val degree = sampler.sample()
            assertTrue("抽到 degree=$degree", degree in 1..sampler.maxDegree)
        }
    }

    @Test
    fun 度数上限随源符号数收敛到100() {
        assertEquals(3, QrTransferLimits.maxDegreeForSourceSymbolCount(3))
        assertEquals(100, QrTransferLimits.maxDegreeForSourceSymbolCount(500))
    }
}
