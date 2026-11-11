package com.mutx163.qingyu.pages.about

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 三路竞速内核的计时判据（2026-11-11 R-1）。
 *
 * 用户真机报「检查更新一直转」的根因不是三路没接，而是**接了假竞速**：
 * 三路塞在调用方的 `coroutineScope` 里，作用域会等全部子协程；阻塞 socket 读又打不断，
 * 于是丢包时 GitCode 200ms 拿到结果也得陪 GitHub API 等满 4s。
 *
 * 这里钉住两件事（与发布版 `raceFutures` 同语义）：
 * 1. **首个成功立即返回**，不等慢兄弟（计时判据：20ms vs 2000ms，必须远小于慢路）；
 * 2. 全部失败时明确返回 null，不会把「检查更新」永久挂住。
 */
class UpdateManifestRaceTest {

    @Test
    fun `首个成功立即返回_不等慢兄弟`() {
        val race = startRaceFirstSuccess(listOf("fast", "slow")) { candidate ->
            when (candidate) {
                "fast" -> {
                    Thread.sleep(20)
                    "FAST"
                }

                else -> {
                    Thread.sleep(2000)
                    "SLOW"
                }
            }
        }

        val startedAt = System.currentTimeMillis()
        val winner = race.awaitWinner()
        val elapsed = System.currentTimeMillis() - startedAt
        race.cancel()

        assertEquals("FAST", winner)
        assertTrue(
            "首胜必须立即返回、不等 2s 的慢兄弟（实测 ${elapsed}ms）——旧实现在这里就是 4s 卡顿",
            elapsed < 600,
        )
    }

    @Test
    fun `全部失败返回 null`() {
        val race = startRaceFirstSuccess(listOf("a", "b", "c")) { null }
        val winner = race.awaitWinner()
        race.cancel()
        assertNull("三路都没结果时应返回 null（页面画检查失败），不能永远挂着", winner)
    }

    @Test
    fun `空候选直接返回 null`() {
        val race = startRaceFirstSuccess(emptyList<String>()) { "unused" }
        val winner = race.awaitWinner()
        race.cancel()
        assertNull(winner)
    }

    @Test
    fun `所有成功结果都留在 successes 里_供摘要回填`() {
        val race = startRaceFirstSuccess(listOf("a", "b")) { candidate ->
            Thread.sleep(if (candidate == "a") 10 else 40)
            "result-$candidate"
        }

        val winner = race.awaitWinner()
        // 胜者立刻返回；落败者稍后才写入 successes —— 摘要回填正是靠这个窗口。
        val deadline = System.currentTimeMillis() + 1500
        while (race.successes.size < 2 && System.currentTimeMillis() < deadline) {
            Thread.sleep(20)
        }
        race.cancel()

        assertEquals("result-a", winner)
        assertEquals(
            "两路成功都应留在 successes（摘要回填要从兄弟策略取 SHA-256）",
            setOf("a", "b"),
            race.successes.keys,
        )
    }
}
