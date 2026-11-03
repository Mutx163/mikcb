package com.mutx163.qingyu.pages

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 底部弹层 / 对话框**套件守卫**（2026-10-30 建立）。
 *
 * ## 背景：为什么弹窗要单独一条守卫
 *
 * 用户 2026-10-30：「所有弹窗都审核一下」。普查全仓 70 个弹层/对话框调用点后发现两个
 * **系统性**缺陷 —— 它们都不编译报错、单测也照绿，只有真机盯屏才看得出：
 *
 * | 规则 | miuix 默认 | 本仓口径（Dart 出处） | 症状 |
 * |---|---|---|---|
 * | S1 | `OverlayBottomSheet(insideMargin = 24dp)` | 16dp（`hyperosMiuixBottomSheetInsideMargin`） | 调用点自己再叠 16dp ⇒ 单边 40dp，内容被挤成中间窄条 |
 * | S1D | `OverlayDialog(insideMargin = 24dp)` | 单边合计 16dp（横 16 或 0/8 + 内容补齐） | 对话框走官方默认 24dp，与全仓 16dp 口径不一致（2026-11-02 弹窗审计 S13） |
 * | S2 | 只 `imePadding()`（只让键盘） | 手势区/导航栏 + 16dp（`bottomGapInsetOf`） | 最后一排按钮贴屏幕最下沿、被小白条压住 |
 * | S3 | `textButtonColors(color = …)` 是**底色** | 危险色只染**字**（Dart `destructive` 变体） | 「红底 + 默认灰字」：既不像原版，对比度也不够 |
 *
 * 32 个底部弹层里 32 个都缺 S2、27 个叠了侧边距。**根因不是缺组件，是每个调用方各自记**
 * —— 所以修法是把口径收进套件 `com.mutx163.qingyu.components.QingyuSheet`，再用这条守卫
 * 把「不许绕开套件」钉死（与 `QingyuPageScaffold` / `QingyuCard` 同一套做法）。
 *
 * ## 棘轮怎么工作
 *
 * 存量调用点**不要求一次清完**（那会把一次提交变成一次重构），冻结在
 * `tool/compose_sheet_baseline/<域>.txt`，一个域一个文件（多 Agent 并行时各改各的）。
 *
 * 1. **新增必红**：`OverlayBottomSheet(` 只能出现在套件自己那个文件里；
 *    别的文件里新出现的、以及不在基线里的危险色误用 ⇒ 失败。
 * 2. **过期必红**：基线里有、代码里已经没有了 ⇒ 失败，要求把那行删掉。
 *    ⇒ 逼着人还债，不许只进不出。
 *
 * ## 判定范围
 *
 * 只扫 `composeP1/kotlin/`。套件自身（`components/QingyuSheet.kt`）豁免 S1；
 * `components/` 其余文件不豁免（它们也不该直接调弹层）。S1D（OverlayDialog）没有
 * 对应套件，豁免口径与 S1 相同：`pages/showcase/` 展厅就是故意展示官方裸组件默认值的。
 */
class ComposeSheetGuardTest {

    @Test
    fun `扫描器必须真的扫到弹层源文件`() {
        val files = renderFiles()
        assertTrue(
            "composeP1 源文件数为 ${files.size}，扫描根疑似失效（门禁空跑会假绿）。" +
                "user.dir=${System.getProperty("user.dir")} repoRoot=${repoRoot()} " +
                "root=${File(repoRoot(), COMPOSE_ROOT).absolutePath}",
            files.size >= 40,
        )
        assertTrue(
            "一个 OverlayBottomSheet 调用点都没扫到，判据已失效",
            files.any { File(it).readText().contains("OverlayBottomSheet(") },
        )
        assertTrue(
            "一个 OverlayDialog 调用点都没扫到，S1D 判据已失效",
            files.any { File(it).readText().contains("OverlayDialog(") },
        )
    }

    @Test
    fun `不允许新增绕开套件的弹层调用`() {
        val baseline = loadBaseline()
        val actual = scanViolations()

        val regressions = actual.keys.filter { it !in baseline }
        assertTrue(
            "新增了弹层守卫违规（`OverlayBottomSheet(` 只允许出现在套件文件里，" +
                "应改用 `QingyuSheet(...)`——统一给 16dp 侧边距 + 底部手势区让位；" +
                "`OverlayDialog` 须显式传 `insideMargin`，官方默认 24dp 不合本仓 16dp 口径）：\n" +
                regressions.joinToString("\n") { "    $it" },
            regressions.isEmpty(),
        )

        val stale = baseline.keys.filter { it !in actual.keys }
        assertTrue(
            "基线里有这些行，但代码已经不违规了 —— 请从 `tool/compose_sheet_baseline/` 删掉对应行" +
                "（棘轮只许收不许放）：\n" + stale.joinToString("\n") { "    $it" },
            stale.isEmpty(),
        )
    }

    // ------------------------------------------------------------------
    // 判据
    // ------------------------------------------------------------------

    private fun renderFiles(): List<String> {
        val root = File(repoRoot(), COMPOSE_ROOT)
        return root.walkTopDown().filter { it.isFile && it.name.endsWith(".kt") }
            .map { it.path.replace('\\', '/') }
            .toList()
    }
    /** 违规集合：`相对路径|规则`。 */
    private fun scanViolations(): Map<String, String> {
        val result = linkedMapOf<String, String>()
        for (path in renderFiles()) {
            val relative = relativeName(path)
            val text = File(path).readText()
            if (!relative.endsWith(SHEET_SUITE_FILE) && !relative.startsWith(SHOWCASE_PREFIX)) {
                text.lineSequence().forEachIndexed { index, line ->
                    if (SHEET_CALL.containsMatchIn(line)) {
                        result["$relative|S1"] =
                            "第 ${index + 1} 行直接调 `OverlayBottomSheet`，应改用 `QingyuSheet`"
                    }
                }
            }
            if (!relative.startsWith(SHOWCASE_PREFIX)) {
                dialogInsideMarginViolations(text).forEach { line ->
                    result["$relative|S1D"] =
                        "第 $line 行 `OverlayDialog` 未显式传 `insideMargin`：" +
                            "官方默认 24dp，本仓口径单边合计 16dp"
                }
            }
            dangerousColorUsages(text).forEach { line ->
                result["$relative|S3"] =
                    "第 $line 行 `textButtonColors(color = 危险色)`：危险色要染**字**（`textColor = …`），" +
                        "否则是「红底 + 灰字」"
            }
            solidDangerWithoutContentColor(text).forEach { line ->
                result["$relative|S4"] =
                    "第 $line 行 `buttonColors(color = 危险色)` 没写 `contentColor`：实心红底会配默认字色，" +
                        "Dart `HyperosButtonVariant.destructive` 是「红底 + `onError` 字」"
            }
        }
        return result
    }

    /**
     * 找出 `textButtonColors(color = 危险色)` 的行号。
     *
     * ## 为什么不能只写正则
     *
     * `color = Color(QingyuTheme.error(dark))` 里有**嵌套括号**，`[^)]*` 那种写法会在
     * `Color(` 的右括号处断掉、漏判（第一版本就是这么漏掉 3 处的）。所以这里按括号配平
     * 取出实参，再只看**顶层**那个 `color = …` 的值（避免把 `textColor = 危险色` 这种
     * **正确**写法误判）。
     */
    private fun dangerousColorUsages(text: String): List<Int> {
        val hits = mutableListOf<Int>()
        var from = 0
        while (true) {
            val start = text.indexOf(TEXT_BUTTON_CALL, from)
            if (start < 0) break
            val openParen = start + TEXT_BUTTON_CALL.length - 1
            val close = matchingParen(text, openParen)
            if (close < 0) break
            val argument = colorArgument(text.substring(openParen + 1, close))
            if (argument != null && DANGER_COLOR.containsMatchIn(argument)) {
                hits += text.take(start).count { it == '\n' } + 1
            }
            from = close
        }
        return hits
    }

    /**
     * 找出 `OverlayDialog(` 调用**没显式传 `insideMargin`** 的行号（规则 S1D）。
     *
     * 2026-11-02 弹窗审计 S13：守卫原本只拦 `OverlayBottomSheet`，对话框全走官方默认
     * 24dp 而守卫看不见。只卡「有没有显式传」这一个判据：数值是否凑够本仓口径
     *（横 16，或横 0/8 + 内容自带 padding 补齐）由评审把关——文本层判数值会误伤
     * `DpSize(0.dp, 16.dp)` 这类合理写法。
     */
    private fun dialogInsideMarginViolations(text: String): List<Int> {
        val hits = mutableListOf<Int>()
        var from = 0
        while (true) {
            val start = text.indexOf(DIALOG_CALL, from)
            if (start < 0) break
            // `XxxOverlayDialog(` 这类自定义名字的尾巴也是 `OverlayDialog(` —— 卡词边界。
            if (start > 0 && (text[start - 1].isLetterOrDigit() || text[start - 1] == '_')) {
                from = start + DIALOG_CALL.length
                continue
            }
            val openParen = start + DIALOG_CALL.length - 1
            val close = matchingParen(text, openParen)
            if (close < 0) break
            val args = text.substring(openParen + 1, close)
            if (!args.contains("insideMargin")) {
                hits += text.take(start).count { it == '\n' } + 1
            }
            from = close
        }
        return hits
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
     * 找出 `buttonColors(color = 危险色)` **且没写 `contentColor`** 的行号（规则 S4）。
     *
     * 这是与 S3 同一类「红底 + 默认字色」的错，只是发生在**实心按钮**上。Dart 的
     * `HyperosButtonVariant.destructive`（`lib/ui/hyperos/hyperos_controls.dart:728-733`）
     * 是「红底 + `onError` 字」，所以正确写法是同时给 `contentColor`。
     *
     * ⚠️ 这是 sheet-app 泳道在收口时报的漏判（他们那两处就是这种形状）。判据只认
     * `ButtonDefaults.buttonColors(...)` 这一个入口，且**同一实参表里没有 `contentColor`** 才算违规
     *（写了 `contentColor` 的正确写法不会被误判）。
     */
    private fun solidDangerWithoutContentColor(text: String): List<Int> {
        val hits = mutableListOf<Int>()
        var from = 0
        while (true) {
            val start = text.indexOf(BUTTON_COLORS_CALL, from)
            if (start < 0) break
            // `textButtonColors(` 的尾巴也是 `buttonColors(` —— 必须卡词边界，否则 S4 会
            // 把 S3 那些文字按钮当成实心按钮重复报一次。
            if (start > 0 && (text[start - 1].isLetterOrDigit() || text[start - 1] == '_')) {
                from = start + BUTTON_COLORS_CALL.length
                continue
            }
            val openParen = start + BUTTON_COLORS_CALL.length - 1
            val close = matchingParen(text, openParen)
            if (close < 0) break
            val args = text.substring(openParen + 1, close)
            val color = colorArgument(args)
            if (color != null && DANGER_COLOR.containsMatchIn(color) && !args.contains("contentColor")) {
                hits += text.take(start).count { it == '\n' } + 1
            }
            from = close
        }
        return hits
    }

    /** 取顶层 `color = …` 的实参文本（到同层逗号为止）；没有则 null。 */
    private fun colorArgument(args: String): String? {
        var i = 0
        while (i < args.length) {
            if (args.startsWith("color", i)) {
                val boundary = i == 0 || args[i - 1] in " ,(\n\r\t"
                val after = args.substring(i + COLOR_KEYWORD_LENGTH)
                if (boundary && AFTER_COLOR_KEYWORD.containsMatchIn(after.take(3))) {
                    val equals = args.indexOf('=', i)
                    if (equals >= 0) {
                        var end = equals + 1
                        var depth = 0
                        while (end < args.length) {
                            val ch = args[end]
                            if (ch == '(') depth++
                            else if (ch == ')') depth--
                            else if (ch == ',' && depth == 0) break
                            end++
                        }
                        return args.substring(equals + 1, end)
                    }
                }
            }
            i++
        }
        return null
    }

    private fun loadBaseline(): Map<String, String> {
        val dir = File(repoRoot(), BASELINE_DIR)
        if (!dir.isDirectory) return emptyMap()
        val result = linkedMapOf<String, String>()
        dir.listFiles { file -> file.isFile && file.name.endsWith(".txt") }
            ?.sortedBy { it.name }
            ?.forEach { file ->
                file.readLines().forEach { raw ->
                    val line = raw.trim()
                    if (line.isEmpty() || line.startsWith("#")) return@forEach
                    val parts = line.split("|")
                    if (parts.size >= 2) result["${parts[0].trim()}|${parts[1].trim()}"] = parts.getOrElse(2) { "" }
                }
            }
        return result
    }

    private fun relativeName(path: String): String {
        val normalized = path.replace('\\', '/')
        // 基线里的键是 **`com/mutx163/qingyu/` 之后**的路径（与
        // `tool/compose_style_baseline/` 那套口径一致）。少了这一段，
        // 真实存在的违规会被判成「新增」、基线里的行全被判成「过期」——两条都红。
        val index = normalized.indexOf(REL_MARKER)
        return if (index >= 0) normalized.substring(index + REL_MARKER.length) else normalized
    }

    private fun repoRoot(): String {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            // 与 `ComposePageStyleGuardTest.repoRoot()` 同一口径：从工作目录往上找
            // 「android/app/src + lib/screens + pubspec.yaml」那一层。
            if (File(dir, "android/app/src").isDirectory) {
                var up: File? = dir
                while (up != null) {
                    if (File(up, "lib/screens").isDirectory && File(up, "pubspec.yaml").isFile) {
                        return up.path
                    }
                    up = up.parentFile
                }
                return dir.path
            }
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到仓库根（android/app/src）—— 守卫无法验证，按失败处理（不许静默跳过）。" +
                "当前工作目录：${System.getProperty("user.dir")}",
        )
    }

    private companion object {
        /**
         * 扫描根：**相对仓库根**的完整路径。
         *
         * ⚠️ 不能只写 `composeP1/kotlin`：`repoRoot()` 返回的是仓库根，拼出来会是
         * `C:\cursor\mikcb\composeP1\kotlin`（不存在）⇒ 扫到 0 个文件，哨兵断言先红、
         * 基线里每一行都被判「过期」。这个坑第一版真踩了（sheet-pages2 报的路径 bug ①）。
         */
        const val COMPOSE_ROOT = "android/app/src/composeP1/kotlin"

        /**
         * 基线键的截断点：键是这一段**之后**的相对路径（与 `tool/compose_style_baseline/` 同口径）。
         *
         * 少了它，键会变成 `com/mutx163/qingyu/app/SettingsHost.kt|S1`，与基线里写的
         * `app/SettingsHost.kt|S1` 对不上 ⇒ 真实违规全被判「新增」（sheet-pages2 报的路径 bug ②）。
         */
        const val REL_MARKER = "composeP1/kotlin/com/mutx163/qingyu/"

        const val BASELINE_DIR = "tool/compose_sheet_baseline"

        /** 套件自身：它就该直接调 `OverlayBottomSheet`。 */
        const val SHEET_SUITE_FILE = "components/QingyuSheet.kt"

        /**
         * `pages/showcase/` 豁免 S1：展厅页就是**故意**逐个展示官方裸组件的地方
         *（与样式守卫对 showcase 的豁免同一口径）。S3 / S4 配色错不豁免。
         */
        const val SHOWCASE_PREFIX = "pages/showcase/"

        val SHEET_CALL = Regex("""\bOverlayBottomSheet\s*\(""")

        /** `OverlayDialog(` 调用标记（规则 S1D，取实参用，按括号配平）。 */
        const val DIALOG_CALL = "OverlayDialog("

        const val TEXT_BUTTON_CALL = "textButtonColors("

        /** 实心按钮配色的入口（规则 S4）。 */
        const val BUTTON_COLORS_CALL = "buttonColors("

        const val COLOR_KEYWORD_LENGTH = 5

        /** `color` 关键字后面必须跟的是 `=`（排除 `colors` / `colorXxx`）。 */
        val AFTER_COLOR_KEYWORD = Regex("""\s*=""")

        /** 危险色的写法（本仓是 `QingyuTheme.error(…)` / `destructive`）。 */
        val DANGER_COLOR = Regex("""(error|Error|destructive|Destructive)""")
    }
}
