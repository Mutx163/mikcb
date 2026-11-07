package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 弹层底部留白**源码守卫**（2026-11-03）。
 *
 * ## 钉的是什么
 *
 * 弹层正文若自己把 `WindowInsets.navigationBars` 的高度**无条件**叠到 16dp 呼吸上，
 * 键盘弹出时面板已被官方弹层抬到键盘上方，就会多出一截 24~48dp 的空白
 *（用户 2026-11-03 实报；套件 `QingyuSheet` 已修，正文侧两处在本次一起对齐）。
 *
 * 判据：**任何读 `WindowInsets.navigationBars` 的文件，都必须消费共享判据
 * [SheetContentBottomGap]**（或属于下表的非弹层豁免件）。判据先剥注释——
 * 讲历史的注释里引用旧写法不算违规，真代码写回旧写法必须红。
 *
 * ## 豁免件（都不是弹层正文）
 *
 * | 文件 | 为什么不走弹层判据 |
 * |---|---|
 * | `components/QingyuSheet.kt` | 套件本体：它自己已按 IME 可见性分流（2026-11-03 R10），本次明确不重构 |
 * | `pages/shell/HomeGlassDock.kt` | 首页玻璃坞：常年停靠屏幕底，不属于「被官方弹层抬起的正文」 |
 * | `pages/shell/GlassDockNavigationBar.kt` | 同上，坞的导航栏形态 |
 */
class SheetBottomGapGuardTest {

    @Test
    fun `扫描器必须真的扫到弹层正文`() {
        val files = composeFiles()
        assertTrue(
            "composeP1 源文件数为 ${files.size}，扫描根疑似失效。" +
                "user.dir=${System.getProperty("user.dir")} root=${composeRoot().absolutePath}",
            files.size >= 40,
        )
        val paths = files.map { relativeName(it) }.toSet()
        assertTrue("未扫到 MaterialSheetBody.kt", "pages/settings/MaterialSheetBody.kt" in paths)
        assertTrue("未扫到 WallpaperSheetBody.kt", "pages/settings/WallpaperSheetBody.kt" in paths)
    }

    @Test
    fun `禁止无条件叠加导航栏高度`() {
        val offenders = composeFiles().filter { file ->
            hasRawNavigationBarGap(file.readText(), relativeName(file))
        }
        assertEquals(
            "以下文件把 `WindowInsets.navigationBars` 的高度直接叠到弹性留白上：" +
                "键盘弹出时官方弹层已把面板抬到键盘上方，会多出一截空白。" +
                "请改走共享纯函数 `SheetContentBottomGap.bottomGapDp(...)`：\n" +
                offenders.joinToString("\n") { "    ${relativeName(it)}" },
            emptyList<File>(),
            offenders,
        )
    }

    @Test
    fun `两个弹层正文必须消费共享判据`() {
        val expected = listOf(
            "pages/settings/MaterialSheetBody.kt",
            "pages/settings/WallpaperSheetBody.kt",
        )
        val missing = expected.filter { relative ->
            val file = File(composeRoot(), "com/mutx163/qingyu/$relative")
            if (!file.isFile) {
                true
            } else {
                "SheetContentBottomGap." !in stripKotlinComments(file.readText())
            }
        }
        assertTrue(
            "这些弹层正文没有消费共享判据 `SheetContentBottomGap`：$missing",
            missing.isEmpty(),
        )
    }

    @Test
    fun `判据剥注释——注释里的旧写法不算违规`() {
        val commentOnly = """
            // 旧写法：WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + 16.dp
            val gap = SheetContentBottomGap.bottomGapDp(imeVisible = true, navigationBarBottomDp = 24f)
        """.trimIndent()
        assertFalse(
            "注释里的旧写法不能判红（否则讲历史的注释会让守卫假红）",
            hasRawNavigationBarGap(commentOnly, "pages/settings/Sample.kt"),
        )

        val blockCommentOnly = """
            /*
             * 旧写法：
             * WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + 16.dp
             */
            val gap = 16.dp
        """.trimIndent()
        assertFalse(
            "块注释里的旧写法不能判红",
            hasRawNavigationBarGap(blockCommentOnly, "pages/settings/Sample.kt"),
        )
    }

    @Test
    fun `判据剥离注释后仍要抓住真代码的旧写法`() {
        val realOldWriting = """
            // 注释里的 SheetContentBottomGap 不算消费
            val bottomGap = WindowInsets.navigationBars
                .asPaddingValues()
                .calculateBottomPadding() + 16.dp
        """.trimIndent()
        assertTrue(
            "真代码写回旧写法必须判红（注释里的判据名不能成为免死金牌）",
            hasRawNavigationBarGap(realOldWriting, "pages/settings/MaterialSheetBody.kt"),
        )

        val exemptFile = """
            val bottomGap = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + 16.dp
        """.trimIndent()
        assertFalse(
            "豁免件（坞 / 套件）不参与判定",
            hasRawNavigationBarGap(exemptFile, "pages/shell/HomeGlassDock.kt"),
        )
    }

    // ------------------------------------------------------------------
    // 判据
    // ------------------------------------------------------------------

    /**
     * 违规判据：读 `WindowInsets.navigationBars`，却不是豁免件、也没消费共享判据。
     *
     * 先在**剥掉注释**的代码上判（行注释 / 可嵌套块注释 / 字符串字面量都按 Kotlin 语义处理）。
     */
    private fun hasRawNavigationBarGap(source: String, relative: String): Boolean {
        if (relative in NON_SHEET_NAV_CONSUMERS) return false
        val code = stripKotlinComments(source)
        return NAVIGATION_BARS in code && SHEET_BOTTOM_GAP !in code
    }

    private fun composeFiles(): List<File> =
        composeRoot().walkTopDown()
            .filter { it.isFile && it.name.endsWith(".kt") }
            .toList()

    private fun composeRoot(): File = File(androidSrc(), "composeP1/kotlin")

    /** 相对 `composeP1/kotlin/com/mutx163/qingyu/` 的路径（与源码目录同一口径）。 */
    private fun relativeName(file: File): String {
        val normalized = file.path.replace('\\', '/')
        val marker = "composeP1/kotlin/com/mutx163/qingyu/"
        val index = normalized.indexOf(marker)
        return if (index >= 0) normalized.substring(index + marker.length) else normalized
    }

    /** 从当前工作目录向上找 `android/app/src`，兼容 Gradle（在 android/ 跑）与 IDE。 */
    private fun androidSrc(): File {
        var dir: File? = File(System.getProperty("user.dir")).absoluteFile
        while (dir != null) {
            val candidate = File(dir, "android/app/src")
            if (candidate.isDirectory) return candidate
            val direct = File(dir, "app/src")
            if (direct.isDirectory && File(dir, "app/build.gradle").isFile) return direct
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到 android/app/src —— 守卫无法验证，按失败处理（不许静默跳过）。" +
                "当前工作目录：${System.getProperty("user.dir")}",
        )
    }

    /**
     * 剥掉 Kotlin 注释（与 `ComposeSheetGuardTest.stripKotlinComments` 同一套状态机，
     * 独立一份避免守卫之间互相耦合）。
     *
     * - `//` 行注释剥到行尾，换行保留（行号不漂）；
     * - 斜杠星块注释按 Kotlin 语义**可嵌套**；
     * - 字符串 / 字符字面量原样保留，`"https://…"` 里的 `//` 不当注释，
     *   转义 `\"` 不终结字符串。
     */
    private fun stripKotlinComments(source: String): String {
        val sb = StringBuilder(source.length)
        var i = 0
        var inLineComment = false
        var inBlockComment = false
        var blockDepth = 0
        var stringQuote: Char? = null
        while (i < source.length) {
            val ch = source[i]
            val next = if (i + 1 < source.length) source[i + 1] else ' '
            when {
                inLineComment -> {
                    if (ch == '\n') {
                        inLineComment = false
                        sb.append(ch)
                    }
                    i++
                }
                inBlockComment -> {
                    if (ch == '/' && next == '*') {
                        blockDepth++
                        i += 2
                    } else if (ch == '*' && next == '/') {
                        blockDepth--
                        i += 2
                        if (blockDepth == 0) inBlockComment = false
                    } else {
                        if (ch == '\n') sb.append(ch)
                        i++
                    }
                }
                stringQuote != null -> {
                    sb.append(ch)
                    if (ch == '\\' && i + 1 < source.length) {
                        sb.append(source[i + 1])
                        i += 2
                    } else {
                        if (ch == stringQuote) stringQuote = null
                        i++
                    }
                }
                ch == '/' && next == '/' -> {
                    inLineComment = true
                    sb.append(' ')
                    i += 2
                }
                ch == '/' && next == '*' -> {
                    inBlockComment = true
                    blockDepth = 1
                    sb.append(' ')
                    i += 2
                }
                ch == '"' || ch == '\'' -> {
                    stringQuote = ch
                    sb.append(ch)
                    i++
                }
                else -> {
                    sb.append(ch)
                    i++
                }
            }
        }
        return sb.toString()
    }

    private companion object {
        const val NAVIGATION_BARS = "WindowInsets.navigationBars"
        const val SHEET_BOTTOM_GAP = "SheetContentBottomGap."

        /**
         * 非弹层正文的豁免件：它们读导航栏高度是**位置需要**，不是「被弹层抬起的正文」。
         * 新增豁免必须在这里写清理由（与样式守卫的豁免台账同一纪律）。
         */
        val NON_SHEET_NAV_CONSUMERS = setOf(
            // 套件本体：自己按 IME 可见性分流（2026-11-03 R10），本次不重构已提交写法。
            "components/QingyuSheet.kt",
            // 首页玻璃坞：停靠在屏幕底，不属于弹层正文。
            "pages/shell/HomeGlassDock.kt",
            // 坞的导航栏形态：同上。
            "pages/shell/GlassDockNavigationBar.kt",
            // 设置页列表：边到边壳里 Scaffold 的 innerPadding 不含导航栏，列表自己要补
            // 底部留白，否则滚到底时最后一行会被系统导航栏盖住（2026-11-07 用户截图）。
            // 它不是弹层正文，不存在「键盘弹起后多出一截」的问题。
            "pages/settings/SettingsPageRenderers.kt",
        )
    }
}
