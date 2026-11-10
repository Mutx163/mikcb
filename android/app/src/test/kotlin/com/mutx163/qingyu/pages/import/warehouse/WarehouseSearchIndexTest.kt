package com.mutx163.qingyu.pages.import.warehouse

import java.util.Base64
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 适配器（脚本）名搜索索引 `index/search_index.yaml` 的单测（2026-11-10 修复批）。
 *
 * 三件事：
 * 1. [parseWarehouseSearchIndex]：嵌套 YAML（`schools[].adapters[]`）宽松解析，与发布版
 *    `parseWarehouseSearchIndexYaml` 同口径（注释/空行/缩进/tab、缺字段跳过、没适配器的学校丢弃）；
 * 2. [WarehouseSearchIndex.matchedAdapterNamesBySchool]：名称或 ID 命中、大小写不敏感、
 *    名称空回退 ID、空白关键词回空表；
 * 3. [loadWarehouseSearchIndex]：候选链里第一个能解析的 200 生效（含 GitCode base64 信封），
 *    全失败回 `null`（搜索退化为学校字段匹配，页面不炸）。
 */
class WarehouseSearchIndexTest {

    // ── 工具 ────────────────────────────────────────────────────────────

    private class FakeFetch(
        private val respond: (String) -> WarehouseHttpResponse?,
    ) : WarehouseFetch {
        val calls = mutableListOf<String>()
        override fun get(url: String): WarehouseHttpResponse? {
            calls.add(url)
            return respond(url)
        }
    }

    private fun ok(body: String) = WarehouseHttpResponse(statusCode = 200, body = body)

    /** 仓库 `index/search_index.yaml` 的真实形状（缩进 2 学校、缩进 6 适配器）。 */
    private val searchYaml = """
        # 由 scripts/build_search_index.py 生成，勿手改
        version_id: v2026-11-01
        schools:
          - id: pku
            name: 北京大学
            adapters:
              - adapter_id: zf
                adapter_name: 正方教务系统
              - adapter_id: wakeup
                adapter_name: WakeUp课程表分享口令导入
          - id: zju
            name: 浙江大学
            adapters:
              - adapter_id: zju-new
                adapter_name: 浙大新教务
          - id: no-adapter-school
            name: 没有适配器的学校
            adapters:
          - id: broken-school
            name: 坏条目学校
        other_key:
          - adapter_id: should_not_leak
    """.trimIndent()

    // ── 解析 ────────────────────────────────────────────────────────────

    @Test
    fun `嵌套 YAML 解析出学校与适配器 下一顶层键截断`() {
        val index = parseWarehouseSearchIndex(searchYaml)

        assertEquals("v2026-11-01", index.versionId)
        assertEquals(listOf("pku", "zju"), index.schools.map { it.id })
        assertEquals(
            listOf("正方教务系统", "WakeUp课程表分享口令导入"),
            index.schools.first().adapters.map { it.adapterName },
        )
        // 没有适配器的学校、跨到下一个顶层键的条目都不能漏进来
        assertTrue(index.schools.none { it.id == "no-adapter-school" })
        assertTrue(index.schools.none { it.id == "broken-school" })
        assertTrue(
            index.schools.flatMap { it.adapters }.none { it.adapterId == "should_not_leak" },
        )
    }

    @Test
    fun `tab 缩进与行内注释按 Dart 口径处理 缺 version_id 记空串`() {
        val content = "schools:\n\t- id: pku\n\t  adapters:\n\t    - adapter_id: zf  # 行内注释\n"
        val index = parseWarehouseSearchIndex(content)

        assertEquals("", index.versionId)
        assertEquals(listOf("pku"), index.schools.map { it.id })
        assertEquals(listOf("zf"), index.schools.single().adapters.map { it.adapterId })
    }

    @Test
    fun `空文件 与 没有 schools 的文件 都回空索引而不抛`() {
        val empty = parseWarehouseSearchIndex("")
        assertEquals("", empty.versionId)
        assertTrue(empty.schools.isEmpty())

        val noSchools = parseWarehouseSearchIndex("version_id: v1\n")
        assertEquals("v1", noSchools.versionId)
        assertTrue(noSchools.schools.isEmpty())
    }

    // ── 匹配 ────────────────────────────────────────────────────────────

    @Test
    fun `按适配器名或 ID 命中 大小写不敏感 名称空回退 ID`() {
        val index = parseWarehouseSearchIndex(searchYaml)

        assertEquals(
            mapOf("pku" to listOf("正方教务系统")),
            index.matchedAdapterNamesBySchool("正方"),
        )
        assertEquals(
            mapOf("pku" to listOf("WakeUp课程表分享口令导入")),
            index.matchedAdapterNamesBySchool("wakeup"),
        )
        assertEquals(
            mapOf("zju" to listOf("浙大新教务")),
            index.matchedAdapterNamesBySchool("ZJU-NEW"),
        )
        assertTrue(index.matchedAdapterNamesBySchool("   ").isEmpty())
        assertTrue(index.matchedAdapterNamesBySchool("不存在的脚本").isEmpty())
    }

    @Test
    fun `适配器名称为空时用 ID 显示与匹配`() {
        val content = """
            schools:
              - id: pku
                adapters:
                  - adapter_id: bare
        """.trimIndent()
        val index = parseWarehouseSearchIndex(content)

        assertEquals(mapOf("pku" to listOf("bare")), index.matchedAdapterNamesBySchool("bare"))
    }

    // ── 拉取 ────────────────────────────────────────────────────────────

    @Test
    fun `候选链里首个可解析的 200 生效 404 的候选被跳过`() {
        val fetch = FakeFetch { url ->
            if (url.contains("githubusercontent")) {
                ok(searchYaml)
            } else {
                WarehouseHttpResponse(statusCode = 404, body = "")
            }
        }

        val index = loadWarehouseSearchIndex(fetch, options = null)

        assertEquals("v2026-11-01", index?.versionId)
        assertEquals(listOf("pku", "zju"), index?.schools?.map { it.id })
        assertTrue("至少试过一个候选", fetch.calls.isNotEmpty())
    }

    @Test
    fun `全部候选失败回 null 不抛`() {
        val fetch = FakeFetch { null }
        assertNull(loadWarehouseSearchIndex(fetch, options = null))

        val httpOnly = FakeFetch { WarehouseHttpResponse(statusCode = 500, body = "boom") }
        assertNull(loadWarehouseSearchIndex(httpOnly, options = null))
    }

    @Test
    fun `GitCode 主地址的 base64 信封能解开`() {
        val envelope = """{"content":"${Base64.getEncoder().encodeToString(searchYaml.toByteArray())}","encoding":"base64"}"""
        val fetch = FakeFetch { url ->
            if (url.contains("api.gitcode.com")) ok(envelope) else null
        }

        val index = loadWarehouseSearchIndex(
            fetch = fetch,
            options = null,
            source = WarehouseRepositorySource.DEFAULT.withHost(WarehouseRepositoryHost.GITCODE),
        )

        assertEquals(listOf("pku", "zju"), index?.schools?.map { it.id })
    }
}
