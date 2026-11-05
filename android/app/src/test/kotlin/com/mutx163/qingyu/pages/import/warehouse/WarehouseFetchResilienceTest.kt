package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.infra.defaultMirrorUrlPrefix
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 拉取层的**抗网络**判据（2026-11-05：用户实报「联网页加载极慢 / 有时出不来 / 挂 VPN 直接失败」）。
 *
 * 钉四件事，全部是「白等」的解药：
 *
 * 1. **每族额度**：主地址 15s、GitHub raw 回退 8s、镜像 6s（[WarehouseRepositoryService]）；
 * 2. **同族跳过只认「主机不可达」**（DNS / 连接被拒）——四个镜像其实是四台不同的代理，
 *    超时 / TLS / 泛 IO 时继续试下一台，白等的上限交给总预算；
 * 3. **整条链总预算**：用尽就不再开新候选，把「6 × 15s = 90s」封死；
 * 4. **错误码分级**：网整体不通（[WarehouseFeedCodes.NETWORK_UNREACHABLE]）与「镜像挂了」
 *    必须分开；而**失败原因不明**（`UNKNOWN`，含所有假实现）一律保持旧码，不改既有断言。
 *
 * 另加 [WarehouseRepositoryCache] 的往返/过期判据——缓存是「有时出不来」的另一半解药。
 *
 * ## 为什么不许用真实墙钟（2026-11-05 稳健性修）
 *
 * 拉取层的每个候选**不真发请求**（假 fetch 立即返回），但 `load()` 的预算判据读的是时钟：
 * 默认实现是 `System.currentTimeMillis()`。于是「六个候选全试」这类断言会**跟着机器快慢抖**——
 * 本机同时跑好几个 Gradle/kotlinc 时会话时停 30 秒，剩余预算直接掉到 800ms 以下，
 * 循环提前收手，断言就成了「无缘无故少试了三个」。
 *
 * 所以本文件所有服务一律经 [service] 建，**时钟冻结在 0**：剩余预算恒等于总预算，
 * 断言只反映收敛逻辑，与机器负载无关。真要看预算怎么用尽的，用 [totalBudgetStopsNewCandidates]
 * 里那种可控推进的假时钟——仍然没有一行真实 `delay`。
 */
class WarehouseFetchResilienceTest {

    // ── 工具 ────────────────────────────────────────────────────────────

    /** 冻结时钟：永远回 0，剩余预算恒等于 `budgetMillis`。 */
    private val frozenClock: () -> Long = { 0L }

    /**
     * 建服务，**默认冻结时钟**（理由见类注释）。
     *
     * 只在这里暴露构造参数，测试正文不去碰 `WarehouseRepositoryService` 的默认墙钟——
     * 那样一不小心就又把时间敏感塞回来了。
     */
    private fun service(
        fetch: WarehouseFetch,
        source: WarehouseRepositorySource = gitCodeSource,
        mirrorUrlPrefix: String? = defaultMirrorUrlPrefix,
        options: WarehouseFetchOptions? = null,
        budgetMillis: Long = DEFAULT_TOTAL_BUDGET_MILLIS,
        clockMillis: () -> Long = frozenClock,
    ): WarehouseRepositoryService = WarehouseRepositoryService(
        fetch = fetch,
        source = source,
        mirrorUrlPrefix = mirrorUrlPrefix,
        options = options,
        budgetMillis = budgetMillis,
        clockMillis = clockMillis,
    )

    /**
     * 按脚本回响应的假 fetch，**记录每次调用的 (url, 超时)**。
     *
     * [failure] 是「这次传输失败的原因」，由 [lastTransportFailure] 报告——
     * 真实现的分类逻辑要真网络才测得到，这里只测**拉取层怎么用这个信息**。
     */
    private class ScriptedFetch(
        private val respond: (url: String) -> WarehouseHttpResponse?,
        private val failure: WarehouseTransportFailure = WarehouseTransportFailure.UNKNOWN,
    ) : WarehouseFetch {
        val calls = mutableListOf<Pair<String, Int>>()

        override fun get(url: String): WarehouseHttpResponse? = get(url, 0)

        override fun get(url: String, timeoutMillis: Int): WarehouseHttpResponse? {
            calls.add(url to timeoutMillis)
            return respond(url)
        }

        override fun lastTransportFailure(): WarehouseTransportFailure = failure
    }

    private val gitCodeSource = WarehouseRepositorySource.DEFAULT.withHost(WarehouseRepositoryHost.GITCODE)
    private val gitHubSource = WarehouseRepositorySource.DEFAULT.withHost(WarehouseRepositoryHost.GITHUB)

    private val rootYaml = """
        schools:
          - id: pku
            name: Peking
            initial: B
            resource_folder: pku
          - id: seu
            name: SEU
            initial: S
            resource_folder: seu
    """.trimIndent()

    private fun ok(body: String = rootYaml) = WarehouseHttpResponse(statusCode = 200, body = body)

    // ── 1. 每族额度 ─────────────────────────────────────────────────────

    @Test
    fun `候选按族给不同超时额度 主 15s 回退 8s 镜像 6s`() {
        val fetch = ScriptedFetch({ null })
        service(fetch = fetch).loadRootIndex()

        // 顺序：主地址 → GitHub raw 回退 → 四个镜像（内置前缀，去重后 4 条）
        assertEquals(
            listOf(15_000, 8_000, 6_000, 6_000, 6_000, 6_000),
            fetch.calls.map { it.second },
        )
        assertTrue(fetch.calls.first().first.startsWith("https://api.gitcode.com"))
        assertTrue(fetch.calls[1].first.startsWith("https://raw.githubusercontent.com"))
    }

    // ── 2. 同族跳过 ─────────────────────────────────────────────────────

    @Test
    fun `镜像主机不可达时（DNS 或拒连）不再逐个白等`() {
        // 判据是「秒失败的主机不可达」：DNS 解析不出来 = 这台设备的出口连不出去，
        // 四台镜像走同一条出口 ⇒ 试一台就够。
        for (failure in listOf(WarehouseTransportFailure.DNS, WarehouseTransportFailure.CONNECT_REFUSED)) {
            val fetch = ScriptedFetch({ null }, failure = failure)
            val result = service(fetch = fetch).loadRootIndex() as WarehouseLoad.Failed

            // 主地址、回退各试一次（不参与同族跳过），第一个镜像 DNS/拒连后其余三个被跳过
            assertEquals("$failure：主 + 回退 + 一个镜像", 3, fetch.calls.size)
            assertEquals(3, result.attempts)
        }
    }

    @Test
    fun `镜像只是超时或 TLS 失败时 继续试完四个镜像`() {
        // 四个镜像是四台不同的代理：一台超时 ≠ 四台全死。最坏的真实路径正是
        // 「前三个恰好半死、第四个通」，所以这几类失败一律不许拉黑同族
        // （收敛交给总预算，不拿命中率来换）。
        for (failure in listOf(
            WarehouseTransportFailure.TIMEOUT,
            WarehouseTransportFailure.TLS,
            WarehouseTransportFailure.IO,
        )) {
            val fetch = ScriptedFetch({ null }, failure = failure)
            service(fetch = fetch).loadRootIndex()

            assertEquals("$failure：六个候选全试", 6, fetch.calls.size)
        }
    }

    @Test
    fun `失败原因不明时不跳过任何候选 行为与改动前一致`() {
        val fetch = ScriptedFetch({ null }, failure = WarehouseTransportFailure.UNKNOWN)
        service(fetch = fetch).loadRootIndex()

        assertEquals("UNKNOWN 一律不推断，六个候选全试", 6, fetch.calls.size)
    }

    // ── 3. 总预算 ───────────────────────────────────────────────────────

    @Test
    fun `总预算用尽后不再开新候选`() {
        // ① 冻结时钟：六个候选全试 —— 证明「收手」只由预算判据决定，不是碰巧到点。
        val frozenFetch = ScriptedFetch({ null })
        service(fetch = frozenFetch, budgetMillis = 32_000L).loadRootIndex()
        assertEquals("时钟不动 ⇒ 余额永远够：六个候选全试", 6, frozenFetch.calls.size)

        // ② 可控时钟：第 1 次问时间用来算 deadline（回 0 ⇒ deadline 32s），之后每次问
        // 都只剩 500ms（< 800ms 门槛）⇒ **第一条候选之前**就收手。一步都不用真等。
        var queries = 0
        val starvedFetch = ScriptedFetch({ null })
        service(
            fetch = starvedFetch,
            budgetMillis = 32_000L,
            clockMillis = {
                queries += 1
                if (queries >= 2) 31_500L else 0L
            },
        ).loadRootIndex()
        assertEquals("余额不足 800ms 就收手：一条都不该发", 0, starvedFetch.calls.size)
    }

    // ── 4. 错误码分级 ───────────────────────────────────────────────────

    @Test
    fun `多数主机传输失败且没拿到任何状态码时报网不通`() {
        val fetch = ScriptedFetch({ null }, failure = WarehouseTransportFailure.DNS)
        val result = service(fetch = fetch).loadRootIndex() as WarehouseLoad.Failed

        assertEquals(WarehouseFeedCodes.NETWORK_UNREACHABLE, result.code)
    }

    @Test
    fun `失败原因不明时仍报原来的镜像码 不改既有断言`() {
        val fetch = ScriptedFetch({ null }, failure = WarehouseTransportFailure.UNKNOWN)
        val withMirror = service(fetch = fetch).loadRootIndex() as WarehouseLoad.Failed
        assertEquals(WarehouseFeedCodes.FETCH_FAILED_MIRROR, withMirror.code)

        val noMirror = service(
            fetch = ScriptedFetch({ null }),
            mirrorUrlPrefix = null,
        ).loadRootIndex() as WarehouseLoad.Failed
        assertEquals(WarehouseFeedCodes.FETCH_FAILED_GITHUB, noMirror.code)
    }

    @Test
    fun `服务器回过状态码就不算网不通`() {
        val fetch = ScriptedFetch({ WarehouseHttpResponse(statusCode = 503, body = "") })
        val result = service(fetch = fetch).loadRootIndex() as WarehouseLoad.Failed

        assertEquals(
            "拿到了 503 说明网是通的，只是服务不行——不许报成网不通",
            WarehouseFeedCodes.FETCH_FAILED_MIRROR,
            result.code,
        )
    }

    // ── 5. 偏好（按设置选源） ───────────────────────────────────────────

    @Test
    fun `preferGitCode 时主地址走 GitCode original 来源不拼镜像`() {
        val fetch = ScriptedFetch({ null })
        val options = WarehouseFetchOptions(preferGitCode = true, mirrorUrlPrefix = null)
        service(fetch = fetch, options = options).loadRootIndex()

        assertTrue(fetch.calls.first().first.startsWith("https://api.gitcode.com"))
        assertEquals("original 来源不带镜像，只剩主地址 + raw 回退", 2, fetch.calls.size)
    }

    @Test
    fun `关掉 preferGitCode 时主地址仍是 GitHub raw`() {
        val fetch = ScriptedFetch({ null })
        val options = WarehouseFetchOptions(preferGitCode = false, mirrorUrlPrefix = null)
        // 用仓库的默认源（不是 GitCode）：这一条测的是「偏好关掉时不许偷偷换宿主」。
        service(
            fetch = fetch,
            source = WarehouseRepositorySource.DEFAULT,
            options = options,
        ).loadRootIndex()

        assertTrue(fetch.calls.first().first.startsWith("https://raw.githubusercontent.com"))
        assertEquals(1, fetch.calls.size)
    }

    // ── 6. 缓存与原文回传 ───────────────────────────────────────────────

    @Test
    fun `成功时把原文带回来 供缓存回写`() {
        val fetch = ScriptedFetch({ ok() })
        val result = service(
            fetch = fetch,
            source = gitHubSource,
            mirrorUrlPrefix = null,
        ).loadRootIndex() as WarehouseLoad.Ok

        assertEquals(rootYaml, result.raw)
        assertEquals(2, result.value.schools.size)
    }

    @Test
    fun `索引缓存能往返 且过期与坏内容判得准`() {
        val store = InMemoryKeyValueStore()
        val cache = WarehouseRepositoryCache(store)
        assertNull("没写过就是没有缓存", cache.readRootIndex())

        cache.writeRootIndex(rootYaml, nowMillis = 1_000L)
        val cached = cache.readRootIndex()
        assertNotNull("写过之后必须读得回来", cached)
        val loaded = cached!!

        assertEquals(2, loaded.value.schools.size)
        assertEquals(1_000L, loaded.fetchedAtMillis)
        assertTrue("一分钟内算新鲜", cache.isFresh(loaded, nowMillis = 61_000L))
        assertFalse(
            "超过 TTL 就不新鲜（但仍可用，只是要立刻后台刷新）",
            cache.isFresh(loaded, nowMillis = 1_000L + WarehouseRepositoryCache.DEFAULT_TTL_MILLIS + 1),
        )

        val broken = WarehouseRepositoryCache(
            InMemoryKeyValueStore(mapOf(WarehouseRepositoryCache.ROOT_INDEX_KEY to "schools:\n")),
        )
        assertNull("解析不出来的缓存当没有缓存，不能反过来上屏成空名单", broken.readRootIndex())
    }

    @Test
    fun `适配器清单缓存按学校分桶 互不覆盖`() {
        val cache = WarehouseRepositoryCache(InMemoryKeyValueStore())
        val pku = WarehouseSchoolEntry(id = "pku", name = "Peking", resourceFolder = "pku")
        val seu = WarehouseSchoolEntry(id = "seu", name = "SEU", resourceFolder = "seu")

        cache.writeAdaptersIndex(pku, "adapters:\n  - adapter_id: a\n    adapter_name: A\n    asset_js_path: a.js\n")
        cache.writeAdaptersIndex(seu, "adapters:\n  - adapter_id: b\n    adapter_name: B\n    asset_js_path: b.js\n")

        assertEquals("a", cache.readAdaptersIndex(pku)?.value?.adapters?.single()?.id)
        assertEquals("b", cache.readAdaptersIndex(seu)?.value?.adapters?.single()?.id)
    }
}
