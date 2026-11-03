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
 * | S2 | 只 `imePadding()`（只让键盘） | 手势区/导航栏 + 16dp（`bottomGapInsetOf`） | 最后一排按钮贴屏幕最下沿、被小白条压住 |
 * | S3 | `textButtonColors(color = …)` 是**底色** | 危险色只染**字**（Dart `destructive` 变体） | 「红底 + 默认灰字」：既不像原版，对比度也不够 |
 * | S5 | `OverlayDialog` 缺省 `insideMargin = 24dp` | 对话框横向 16dp（与 S1 同一口径） | 内容自带边距叠上去就是 32~40dp |
 * | S6 | 平台 `androidx.compose.ui.window.Dialog` / `Popup` | 一律走 miuix 官方 `OverlayDialog` / `QingyuSheet` / `OverlayListPopup` | 无遮罩/返回键/进出动画口径，弹层审核查漏的 11 个自建弹窗全是这种形态 |
 * | S7 | `if (show) { QingyuSheet(...) }` 条件挂载 | 常驻组合 + `show` 驱动 + `remember` 最后非空 | 退出动画放不完：弹层直接消失而不是下滑；`show` 变化时整棵子树重建 |
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
 * `components/` 其余文件不豁免（它们也不该直接调弹层）。
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
            "一个 OverlayDialog 调用点都没扫到，S5 判据已失效",
            files.any { File(it).readText().contains(DIALOG_CALL) },
        )
    }

    @Test
    fun `不允许新增绕开套件的弹层调用`() {
        val baseline = loadBaseline()
        val actual = scanViolations()

        val regressions = actual.keys.filter { it !in baseline }
        assertTrue(
            "新增了绕开 `components/QingyuSheet.kt` 的弹层调用（应当改用 `QingyuSheet(...)`，" +
                "它统一给 16dp 侧边距 + 底部手势区让位）：\n" +
                regressions.joinToString("\n") { "    $it" } +
                "\n（`OverlayBottomSheet(` 只允许出现在套件文件里）",
            regressions.isEmpty(),
        )

        val stale = baseline.keys.filter { it !in actual.keys }
        assertTrue(
            "基线里有这些行，但代码已经不违规了 —— 请从 `tool/compose_sheet_baseline/` 删掉对应行" +
                "（棘轮只许收不许放）：\n" + stale.joinToString("\n") { "    $it" },
            stale.isEmpty(),
        )
    }

    /**
     * S7（2026-11-03 补）：`pages/transfer/` 自建弹层必须**常驻组合**，不许条件挂载。
     *
     * 背景：本域把「预览弹层 / 二维码范围弹层」从 `if (show) { Dialog }` 改成常驻 +
     * `show` 驱动（退场动画才能放完）。S1/S5/S6 只查入口与参数，条件挂载一条都拦不住，
     * 而且这种形状编译照过、单测照绿，只有真机看得出「弹层直接消失」。
     *
     * 判据（只扫 `pages/transfer` 下的 .kt 文件，注释整行掏出）：
     * - 弹层调用出现在 `if (...)` / `when (...)` / `...?.let {` / `....let {` 的块内 → 违规；
     * - `if (...) QingyuSheet(...)` 这种单行形态 → 违规；
     * - 普通容器 lambda（`Row { ... }`、`Column { ... }`、`Box { ... }`、`surface { ... }`）不算。
     *
     * 咬合探针：给 `DataTransferPage.kt` 的 `OverlayDialog` 套一层 `if (false) { ... }`，
     * 这条必须红；还原后绿（2026-11-03 实际执行过）。
     */
    @Test
    fun `pages transfer 自建弹层必须常驻组合且 show 驱动`() =
        assertPermanentSheetMounts(TRANSFER_PREFIX, "pages/transfer")

    /**
     * S8（2026-11-03 补）：`pages/sync/` 与 S7 同等强度。
     *
     * `pages/sync` 的弹层同样是常驻组合 + `show` 驱动（备份详情、控制器页、情侣 WebDAV、
     * 情侣课表设置）；条件挂载会让退场动画整棵消失，且编译/单测都看不出来。
     * 咬合探针：给 `CloudSyncControllerPage.kt:242` 的 `OverlayDialog` 套 `if (false) { ... }`
     * 必须红，还原后绿（2026-11-03 实际执行过）。
     */
    @Test
    fun `pages sync 自建弹层必须常驻组合且 show 驱动`() =
        assertPermanentSheetMounts(SYNC_PREFIX, "pages/sync")

    private fun assertPermanentSheetMounts(prefix: String, label: String) {
        val files = renderFiles().filter { it.contains(prefix) }
        assertTrue(
            "$label 下一个弹层文件都没扫到，判据失效（扫描根 user.dir=" +
                "${System.getProperty("user.dir")}）",
            files.any { File(it).readText().contains("QingyuSheet(") },
        )
        val violations = files.flatMap { path ->
            conditionalSheetMounts(File(path).readText()).map { line ->
                "${relativeName(path)}:$line 弹层被 if/when/let 条件挂载"
            }
        }
        assertTrue(
            "$label 有弹层被条件挂载（应为常驻组合 + `show` 驱动，退出动画才放得完）：\n" +
                violations.joinToString("\n") { "    $it" },
            violations.isEmpty(),
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
            dialogMissingInsideMargin(text).forEach { line ->
                result["$relative|S5"] =
                    "第 $line 行 `OverlayDialog` 没传 `insideMargin`：官方默认 24dp，本仓口径" +
                        "横向 16dp（`DpSize(16.dp, 16.dp)`），缺省会与内容边距叠成 32~40dp"
            }
            platformDialogUsages(text).forEach { line ->
                result["$relative|S6"] =
                    "第 $line 行引用平台 `androidx.compose.ui.window.Dialog/Popup`：绕开 miuix 官方" +
                        "弹层就没有遮罩、返回键关闭与进出动画（2026-11-02 弹窗审核查漏的 11 个自建弹窗" +
                        "全是这种形态）。改用 `OverlayDialog` / `QingyuSheet` / `OverlayListPopup`"
            }
        }
        return result
    }

    /**
     * 找出平台 `androidx.compose.ui.window.Dialog` / `Popup` 的引用行号（规则 S6，2026-11-03 补）。
     *
     * 背景：弹窗审核查漏发现 11 个自建/内联弹窗（日程族 4、云同步 2、课表管理 5）全部绕开
     * miuix 官方弹层 —— 它们既不被 S1（`OverlayBottomSheet`）也不被 S5（`OverlayDialog`）
     * 拦住，因为根本没调官方入口。判据只认**全限定名**（import 或全限定调用）：Kotlin 不调
     * import / 全限定名就到不了平台 `Dialog`/`Popup`，所以这条是零误报的硬门。整行注释
     * 先掏空（与 S5 同口径），`CourseOverviewPage.kt` 的考古 KDoc 不会误伤。
     * 词边界 `\b` 保证 `PopupProperties` 这类同前缀类型也会被拦——它只服务于平台 `Popup`，
     * 本就应一起走官方组件；`OverlayListPopup` 等官方组件不含该全限定名，不受影响。
     */
    private fun platformDialogUsages(text: String): List<Int> {
        val hits = mutableListOf<Int>()
        text.lineSequence().forEachIndexed { index, line ->
            val trimmed = line.trimStart()
            if (trimmed.startsWith("//") || trimmed.startsWith("*") || trimmed.startsWith("/*")) {
                return@forEachIndexed
            }
            if (PLATFORM_DIALOG_REF.containsMatchIn(line)) {
                hits += index + 1
            }
        }
        return hits
    }

    /**
     * 找出 `OverlayDialog(` 实参表里**没有 `insideMargin`** 的行号（规则 S5，2026-11-03 补）。
     *
     * 背景：守卫原本只拦 `OverlayBottomSheet`（S1），对话框漏网 —— 审核报告 S13 点名的
     * 4 处 `OverlayDialog` 没传 `insideMargin` 全是事后真机看出来的。判据与 S3/S4 同一套
     * 括号配平；**整行注释先掏空**（`// 旧版 OverlayDialog(...)` 这类考古注释不算调用，
     * sync/CoupleTimetableSettingsPage.kt 里真有一条），行号按原始文本计。
     */
    private fun dialogMissingInsideMargin(text: String): List<Int> {
        val code = text.lineSequence()
            .map { line ->
                val trimmed = line.trimStart()
                if (trimmed.startsWith("//") || trimmed.startsWith("*") || trimmed.startsWith("/*")) "" else line
            }
            .joinToString("\n")
        val hits = mutableListOf<Int>()
        var from = 0
        while (true) {
            val start = code.indexOf(DIALOG_CALL, from)
            if (start < 0) break
            val openParen = start + DIALOG_CALL.length - 1
            val close = matchingParen(code, openParen)
            if (close < 0) break
            val args = code.substring(openParen + 1, close)
            if (!args.contains("insideMargin")) {
                hits += code.take(start).count { it == '\n' } + 1
            }
            from = close
        }
        return hits
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

    /**
     * 找出被 `if` / `when` / `let` 条件挂载的弹层调用行号（规则 S7）。
     *
     * 用缩进 + 块栈做近似（不引 Kotlin 解析器）：行尾 `{` 入栈，行首 `}` 且缩进不大于栈顶
     * 就出栈；弹层调用出现时，只要栈里有一层是条件块就判违规。注释整行掏空（含块注释）
     * 避免考古 KDoc 误伤。缩进在本仓统一 4 空格，探针（`if (false) {`）能稳定命中。
     */
    private fun conditionalSheetMounts(text: String): List<Int> {
        val hits = mutableListOf<Int>()
        data class Block(val indent: Int, val header: String)
        val stack = ArrayDeque<Block>()
        var inBlockComment = false
        text.lineSequence().forEachIndexed { index, line ->
            val trimmed = line.trimStart()
            if (inBlockComment) {
                if (trimmed.contains("*/")) inBlockComment = false
                return@forEachIndexed
            }
            if (trimmed.startsWith("/*")) {
                inBlockComment = !trimmed.contains("*/")
                return@forEachIndexed
            }
            if (trimmed.startsWith("//") || trimmed.startsWith("*")) return@forEachIndexed
            val indent = line.length - trimmed.length
            while (stack.isNotEmpty() && trimmed.startsWith("}") && indent <= stack.last().indent) {
                stack.removeLast()
            }
            if (SHEET_ANY.containsMatchIn(line) || SINGLE_LINE_CONDITIONAL_SHEET.containsMatchIn(line)) {
                if (SINGLE_LINE_CONDITIONAL_SHEET.containsMatchIn(line) ||
                    stack.any { isConditionalHeader(it.header) }
                ) {
                    hits += index + 1
                }
            }
            if (trimmed.endsWith("{") && !trimmed.startsWith("}")) {
                stack.addLast(Block(indent, trimmed))
            }
        }
        return hits
    }

    private fun isConditionalHeader(header: String): Boolean {
        val h = header.trimStart()
        return h.startsWith("if (") || h.startsWith("if(") ||
            h.startsWith("when (") || h.startsWith("when(") ||
            h.startsWith("when {") ||
            h.endsWith("?.let {") || h.endsWith(".let {") ||
            h.endsWith("?.let{") || h.endsWith(".let{")
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

        /** 对话框口径的入口（规则 S5）。 */
        const val DIALOG_CALL = "OverlayDialog("

        /** 平台 Dialog/Popup 的全限定名（规则 S6）。 */
        val PLATFORM_DIALOG_REF = Regex("""androidx\.compose\.ui\.window\.(Dialog|Popup)\b""")

        const val TEXT_BUTTON_CALL = "textButtonColors("

        /** 实心按钮配色的入口（规则 S4）。 */
        const val BUTTON_COLORS_CALL = "buttonColors("

        const val COLOR_KEYWORD_LENGTH = 5

        /** `color` 关键字后面必须跟的是 `=`（排除 `colors` / `colorXxx`）。 */
        val AFTER_COLOR_KEYWORD = Regex("""\s*=""")

        /** 危险色的写法（本仓是 `QingyuTheme.error(…)` / `destructive`）。 */
        val DANGER_COLOR = Regex("""(error|Error|destructive|Destructive)""")

        /** S7 只扫本域自建弹层目录（裁决作用域）。 */
        const val TRANSFER_PREFIX = "/pages/transfer/"

        /** S8：`pages/sync` 与 S7 同等强度。 */
        const val SYNC_PREFIX = "/pages/sync/"

        /** 弹层入口（套件与 miuix 对话框）。 */
        val SHEET_ANY = Regex("""(?:QingyuSheet|OverlayDialog)\s*\(""")

        /** `if (...) QingyuSheet(...)` 不换行形态。 */
        val SINGLE_LINE_CONDITIONAL_SHEET = Regex(
            """if\s*\(.*\)\s*(?:QingyuSheet|OverlayDialog)\s*\(""",
        )
    }
}
