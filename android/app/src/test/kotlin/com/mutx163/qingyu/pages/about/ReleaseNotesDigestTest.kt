package com.mutx163.qingyu.pages.about

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 发布说明摘要解析测试（`buildReleaseNotesDigest` / `releaseChangeCounts`）。
 *
 * 期望值来源（独立于实现）：
 * - 规则逐条对照 `lib/utils/release_notes_digest.dart`（2026-10-28 快照）；
 * - 两条**真实发布说明**直接读仓库里的 `docs/releases/v2.1.1.9.md` 与 `v2.1.4.1.md`，
 *   期望值是人对着原文数出来的（14 条 = 4 新增 + 10 优化；21 条 = 2 + 8 + 11），
 *   不是从实现里抄的。
 *
 * 为什么用真文件当夹具：这一层的全部价值就是「把一版几十条的扁平正文压成 3 条重点」，
 * 编造的短样本测不出真实的边界（分组标题带条数、声明重点与正文写法不一致、
 * 中英混排的标签）。
 */
class ReleaseNotesDigestTest {

    private fun releaseNotes(version: String): String {
        val relative = "docs/releases/$version.md"
        val candidates = listOf(File("../../$relative"), File("../$relative"), File(relative))
        val file = candidates.firstOrNull { it.isFile }
            ?: error("找不到 $relative，工作目录=${File(".").absolutePath}")
        return file.readText(Charsets.UTF_8)
    }

    // ---------- 空与退化输入 ----------

    @Test
    fun `空正文没有条目也没有重点`() {
        for (body in listOf("", "   ", "\n\n", "\r\n")) {
            val digest = buildReleaseNotesDigest(body)
            assertTrue("body=<$body> 应判为空", digest.isEmpty)
            assertEquals(0, digest.total)
            assertTrue(digest.highlights.isEmpty())
            assertEquals("", digest.intro)
        }
    }

    @Test
    fun `没有条目时退回原文的标志是 isEmpty`() {
        // 纯段落正文（老版本）解析不出条目 → isEmpty，渲染层据此退回 Markdown 分块。
        val digest = buildReleaseNotesDigest("首个推荐版本。\n\n这一版只是修了几个小问题。")
        assertTrue(digest.isEmpty)
        assertEquals("首个推荐版本。", digest.intro)
    }

    // ---------- 分类识别 ----------

    @Test
    fun `中文分类前缀决定类型与标签`() {
        val digest = buildReleaseNotesDigest(
            """
            - 新增 弹窗顶部渐变模糊带：材质面板顶部的分段坐到模糊带上。
            - 优化 主题色所见即所得：浅色模式下选亮黄就是要看到亮黄。
            - 修复 登录页偶发白屏。
            - 移除 旧的分享入口。
            - 顺手改了个没分类的东西。
            """.trimIndent(),
        )
        assertEquals(
            listOf(
                ReleaseChangeKind.ADDED,
                ReleaseChangeKind.IMPROVED,
                ReleaseChangeKind.FIXED,
                ReleaseChangeKind.REMOVED,
                ReleaseChangeKind.OTHER,
            ),
            digest.entries.map { it.kind },
        )
        assertEquals(listOf("新增", "优化", "修复", "移除", ""), digest.entries.map { it.label })
    }

    @Test
    fun `短标题取第一个句内分隔符之前的半句`() {
        val digest = buildReleaseNotesDigest("- 新增 弹窗顶部渐变模糊带：材质面板顶部的分段坐到模糊带上。")
        val entry = digest.entries.single()
        assertEquals("弹窗顶部渐变模糊带：材质面板顶部的分段坐到模糊带上。", entry.text)
        assertEquals("弹窗顶部渐变模糊带", entry.headline)
    }

    @Test
    fun `短标题超过四十字截断并补省略号`() {
        val long = "字".repeat(45)
        val digest = buildReleaseNotesDigest("- 新增 $long")
        assertEquals("字".repeat(40) + "…", digest.entries.single().headline)
    }

    @Test
    fun `英文分类词按作者原本的大小写做标签`() {
        val digest = buildReleaseNotesDigest(
            """
            - New: dark mode
            - FIXED a crash
            """.trimIndent(),
        )
        assertEquals(
            listOf(ReleaseChangeKind.ADDED, ReleaseChangeKind.FIXED),
            digest.entries.map { it.kind },
        )
        assertEquals(listOf("New", "FIXED"), digest.entries.map { it.label })
        assertEquals(listOf("dark mode", "a crash"), digest.entries.map { it.text })
    }

    @Test
    fun `分类前缀必须真带内容才算前缀`() {
        // 「新增」后面没有内容（rest.length == keyword.length）时不算分类前缀，
        // 整句按无分类处理，而不是产出一条空条目。
        val digest = buildReleaseNotesDigest("- 新增")
        val entry = digest.entries.single()
        assertEquals(ReleaseChangeKind.OTHER, entry.kind)
        assertEquals("新增", entry.text)
        assertEquals("新增", entry.headline)
    }

    @Test
    fun `分组标题的分类会继承给不带前缀的条目`() {
        val digest = buildReleaseNotesDigest(
            """
            ## 新增

            - 桌面小组件课程颜色
            - 课程颜色开关

            ## 修复

            - 登录页偶发白屏
            """.trimIndent(),
        )
        assertEquals(
            listOf(ReleaseChangeKind.ADDED, ReleaseChangeKind.ADDED, ReleaseChangeKind.FIXED),
            digest.entries.map { it.kind },
        )
        assertEquals(listOf("新增", "新增", "修复"), digest.entries.map { it.label })
        assertEquals(listOf("桌面小组件课程颜色", "课程颜色开关", "登录页偶发白屏"), digest.entries.map { it.headline })
    }

    @Test
    fun `分组标题带条数与装饰符也能认出分类`() {
        val digest = buildReleaseNotesDigest(
            """
            ## 新增 · 2

            - 甲

            ### ✨ 修复

            - 乙
            """.trimIndent(),
        )
        assertEquals(
            listOf(ReleaseChangeKind.ADDED, ReleaseChangeKind.FIXED),
            digest.entries.map { it.kind },
        )
        assertEquals(listOf("新增", "修复"), digest.entries.map { it.label })
    }

    // ---------- 跳过规则 ----------

    @Test
    fun `代码围栏里的内容不算条目`() {
        val digest = buildReleaseNotesDigest(
            "- 新增 功能一\n\n```\n- 新增 代码里的示例\n```\n\n- 修复 功能二",
        )
        assertEquals(listOf("功能一", "功能二"), digest.entries.map { it.text })
    }

    @Test
    fun `分隔线表格图片行都不算条目`() {
        val digest = buildReleaseNotesDigest(
            "- 新增 功能一\n\n---\n\n| 列 | 值 |\n\n![图](shot.png)\n",
        )
        assertEquals(1, digest.entries.size)
        assertEquals("功能一", digest.entries.single().text)
    }

    @Test
    fun `正文里的 sha256 行不算条目`() {
        val digest = buildReleaseNotesDigest("- 新增 功能一\n\nSHA-256: 0123456789abcdef\n")
        assertEquals(1, digest.entries.size)
    }

    @Test
    fun `缩进的二级条目不算独立条目`() {
        // 发布说明里的二级条目是上一条的细节说明，重复计数会把「一版 3 件事」
        // 说成「一版 3 件事 + 2 条细节」。
        val digest = buildReleaseNotesDigest("- 新增 功能一：说明\n  - 细节一\n  - 细节二\n")
        assertEquals(1, digest.entries.size)
        assertEquals("功能一：说明", digest.entries.single().text)
    }

    @Test
    fun `行内链接与强调标记在解析时被清掉`() {
        val digest = buildReleaseNotesDigest("- 新增 **加粗** [链接](https://example.com) 尾巴")
        assertEquals("加粗 链接 尾巴", digest.entries.single().text)
    }

    // ---------- 导语 ----------

    @Test
    fun `第一条条目之前的普通文字是导语`() {
        val digest = buildReleaseNotesDigest("# v1.0.0\n\n首个推荐版本。\n\n- 新增 功能一\n")
        assertEquals("首个推荐版本。", digest.intro)
    }

    @Test
    fun `以冒号结尾的引导句不算导语`() {
        val digest = buildReleaseNotesDigest("# v1.0.0\n\n本次更新：\n\n- 新增 功能一\n")
        assertEquals("", digest.intro)
    }

    // ---------- 重点挑选 ----------

    @Test
    fun `声明重点优先于分类优先级`() {
        val digest = buildReleaseNotesDigest(
            """
            # v1.2.3

            > 本次重点：弹窗顶部渐变模糊带、课程颜色

            - 新增 弹窗顶部渐变模糊带：材质面板顶部的分段坐到模糊带上，看起来更整体。
            - 新增 课程颜色开关：三档可选。
            - 修复 登录页偶发白屏。
            """.trimIndent(),
        )
        assertTrue(digest.highlightsDeclared)
        assertEquals(2, digest.highlights.size)
        assertEquals(
            listOf("弹窗顶部渐变模糊带", "课程颜色"),
            digest.highlights.map { it.headline },
        )
        // 声明的是简写，认回条目后要带上那条条目自己的分类与完整正文。
        assertEquals(ReleaseChangeKind.ADDED, digest.highlights[1].kind)
        assertEquals("课程颜色开关：三档可选。", digest.highlights[1].text)
        assertEquals("新增", digest.highlights[1].label)
        assertEquals(0, digest.unresolvedHighlights.size)
    }

    @Test
    fun `没声明重点时按新增优化移除修复的优先级挑`() {
        val digest = buildReleaseNotesDigest(
            """
            ## 新增

            - 桌面小组件课程颜色
            - 课程颜色开关

            ## 修复

            - 登录页偶发白屏
            """.trimIndent(),
        )
        assertFalse(digest.highlightsDeclared)
        assertEquals(
            listOf("桌面小组件课程颜色", "课程颜色开关", "登录页偶发白屏"),
            digest.highlights.map { it.headline },
        )
    }

    @Test
    fun `重点条数上限为零时不出重点`() {
        val digest = buildReleaseNotesDigest("## 新增\n\n- 甲\n- 乙\n", maxHighlights = 0)
        assertTrue(digest.highlights.isEmpty())
        assertFalse(digest.highlightsDeclared)
        assertEquals(2, digest.total)
    }

    @Test
    fun `声明的简写与正文不互为子串时按相似度兜底`() {
        // 作者声明写的是给人看的简写，正文那条字面上不包含它 —— 没有这一层兜底，
        // 声明的重点会整条认不回来（unresolvedHighlights 非空）。
        val digest = buildReleaseNotesDigest(
            """
            > 本次重点：十档玻璃滑杆

            - 优化 液态玻璃的档位改成一根 10 格节点滑杆
            """.trimIndent(),
        )
        assertTrue(digest.highlightsDeclared)
        assertEquals(1, digest.highlights.size)
        assertEquals("十档玻璃滑杆", digest.highlights.single().headline)
        assertEquals(ReleaseChangeKind.IMPROVED, digest.highlights.single().kind)
        assertEquals("液态玻璃的档位改成一根 10 格节点滑杆", digest.highlights.single().text)
        assertEquals(0, digest.unresolvedHighlights.size)
    }

    @Test
    fun `认不回来的声明会留下 unresolvedHighlights`() {
        val digest = buildReleaseNotesDigest(
            """
            > 本次重点：完全无关的一句话

            - 新增 弹窗顶部渐变模糊带
            """.trimIndent(),
        )
        assertTrue(digest.highlightsDeclared)
        assertEquals(1, digest.unresolvedHighlights.size)
        assertEquals("完全无关的一句话", digest.unresolvedHighlights.single().text)
    }

    @Test
    fun `本次重点小节里的条目既是声明也是条目`() {
        val digest = buildReleaseNotesDigest(
            """
            ## 本次重点

            - 弹窗顶部渐变模糊带
            - 课程颜色
            """.trimIndent(),
        )
        assertTrue(digest.highlightsDeclared)
        assertEquals(2, digest.total)
        assertEquals(listOf("弹窗顶部渐变模糊带", "课程颜色"), digest.highlights.map { it.headline })
        assertEquals(listOf(ReleaseChangeKind.OTHER, ReleaseChangeKind.OTHER), digest.highlights.map { it.kind })
    }

    // ---------- 分类计数 ----------

    @Test
    fun `计数按新增优化修复移除的固定顺序`() {
        val digest = buildReleaseNotesDigest(
            """
            - 修复 甲
            - 新增 乙
            - 移除 丙
            - 优化 丁
            """.trimIndent(),
        )
        assertEquals(
            listOf("新增" to 1, "优化" to 1, "修复" to 1, "移除" to 1),
            releaseChangeCounts(digest),
        )
    }

    @Test
    fun `零条的分类不进计数行`() {
        val digest = buildReleaseNotesDigest("- 新增 甲\n- 新增 乙\n")
        assertEquals(listOf("新增" to 2), releaseChangeCounts(digest))
    }

    // ---------- 真实发布说明（人对着原文数出来的期望值）----------

    @Test
    fun `真实版本 v2_1_1_9 的摘要`() {
        val digest = buildReleaseNotesDigest(releaseNotes("v2.1.1.9"))
        assertEquals(14, digest.total)
        assertEquals(4, digest.countOf(ReleaseChangeKind.ADDED))
        assertEquals(10, digest.countOf(ReleaseChangeKind.IMPROVED))
        assertEquals("", digest.intro)

        assertTrue(digest.highlightsDeclared)
        assertEquals(
            listOf("桌面小组件课程颜色", "课程颜色开关（小组件设置）", "全 App 主题色贯穿"),
            digest.highlights.map { it.headline },
        )
        assertEquals(
            listOf(ReleaseChangeKind.ADDED, ReleaseChangeKind.ADDED, ReleaseChangeKind.ADDED),
            digest.highlights.map { it.kind },
        )
        assertEquals(listOf("新增" to 4, "优化" to 10), releaseChangeCounts(digest))
        assertEquals(0, digest.unresolvedHighlights.size)
        // 「3 条重点」之外还有 11 条，所以这一版必须给展开入口。
        assertTrue(digest.total > digest.highlights.size)
    }

    @Test
    fun `真实版本 v2_1_4_1 的分组标题格式`() {
        val digest = buildReleaseNotesDigest(releaseNotes("v2.1.4.1"))
        assertEquals(21, digest.total)
        assertEquals(2, digest.countOf(ReleaseChangeKind.ADDED))
        assertEquals(8, digest.countOf(ReleaseChangeKind.IMPROVED))
        assertEquals(11, digest.countOf(ReleaseChangeKind.FIXED))
        assertEquals("", digest.intro)

        assertTrue(digest.highlightsDeclared)
        assertEquals(
            listOf("更新日志改成「本次重点 + 分类分组」", "软件更新页重做", "转场更顺"),
            digest.highlights.map { it.headline },
        )
        assertEquals(listOf("新增" to 2, "优化" to 8, "修复" to 11), releaseChangeCounts(digest))
        assertEquals(0, digest.unresolvedHighlights.size)
    }

    @Test
    fun `真实发布说明全部都能解析出条目`() {
        // 回归网：docs/releases/ 里任何一版如果格式漂移到「一条条目都认不出」，
        // 更新日志页就会退回整段原文——那是这一层要防的退步。
        val dir = listOf(
            File("../../docs/releases"),
            File("../docs/releases"),
            File("docs/releases"),
        ).firstOrNull { it.isDirectory } ?: error("找不到 docs/releases")
        val notes = dir.listFiles { file -> file.name.endsWith(".md") }.orEmpty()
        assertTrue("docs/releases 下应有发布说明", notes.size > 100)

        val unparsed = notes.filter { buildReleaseNotesDigest(it.readText(Charsets.UTF_8)).isEmpty }
        assertTrue(
            "以下发布说明解析不出任何条目：${unparsed.map { it.name }}",
            unparsed.isEmpty(),
        )
    }
}
