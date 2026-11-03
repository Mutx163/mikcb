package com.mutx163.qingyu.pages.a11y

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 读屏语义守卫（2026-11-03 建立）。
 *
 * ## 它防的是哪一类事故
 *
 * 纯图标 `IconButton` 忘传 `contentDescription`，视觉上完全正常、编译也过，
 * TalkBack 却只会念「按钮」。这类缺陷无法被 L0 模型层测试或截图测试发现，
 * 只能逐条读源码判。
 *
 * ## 判据（先剥注释）
 *
 * 一个 `IconButton(...) { ... }` 的 lambda 体内同时满足以下三条才算「有标签」：
 * 1. 存在非 `null` 的 `contentDescription =`；或
 * 2. lambda 里有可见 `Text(...)`；或
 * 3. 通过 `semantics { contentDescription = ... }` 补标签。
 * 三个都没有 ⇒ 违规。注释里的示例代码不算数（先剥 `//` 与 `/* */`）。
 *
 * ## 白名单只减不增
 *
 * 现存违规登记在 [BASELINE]，格式 `相对路径|数量|原因`。任何文件的数量
 * **必须与基线精确相等**：
 * - 新增违规（基线里没有的文件 / 数量变多）⇒ 红；
 * - 修好一条却没下调基线（数量变少）⇒ 也红，逼着把基线同步删掉。
 * 想在基线里加行必须人工编辑并写明原因，脚本不会自动补。
 *
 * ## 咬合探针
 *
 * 判据本身喂了四份样例（无标签 / 有 description / 有 Text / 只在注释里），
 * 以及故意改坏的 `QingyuCard` 副本，随一次 L0 运行一起验证，不需要改真文件。
 */
class AccessibilitySemanticsGuardTest {

    // ---------------------------------------------------------------- 主判据

    @Test
    fun `纯图标按钮没有语义标签即红`() {
        val baseline = loadBaseline()
        val actual = collectViolations()

        val newOnes = actual.keys - baseline.keys
        assertTrue(
            "发现未登记的无标签纯图标按钮：$newOnes。请补 contentDescription/Text，" +
                "确需保留则人工编辑 $BASELINE 并写明原因",
            newOnes.isEmpty(),
        )

        baseline.forEach { (file, allowed) ->
            val now = actual[file] ?: 0
            assertEquals(
                "$file 的无标签图标按钮数量与基线不符（基线 $allowed，实际 $now）。" +
                    "修好了就下调基线；偷偷加回去同样会红",
                allowed,
                now,
            )
        }
    }

    @Test
    fun `扫描器没有空转`() {
        val scanned = composeRoot().walkTopDown().count { it.isFile && it.extension == "kt" }
        assertTrue("只扫到 $scanned 个 composeP1 源文件，路径解析可能失效", scanned > 100)
        assertTrue(
            "判据对明显违规样例没有反应，守卫等于空转",
            detectsIconButtonWithoutLabel(UNLABELED_SAMPLE),
        )
    }

    @Test
    fun `判据咬合 四种样例方向都对`() {
        assertTrue(
            "无标签样例没有被判违规",
            detectsIconButtonWithoutLabel(UNLABELED_SAMPLE),
        )
        assertFalse(
            "有 contentDescription 的样例被误判",
            detectsIconButtonWithoutLabel(LABELED_SAMPLE),
        )
        assertFalse(
            "带可见 Text 的样例被误判",
            detectsIconButtonWithoutLabel(TEXT_SAMPLE),
        )
        assertFalse(
            "只出现在注释里的 IconButton 被当真（剥注释失效）",
            detectsIconButtonWithoutLabel(COMMENTED_SAMPLE),
        )
    }

    // ---------------------------------------------------------------- 共享卡片

    @Test
    fun `可点卡片声明按钮角色并合并子节点`() {
        val card = read(CARD)
        assertTrue(
            "QingyuCard 的可点分支没有 semantics(mergeDescendants = true) + Role.Button——" +
                "读屏会把卡片拆成碎片、也不知道它是按钮",
            clickableCardAnnouncesButton(card),
        )
        assertFalse(
            "咬合探针失效：删掉 Role.Button 后判据仍为真",
            clickableCardAnnouncesButton(card.replace("role = Role.Button", "")),
        )
        assertFalse(
            "咬合探针失效：删掉 mergeDescendants 后判据仍为真",
            clickableCardAnnouncesButton(card.replace("mergeDescendants = true", "")),
        )
    }

    // ---------------------------------------------------------------- 关键修复点

    @Test
    fun `已修的关键语义没有被回退`() {
        val themeSwatch = read(GUIDE_PAGE)
        assertTrue(
            "指南主题色块丢了名字/单选语义（只剩一个念不出颜色的按钮）",
            colorSwatchHasNameAndRadioRole(themeSwatch),
        )
        assertFalse(
            "咬合探针失效：删掉 contentDescription = label 后仍为真",
            colorSwatchHasNameAndRadioRole(
                themeSwatch.replace("contentDescription = label", ""),
            ),
        )

        val wallpaper = read(WALLPAPER_STRIP)
        assertTrue(
            "最近壁纸卡丢了合并语义（缩略图与标签会被念成两个节点）",
            wallpaCardMergesChildren(wallpaper),
        )
        assertFalse(
            "咬合探针失效：删掉合并语义后仍为真",
            wallpaCardMergesChildren(
                wallpaper.replace("semantics(mergeDescendants = true)", ""),
            ),
        )

        val chrome = read(APPEARANCE_CHROME)
        assertTrue(
            "外观编辑页圆钮又变成内外两层可点节点（同一动作会被念两遍）",
            circleActionHasSingleNode(chrome),
        )
        assertFalse(
            "咬合探针失效：删掉 clearAndSetSemantics 后仍为真",
            circleActionHasSingleNode(chrome.replace("clearAndSetSemantics {}", "")),
        )
    }

    // ---------------------------------------------------------------- 判据实现

    /** 违规收集：相对 composeP1 根目录的路径 → 条数。 */
    private fun collectViolations(): Map<String, Int> {
        val root = composeRoot()
        val out = mutableMapOf<String, Int>()
        root.walkTopDown().filter { it.isFile && it.extension == "kt" }.forEach { file ->
            val text = stripComments(file.readText(Charsets.UTF_8))
            iconButtonBlocks(text).forEach { block ->
                if (!hasAccessibleLabel(block)) {
                    val rel = file.relativeTo(root).path.replace('\\', '/')
                    out[rel] = (out[rel] ?: 0) + 1
                }
            }
        }
        return out
    }

    private fun detectsIconButtonWithoutLabel(source: String): Boolean =
        iconButtonBlocks(stripComments(source)).any { !hasAccessibleLabel(it) }

    /** `IconButton(` 调用块（含 lambda），用括号/花括号配对，避免截断。 */
    private fun iconButtonBlocks(text: String): List<String> {
        val blocks = mutableListOf<String>()
        val regex = Regex("""(?<![A-Za-z0-9_.])IconButton\s*\(""")
        regex.findAll(text).forEach { match ->
            val openParen = match.range.last
            val closeParen = matchingIndex(text, openParen, '(', ')') ?: return@forEach
            val openBrace = text.indexOf('{', closeParen)
            if (openBrace < 0) return@forEach
            val closeBrace = matchingIndex(text, openBrace, '{', '}') ?: return@forEach
            blocks += text.substring(match.range.first, closeBrace + 1)
        }
        return blocks
    }

    private fun matchingIndex(text: String, openIndex: Int, open: Char, close: Char): Int? {
        var depth = 0
        for (i in openIndex until text.length) {
            when (text[i]) {
                open -> depth++
                close -> {
                    depth--
                    if (depth == 0) return i
                }
            }
        }
        return null
    }

    private fun hasAccessibleLabel(block: String): Boolean {
        val all = Regex("""contentDescription\s*=""").findAll(block).count()
        val nulls = Regex("""contentDescription\s*=\s*null\b""").findAll(block).count()
        if (all > nulls) return true
        return Regex("""\bText\s*\(""").containsMatchIn(block)
    }

    private fun clickableCardAnnouncesButton(source: String): Boolean {
        val code = stripComments(source)
        return code.contains("semantics(mergeDescendants = true)") &&
            code.contains("role = Role.Button")
    }

    private fun colorSwatchHasNameAndRadioRole(source: String): Boolean {
        val code = stripComments(source)
        return code.contains("contentDescription = label") &&
            code.contains("role = Role.RadioButton")
    }

    private fun wallpaCardMergesChildren(source: String): Boolean =
        stripComments(source).contains("semantics(mergeDescendants = true)")

    private fun circleActionHasSingleNode(source: String): Boolean {
        val code = stripComments(source)
        return code.contains("clearAndSetSemantics {}") &&
            code.contains("contentDescription = null")
    }

    // ---------------------------------------------------------------- 文件与基线

    private fun loadBaseline(): Map<String, Int> {
        val file = File(repoRoot(), BASELINE)
        check(file.isFile) { "缺少基线文件 $BASELINE" }
        val out = mutableMapOf<String, Int>()
        file.readLines(Charsets.UTF_8)
            .map { it.trim() }
            .filter { it.isNotEmpty() && !it.startsWith("#") }
            .forEach { line ->
                val parts = line.split('|')
                require(parts.size == 3) { "基线行格式错误：$line（应为 路径|数量|原因）" }
                require(parts[2].isNotBlank()) { "基线行必须写明原因：$line" }
                out[parts[0]] = parts[1].toInt()
            }
        return out
    }

    /** 从工作目录向上找仓库根，再读文件；与同目录守卫测试同一套做法。 */
    private fun repoRoot(): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            if (File(dir, "android/app/src/composeP1").isDirectory) return dir!!
            dir = dir?.parentFile
        }
        error("找不到仓库根（工作目录 ${File("").absolutePath}）")
    }

    private fun composeRoot(): File = File(repoRoot(), COMPOSE_ROOT)

    private fun read(relativePath: String): String {
        val file = File(repoRoot(), relativePath)
        check(file.isFile) { "找不到 $relativePath" }
        return file.readText(Charsets.UTF_8)
    }

    /** 剥 `//` 行注释与 `/* */` 块注释；判据只看代码。 */
    private fun stripComments(text: String): String =
        text.replace(Regex("""/\*[\s\S]*?\*/"""), "")
            .lineSequence()
            .joinToString("\n") { line -> line.substringBefore("//") }

    private companion object {
        const val COMPOSE_ROOT =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu"

        const val BASELINE = "tool/a11y_icon_button_baseline.txt"

        const val CARD =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/components/QingyuCard.kt"

        const val GUIDE_PAGE =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/guide/UserGuidePage.kt"

        const val WALLPAPER_STRIP =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/RecentWallpaperStrip.kt"

        const val APPEARANCE_CHROME =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/AppearanceEditorChrome.kt"

        const val UNLABELED_SAMPLE = """
            IconButton(onClick = {}) {
                Icon(imageVector = MiuixIcons.Close, contentDescription = null)
            }
        """

        const val LABELED_SAMPLE = """
            IconButton(onClick = {}) {
                Icon(imageVector = MiuixIcons.Close, contentDescription = "关闭")
            }
        """

        const val TEXT_SAMPLE = """
            IconButton(onClick = {}) {
                Text("关闭")
            }
        """

        const val COMMENTED_SAMPLE = """
            // IconButton(onClick = {}) { Icon(imageVector = MiuixIcons.Close) }
            /* IconButton(onClick = {}) {
                Icon(imageVector = MiuixIcons.Close, contentDescription = null)
            } */
        """
    }
}
