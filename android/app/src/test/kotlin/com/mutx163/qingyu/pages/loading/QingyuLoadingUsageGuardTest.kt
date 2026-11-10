package com.mutx163.qingyu.pages.loading

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 全软件加载态统一（总清单 D1）守卫 —— 防回退。
 *
 * 规格：`.agents/notes/proposed/2026-11-10-loading-state-unification.md`
 * 套件：`composeP1/.../components/QingyuLoading.kt`（批次 0，美化一独占）
 *
 * ## 它防的是哪一类事故
 *
 * 改造前全仓有 8 种直径（14/16/18/20/22/24/28/48 加官方默认 30）、6 档垂直留白、
 * 两种写法，还有 3 处把默认主色的蓝圈画在 primary 蓝底按钮上（等于隐形）。
 * 只要有人回头直接写一个 `CircularProgressIndicator()`，这些偏差就会悄悄长回来，
 * 而且**源码能编译、单测全绿**，只有真机逐页看才发现。
 *
 * ## 判据（为什么不是「全仓只许套件」的硬名单）
 *
 * 2026-11-10 各条泳道正在并行迁移（半天内 about 族 5 个文件、IcsExport、MemoryStats、
 * LiveDiagnostics、ImportCommon 陆续落地）。硬编码「还没迁移的文件清单」会让守卫每几分钟
 * 就因「清单过期」而红，追着别人屁股改，反而没人敢跑门禁。所以这里用**三条零维护**的判据：
 *
 * 1. **已迁入的文件不许回退**：任何 import 了 `components.QingyuLoading` 的文件里，
 *    不许再出现直接调用——部分迁移 + 后来者补一个裸圈，是这类事故最真实的样子。
 * 2. **`pages/sync` 整域不许直接调用**：这是 D1 批次 1 的完成态（11 个渲染点全迁），
 *    作为本批次的硬棘轮钉住。
 * 3. **`components` 层只有套件能画加载圈**：共享件层不许各写各的。
 *
 * 等到批次 5 收口（各域全部迁完、全仓直接调用归零），这条守卫升级为「全仓只许套件」；
 * 届时第 1 条判据自然覆盖全仓，判据本身不用改。
 *
 * ## 为什么放在 `pages/loading` 这个只有测试的目录
 *
 * 本机 L0（`scripts/test-kotlin-module.ps1`）按 `pages/<域>` 找源码与测试目录；
 * 这是全仓守卫，不属于任何页面域，所以单独开一个**只有测试目录**的域，
 * 用 `-Module pages/loading` 就能跑，不必等整包 L2。
 *
 * ## 咬合探针（2026-11-10 已做，见 D1 批次回报）
 *
 * 往 `pages/sync/CloudBackupListPage.kt` 塞一行 `CircularProgressIndicator()` ⇒ 本守卫红；
 * 还原后绿。
 */
class QingyuLoadingUsageGuardTest {

    @Test
    fun `扫描器必须真的扫到源码`() {
        val files = sourceFiles()
        assertTrue(
            "只扫到 ${files.size} 个 .kt（预期 >= $MIN_EXPECTED_FILES）—— 仓库根判定或目录名已变，" +
                "判据会空跑假绿。user.dir=${System.getProperty("user.dir")}",
            files.size >= MIN_EXPECTED_FILES,
        )
        assertTrue(
            "找不到加载态套件 $SUITE_PATH —— 文件改名/移动后必须同步更新本守卫",
            files.any { it.relativePath == SUITE_PATH },
        )
        // 判据 1 依赖「有文件 import 套件」；不足则说明套件被架空，判据变空跑。
        val importers = files.count { importsSuite(it.file.readText()) }
        assertTrue(
            "只有 $importers 个文件 import 了加载态套件（预期 >= $MIN_EXPECTED_IMPORTERS）——" +
                "套件被架空或批量回退，判据 1 会静默失效。",
            importers >= MIN_EXPECTED_IMPORTERS,
        )
    }

    @Test
    fun `已迁入套件的文件不许再直接调官方加载组件`() {
        val offenders = linkedMapOf<String, List<Int>>()
        for (source in sourceFiles()) {
            if (source.relativePath == SUITE_PATH) continue
            if (!importsSuite(source.file.readText())) continue
            val lines = directCalls(source.file)
            if (lines.isNotEmpty()) offenders[source.relativePath] = lines
        }
        assertTrue(
            buildString {
                appendLine("这些文件已经 import 了 components/QingyuLoading，却还留着直接调用。")
                appendLine("档位选择：")
                appendLine("  档 A 首载居中 → QingyuLoadingCenter(fillPage = true/false)")
                appendLine("  档 B 行内     → QingyuLoadingInline(slot = Button/IconSlot/Badge) / QingyuLoadingInButton()")
                appendLine("  档 C 局部遮罩 → QingyuLoadingScrim(color = …)  // 必须显式给色")
                appendLine("  档 D 确定进度 → QingyuLoadingProgressBar(progress)")
                appendLine("违规位置：")
                offenders.forEach { (path, lines) -> appendLine("    $path:${lines.joinToString(",")}") }
            },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `sync 域必须零直接调用`() {
        val offenders = linkedMapOf<String, List<Int>>()
        for (source in sourceFiles()) {
            if (source.relativePath == SUITE_PATH) continue
            if (!source.relativePath.startsWith("$RECORDED_SYNC_PREFIX/") &&
                !source.relativePath.startsWith("$MAIN_SYNC_PREFIX/")
            ) {
                continue
            }
            val lines = directCalls(source.file)
            if (lines.isNotEmpty()) offenders[source.relativePath] = lines
        }
        assertTrue(
            "D1 批次 1 的完成态是「sync 域 11 个渲染点全走套件」，这里又出现了直接调用：\n" +
                offenders.map { (path, lines) -> "    $path:${lines.joinToString(",")}" }.joinToString("\n"),
            offenders.isEmpty(),
        )
    }

    @Test
    fun `共享件层只有套件能画加载圈`() {
        val offenders = linkedMapOf<String, List<Int>>()
        for (source in sourceFiles()) {
            if (source.relativePath == SUITE_PATH) continue
            if (!source.relativePath.contains("/components/")) continue
            val lines = directCalls(source.file)
            if (lines.isNotEmpty()) offenders[source.relativePath] = lines
        }
        assertTrue(
            "components/ 是共享件层，加载圈只能由 QingyuLoading.kt 提供，页面/套件不许各画各的：\n" +
                offenders.map { (path, lines) -> "    $path:${lines.joinToString(",")}" }.joinToString("\n"),
            offenders.isEmpty(),
        )
    }

    @Test
    fun `档 B 行内加载不许传 tint`() {
        val offenders = linkedMapOf<String, List<Int>>()
        for (source in sourceFiles()) {
            if (source.relativePath == SUITE_PATH) continue
            val stripped = stripCommentsAndStrings(source.file.readText())
            val lines = callArguments(stripped, "QingyuLoadingInline(")
                .filter { (_, args) -> TOP_LEVEL_TINT.containsMatchIn(args) }
                .map { (line, _) -> line }
            if (lines.isNotEmpty()) offenders[source.relativePath] = lines
        }
        assertTrue(
            buildString {
                appendLine("档 B 不许传 tint：发布版图标位是裸 `HyperosCircularProgress(18, 2)`（miuix 默认主色），")
                appendLine("传 actionIcon 之类的灰/彩色就等于自造观感升级（2026-11-10 已与发布版逐处核对，四处全裸圈）。")
                appendLine("违规位置：")
                offenders.forEach { (path, lines) -> appendLine("    $path:${lines.joinToString(",")}") }
            },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `套件口径与发布版 v2_1_4_1 对齐`() {
        val text = File(repoRoot(), SUITE_PATH).readText()
        val essential = linkedMapOf(
            "档 A 入口" to "fun QingyuLoadingCenter(",
            "档 B 入口" to "fun QingyuLoadingInline(",
            "档 B 按钮入口" to "fun QingyuLoadingInButton(",
            // 2026-11-10 评审三-08 收口：发布版页脚栏忙态是 18/2，与云同步那族 16/2 并存，
            // 套件给具名大档；这里钉住入口与常数值，改回自由传参或改数都会红。
            "档 B 按钮大档入口" to "fun QingyuLoadingInButtonLarge(",
            "档 B 按钮大档直径（发布版 FooterBar busy 18）" to "val InlineLargeSize = 18.dp",
            "档 B′ 行首方块入口" to "fun QingyuLoadingAccentGlyph(",
            "档 B′ 行首方块直径（取件码，22/2.2）" to "val AccentGlyphSize = 22.dp",
            "档 B′ 行首方块线宽" to "val AccentGlyphStrokeWidth = 2.2.dp",
            "档 C 入口" to "fun QingyuLoadingScrim(",
            "档 D 入口" to "fun QingyuLoadingProgressBar(",
            "档 A 直径（发布版 hyperos_progress.dart:10）" to "val PageSize = 24.dp",
            "档 A 线宽（发布版 hyperos_progress.dart:11）" to "val PageStrokeWidth = 2.5.dp",
            "档 B 按钮直径（发布版 cloud_sync_screen.dart:22-28）" to "val InlineSize = 16.dp",
            "档 B 线宽" to "val InlineStrokeWidth = 2.dp",
            // 2026-11-10 评审 D1-1：原先只盖 3/6 组数值哨兵，槽位与遮罩档的六个刻度漏网——
            // 谁把 18 改成 20、把 28 改成 30，原判据不会红。这里补齐（尺寸 + 线宽成对钉）。
            "档 B 图标位（18/2，发布版 live_diagnostics :518/:528）" to
                "IconSlot(QingyuLoadingDefaults.IconSlotSize, QingyuLoadingDefaults.InlineStrokeWidth),",
            "档 B 图标位直径" to "val IconSlotSize = 18.dp",
            "档 B 角标（14/2，发布版 :619）" to
                "Badge(QingyuLoadingDefaults.BadgeSize, QingyuLoadingDefaults.InlineStrokeWidth),",
            "档 B 角标直径" to "val BadgeSize = 14.dp",
            "档 C 遮罩直径（28，发布版 bing :606-616）" to "val ScrimSize = 28.dp",
            "档 C 排队直径（24，发布版 :564-574）" to "val QueuedSize = 24.dp",
            "档 C 缩略图直径（18，发布版 :526-534）" to "val ThumbnailSize = 18.dp",
            "档 A 块内最小高度（120）" to "val BlockMinHeight = 120.dp",
            // 官方默认是写死的 Color.Gray，不跟主题 —— 档 C 必须显式给色，所以这里不许有默认值。
            "档 C 必须显式给色" to "fun QingyuLoadingScrim(\n    color: Color,",
        )
        val lost = essential.filterValues { !text.contains(it) }
        assertTrue(
            "QingyuLoading.kt 的口径被改动了，下面这些不再成立（依据见 D1 方案 §2-§3）：\n" +
                lost.map { (why, needle) -> "    $why → 找不到 `$needle`" }.joinToString("\n"),
            lost.isEmpty(),
        )
    }

    // ------------------------------------------------------------------
    // 判据实现
    // ------------------------------------------------------------------

    private data class SourceFile(val relativePath: String, val file: File)

    /** 仓库根：从 user.dir 往上找含 `android/app/src` 的目录（与既有守卫同一套写法）。 */
    private fun repoRoot(): File {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            if (File(dir, "android/app/src").isDirectory) return dir
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到仓库根（android/app/src）—— 守卫无法验证，按失败处理（不许静默跳过）。" +
                "user.dir=${System.getProperty("user.dir")}",
        )
    }

    private fun sourceFiles(): List<SourceFile> {
        val root = repoRoot()
        val bases = listOf(
            "android/app/src/main/kotlin",
            "android/app/src/composeP1/kotlin",
        )
        return bases.flatMap { base ->
            val dir = File(root, base)
            if (!dir.isDirectory) {
                emptyList()
            } else {
                dir.walkTopDown()
                    .filter { it.isFile && it.extension == "kt" }
                    .map { SourceFile(it.relativeTo(root).invariantSeparatorsPath, it) }
                    .toList()
            }
        }
    }

    /** 一个文件里直接调用官方加载组件的行号。 */
    private fun directCalls(file: File): List<Int> {
        val stripped = stripCommentsAndStrings(file.readText())
        return INDICATOR_CALL.findAll(stripped)
            .map { stripped.take(it.range.first).count { ch -> ch == '\n' } + 1 }
            .toList()
    }

    /** 取 `call(` 每个调用的实参文本与起始行号（跳过 `fun ` 定义）。 */
    private fun callArguments(stripped: String, call: String): List<Pair<Int, String>> {
        val result = mutableListOf<Pair<Int, String>>()
        var from = 0
        while (true) {
            val start = stripped.indexOf(call, from)
            if (start < 0) break
            val before = stripped.take(start).trimEnd()
            if (before.endsWith("fun")) {
                from = start + call.length
                continue
            }
            val openParen = start + call.length - 1
            val close = matchingParen(stripped, openParen)
            if (close < 0) break
            result += (stripped.take(start).count { it == '\n' } + 1) to
                stripped.substring(openParen + 1, close)
            from = close
        }
        return result
    }

    private fun matchingParen(text: String, openIndex: Int): Int {
        var depth = 0
        var i = openIndex
        while (i < text.length) {
            when (text[i]) {
                '(' -> depth++
                ')' -> {
                    depth--
                    if (depth == 0) return i
                }
            }
            i++
        }
        return -1
    }

    /**
     * 把注释与字符串字面量内容抹成空格（换行保留），避免 KDoc 里写一句
     * 「同 Dart `LinearProgressIndicator(minHeight: 6)`」就被判成真实调用。
     */
    private fun stripCommentsAndStrings(text: String): String {
        val out = StringBuilder(text.length)
        var i = 0
        fun blank(from: Int, count: Int) {
            repeat(count) { offset ->
                out.append(if (text[from + offset] == '\n') '\n' else ' ')
            }
        }
        while (i < text.length) {
            when {
                text.startsWith("//", i) -> {
                    val end = text.indexOf('\n', i).let { if (it < 0) text.length else it }
                    blank(i, end - i)
                    i = end
                }
                text.startsWith("/*", i) -> {
                    val end = text.indexOf("*/", i + 2).let { if (it < 0) text.length else it + 2 }
                    blank(i, end - i)
                    i = end
                }
                text.startsWith("\"\"\"", i) -> {
                    val end = text.indexOf("\"\"\"", i + 3).let { if (it < 0) text.length else it + 3 }
                    blank(i, end - i)
                    i = end
                }
                text[i] == '"' || text[i] == '\'' -> {
                    val quote = text[i]
                    var j = i + 1
                    while (j < text.length) {
                        when {
                            text[j] == '\\' -> j += 2
                            text[j] == quote -> {
                                j++
                                break
                            }
                            text[j] == '\n' -> break
                            else -> j++
                        }
                    }
                    val end = minOf(j, text.length)
                    blank(i, end - i)
                    i = end
                }
                else -> {
                    out.append(text[i])
                    i++
                }
            }
        }
        return out.toString()
    }

    private companion object {
        const val SUITE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/components/QingyuLoading.kt"

        /**
         * 套件导入 token：**逐个公开入口点名，不含通配**。
         *
         * 2026-11-10 评审 D1-7：原先只有一条前缀常量 `...components.QingyuLoading`，
         * 用 `import com.mutx163.qingyu.components.*` 星号导入的文件判据 1 会漏（前缀不匹配 →
         * 该文件被当成「没迁入套件」，于是「迁入后又回退直调」抓不到）。这里列全入口，
         * 新增公开入口必须同步加进来；同时提供 [importsSuite] 统一判定。
         */
        val SUITE_IMPORT_TOKENS = listOf(
            "import com.mutx163.qingyu.components.QingyuLoadingCenter",
            "import com.mutx163.qingyu.components.QingyuLoadingInline",
            "import com.mutx163.qingyu.components.QingyuLoadingInButton",
            "import com.mutx163.qingyu.components.QingyuLoadingScrim",
            "import com.mutx163.qingyu.components.QingyuLoadingProgressBar",
            "import com.mutx163.qingyu.components.QingyuLoadingAccentGlyph",
            "import com.mutx163.qingyu.components.QingyuLoadingDefaults",
            "import com.mutx163.qingyu.components.QingyuLoadingSlot",
        )

        /** 该源码文本是否导入了套件（任一公开入口）。 */
        fun importsSuite(text: String): Boolean = SUITE_IMPORT_TOKENS.any { text.contains(it) }

        const val RECORDED_SYNC_PREFIX =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync"

        const val MAIN_SYNC_PREFIX = "android/app/src/main/kotlin/com/mutx163/qingyu/pages/sync"

        /** 空跑哨兵：当前实测 831 个 .kt，留足余量。 */
        const val MIN_EXPECTED_FILES = 700

        /** 2026-11-10 下午实测已有 15 个文件 import 套件（AccentGlyph 到货后），留余量。 */
        const val MIN_EXPECTED_IMPORTERS = 8

        /** 名称前不能是字母（排除 `MiuixCircularProgressIndicator(` 之类别名）。 */
        val INDICATOR_CALL = Regex(
            """(?<!\w)(CircularProgressIndicator|LinearProgressIndicator|InfiniteProgressIndicator)\s*\(""",
        )

        /** 顶层 `tint = …` 实参（不碰 `tint:` 之类声明）。 */
        val TOP_LEVEL_TINT = Regex("""(?<![\w.])tint\s*=""")
    }
}
