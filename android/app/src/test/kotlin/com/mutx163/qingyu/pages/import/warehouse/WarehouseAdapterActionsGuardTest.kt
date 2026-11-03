package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 学校适配器列表页「按钮观感」守卫（2026-11-03）。
 *
 * ## 它防的是哪一类事故
 *
 * 用户实报适配器卡片「四颗按钮像四种不同控件」：`录制导入`/`查看详情` 此前用
 * `surfaceVariant` 当按钮容器（本仓主题接线未覆写该槽位，亮色官方默认 = 纯白），
 * 落在白卡片上 WCAG 对比比 **1.0**——容器完全隐形，只剩一行蓝字飘着；加上
 * 「快捷导入」浅蓝胶囊、「网页登录导入」默认灰，同一张卡里实心/胶囊/文字链三种
 * 语言混用，第二行还是 SpaceBetween 散排，同列长度互不相齐。
 *
 * ## 口径（2026-11-03 重排定稿）
 *
 * - 单一主操作：「网页登录导入」= `ButtonDefaults.buttonColorsPrimary()`；
 * - 其余（录制导入 / 快捷导入 / 查看详情 / 空态重试）统一次级灰
 *   `buttonColors(color = secondary, contentColor = onSecondaryVariant)`；
 * - 动作按钮统一 2×2 等宽网格：列宽全部 `weight(1f)` 等分；
 * - 「查看详情」固定右列（对齐旧版 centerRight 的位置记忆），无宏时左列留空位。
 *
 * 数值判据（两色算不算「融」）在 `com.mutx163.qingyu.utils.ButtonContrastRules`；
 * 判据匹配前剥掉行注释 / 可嵌套块注释 / 字符串字面量（家法同
 * `SettingsButtonStyleGuardTest`，注释里的示例代码不许误报）。
 */
class WarehouseAdapterActionsGuardTest {

    @Test
    fun `受守文件必须存在且扫得到按钮`() {
        val text = readGuardedSource()
        val buttons = buttonCalls(text)
        assertTrue(
            "受守文件里 Button( 少于 5 颗（应为 4 颗动作 + 1 颗空态重试），判据已失效（空跑假绿）",
            buttons.size >= 5,
        )
    }

    @Test
    fun `页面级按钮必须显式传colors`() {
        val violations = buttonCalls(readGuardedSource())
            .filter { topLevelArgument(it.arguments, "colors") == null }
            .map { "Button@line ${it.line}" }
        assertTrue(
            "本页按钮落在白卡/页底上，官方默认容器（secondaryVariant 亮 #F0F0F0 / surfaceVariant 白）" +
                "会融进背景；必须显式传 colors（主操作 buttonColorsPrimary，次操作 secondary 灰）。" +
                "违规：\n" + violations.joinToString("\n"),
            violations.isEmpty(),
        )
    }

    @Test
    fun `网页登录导入必须是主操作实心`() {
        val call = buttonCalls(readGuardedSource())
            .firstOrNull { it.arguments.contains("webLoginImport") }
        assertTrue("扫不到「网页登录导入」按钮（webLoginImport），判据已失效", call != null)
        assertTrue(
            "「网页登录导入」是本页唯一主操作，必须用 ButtonDefaults.buttonColorsPrimary()（蓝色实心）；" +
                "降到灰底或文字链会让「进哪所学校先做哪一步」读不出来（用户实报的四种控件混排就含这条）。",
            call!!.arguments.contains("buttonColorsPrimary"),
        )
    }

    @Test
    fun `动作按钮必须等宽网格`() {
        val actions = listOf(
            "webLoginImport",
            "recordImportAction",
            "quickImportAction",
            "viewDetailsAction",
        )
        val calls = buttonCalls(readGuardedSource())
        val violations = mutableListOf<String>()
        for (action in actions) {
            val call = calls.firstOrNull { it.arguments.contains(action) }
            if (call == null) {
                if (action == "quickImportAction") continue // 条件动作仍应存在，缺失由哨兵之外另行报
                violations += "$action：扫不到按钮调用"
                continue
            }
            if (!call.arguments.contains("weight(1f)")) {
                violations += "$action：Button 未用 weight(1f) 等分列宽（会缩成 wrapContent 长短不一）"
            }
        }
        assertTrue(
            "动作按钮必须两列等宽网格（weight(1f) 等分），不许同一列两颗长度不同。违规：\n" +
                violations.joinToString("\n"),
            violations.isEmpty(),
        )
    }

    @Test
    fun `禁止surfaceVariant当按钮容器`() {
        val stripped = stripCommentsAndStrings(readGuardedSource())
        val violations = buttonCalls(stripped)
            .filter { it.arguments.contains("color = MiuixTheme.colorScheme.surfaceVariant") }
            .map { "Button@line ${it.line}" }
        assertTrue(
            "surfaceVariant 在本仓亮色主题下是纯白（槽位未覆写），白底按钮落在白卡片上" +
                "WCAG 对比比 1.0 完全隐形（用户实报「纯蓝字」事故的根源）；" +
                "次级按钮请用 secondary（#E6E6E6）+ onSecondaryVariant 墨。违规：\n" +
                violations.joinToString("\n"),
            violations.isEmpty(),
        )
    }

    @Test
    fun `注释里的关键字不触发判据`() {
        val code = """
            class Sample {
                // Button(onClick = {}) 注释里的按钮不算
                /* ButtonDefaults.buttonColorsPrimary() 块注释也不算 */
                val doc = "surfaceVariant"
                fun render() {
                    Button(
                        onClick = {},
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(
                            color = MiuixTheme.colorScheme.secondary,
                            contentColor = MiuixTheme.colorScheme.onSecondaryVariant,
                        ),
                    ) { Text(text = "ok") }
                }
            }
        """.trimIndent()
        val stripped = stripCommentsAndStrings(code)
        val calls = buttonCalls(stripped)
        assertTrue("剥离后应恰好剩 1 处真实 Button(，实际 ${calls.size}", calls.size == 1)
        assertTrue(
            "剥离失败：注释/字符串里的关键字仍然参与匹配\n---STRIPPED-START---\n$stripped\n---STRIPPED-END---",
            calls.single().arguments.contains("surfaceVariant").not() &&
                calls.single().arguments.contains("buttonColorsPrimary").not(),
        )
    }

    // ------------------------------------------------------------------
    // 判据工具（与 SettingsButtonStyleGuardTest 同一套家法的裁剪版）
    // ------------------------------------------------------------------

    private fun readGuardedSource(): String {
        val file = File(repoRoot(), GUARDED_FILE)
        assertTrue(
            "守卫目标文件不存在：${file.absolutePath}。文件改名/移动后必须同步更新本守卫。",
            file.isFile,
        )
        return stripCommentsAndStrings(file.readText())
    }

    private data class SourceCall(val line: Int, val arguments: String)

    /** 剥掉行注释、可嵌套块注释与字符串字面量（普通 + `"""` 原始串）。 */
    private fun stripCommentsAndStrings(text: String): String {
        val out = StringBuilder(text.length)
        var i = 0
        var blockDepth = 0
        while (i < text.length) {
            if (blockDepth > 0) {
                if (text.startsWith("/*", i)) {
                    blockDepth++
                    i += 2
                } else if (text.startsWith("*/", i)) {
                    blockDepth--
                    i += 2
                } else {
                    if (text[i] == '\n') out.append('\n')
                    i++
                }
                continue
            }
            if (text.startsWith("//", i)) {
                while (i < text.length && text[i] != '\n') i++
                continue
            }
            if (text.startsWith("/*", i)) {
                blockDepth = 1
                i += 2
                continue
            }
            if (text[i] == '"') {
                var j = i + 1
                while (j < text.length) {
                    when {
                        text[j] == '\\' -> j += 2
                        text[j] == '\n' -> {
                            repeat(j - i) { out.append(' ') }
                            out.append('\n')
                            i = j + 1
                            break
                        }
                        text[j] == '"' -> {
                            repeat(j + 1 - i) { out.append(' ') }
                            i = j + 1
                            break
                        }
                        else -> j++
                    }
                }
                if (j >= text.length) i = j
                continue
            }
            if (text[i] == '\'') {
                out.append(' ')
                i++
                while (i < text.length && text[i] != '\'') {
                    if (text[i] == '\\' && i + 1 < text.length) i++
                    i++
                }
                if (i < text.length) {
                    out.append(' ')
                    i++
                }
                continue
            }
            out.append(text[i])
            i++
        }
        return out.toString()
    }

    /** 取所有 `Button(` 调用（词边界排除 `TextButton(` / `IconButton(`）。 */
    private fun buttonCalls(text: String): List<SourceCall> {
        val result = mutableListOf<SourceCall>()
        var from = 0
        while (true) {
            val start = text.indexOf("Button(", from)
            if (start < 0) break
            val prevOk = start == 0 || !(text[start - 1].isLetterOrDigit() || text[start - 1] == '_')
            if (!prevOk) {
                from = start + "Button(".length
                continue
            }
            val openParen = start + "Button(".length - 1
            var depth = 0
            var i = openParen
            var close = -1
            while (i < text.length) {
                when (text[i]) {
                    '(' -> depth++
                    ')' -> {
                        depth--
                        if (depth == 0) {
                            close = i
                        }
                    }
                }
                if (close >= 0) break
                i++
            }
            if (close < 0) break
            result += SourceCall(
                line = text.take(start).count { it == '\n' } + 1,
                arguments = text.substring(openParen + 1, close),
            )
            from = close
        }
        return result
    }

    /** 取 `name = …` 的**顶层**实参文本；没有则 null。 */
    private fun topLevelArgument(args: String, name: String): String? {
        var depth = 0
        var i = 0
        while (i < args.length) {
            when (args[i]) {
                '(', '[', '{' -> depth++
                ')', ']', '}' -> depth--
            }
            if (depth == 0 && args.startsWith(name, i)) {
                val before = if (i == 0) ' ' else args[i - 1]
                val afterName = i + name.length
                val boundaryBefore = !(before.isLetterOrDigit() || before == '_')
                val equals = args.indexOf('=', afterName)
                val boundaryAfter = equals >= 0 && args.substring(afterName, equals).isBlank()
                if (boundaryBefore && boundaryAfter) {
                    var end = equals + 1
                    var inner = 0
                    while (end < args.length) {
                        when (args[end]) {
                            '(', '[', '{' -> inner++
                            ')', ']', '}' -> inner--
                            ',' -> if (inner == 0) return args.substring(equals + 1, end)
                        }
                        end++
                    }
                    return args.substring(equals + 1, end)
                }
            }
            i++
        }
        return null
    }

    private fun repoRoot(): String {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
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
        /** 多 Agent 并行：只守本批改的这一个文件，别把别人在途的文件记进来。 */
        const val GUARDED_FILE =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseSchoolAdaptersPage.kt"
    }
}
