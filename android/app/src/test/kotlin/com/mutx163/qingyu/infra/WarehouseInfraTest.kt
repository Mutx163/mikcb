package com.mutx163.qingyu.infra

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 适配仓单测。
 *
 * 期望值来源：
 * - Dart 逐行（warehouse_repository_models.dart 三种 URL 形态、搜索匹配、
 *   about_screen.dart 分组 trim/跳空/双排序、缓存损坏回空表）；
 * - 人推边界：非法 URL 四种错误码、空查询返回原表、名称空回退 ID、
 *   缓存中非字符串标签被过滤、round-trip 保序。
 */
class WarehouseInfraTest {

    // ---------- fromGitHubUrl ----------

    @Test
    fun `parses github repo page url`() {
        val source = WarehouseRepositorySource.fromGitHubUrl("https://github.com/Mutx163/qingyu_warehouse")
        assertEquals("Mutx163", source.owner)
        assertEquals("qingyu_warehouse", source.repo)
        assertEquals("main", source.branch)
        assertEquals(WarehouseRepositoryHost.GITHUB, source.host)
    }

    @Test
    fun `parses raw url with branch`() {
        val source = WarehouseRepositorySource.fromGitHubUrl(
            "https://raw.githubusercontent.com/Mutx163/qingyu_warehouse/dev/index.yaml",
        )
        assertEquals("dev", source.branch)
        assertEquals("Mutx163", source.owner)
    }

    @Test
    fun `parses gitcode url as gitcode host`() {
        val source = WarehouseRepositorySource.fromGitHubUrl("https://gitcode.com/mutx/qingyu")
        assertEquals(WarehouseRepositoryHost.GITCODE, source.host)
        assertEquals("mutx", source.owner)
    }

    @Test
    fun `rejects invalid urls with dart error codes`() {
        // 人推：四种错误码与 Dart 字面量一致（调用方按码展示）。
        assertFailsWithCode("not a url at all !!! :::", "invalid_repository_url")
        assertFailsWithCode("https://github.com/only-one", "incomplete_github_repo_url")
        assertFailsWithCode("https://raw.githubusercontent.com/a/b", "incomplete_raw_github_url")
        assertFailsWithCode("https://gitlab.com/a/b", "github_only_supported")
    }

    private fun assertFailsWithCode(url: String, code: String) {
        try {
            WarehouseRepositorySource.fromGitHubUrl(url)
            throw AssertionError("expected WarehouseRepositoryException for $url")
        } catch (e: WarehouseRepositoryException) {
            assertEquals(code, e.message)
        }
    }

    // ---------- uri builders ----------

    @Test
    fun `builds raw and gitcode uris`() {
        val source = WarehouseRepositorySource(owner = "Mutx163", repo = "qingyu_warehouse")
        assertEquals(
            "https://raw.githubusercontent.com/Mutx163/qingyu_warehouse/main/index/root.yaml",
            source.buildRawFileUri("/index/root.yaml").toString(),
        )
        // gitcode 命名空间只出现在默认源（gitcodeOwner="mutx" 显式指定）；
        // 手造 owner="Mutx163" 又不带 gitcodeOwner 时 Dart 同样回退 owner。
        assertEquals(
            "https://api.gitcode.com/api/v5/repos/mutx/qingyu_warehouse/contents/a%20b.yaml?ref=main",
            defaultQingyuWarehouseSource.buildGitCodeContentsUri("a b.yaml").toString(),
        )
        assertEquals("https://github.com/Mutx163/qingyu_warehouse", source.repositoryUrl)
    }

    @Test
    fun `file uri follows host`() {
        val github = WarehouseRepositorySource(owner = "o", repo = "r")
        assertTrue(github.buildFileUri("x.yaml").toString().startsWith("https://raw.githubusercontent.com/"))
        val gitcode = github.withHost(WarehouseRepositoryHost.GITCODE)
        assertTrue(gitcode.buildFileUri("x.yaml").toString().startsWith("https://api.gitcode.com/"))
    }

    @Test
    fun `withHost returns same instance when unchanged`() {
        val source = defaultQingyuWarehouseSource
        assertSame(source, source.withHost(WarehouseRepositoryHost.GITHUB))
        assertEquals(WarehouseRepositoryHost.GITHUB, defaultQingyuWarehouseSource.host)
        assertEquals("mutx", defaultQingyuWarehouseSource.gitcodeOwner)
    }

    // ---------- search ----------

    private val schools = listOf(
        WarehouseSchoolEntry("whu", "武汉大学", "W", "whu"),
        WarehouseSchoolEntry("hust", "华中科技大学", "H", "hust"),
    )

    @Test
    fun `filter matches name id initial and folder`() {
        assertEquals(listOf("whu"), filterWarehouseSchools(schools, "武汉").map { it.id })
        assertEquals(listOf("hust"), filterWarehouseSchools(schools, "HUST").map { it.id })
        assertEquals(listOf("whu"), filterWarehouseSchools(schools, "w").map { it.id })
        assertEquals(listOf("hust"), filterWarehouseSchools(schools, "hust").map { it.id })
        assertTrue(filterWarehouseSchools(schools, "不存在").isEmpty())
    }

    @Test
    fun `blank query returns original list`() {
        assertSame(schools, filterWarehouseSchools(schools, "   "))
    }

    @Test
    fun `filter falls back to adapter matches`() {
        // 人推：学校字段全不命中时，有适配器命中的学校被带出来。
        val matches = mapOf("hust" to listOf("WakeUp导入"))
        assertEquals(listOf("hust"), filterWarehouseSchools(schools, "wakeup", matches).map { it.id })
        assertTrue(filterWarehouseSchools(schools, "wakeup").isEmpty())
    }

    @Test
    fun `matched adapter names prefer display name and match id`() {
        val school = WarehouseSearchSchoolEntry(
            "s1",
            listOf(
                WarehouseSearchAdapterEntry("wakeup", "WakeUp分享口令导入"),
                WarehouseSearchAdapterEntry("bare", ""),
            ),
        )
        assertEquals(listOf("WakeUp分享口令导入"), school.matchedAdapterNames("分享口令"))
        // ID 参与匹配；名称为空回退 ID 展示。
        assertEquals(listOf("bare"), school.matchedAdapterNames("BARE"))
        assertTrue(school.matchedAdapterNames("   ").isEmpty())
    }

    @Test
    fun `matched names by school skips empty hits`() {
        val index = WarehouseSearchIndex(
            "v1",
            listOf(
                WarehouseSearchSchoolEntry("s1", listOf(WarehouseSearchAdapterEntry("a", "Alpha"))),
                WarehouseSearchSchoolEntry("s2", listOf(WarehouseSearchAdapterEntry("b", "Beta"))),
            ),
        )
        assertEquals(mapOf("s1" to listOf("Alpha")), index.matchedAdapterNamesBySchool("alpha"))
        assertTrue(index.matchedAdapterNamesBySchool("  ").isEmpty())
    }

    // ---------- maintainer grouping ----------

    @Test
    fun `grouping trims skips blank and sorts`() {
        val groups = groupMaintainerLabels(
            listOf(
                " bob " to buildMaintainerLabel("B校", "导入2"),
                "alice" to buildMaintainerLabel("A校", "导入1"),
                "bob" to buildMaintainerLabel("A校", "导入0"),
                "  " to buildMaintainerLabel("X校", "幽灵"),
                "" to buildMaintainerLabel("Y校", "幽灵2"),
            ),
        )
        assertEquals(listOf("alice", "bob"), groups.map { it.name })
        assertEquals(listOf("A校 · 导入0", "B校 · 导入2"), groups[1].adapterLabels)
        assertEquals("A校 · 导入1", groups[0].adapterLabels.single())
    }

    @Test
    fun `maintainer label shape`() {
        assertEquals("武汉大学 · WakeUp导入", buildMaintainerLabel("武汉大学", "WakeUp导入"))
    }

    // ---------- maintainers cache ----------

    @Test
    fun `cache round trip preserves groups`() {
        val groups = listOf(
            MaintainerGroup("alice", listOf("A校 · 导入1")),
            MaintainerGroup("bob", emptyList()),
        )
        val decoded = decodeMaintainersCache(encodeMaintainersCache(groups))
        assertEquals(groups, decoded)
    }

    @Test
    fun `cache decode tolerates corruption`() {
        // Dart 口径：null/空/非法/非数组一律空表；空名丢弃；非字符串标签过滤。
        assertTrue(decodeMaintainersCache(null).isEmpty())
        assertTrue(decodeMaintainersCache("").isEmpty())
        assertTrue(decodeMaintainersCache("not json").isEmpty())
        assertTrue(decodeMaintainersCache("{}").isEmpty())
        val mixed = "[{\"name\":\"\",\"adapterLabels\":[\"x\"]}," +
            "{\"name\":\"bob\",\"adapterLabels\":[\"A\",7,null]},42]"
        assertEquals(
            listOf(MaintainerGroup("bob", listOf("A"))),
            decodeMaintainersCache(mixed),
        )
    }

    // ---------- adapter copyWith ----------

    @Test
    fun `adapter copyWith replaces only given fields`() {
        val entry = WarehouseAdapterEntry(
            adapterId = "a", adapterName = "n", category = "c",
            assetJsPath = "p", importUrl = "u", maintainer = "m", description = "d",
        )
        val copied = entry.copyWith(isQingyuOnly = true)
        assertEquals(true, copied.isQingyuOnly)
        assertEquals("a", copied.adapterId)
        assertEquals("", copied.sha256)
        assertNull(entry.copyWith().let { if (it == entry) null else it })
    }
}
