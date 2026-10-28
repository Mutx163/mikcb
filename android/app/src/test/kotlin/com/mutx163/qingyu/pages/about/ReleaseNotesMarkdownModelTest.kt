package com.mutx163.qingyu.pages.about

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** [buildReleaseNotesMarkdownBlocks] / [parseInline] 的契约测试。 */
class ReleaseNotesMarkdownModelTest {

    @Test
    fun `strips leading version heading and blank lines`() {
        val blocks = buildReleaseNotesMarkdownBlocks("# v1.2.3\n\n### 新增\n- 一条")
        assertEquals(MdBlockKind.HEADING3, blocks[0].kind)
        assertEquals("新增", blocks[0].spans.joinToString("") { it.text })
        assertEquals(MdBlockKind.BULLET, blocks[1].kind)
    }

    @Test
    fun `keeps version heading when not stripped`() {
        val blocks = buildReleaseNotesMarkdownBlocks("# v1.2.3\n正文", stripVersionHeading = false)
        assertEquals(MdBlockKind.HEADING1, blocks[0].kind)
    }

    @Test
    fun `heading levels map to four kinds`() {
        val kinds = buildReleaseNotesMarkdownBlocks(
            "# A\n## B\n### C\n#### D\n##### E",
        ).map { it.kind }
        assertEquals(
            listOf(
                MdBlockKind.HEADING1,
                MdBlockKind.HEADING2,
                MdBlockKind.HEADING3,
                MdBlockKind.HEADING4,
                MdBlockKind.HEADING4,
            ),
            kinds,
        )
    }

    @Test
    fun `bullet and numbered lists`() {
        val blocks = buildReleaseNotesMarkdownBlocks("- 无序\n1. 有序")
        assertEquals(MdBlockKind.BULLET, blocks[0].kind)
        assertEquals(MdBlockKind.NUMBERED, blocks[1].kind)
        assertEquals("1", blocks[1].marker)
        assertEquals("有序", blocks[1].spans.joinToString("") { it.text })
    }

    @Test
    fun `rule detected`() {
        val blocks = buildReleaseNotesMarkdownBlocks("上\n---\n下")
        assertEquals(listOf(MdBlockKind.PARAGRAPH, MdBlockKind.RULE, MdBlockKind.PARAGRAPH), blocks.map { it.kind })
    }

    @Test
    fun `multi line paragraph joins with space`() {
        val blocks = buildReleaseNotesMarkdownBlocks("第一行\n第二行")
        assertEquals(1, blocks.size)
        assertEquals(MdBlockKind.PARAGRAPH, blocks[0].kind)
        assertEquals("第一行 第二行", blocks[0].spans.joinToString("") { it.text })
    }

    @Test
    fun `inline bold and plain split`() {
        val spans = parseInline("**粗体**普通")
        assertEquals(2, spans.size)
        assertTrue(spans[0].bold)
        assertEquals("粗体", spans[0].text)
        assertEquals("普通", spans[1].text)
        assertTrue(!spans[1].bold)
    }

    @Test
    fun `inline code span`() {
        val spans = parseInline("用 `code` 包起来")
        val codeSpan = spans.firstOrNull { it.code }
        assertEquals("code", codeSpan?.text)
    }

    @Test
    fun `inline link captures url`() {
        val spans = parseInline("见[这里](https://example.com/x)")
        val link = spans.firstOrNull { it.linkUrl != null }
        assertEquals("这里", link?.text)
        assertEquals("https://example.com/x", link?.linkUrl)
    }

    @Test
    fun `inline italic underscore`() {
        val spans = parseInline("_斜_")
        assertTrue(spans.any { it.italic && it.text == "斜" })
    }

    @Test
    fun `blockquote rendered as paragraph`() {
        val blocks = buildReleaseNotesMarkdownBlocks("> 本次重点：X")
        assertEquals(MdBlockKind.PARAGRAPH, blocks[0].kind)
        assertEquals("本次重点：X", blocks[0].spans.joinToString("") { it.text })
    }

    @Test
    fun `blank input yields no blocks`() {
        assertTrue(buildReleaseNotesMarkdownBlocks("   \n\n").isEmpty())
        assertNull(parseInline("").firstOrNull { it.text.isNotEmpty() })
    }
}
