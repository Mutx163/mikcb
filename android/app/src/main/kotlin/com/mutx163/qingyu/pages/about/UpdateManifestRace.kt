package com.mutx163.qingyu.pages.about

import java.util.concurrent.CompletableFuture
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * 「谁先成功用谁」的竞速内核（发布版 `raceFutures`，`lib/utils/async_utils.dart:42-66` 的
 * Kotlin 等价物；2026-11-11 R-1 修复，从 `AboutUpdateHost` 的假竞速抽出来）。
 *
 * ## 为什么必须独立线程池、不等落败者
 *
 * 用户真机报「检查更新一直转」。旧实现三路都在调用方的 `coroutineScope` 里：那个作用域
 * **会等全部子协程结束**；而 `HttpURLConnection` 的 socket 读是**阻塞**的，协程取消打不断
 * 它 —— 国内丢包时 GitCode 200ms 拿到结果，也要陪 GitHub API 等满 4s。
 *
 * 本内核把每一路丢进**自己的线程池**：各路的阻塞读互不牵连；[RaceHandle.awaitWinner]
 * 只等「首个成功」（或全部失败），拿到即返回，**不 join 落败者**。落败者留在池里按各自的
 * 连接/读超时自然收尾，调用方不再等它。
 *
 * ## 为什么不用 coroutines 实现
 *
 * 本文件在 `main` 源集：轻量单测通道（`scripts/test-kotlin-module.ps1`）的 classpath 只有
 * stdlib + JUnit，没有 kotlinx-coroutines。用 `ExecutorService + CompletableFuture` 写，
 * 这个内核就能在 L0 里直接单测（含「首胜不等慢兄弟」的计时判据）。
 *
 * ## 契约
 *
 * - `attempt` 返回 `null` = 这一路没拿到可用结果，不参与竞争；
 * - 首个非空结果胜出；全部失败时 [RaceHandle.awaitWinner] 返回 `null`；
 * - [RaceHandle.successes] 线程安全，供调用方做摘要回填；
 * - 调用方用完必须 [RaceHandle.cancel]，别把落败者的后台任务留成孤儿。
 */
internal class RaceHandle<T : Any, R : Any>(
    private val executor: ExecutorService,
    /** 已成功的候选 → 结果（并发写；读时**不保证**已全部到齐）。 */
    val successes: ConcurrentHashMap<T, R>,
    private val winner: CompletableFuture<R?>,
) {

    /**
     * 等首个成功的结果；全部失败返回 null。
     *
     * **阻塞调用**：调用方要在 IO 线程上等（宿主用 `withContext(Dispatchers.IO)`）。
     * [timeoutMillis] 是兜底上限：即使某路 `attempt` 自身卡死，也不会把「检查更新」永久挂住。
     */
    fun awaitWinner(timeoutMillis: Long = DEFAULT_WAIT_TIMEOUT_MS): R? = try {
        winner.get(timeoutMillis, TimeUnit.MILLISECONDS)
    } catch (_: Exception) {
        null
    }

    /** 取消落败者（阻塞中的 socket 读不保证立刻停，但没有人再等它）。 */
    fun cancel() {
        executor.shutdownNow()
    }

    companion object {
        /** 单次检查的最长等待：三条路的连接/读超时都在这以内，超了按「没查到」收场。 */
        const val DEFAULT_WAIT_TIMEOUT_MS = 20_000L
    }
}

/**
 * 在独立线程池上并发启动 [candidates] 的 [attempt]，返回竞速句柄。
 *
 * @param candidates 候选（顺序只影响起跑顺序，不影响「谁先成功用谁」）
 * @param attempt 单路尝试（阻塞调用，跑在线程池里）；返回 null 表示这一路无可用结果
 */
internal fun <T : Any, R : Any> startRaceFirstSuccess(
    candidates: List<T>,
    attempt: (T) -> R?,
): RaceHandle<T, R> {
    val successes = ConcurrentHashMap<T, R>()
    val winner = CompletableFuture<R?>()
    val executor = Executors.newFixedThreadPool(candidates.size.coerceAtLeast(1)) { runnable ->
        Thread(runnable, "manifest-race").apply { isDaemon = true }
    }
    if (candidates.isEmpty()) {
        winner.complete(null)
        return RaceHandle(executor, successes, winner)
    }
    val remaining = AtomicInteger(candidates.size)
    for (candidate in candidates) {
        executor.execute {
            val result = runCatching { attempt(candidate) }.getOrNull()
            if (result != null) {
                successes[candidate] = result
                // 首个 complete 生效；后来的 complete 返回 false，不会覆盖胜者。
                winner.complete(result)
            }
            if (remaining.decrementAndGet() == 0) {
                // 全部结束仍无人胜出 → 明确交回「没结果」，调用方不会永远挂着。
                winner.complete(null)
            }
        }
    }
    return RaceHandle(executor, successes, winner)
}
