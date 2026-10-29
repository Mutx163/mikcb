package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.infra.MaintainerGroup
import com.mutx163.qingyu.infra.WarehouseRepositorySource
import com.mutx163.qingyu.infra.maintainersCacheKey
import java.io.File
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * F09（关于族收尾）取数层测试：鸣谢名单 + 教务适配者名单。
 *
 * ## 期望值来源（独立于实现）
 *
 * - **候选顺序与状态码口径**：`support_creator_service.dart:fetchDonors` /
 *   `_fetchDonorData`（官方直连 → GitCode，非 200 抛 `http_N`）；
 * - **YAML 解析**：`warehouse_repository_service.dart:_parseYamlListMaps`（:631-731）
 *   与 `fetchRootIndex` / `fetchAdaptersIndex` 的过滤条件（:71-142）；
 * - **分组/排序**：`about_screen.dart:_fetchMaintainersFromWarehouse`（:2315-2367）；
 * - **文案**：直读 `lib/l10n/app_zh.arb` 对拍，不手抄。
 *
 * ## 为什么一个真实网络请求都不发
 *
 * `JdkAboutHttp` 只是「`HttpURLConnection` 读 200 的 body」这十几行，靠单测证明它没意义；
 * 有意义的是**拿到状态码之后怎么判断**。[FakeHttp] 把 200/304/404/500/抛异常五种输入
 * 逐一喂进去，这才是本页最容易出错的地方。
 */
class AboutFeedTest {

    // ---------- 假件 ----------

    /**
     * 按 URL 精确回放响应。没配的 URL 视为「服务器不存在这条路径」（返回 null = 传输失败）。
     */
    private class FakeHttp(
        private val responses: Map<String, AboutHttpResponse?> = emptyMap(),
        private val throwOnUrls: Set<String> = emptySet(),
    ) : AboutHttp {
        val requested = java.util.Collections.synchronizedList(arrayListOf<String>())

        override fun get(url: String): AboutHttpResponse? {
            requested.add(url)
            if (throwOnUrls.contains(url)) {
                throw java.io.IOException("simulated timeout")
            }
            return responses[url]
        }
    }

    private val source = WarehouseRepositorySource(owner = "Mutx163", repo = "qingyu_warehouse")

    private fun rootUrl() = source.buildFileUri(WarehouseMaintainersFeed.ROOT_INDEX_PATH).toString()

    private fun adaptersUrl(folder: String) =
        source.buildFileUri("resources/$folder/adapters.yaml").toString()

    private fun donorsJson(vararg names: String): String {
        val donors = names.joinToString(",") { "{\"name\":\"$it\"}" }
        return "{\"title\":\"鸣谢\",\"updatedAt\":\"2026-10-01\",\"donors\":[$donors]}"
    }

    // ---------- 鸣谢名单 ----------

    @Test
    fun `官方直连200即采用_不再请求GitCode`() {
        val http = FakeHttp(
            mapOf(SupportDonorsFeed.DONORS_URL to AboutHttpResponse(200, donorsJson("张三", "李四"))),
        )
        val outcome = SupportDonorsFeed(http).fetch()

        assertTrue("outcome=$outcome", outcome is DonorsFetchOutcome.Success)
        val data = (outcome as DonorsFetchOutcome.Success).data
        assertEquals(listOf("张三", "李四"), data.donors.map { it.name })
        assertEquals("鸣谢", data.title)
        assertEquals(1, http.requested.size)
        assertEquals(SupportDonorsFeed.DONORS_URL, http.requested.single())
    }

    @Test
    fun `官方直连404回退GitCode信封成功`() {
        val inner = donorsJson("王五")
        val base64 = java.util.Base64.getEncoder().encodeToString(inner.toByteArray(Charsets.UTF_8))
        val envelope = "{\"encoding\":\"base64\",\"content\":\"$base64\"}"
        val http = FakeHttp(
            mapOf(
                SupportDonorsFeed.DONORS_URL to AboutHttpResponse(404, ""),
                SupportDonorsFeed.GITCODE_DONORS_URL to AboutHttpResponse(200, envelope),
            ),
        )

        val outcome = SupportDonorsFeed(http).fetch()

        assertTrue("outcome=$outcome", outcome is DonorsFetchOutcome.Success)
        assertEquals(
            listOf("王五"),
            (outcome as DonorsFetchOutcome.Success).data.donors.map { it.name },
        )
    }

    @Test
    fun `两条候选都非200时_原因是最后一条的真状态码`() {
        val http = FakeHttp(
            mapOf(
                SupportDonorsFeed.DONORS_URL to AboutHttpResponse(404, ""),
                SupportDonorsFeed.GITCODE_DONORS_URL to AboutHttpResponse(500, ""),
            ),
        )

        val outcome = SupportDonorsFeed(http).fetch()

        assertEquals(DonorsFetchOutcome.Failure("http_500"), outcome)
    }

    @Test
    fun `payload不是对象时_报donors_payload_not_map而不是空名单`() {
        val http = FakeHttp(
            mapOf(
                SupportDonorsFeed.DONORS_URL to AboutHttpResponse(200, "[1,2,3]"),
                SupportDonorsFeed.GITCODE_DONORS_URL to AboutHttpResponse(200, "[1,2,3]"),
            ),
        )
        val feed = SupportDonorsFeed(http)

        // 单条候选的口径：200 + 非对象 → donors_payload_not_map（不是 donors_payload_not_json）。
        assertEquals(
            DonorsFetchOutcome.Failure("donors_payload_not_map"),
            feed.attempt(SupportDonorsFeed.DONORS_URL),
        )
        // 跨候选的口径：全失败时取**最后一条**候选的原因（那是最终卡住用户的那条）。
        assertEquals(
            DonorsFetchOutcome.Failure("gitcode_contents_decode_failed"),
            feed.fetch(),
        )
    }

    @Test
    fun `304语义是数据没变_不是失败也不是空名单`() {
        val http = FakeHttp(
            mapOf(
                SupportDonorsFeed.DONORS_URL to AboutHttpResponse(304, ""),
                SupportDonorsFeed.GITCODE_DONORS_URL to AboutHttpResponse(304, ""),
            ),
        )

        assertEquals(DonorsFetchOutcome.NotModified, SupportDonorsFeed(http).fetch())
    }

    @Test
    fun `传输层抛异常按网络不可用_不向上冒泡`() {
        val http = FakeHttp(throwOnUrls = setOf(SupportDonorsFeed.DONORS_URL))
        val outcome = SupportDonorsFeed(http).fetch()

        assertEquals(DonorsFetchOutcome.Failure("network_unreachable"), outcome)
    }

    @Test
    fun `空donors数组是合法结果_不是失败`() {
        val http = FakeHttp(
            mapOf(SupportDonorsFeed.DONORS_URL to AboutHttpResponse(200, "{\"donors\":[]}")),
        )
        val outcome = SupportDonorsFeed(http).fetch()

        assertTrue(outcome is DonorsFetchOutcome.Success)
        assertTrue((outcome as DonorsFetchOutcome.Success).data.donors.isEmpty())
    }

    // ---------- YAML 解析 ----------

    @Test
    fun `root_index解析_缺列的条目被丢弃`() {
        val yaml = """
            version: 2
            schools:
              - id: a
                name: 甲大学
                initial: J
                resource_folder: a-univ
              - id: b
                name: 乙大学
              - id: c
                name: 丙大学
                resource_folder: c-univ
            other_key:
              - id: z
        """.trimIndent()

        val rows = parseWarehouseRootIndexYaml(yaml)

        assertEquals(listOf("a", "c"), rows.map { it.id })
        assertEquals(listOf("a-univ", "c-univ"), rows.map { it.resourceFolder })
    }

    @Test
    fun `根索引顶层段结束后不再收条目`() {
        val yaml = """
            schools:
              - id: a
                name: 甲
                resource_folder: a
            adapters:
              - id: x
                name: 不该被当成学校
                resource_folder: y
        """.trimIndent()

        assertEquals(listOf("a"), parseWarehouseRootIndexYaml(yaml).map { it.id })
    }

    @Test
    fun `adapters解析_引号去壳_注释剥离_制表符当两空格`() {
        val yaml = "adapters:\n" +
            "\t- adapter_id: \"js-a\"  # 行内注释\n" +
            "\t  adapter_name: '某学校教务'\n" +
            "\t  asset_js_path: a.js\n" +
            "\t  maintainer: \" 某人 \"\n" +
            "\t- adapter_id: js-b\n" +
            "\t  adapter_name: 缺脚本\n" +
            "\t  maintainer: 某人\n"

        val rows = parseWarehouseAdaptersYaml(yaml)

        assertEquals(1, rows.size)
        assertEquals("js-a", rows[0].adapterId)
        assertEquals("某学校教务", rows[0].adapterName)
        // 引号去壳后按 Dart `_parseYamlPair` 的口径再 trim 一次。
        assertEquals("某人", rows[0].maintainer)
    }

    @Test
    fun `不在顶层段的条目一律不收`() {
        val yaml = """
            adapters:
              - adapter_id: a
                asset_js_path: a.js
            resources:
              - adapter_id: b
                asset_js_path: b.js
        """.trimIndent()

        assertEquals(listOf("a"), parseWarehouseAdaptersYaml(yaml).map { it.adapterId })
    }

    // ---------- 适配者名单取数 ----------

    private fun schoolYaml(vararg pairs: Pair<String, String>): String {
        val body = pairs.joinToString("\n") { (adapterName, maintainer) ->
            "  - adapter_id: id-$adapterName\n" +
                "    adapter_name: $adapterName\n" +
                "    asset_js_path: $adapterName.js\n" +
                "    maintainer: $maintainer"
        }
        return "adapters:\n$body\n"
    }

    @Test
    fun `两校合并_标签是学校名点适配器名_组按名排序`() {
        val root = """
            schools:
              - id: s1
                name: 甲大学
                resource_folder: s1
              - id: s2
                name: 乙大学
                resource_folder: s2
        """.trimIndent()
        val http = FakeHttp(
            mapOf(
                rootUrl() to AboutHttpResponse(200, root),
                adaptersUrl("s1") to AboutHttpResponse(200, schoolYaml("教务A" to "张三", "教务B" to "李四")),
                adaptersUrl("s2") to AboutHttpResponse(200, schoolYaml("教务C" to "张三")),
            ),
        )

        val outcome = WarehouseMaintainersFeed(http, source, parallelism = 1).fetch()

        assertTrue(outcome is MaintainersFetchOutcome.Success)
        val groups = (outcome as MaintainersFetchOutcome.Success).groups
        assertEquals(listOf("张三", "李四"), groups.map { it.name })
        assertEquals(listOf("乙大学 · 教务C", "甲大学 · 教务A"), groups[0].adapterLabels)
        assertEquals(listOf("甲大学 · 教务B"), groups[1].adapterLabels)
    }

    @Test
    fun `单校失败不影响其它学校_部分成功照常返回`() {
        val root = """
            schools:
              - id: s1
                name: 甲大学
                resource_folder: s1
              - id: s2
                name: 乙大学
                resource_folder: s2
        """.trimIndent()
        val http = FakeHttp(
            mapOf(
                rootUrl() to AboutHttpResponse(200, root),
                adaptersUrl("s1") to AboutHttpResponse(200, schoolYaml("教务A" to "张三")),
                adaptersUrl("s2") to AboutHttpResponse(404, ""),
            ),
        )

        val outcome = WarehouseMaintainersFeed(http, source, parallelism = 1).fetch()

        assertTrue(outcome is MaintainersFetchOutcome.Success)
        assertEquals(
            listOf("张三"),
            (outcome as MaintainersFetchOutcome.Success).groups.map { it.name },
        )
    }

    @Test
    fun `根索引500_报错而不是空名单`() {
        val http = FakeHttp(mapOf(rootUrl() to AboutHttpResponse(500, "")))

        val outcome = WarehouseMaintainersFeed(http, source, parallelism = 1).fetch()

        assertEquals(MaintainersFetchOutcome.Failure("http_500"), outcome)
    }

    @Test
    fun `根索引空表_报no_schools而不是空名单`() {
        val http = FakeHttp(mapOf(rootUrl() to AboutHttpResponse(200, "schools:\n")))

        val outcome = WarehouseMaintainersFeed(http, source, parallelism = 1).fetch()

        assertEquals(
            MaintainersFetchOutcome.Failure(WarehouseMaintainersFeed.REASON_NO_SCHOOLS),
            outcome,
        )
    }

    @Test
    fun `所有学校都失败时不许冒充没有适配者`() {
        val root = """
            schools:
              - id: s1
                name: 甲大学
                resource_folder: s1
        """.trimIndent()
        val http = FakeHttp(
            mapOf(
                rootUrl() to AboutHttpResponse(200, root),
                adaptersUrl("s1") to AboutHttpResponse(500, ""),
            ),
        )

        val outcome = WarehouseMaintainersFeed(http, source, parallelism = 1).fetch()

        assertEquals(
            MaintainersFetchOutcome.Failure(WarehouseMaintainersFeed.REASON_ALL_SCHOOLS_FAILED),
            outcome,
        )
    }

    @Test
    fun `学校都能读到但确实没有maintainer_是真空态`() {
        val root = """
            schools:
              - id: s1
                name: 甲大学
                resource_folder: s1
        """.trimIndent()
        val http = FakeHttp(
            mapOf(
                rootUrl() to AboutHttpResponse(200, root),
                adaptersUrl("s1") to AboutHttpResponse(200, schoolYaml("教务A" to "")),
            ),
        )

        val outcome = WarehouseMaintainersFeed(http, source, parallelism = 1).fetch()

        assertTrue(outcome is MaintainersFetchOutcome.Success)
        assertTrue((outcome as MaintainersFetchOutcome.Success).groups.isEmpty())
    }

    // ---------- 缓存 ----------

    @Test
    fun `缓存往返_名单与时间都能读回`() {
        val store = InMemoryKeyValueStore()
        val groups = listOf(
            MaintainerGroup("张三", listOf("甲大学 · 教务A")),
            MaintainerGroup("李四", listOf("乙大学 · 教务B")),
        )

        writeMaintainersCache(store, groups, 1_700_000_000_000L)

        assertEquals(groups, readMaintainersCache(store))
        assertEquals(1_700_000_000_000L, readMaintainersCacheTime(store))
        assertTrue(store.getString(maintainersCacheKey)!!.contains("张三"))
    }

    @Test
    fun `缓存损坏时回空表_不抛异常`() {
        val store = InMemoryKeyValueStore(mapOf(maintainersCacheKey to "{坏掉的 JSON"))

        assertTrue(readMaintainersCache(store).isEmpty())
        assertNull(readMaintainersCacheTime(store))
    }

    @Test
    fun `缓存时间按本地时区格式化`() {
        // 2026-10-29 14:40 UTC = 东八区 22:40。
        val millis = java.time.Instant.parse("2026-10-29T14:40:00Z").toEpochMilli()

        assertEquals(
            "2026-10-29 22:40",
            formatMaintainersCacheTime(millis, ZoneId.of("Asia/Shanghai")),
        )
    }

    // ---------- GitCode 信封 ----------

    @Test
    fun `gitcode信封解析_坏base64与非信封都回null`() {
        assertEquals(null, decodeGitCodeContentsBody("{\"content\":\"@@@\"}"))
        assertEquals(null, decodeGitCodeContentsBody("{\"encoding\":\"base64\"}"))
        assertEquals(null, decodeGitCodeContentsBody("not json"))

        val base64 = java.util.Base64.getEncoder().encodeToString("名单".toByteArray(Charsets.UTF_8))
        assertEquals("名单", decodeGitCodeContentsBody("{\"content\":\"$base64\"}"))
    }

    @Test
    fun `gitcode主机判据`() {
        assertTrue(isGitCodeContentsUrl(SupportDonorsFeed.GITCODE_DONORS_URL))
        assertTrue(!isGitCodeContentsUrl(SupportDonorsFeed.DONORS_URL))
        assertTrue(!isGitCodeContentsUrl("不是 URL"))
    }

    // ---------- 文案对拍 ----------

    private fun arbString(key: String): String {
        val candidates = listOf(
            File("../lib/l10n/app_zh.arb"),
            File("../../lib/l10n/app_zh.arb"),
            File("lib/l10n/app_zh.arb"),
            File("../../../lib/l10n/app_zh.arb"),
        )
        val file = candidates.firstOrNull { it.isFile }
            ?: error("找不到 lib/l10n/app_zh.arb，工作目录=${File(".").absolutePath}")
        @Suppress("UNCHECKED_CAST")
        val json = MiniJson.parse(file.readText(Charsets.UTF_8)) as Map<String, Any?>
        return json[key] as? String ?: error("ARB 缺少键 $key")
    }

    @Test
    fun `新增文案与ARB逐字一致`() {
        assertEquals(
            arbString("updatedAtLabel").replace("{time}", "2026-10-29 22:40"),
            ContributorsStrings.cachedAtLabel("2026-10-29 22:40"),
        )
        assertEquals(arbString("reloadAction"), ContributorsStrings.reloadAction)
    }
}
