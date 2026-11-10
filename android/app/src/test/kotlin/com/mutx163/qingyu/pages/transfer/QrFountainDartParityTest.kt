package com.mutx163.qingyu.pages.transfer

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * **跨版本二维码互通的黄金向量**（2026-11-10 修 D1）。
 *
 * ## 这组期望值是哪来的
 *
 * 不是从 Kotlin 实现里抄的，是用**发布版同款 Dart SDK** 跑出来的：
 *
 * ```text
 * D:\Flutter\flutter\bin\cache\dart-sdk\bin\dart.exe  (Dart 3.12.2)
 * Flutter 3.44.8 —— 与 .github/workflows/android-build.yml 的 FLUTTER_STABLE_VERSION 一致
 * ```
 *
 * 脚本（临时目录，未入库）：
 *
 * ```dart
 * import 'dart:math';
 *
 * // 与 fountain_codes-1.0.0 的 LTCodec._selectNeighbors 同算法
 * Set<int> select(int seed, int k, int degree) {
 *   final rng = Random(seed);
 *   final picked = <int>{};
 *   final target = degree > k ? k : degree;
 *   while (picked.length < target) picked.add(rng.nextInt(k));
 *   return picked;
 * }
 * ```
 *
 * 发布版 `fountain_codes-1.0.0/lib/src/lt/lt_codec.dart:61-65` 用 `Random(esiOrSeed)`
 * 建邻居，`:83-91` 的 `_selectNeighbors` 就是上面这 6 行。帧里不带邻居集合，
 * 所以只要这两个序列一致，Compose 端与 Flutter 2.1.4.1 就能互相解出同一份数据。
 *
 * ## 怎么用
 *
 * - 邻居向量按**排序后**比较：XOR 可交换，集合内容才是协议，插入顺序不是。
 * - `nextInt` 序列用来单独钉 PRNG 本身（含 2 的幂快路径与非幂取模拒绝采样）。
 *
 * **不要凭记忆改这些数字**；要改算法，先用同样的 Dart 脚本重生成。
 */
class QrFountainDartParityTest {

    // ── PRNG：Dart Random(seed).nextInt(n) 的原始序列 ──────────────────

    private data class DrawCase(
        val seed: Int,
        val bound: Int,
        val expected: IntArray,
    )

    private val drawCases = listOf(
        DrawCase(
            seed = 4242,
            bound = 1000,
            expected = intArrayOf(
                343, 450, 312, 686, 521, 130, 926, 371, 300, 358,
                99, 364, 642, 169, 655, 75, 962, 567, 575, 675,
            ),
        ),
        DrawCase(
            seed = 0,
            bound = 1000,
            expected = intArrayOf(
                455, 9, 964, 499, 806, 191, 694, 881, 841, 569,
                959, 818, 72, 872, 451, 694, 777, 205, 648, 693,
            ),
        ),
        DrawCase(
            seed = 1,
            bound = 1000,
            expected = intArrayOf(
                204, 187, 295, 259, 275, 837, 848, 169, 216, 781,
                234, 263, 333, 784, 151, 398, 37, 376, 159, 199,
            ),
        ),
        DrawCase(
            seed = 20261028,
            bound = 1000,
            expected = intArrayOf(
                617, 22, 807, 575, 525, 474, 779, 349, 348, 230,
                338, 340, 33, 996, 375, 401, 233, 917, 976, 739,
            ),
        ),
        DrawCase(
            seed = Int.MAX_VALUE,
            bound = 1000,
            expected = intArrayOf(
                426, 597, 669, 313, 655, 346, 286, 757, 60, 444,
                916, 101, 198, 528, 808, 144, 895, 233, 873, 244,
            ),
        ),
        // 2 的幂快路径：nextInt(7) 走模 7 的拒绝采样，和上面 nextInt(1000) 的路径不同。
        DrawCase(
            seed = 777,
            bound = 7,
            expected = intArrayOf(
                5, 5, 1, 2, 5, 4, 0, 2, 4, 6,
                6, 2, 5, 0, 6, 3, 4, 2, 5, 4,
            ),
        ),
    )

    @Test
    fun `DartRandom 的 nextInt 序列与 Dart 黄金向量逐项一致`() {
        for (case in drawCases) {
            val random = DartRandom(case.seed)
            val actual = IntArray(case.expected.size) { random.nextInt(case.bound) }
            assertArrayEquals(
                "seed=${case.seed} bound=${case.bound} 与 Dart Random 序列不一致",
                case.expected,
                actual,
            )
        }
    }

    // ── 协议：seed + degree → 邻居集合 ───────────────────────────────

    private data class NeighborCase(
        val seed: Int,
        val sourceSymbolCount: Int,
        val degree: Int,
        val expected: IntArray,
    )

    private val neighborCases = listOf(
        NeighborCase(4242, 16, 5, intArrayOf(1, 8, 10, 14, 15)),
        NeighborCase(777, 10, 4, intArrayOf(2, 3, 4, 5)),
        NeighborCase(9, 3, 3, intArrayOf(0, 1, 2)),
        NeighborCase(123456, 1, 1, intArrayOf(0)),
        NeighborCase(2026, 7, 7, intArrayOf(0, 1, 2, 3, 4, 5, 6)),
        NeighborCase(1, 2, 2, intArrayOf(0, 1)),
        NeighborCase(0, 5, 3, intArrayOf(0, 1, 4)),
        NeighborCase(12345, 13, 5, intArrayOf(3, 6, 7, 9, 12)),
        NeighborCase(
            2147483647,
            8192,
            100,
            intArrayOf(
                169, 276, 396, 520, 666, 760, 761, 788, 841, 902,
                910, 926, 974, 1148, 1241, 1301, 1367, 1497, 1536, 1557,
                1637, 1642, 1644, 1903, 2046, 2096, 2148, 2212, 2311, 2418,
                2430, 2437, 2462, 2784, 2807, 2860, 2897, 2904, 2947, 3054,
                3088, 3094, 3116, 3140, 3257, 3275, 3303, 3341, 3493, 3755,
                3846, 3921, 3933, 4383, 4419, 4478, 4486, 4500, 4526, 4678,
                4807, 4931, 4932, 4939, 4948, 5016, 5114, 5136, 5187, 5194,
                5217, 5264, 5339, 5446, 5536, 5613, 5644, 5813, 5914, 5927,
                5963, 6001, 6036, 6185, 6205, 6236, 6296, 6302, 6432, 6524,
                6748, 6857, 7208, 7269, 7642, 7740, 7827, 7836, 7909, 8181,
            ),
        ),
    )

    @Test
    fun `邻居集合与发布版 Dart 黄金向量完全一致`() {
        for (case in neighborCases) {
            val actual = QrFountainNeighbors
                .select(case.seed, case.sourceSymbolCount, case.degree)
                .sortedArray()
            assertArrayEquals(
                "seed=${case.seed} k=${case.sourceSymbolCount} degree=${case.degree} " +
                    "的邻居集合与发布版 fountain_codes 不一致——跨版本互传会失败",
                case.expected,
                actual,
            )
        }
    }

    @Test
    fun `黄金向量覆盖 2 的幂与非 2 的幂两种走法`() {
        // 这条是防「以后有人把向量换成清一色 k=16」把拒绝采样路径漏掉。
        val powers = neighborCases.filter { (it.sourceSymbolCount and (it.sourceSymbolCount - 1)) == 0 }
        val nonPowers = neighborCases.filter { (it.sourceSymbolCount and (it.sourceSymbolCount - 1)) != 0 }
        assertTrue("必须同时覆盖 2 的幂 k", powers.isNotEmpty())
        assertTrue("必须同时覆盖非 2 的幂 k", nonPowers.isNotEmpty())
        assertEquals("向量条数变了要同步说明来由", 9, neighborCases.size)
    }
}
