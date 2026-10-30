package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * 适配仓数据层（8a）的 JVM 单测。
 *
 * 覆盖三段纯逻辑：
 * 1. [WarehouseYamlList]：仓库两种文件的真实形状（引号 / 注释 / tab 缩进 / 下一节边界）；
 * 2. [parseWarehouseRootIndex] / [parseWarehouseAdaptersIndex]：字段映射、坏条目丢弃、
 *    空清单报什么码；
 * 3. [WarehouseRepositoryService]：候选链顺序、第几个候选才成功、全失败报哪个码、
 *    解析失败**不换候选**、GitCode base64 信封。
 *
 * 网络不发真请求：[WarehouseFetch] 注入假件，按 URL 回预设响应。
 */
class WarehouseRepositoryFeedTest {

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

    private val gitHubSource = WarehouseRepositorySource(
        owner = "Mutx163",
        repo = "qingyu_warehouse",
        branch = "main",
        host = WarehouseRepositoryHost.GITHUB,
        // 与 Dart 默认源一致：`gitcodeOwner` 覆盖后 GitCode 侧的命名空间是 `mutx`。
        gitcodeOwner = "mutx",
    )

    private val gitCodeSource = gitHubSource.withHost(WarehouseRepositoryHost.GITCODE)

    private val school = WarehouseSchoolEntry(
        id = "pku",
        name = "北京大学",
        initial = "B",
        resourceFolder = "pku",
    )

    private val rootYaml = """
        # 适配仓根索引
        version: 1
        schools:
          - id: pku
            name: 北京大学
            initial: B
            resource_folder: pku
          - id: tsinghua
            name: "清华大学"   # 行内注释要剥掉
            initial: 'Q'
            resource_folder: tsinghua
        adapters:
          - adapter_id: should_not_leak
    """.trimIndent()

    // ── YAML 子集解析 ───────────────────────────────────────────────────

    @Test
    fun `顶层键下的条目按缩进成组 引号与行内注释按 Dart 口径处理`() {
        val rows = WarehouseYamlList.parse(rootYaml, topLevelKey = "schools")

        assertEquals(2, rows.size)
        assertEquals("pku", rows[0]["id"])
        assertEquals("北京大学", rows[0]["name"])
        assertEquals("pku", rows[0]["resource_folder"])
        // 双引号 + 行内注释：值里不能留 '"清华大学"   # …'
        assertEquals("清华大学", rows[1]["name"])
        // 单引号
        assertEquals("Q", rows[1]["initial"])
    }

    @Test
    fun `缩进归零的下一节必须截断 不能把 adapters 读进 schools`() {
        val rows = WarehouseYamlList.parse(rootYaml, topLevelKey = "schools")
        assertTrue(rows.none { it.containsKey("adapter_id") })

        val adapterRows = WarehouseYamlList.parse(rootYaml, topLevelKey = "adapters")
        assertEquals(1, adapterRows.size)
        assertEquals("should_not_leak", adapterRows[0]["adapter_id"])
    }

    @Test
    fun `顶层键不存在时回空列表 不抛`() {
        assertEquals(0, WarehouseYamlList.parse(rootYaml, topLevelKey = "courses").size)
        assertEquals(0, WarehouseYamlList.parse("", topLevelKey = "schools").size)
    }

    @Test
    fun `tab 缩进按两个空格折算 条目仍能被识别`() {
        val content = "schools:\n\t- id: a\n\t  name: 甲\n\t  resource_folder: a\n"
        val rows = WarehouseYamlList.parse(content, topLevelKey = "schools")
        assertEquals(1, rows.size)
        assertEquals("甲", rows[0]["name"])
    }

    @Test
    fun `没有冒号加空格的行不是键值对 单个引号也不会把解析打崩`() {
        assertNull(WarehouseYamlList.parsePair("id:pku"))
        assertNull(WarehouseYamlList.parsePair(": value"))
        assertEquals("k" to "'", WarehouseYamlList.parsePair("k: '"))
        assertEquals("k" to "v", WarehouseYamlList.parsePair("k: v"))
    }

    @Test
    fun `值里的转义按 Dart 只解 n r t 三个`() {
        assertEquals("第一行\n第二行", WarehouseYamlList.decodeEscaped("第一行\\n第二行"))
        assertEquals("a\tb", WarehouseYamlList.decodeEscaped("a\\tb"))
        // 未知转义原样保留（Dart 也不解 \uXXXX，服务端已经给的是明文）
        assertEquals("a\\u4e2db", WarehouseYamlList.decodeEscaped("a\\u4e2db"))
    }

    // ── 两个索引的解析 ──────────────────────────────────────────────────

    @Test
    fun `根索引映射四字段 缺 resource_folder 的条目必须丢掉`() {
        val content = """
            schools:
              - id: ok
                name: 正常学校
                initial: Z
                resource_folder: ok
              - id: no_folder
                name: 没有资源目录
                initial: N
              - name: 没有 id
                initial: M
                resource_folder: m
        """.trimIndent()

        val index = parseWarehouseRootIndex(content)
        assertEquals(1, index.schools.size)
        assertEquals("ok", index.schools[0].id)
        // 根索引里没有的字段落默认值
        assertEquals("default", index.schools[0].category)
    }

    @Test
    fun `根索引一所学校都没有时报 warehouse_no_schools_index`() {
        try {
            parseWarehouseRootIndex("schools:\nversion: 1\n")
            fail("空清单必须报错，不能静默返回空列表")
        } catch (error: WarehouseFeedException) {
            assertEquals(WarehouseFeedCodes.NO_SCHOOLS, error.code)
        }
    }

    @Test
    fun `适配器索引映射 Dart 键名 含 sha256 与 import_url`() {
        val content = """
            school_id: pku
            adapters:
              - adapter_id: zf
                adapter_name: 正方教务
                category: 教务
                asset_js_path: scripts/zf.js
                import_url: https://elective.pku.edu.cn/
                maintainer: 某人
                description: 正方 v4
                sha256: abc123
              - adapter_id: broken
                adapter_name: 缺脚本
                import_url: https://example.com/
        """.trimIndent()

        val index = parseWarehouseAdaptersIndex(content, school)
        assertEquals(1, index.adapters.size)
        val adapter = index.adapters[0]
        assertEquals("zf", adapter.id)
        assertEquals("正方教务", adapter.name)
        assertEquals("scripts/zf.js", adapter.script)
        assertEquals("https://elective.pku.edu.cn/", adapter.importUrl)
        assertEquals("abc123", adapter.sha256)
        assertEquals("pku", index.schoolId)
        assertEquals("北京大学", index.schoolName)
    }

    @Test
    fun `适配器全被过滤时报 warehouse_no_adapters 且带学校标识`() {
        try {
            parseWarehouseAdaptersIndex("adapters:\n  - adapter_id: x\n", school)
            fail("空清单必须报错")
        } catch (error: WarehouseFeedException) {
            assertEquals(WarehouseFeedCodes.NO_ADAPTERS, error.code)
            // 多校共用同一个仓时，日志必须能分清是哪所学校的适配器为空
            assertTrue(error.detail.contains("pku"))
        }
    }

    // ── 候选链 ──────────────────────────────────────────────────────────

    @Test
    fun `GitHub 宿主的主地址是 raw 镜像排在其后 且不重复`() {
        val urls = WarehouseRepositoryUrls.candidateUrls(gitHubSource, "index/root_index.yaml")
        assertEquals(
            "https://raw.githubusercontent.com/Mutx163/qingyu_warehouse/main/index/root_index.yaml",
            urls.first(),
        )
        assertEquals("主地址只能出现一次", 1, urls.count { it == urls.first() })
        assertTrue("开了镜像就要有镜像候选", urls.size > 1)
        assertTrue(urls.drop(1).all { it.endsWith("/index/root_index.yaml") })
    }

    @Test
    fun `GitCode 宿主先试 v5 contents API 再回退 GitHub raw`() {
        val urls = WarehouseRepositoryUrls.candidateUrls(gitCodeSource, "index/root_index.yaml")
        assertEquals(
            "https://api.gitcode.com/api/v5/repos/mutx/qingyu_warehouse/contents/index/root_index.yaml?ref=main",
            urls.first(),
        )
        assertEquals(
            "https://raw.githubusercontent.com/Mutx163/qingyu_warehouse/main/index/root_index.yaml",
            urls[1],
        )
    }

    @Test
    fun `关掉镜像时候选只有主地址加 GitCode 回退`() {
        assertEquals(1, WarehouseRepositoryUrls.candidateUrls(gitHubSource, "a.yaml", null).size)
        assertEquals(2, WarehouseRepositoryUrls.candidateUrls(gitCodeSource, "a.yaml", null).size)
    }

    // ── 拉取服务：候选切换与错误分类 ────────────────────────────────────

    @Test
    fun `主地址 500 时换下一个候选 拿到的 url 是成功的那个`() {
        val primary = WarehouseRepositoryUrls.primaryUrl(gitHubSource, "index/root_index.yaml")
        val fetch = FakeFetch { url ->
            if (url == primary) WarehouseHttpResponse(statusCode = 500, body = "") else ok(rootYaml)
        }
        val service = WarehouseRepositoryService(fetch = fetch, source = gitHubSource)

        val result = service.loadRootIndex()
        assertTrue(result is WarehouseLoad.Ok)
        result as WarehouseLoad.Ok
        assertEquals(2, result.value.schools.size)
        assertEquals(2, result.attempts)
        assertEquals(fetch.calls[1], result.url)
    }

    @Test
    fun `传输层失败回 null 也算这次候选失败 继续下一个`() {
        val primary = WarehouseRepositoryUrls.primaryUrl(gitHubSource, "index/root_index.yaml")
        val fetch = FakeFetch { url -> if (url == primary) null else ok(rootYaml) }
        val result = WarehouseRepositoryService(fetch = fetch, source = gitHubSource).loadRootIndex()
        assertTrue(result is WarehouseLoad.Ok)
        assertEquals(2, (result as WarehouseLoad.Ok).attempts)
    }

    @Test
    fun `全部候选失败时报镜像码 关掉镜像时报 GitHub 码`() {
        val dead = FakeFetch { null }

        val withMirror = WarehouseRepositoryService(fetch = dead, source = gitHubSource)
            .loadRootIndex() as WarehouseLoad.Failed
        assertEquals(WarehouseFeedCodes.FETCH_FAILED_MIRROR, withMirror.code)
        assertEquals(dead.calls.size, withMirror.attempts)

        val noMirror = WarehouseRepositoryService(
            fetch = dead,
            source = gitHubSource,
            mirrorUrlPrefix = null,
        ).loadRootIndex() as WarehouseLoad.Failed
        assertEquals(WarehouseFeedCodes.FETCH_FAILED_GITHUB, noMirror.code)
        assertEquals(1, noMirror.attempts)
    }

    @Test
    fun `解析失败不换候选 一次就停 报解析码`() {
        val fetch = FakeFetch { ok("schools:\nversion: 1\n") }
        val result = WarehouseRepositoryService(fetch = fetch, source = gitHubSource)
            .loadRootIndex() as WarehouseLoad.Failed

        assertEquals(WarehouseFeedCodes.NO_SCHOOLS, result.code)
        assertEquals("格式错了换镜像也没用，不该把超时乘上候选数", 1, result.attempts)
        assertEquals(1, fetch.calls.size)
    }

    @Test
    fun `GitCode 信封解出 base64 正文后能正常解析`() {
        val encoded = java.util.Base64.getEncoder()
            .encodeToString(rootYaml.toByteArray(Charsets.UTF_8))
        val envelope = """{"content":"$encoded","encoding":"base64"}"""
        val fetch = FakeFetch { ok(envelope) }

        val result = WarehouseRepositoryService(fetch = fetch, source = gitCodeSource)
            .loadRootIndex()
        assertTrue(result is WarehouseLoad.Ok)
        assertEquals(2, (result as WarehouseLoad.Ok).value.schools.size)
        assertEquals(1, result.attempts)
    }

    @Test
    fun `信封坏了换下一个候选 而不是当成空内容`() {
        val fetch = FakeFetch { url ->
            if (url.startsWith("https://api.gitcode.com")) {
                ok("""{"content":"","encoding":"base64"}""")
            } else {
                ok(rootYaml)
            }
        }
        val result = WarehouseRepositoryService(fetch = fetch, source = gitCodeSource)
            .loadRootIndex() as WarehouseLoad.Ok

        assertEquals(2, result.value.schools.size)
        assertTrue(result.url.startsWith("https://raw.githubusercontent.com"))
        assertEquals(2, result.attempts)
    }

    @Test
    fun `适配器清单按学校 resource_folder 拼路径`() {
        val fetch = FakeFetch { ok("adapters:\n  - adapter_id: a\n    adapter_name: 甲\n    asset_js_path: s.js\n") }
        val service = WarehouseRepositoryService(fetch = fetch, source = gitHubSource, mirrorUrlPrefix = null)

        val result = service.loadAdaptersIndex(school)
        assertTrue(result is WarehouseLoad.Ok)
        assertEquals(1, (result as WarehouseLoad.Ok).value.adapters.size)
        assertTrue(fetch.calls.first().endsWith("/resources/pku/adapters.yaml"))
    }

    @Test
    fun `decodeGitCodeContentsBody 对非信封与坏 base64 一律回 null`() {
        assertNull(decodeGitCodeContentsBody("schools:\n"))
        assertNull(decodeGitCodeContentsBody("""{"content":null}"""))
        assertNull(decodeGitCodeContentsBody("""{"content":"@@@@"}"""))
        assertTrue(isGitCodeContentsUrl("https://api.gitcode.com/api/v5/repos/a/b/contents/x?ref=main"))
        assertTrue(!isGitCodeContentsUrl("https://raw.githubusercontent.com/a/b/main/x"))
    }
}
