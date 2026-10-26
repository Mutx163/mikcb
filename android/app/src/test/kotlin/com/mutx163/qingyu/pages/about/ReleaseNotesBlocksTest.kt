package com.mutx163.qingyu.pages.about

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 更新日志分块测试。
 *
 * 期望值来源（独立于实现）：逐条对照 `about_screen.dart:145-205` 的分支，
 * 重点是三条容易写错的地方——「版本标题被丢掉」「嵌套项不切块」「围栏内不切块」。
 */
class ReleaseNotesBlocksTest {

    @Test
    fun `空白输入返回空列表`() {
        assertTrue(splitReleaseNotesIntoBlocks("").isEmpty())
        assertTrue(splitReleaseNotesIntoBlocks("   \n\n  ").isEmpty())
    }

    @Test
    fun `CRLF与CR都归一成LF`() {
        val crlf = splitReleaseNotesIntoBlocks("# 标题\r\n\r\n正文")
        val cr = splitReleaseNotesIntoBlocks("# 标题\r\r正文")
        assertEquals(listOf("# 标题", "正文"), crlf)
        assertEquals(listOf("# 标题", "正文"), cr)
    }

    @Test
    fun `开头的版本标题被丢掉`() {
        // Dart :157-162 —— 版本号由界面自己画，不在正文里重复一遍。
        val blocks = splitReleaseNotesIntoBlocks("# v1.2.3\n\n正文第一段")
        assertEquals(listOf("正文第一段"), blocks)
    }

    @Test
    fun `非版本号的普通标题不会被丢掉`() {
        val blocks = splitReleaseNotesIntoBlocks("# 更新内容\n\n正文")
        assertEquals(listOf("# 更新内容", "正文"), blocks)
    }

    @Test
    fun `版本标题前后有大小写与空白也认`() {
        val blocks = splitReleaseNotesIntoBlocks("  # V1.2.3-BETA  \n正文")
        assertEquals(listOf("正文"), blocks)
    }

    @Test
    fun `标题与顶层列表项各自成块`() {
        val data = """
            ## 新增
            - 第一项
            - 第二项
            ## 修复
            1. 修了一个
        """.trimIndent()
        assertEquals(
            listOf("## 新增", "- 第一项", "- 第二项", "## 修复", "1. 修了一个"),
            splitReleaseNotesIntoBlocks(data),
        )
    }

    @Test
    fun `嵌套缩进项留在父项那块`() {
        val data = """
            - 父项
              - 子项
            - 另一个父项
        """.trimIndent()
        // 缩进行不匹配 ^[-+*]\s+，所以与父项同块（Dart :186-190 注释明说）。
        assertEquals(listOf("- 父项\n  - 子项", "- 另一个父项"), splitReleaseNotesIntoBlocks(data))
    }

    @Test
    fun `空行切段且不保留空行`() {
        val data = "第一段\n\n第二段\n\n\n第三段"
        assertEquals(listOf("第一段", "第二段", "第三段"), splitReleaseNotesIntoBlocks(data))
    }

    @Test
    fun `围栏内的井号不当标题切`() {
        val data = """
            ```
            # 这是代码里的注释
            ```
        """.trimIndent()
        // 围栏内的行全部留在同一块，`#` 行不切块。
        val blocks = splitReleaseNotesIntoBlocks(data)
        assertEquals(1, blocks.size)
        assertTrue(blocks[0].contains("# 这是代码里的注释"))
    }

    @Test
    fun `围栏内的列表项也不切块`() {
        val data = """
            ~~~
            - 这是代码内容
            ~~~
        """.trimIndent()
        assertEquals(1, splitReleaseNotesIntoBlocks(data).size)
    }

    @Test
    fun `围栏结束后恢复正常切块`() {
        val data = """
            ```
            code
            ```
            - 围栏外的一项
        """.trimIndent()
        val blocks = splitReleaseNotesIntoBlocks(data)
        assertEquals(2, blocks.size)
        assertEquals("- 围栏外的一项", blocks[1])
    }

    @Test
    fun `块内容两侧空白被去掉`() {
        val blocks = splitReleaseNotesIntoBlocks("  正文  \n\n  - 项  ")
        assertEquals(listOf("正文", "- 项"), blocks)
    }

    @Test
    fun `带序号的点与括号都算顶层项`() {
        val blocks = splitReleaseNotesIntoBlocks("1. 甲\n2) 乙")
        assertEquals(listOf("1. 甲", "2) 乙"), blocks)
    }

    @Test
    fun `普通段落里的井号不切块`() {
        // `#` 后必须有空白才算标题；`C# 语言` 不是标题。
        assertEquals(listOf("C# 语言"), splitReleaseNotesIntoBlocks("C# 语言"))
    }

    @Test
    fun `标题层级一到六都认七不认`() {
        // 七级（七个井号）不是标题：`^#{1,6}` 后必须紧跟空白才成立，匹配不上，
        // 于是它既不开新块、也不是空行，就**并进上一块**。这条第一版我把期望
        // 写成了两块，被测试当场抓住——实现是对的，是期望错了（记录以免再犯）。
        val lines = listOf("###### 六级", "####### 七级")
        val text = lines.joinToString("\n")
        assertEquals(listOf(text), splitReleaseNotesIntoBlocks(text))
    }

    @Test
    fun `七个井号单独出现时自成一普通段落`() {
        assertEquals(listOf("####### 七级"), splitReleaseNotesIntoBlocks("####### 七级"))
    }

}
