package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.core.MiniJson
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 更新日志页纯逻辑测试（版本扫描 / 排序 / 装载 / 文案对拍）。
 *
 * 期望值来源（独立于实现）：
 * - 扫描与排序口径：逐条对照 `lib/screens/changelog_screen.dart:12-46 / 68-105`；
 * - 回退列表：`changelog_screen.dart:125-240` 逐字抄录，并**人工核对它本身严格倒序**
 *   （不是拿实现的排序结果当期望值）；
 * - 文案：直读 `i18n/app_zh.arb` 逐字对拍（不手抄）。
 *
 * 为什么「回退列表严格倒序」值得钉一条：那份列表是手写的 114 行版本号，
 * 新增版本时最容易犯的错就是往末尾追加（或插错位置）——那会让回退路径的展示顺序
 * 与真实清单不一致，而这条路径只在清单接口挂掉时才走到，平时没人会看见。
 */
class ChangelogModelTest {

    private fun repoFile(relative: String): File {
        val candidates = listOf(
            File("../../$relative"),
            File("../$relative"),
            File(relative),
        )
        return candidates.firstOrNull { it.isFile }
            ?: error("找不到 $relative，工作目录=${File(".").absolutePath}")
    }

    private fun arbString(key: String): String {
        @Suppress("UNCHECKED_CAST")
        val json = MiniJson.parse(repoFile("i18n/app_zh.arb").readText(Charsets.UTF_8))
            as Map<String, Any?>
        return json[key] as? String ?: error("ARB 缺少键 $key")
    }

    // ---------- asset key 匹配 ----------

    @Test
    fun `只认数字版本号的 md`() {
        assertEquals("v2.1.1.4", matchReleaseAssetKey("docs/releases/v2.1.1.4.md"))
        assertEquals("v1.1.5-a", matchReleaseAssetKey("docs/releases/v1.1.5-a.md"))
        assertEquals("v2.0", matchReleaseAssetKey("docs/releases/v2.0.md"))
    }

    @Test
    fun `同目录的 html 与 json 不算版本`() {
        // 这四条是 docs/releases/ 里真实存在的非版本文件（APK 里 134 个文件含它们）。
        assertNull(matchReleaseAssetKey("docs/releases/index.html"))
        assertNull(matchReleaseAssetKey("docs/releases/feed.json"))
        assertNull(matchReleaseAssetKey("docs/releases/latest.json"))
        assertNull(matchReleaseAssetKey("docs/releases/README.md"))
    }

    @Test
    fun `前缀不对的 key 不算版本`() {
        // Kotlin 侧实际要扫的是 APK 里的 flutter_assets/ 前缀；认版本号时必须先剥掉它，
        // 否则一个版本都扫不出来（这条就是那个坑的守卫）。
        assertNull(matchReleaseAssetKey("flutter_assets/docs/releases/v1.1.0.md"))
        assertNull(matchReleaseAssetKey("assets/flutter_assets/docs/releases/v1.1.0.md"))
    }

    // ---------- 版本解析与比较 ----------

    @Test
    fun `版本号按数字段解析`() {
        assertEquals(listOf(2, 1, 1, 4), parseReleaseVersion("v2.1.1.4"))
        assertEquals(listOf(2, 1, 1), parseReleaseVersion("v2.1.1"))
        assertEquals(listOf(1, 1, 5), parseReleaseVersion("v1.1.5-a"))
        assertEquals(listOf(0), parseReleaseVersion("dev-build"))
    }

    @Test
    fun `倒序比较按数字段而不是字符串`() {
        // 字符串比较会把 v1.1.9.7 排到 v1.1.10 前面（"9" > "1"），这是这一页最容易错的点。
        assertTrue(compareReleaseVersionsDesc("v1.1.10", "v1.1.9.7") < 0)
        assertTrue(compareReleaseVersionsDesc("v1.1.9.7", "v1.1.10") > 0)
    }

    @Test
    fun `段数不同时短的一侧补零`() {
        assertTrue(compareReleaseVersionsDesc("v2.1.1.4", "v2.1.1") < 0)
        assertTrue(compareReleaseVersionsDesc("v2.1.1", "v2.0.5.6") < 0)
        assertEquals(0, compareReleaseVersionsDesc("v2.1.1", "v2.1.1.0"))
    }

    @Test
    fun `排序结果去重且最新在前`() {
        val shuffled = listOf("v1.1.9.7", "v2.0", "v1.1.10", "v2.1.1.4", "v2.1.1", "v1.1.9.7")
        assertEquals(
            listOf("v2.1.1.4", "v2.1.1", "v2.0", "v1.1.10", "v1.1.9.7"),
            sortReleaseVersionsDesc(shuffled),
        )
    }

    // ---------- 装载 ----------

    @Test
    fun `读不到的版本跳过而不是占位`() {
        val entries = assembleChangelogEntries(listOf("v2.1.1.9", "v2.1.1.8", "v2.1.1.7")) { version ->
            when (version) {
                "v2.1.1.8" -> null
                else -> "body-$version"
            }
        }
        assertEquals(listOf("v2.1.1.9", "v2.1.1.7"), entries.map { it.version })
        assertEquals(listOf("body-v2.1.1.9", "body-v2.1.1.7"), entries.map { it.content })
    }

    @Test
    fun `读取抛异常按读不到处理`() {
        val entries = assembleChangelogEntries(listOf("v1", "v2")) { version ->
            if (version == "v1") error("asset missing") else "ok"
        }
        assertEquals(listOf("v2"), entries.map { it.version })
    }

    @Test
    fun `空正文仍然算一个版本`() {
        // Dart 的 rootBundle.loadString 对空文件返回空串（不抛），所以空文件要出现在列表里。
        val entries = assembleChangelogEntries(listOf("v1")) { "" }
        assertEquals(1, entries.size)
        assertEquals("", entries[0].content)
    }

    // ---------- 回退列表 ----------

    @Test
    fun `回退列表与 Dart 逐字一致`() {
        val versions = knownChangelogVersions()
        assertEquals(114, versions.size)
        assertEquals("v2.1.1.9", versions.first())
        assertEquals("v1.1.0", versions.last())
        // 抽查 Dart 列表里两个「跳号」的位置（v1.2.1.11 之后是 .9，v1.2.0.24 之后是 .22）：
        // 它们说明这份列表是逐版手抄的，不是补全生成的。
        assertEquals("v1.2.1.9", versions[versions.indexOf("v1.2.1.11") + 1])
        assertEquals("v1.2.0.22", versions[versions.indexOf("v1.2.0.24") + 1])
    }

    @Test
    fun `回退列表本身严格倒序`() {
        val versions = knownChangelogVersions()
        for (index in 0 until versions.size - 1) {
            assertTrue(
                "${versions[index]} 应排在 ${versions[index + 1]} 之前（回退列表本身必须倒序）",
                compareReleaseVersionsDesc(versions[index], versions[index + 1]) < 0,
            )
        }
    }

    // ---------- 文案与 ARB 对拍 ----------

    @Test
    fun `文案与 ARB 逐字一致`() {
        assertEquals(arbString("aboutChangelogTitle"), ChangelogStrings.title)
        assertEquals(arbString("aboutUpdateHighlightsTitle"), ChangelogStrings.highlightsTitle)
        assertEquals(arbString("aboutUpdateViewFullAction"), ChangelogStrings.viewFullAction)
        assertEquals(arbString("aboutUpdateCollapseAction"), ChangelogStrings.collapseAction)
    }

    @Test
    fun `带占位符的展开文案按 ARB 原文替换`() {
        val pattern = arbString("aboutUpdateViewAllAction")
        assertTrue("ARB 的 aboutUpdateViewAllAction 应含 {count} 占位符，实际=$pattern", pattern.contains("{count}"))
        assertEquals(pattern.replace("{count}", "21"), ChangelogStrings.viewAllAction(21))
    }
}
