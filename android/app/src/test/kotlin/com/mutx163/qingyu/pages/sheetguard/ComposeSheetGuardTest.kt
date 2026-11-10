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
 * | S3 | `textButtonColors(color = …)` 是**底色**；不给 `textColor` 时字是默认灰 | 发布版 `destructive` 磨砂钮 = **红字 + 淡红水洗底** | 三种错形：整颗饱和红底 / 水洗底配灰字 / 只有红字没水洗底（见下节） |
 *
 * 32 个底部弹层里 32 个都缺 S2、27 个叠了侧边距。**根因不是缺组件，是每个调用方各自记**
 * —— 所以修法是把口径收进套件 `com.mutx163.qingyu.components.QingyuSheet`，再用这条守卫
 * 把「不许绕开套件」钉死（与 `QingyuPageScaffold` / `QingyuCard` 同一套做法）。
 *
 * ## S3 的发布版口径（2026-11-10 修订：水洗底是合法形态）
 *
 * 发布版 `HyperosFrostedSheetButton(variant = destructive)` 既不是「红底 + 灰字」，也不是
 * 「中性底 + 红字」，而是**红字 + 淡红水洗底**。tag `v2.1.4.1` 逐行读数：
 *
 * - `lib/ui/hyperos/hyperos_controls.dart:846-859`：`fg = error`（禁用 `error@0.45`）、
 *   `tint = error @ 深色 0.14 / 浅色 0.10`（禁用 `error@0.06`）；
 * - 同文件 `:895-897`：`HyperosFrostedSurface(tint = tint, …)`；
 * - `lib/ui/hyperos/frosted/frosted_header_background.dart:157`（`tint` 字段）、`:170-175` /
 *   `:195-207`：`tint` 就是这个表面的**填充色** ⇒ 那层「水洗」。
 *
 * 所以 S3 从「见到 `color = 危险色` 就红」改成**三态**（阈值 [WASH_ALPHA_MAX] = 0.2，
 * 比发布版的 0.10 / 0.14 留一档余量，禁用档 0.06 也自然落在里面）：
 *
 * | 形态 | 典型写法 | 判定 |
 * |---|---|---|
 * | 水洗底 + 红字（**唯一合法**） | `color = destructive.copy(alpha = 0.10f), textColor = destructive` | 放行 |
 * | 饱和红底 | `color = error` / `color = error.copy(alpha = 0.5f)` | 红：整颗红底 + 默认灰字 |
 * | 水洗底没染字 | `color = error.copy(alpha = 0.1f)`（同句没有 `textColor`） | 红：淡红底配默认灰字 |
 * | 纯红字没水洗底 | `textColor = error`（同句没有 `color`） | 红：中性灰底 + 红字，比发布版少一层水洗 |
 *
 * **已知盲区（判据只看字面 token，不做数据流）**：危险色与水洗底经变量传进来时判据看不见
 * （活例 `pages/course/ClassAlarmSheet.kt` 的 `removeColor`）⇒ **不报**。这是「不误伤」的
 * 代价，不是放行；要在守卫保护下，就得把 token 写在同一个调用里。
 *
 * **为什么不把这些合法形态登记进基线**：基线键是 `相对路径|规则`（没有行号，也没有
 * 具体实参，见 [loadBaseline]）——登记一条等于把**整个文件**的 S3 放行，之后该文件再写
 * 饱和红底也不会红。那是弱化守卫，不是登记口径；合法形态的正确去处是判据自己认得它。
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
 *
 * ## 怎么跑（2026-11-10 起在 `sheetguard/` 独立模块）
 *
 * 本文件原先在 `test/.../pages/` 根，`-Module pages` 会递归整棵 pages 树（含 compose 文件）
 * 必红、L0 点不了名，只能等整包 L2。现在与 `QingyuSheetScaleGuardTest` 同住
 * `pages/sheetguard/`，任何泳道都能在交活前点名跑（不抢 Gradle 锁）：
 *
 * ```bash
 * pwsh -File scripts/test-kotlin-module.ps1 -Module pages/sheetguard          # 约 25s，L0
 * pwsh -File scripts/safe-gradle.ps1 :app:testDevDebugUnitTest --tests "*ComposeSheetGuardTest"  # 权威 L2
 * ```
 *
 * 跑的时候**工作目录必须是仓库根**：判据靠 `user.dir` 往上找 `android/app/src`（[repoRoot]），
 * 在 `android/` 里跑会扫不到源文件而先红在哨兵上。
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
                regressions.joinToString("\n") { "    $it —— ${actual[it]}" },
            regressions.isEmpty(),
        )

        val stale = baseline.keys.filter { it !in actual.keys }
        assertTrue(
            "基线里有这些行，但代码已经不违规了 —— 请从 `tool/compose_sheet_baseline/` 删掉对应行" +
                "（棘轮只许收不许放）：\n" + stale.joinToString("\n") { "    $it" },
            stale.isEmpty(),
        )
    }

    @Test
    fun `S1D 判据必须剥掉注释——注释里写 insideMargin 不算传了`() {
        // 假绿盲区的原始形状（2026-11-03 另一路探针踩中）：实参区只有**注释**写了
        // insideMargin，真没传。裸 contains 会放行 ⇒ 必须判红。
        val commentOnly = """
            OverlayDialog(
                show = true,
                // insideMargin = DpSize(16.dp, 16.dp) 的口径见套件文档
                title = "T",
            ) { }
        """.trimIndent()
        assertTrue(
            "实参区只有注释写了 insideMargin（真没传）必须判红",
            dialogInsideMarginViolations(commentOnly).isNotEmpty(),
        )

        // 块注释同罪；且 Kotlin 块注释可嵌套，剥的时候得配平。
        val blockCommentOnly = """
            OverlayDialog(
                show = true,
                /* 口径是 insideMargin = DpSize(16.dp, 16.dp)，/* 嵌套一层 */ 注释结束 */
                title = "T",
            ) { }
        """.trimIndent()
        assertTrue(
            "实参区只有块注释写了 insideMargin（真没传）必须判红",
            dialogInsideMarginViolations(blockCommentOnly).isNotEmpty(),
        )

        // 真传了必须判绿——含「注释 + 真参」同框与字符串里的 //（不许把同行真参吃掉）。
        val realPass = """
            OverlayDialog(
                show = true,
                insideMargin = DpSize(16.dp, 16.dp), // 官方默认 24，收成 16
                title = "https://example.com/a",
            ) { }
        """.trimIndent()
        assertTrue(
            "真传 insideMargin（含注释与字符串 // 同框）不应判红",
            dialogInsideMarginViolations(realPass).isEmpty(),
        )
    }

    @Test
    fun `S1D 判据必须剥掉注释——注释里的假调用不算调用`() {
        // 假红盲区（2026-11-03 弹层审计第二批踩中）：讲历史的注释引用了旧写法
        // `OverlayDialog(show = true)`，判据在**原文**里找调用名时把注释当成了真调用，
        // 对着注释报 S1D。判据必须先整篇剥注释再找 `OverlayDialog(`。
        val fakeCallInLineComment = """
            // 原先 if (confirmDelete) { OverlayDialog(show = true) } 条件挂载，已改常驻。
            OverlayDialog(
                show = state != null,
                insideMargin = DpSize(16.dp, 16.dp),
            ) { }
        """.trimIndent()
        assertTrue(
            "行注释里的假 OverlayDialog( 不能算真实调用（真调用已传 insideMargin）",
            dialogInsideMarginViolations(fakeCallInLineComment).isEmpty(),
        )

        val fakeCallInBlockComment = """
            /**
             * 历史写法示例：
             * OverlayDialog(
             *     show = true,
             * )
             */
            val ok = 1
        """.trimIndent()
        assertTrue(
            "KDoc 里的假 OverlayDialog( 不能算真实调用",
            dialogInsideMarginViolations(fakeCallInBlockComment).isEmpty(),
        )

        // 反向咬合：注释之后**真调用**没传 insideMargin，仍要判红（剥注释不能把真账也剥掉）。
        val realMissing = """
            // 注释里的 OverlayDialog(show = true) 不算数
            OverlayDialog(
                show = true,
            ) { }
        """.trimIndent()
        assertTrue(
            "真调用没传 insideMargin 仍必须判红",
            dialogInsideMarginViolations(realMissing).isNotEmpty(),
        )

        // S3/S4 与 S1D 同盲区：注释里写的假 buttonColors 不参与判定。
        val fakeDangerInComment = """
            // 历史写法：buttonColors(color = error) 忘了 contentColor
            val ok = ButtonDefaults.buttonColors()
        """.trimIndent()
        assertTrue(
            "注释里的假 buttonColors(color = 危险色) 不能判 S4",
            solidDangerWithoutContentColor(fakeDangerInComment).isEmpty(),
        )
    }

    @Test
    fun `S3 判据必须只认发布版水洗形态`() {
        // 发布版 destructive 磨砂钮 = 红字 + 淡红水洗底（v2.1.4.1 hyperos_controls.dart:846-859，
        // tint 就是表面填充色，见 frosted_header_background.dart:170-175）。这是**合法形态**，
        // 别再逼人改成「只染字」——那种写法反而会掉成中性灰底。
        val wash = """
            TextButton(
                text = deleteLabel,
                colors = ButtonDefaults.textButtonColors(
                    color = destructive.copy(alpha = if (dark) 0.14f else 0.10f),
                    disabledColor = destructive.copy(alpha = 0.06f),
                    textColor = destructive,
                    disabledTextColor = destructive.copy(alpha = 0.45f),
                ),
            )
        """.trimIndent()
        assertTrue(
            "水洗底 + 红字是发布版形态，必须放行；实际判红：${dangerTextButtonViolations(wash)}",
            dangerTextButtonViolations(wash).isEmpty(),
        )

        // ① 饱和红底（`color` 给了危险色、没做水洗）——核心意图，仍必须红。
        val saturated = """
            colors = ButtonDefaults.textButtonColors(color = Color(QingyuTheme.error(dark)))
        """.trimIndent()
        assertTrue(
            "整颗饱和红底必须判红",
            dangerTextButtonViolations(saturated).isNotEmpty(),
        )

        // ①' 写了 `.copy(alpha = …)` 但 alpha 高于水洗档：仍是红块，不能靠「有 copy」蒙过去。
        val halfRed = """
            colors = ButtonDefaults.textButtonColors(
                color = error.copy(alpha = 0.5f),
                textColor = error,
            )
        """.trimIndent()
        assertTrue(
            "alpha 高于 $WASH_ALPHA_MAX 仍算饱和红底，必须判红",
            dangerTextButtonViolations(halfRed).isNotEmpty(),
        )

        // ② 水洗底没染字：淡红底 + 默认灰字，对比度坏，仍必须红。
        val washWithoutInk = """
            colors = ButtonDefaults.textButtonColors(
                color = error.copy(alpha = 0.10f),
            )
        """.trimIndent()
        assertTrue(
            "水洗底没给 `textColor = 危险色` 必须判红",
            dangerTextButtonViolations(washWithoutInk).isNotEmpty(),
        )

        // ③ 纯红字没水洗底：中性灰底 + 红字，比发布版少一层水洗，仍必须红。
        val inkOnly = """
            colors = ButtonDefaults.textButtonColors(
                textColor = Color(QingyuTheme.error(dark)),
            )
        """.trimIndent()
        assertTrue(
            "只染字、没有淡红水洗底必须判红",
            dangerTextButtonViolations(inkOnly).isNotEmpty(),
        )

        // ④ 中性色按钮（底色不是危险色）不归 S3 管——别把普通按钮的 alpha 算子误伤。
        val neutral = """
            colors = ButtonDefaults.textButtonColors(
                color = secondaryVariant.copy(alpha = 0.10f),
                textColor = primaryTextColor,
            )
        """.trimIndent()
        assertTrue(
            "中性色文字按钮不该被判 S3",
            dangerTextButtonViolations(neutral).isEmpty(),
        )

        // ⑤ 剥注释：注释里提到的「正确/错误写法」都不参与判定（与 S1D 同盲区）。
        val commented = """
            // 历史写法：ButtonDefaults.textButtonColors(color = error) —— 整颗红底
            // 也曾经改成过 textButtonColors(textColor = error) 的纯红字
            val ok = 1
        """.trimIndent()
        assertTrue(
            "注释里的假 textButtonColors 用法不能判 S3",
            dangerTextButtonViolations(commented).isEmpty(),
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
            // 四条判据都只看代码：先整篇剥注释（保留换行，行号不漂），
            // 注释里写的 `OverlayBottomSheet(` / 假调用 / 假实参都不参与判定。
            val code = stripKotlinComments(text)
            if (!relative.endsWith(SHEET_SUITE_FILE) && !relative.startsWith(SHOWCASE_PREFIX)) {
                code.lineSequence().forEachIndexed { index, line ->
                    if (SHEET_CALL.containsMatchIn(line)) {
                        result["$relative|S1"] =
                            "第 ${index + 1} 行直接调 `OverlayBottomSheet`，应改用 `QingyuSheet`"
                    }
                }
            }
            if (!relative.startsWith(SHOWCASE_PREFIX)) {
                dialogInsideMarginViolations(code).forEach { line ->
                    result["$relative|S1D"] =
                        "第 $line 行 `OverlayDialog` 未显式传 `insideMargin`：" +
                            "官方默认 24dp，本仓口径单边合计 16dp"
                }
            }
            dangerTextButtonViolations(code).forEach { (line, why) ->
                result["$relative|S3"] = "第 $line 行 $why"
            }
            solidDangerWithoutContentColor(code).forEach { line ->
                result["$relative|S4"] =
                    "第 $line 行 `buttonColors(color = 危险色)` 没写 `contentColor`：实心红底会配默认字色，" +
                        "Dart `HyperosButtonVariant.destructive` 是「红底 + `onError` 字」"
            }
        }
        return result
    }

    /**
     * 找出 `textButtonColors(...)` 里**危险色用法不合发布版口径**的位置（规则 S3）。
     *
     * 返回「行号 to 错在哪」；空 = 合法（水洗底 + 红字），或这个调用压根没提危险色。
     * 三态判据与发布版读数见类 KDoc 的「S3 的发布版口径」；阈值 [WASH_ALPHA_MAX]。
     *
     * ## 为什么不能只写正则
     *
     * `color = Color(QingyuTheme.error(dark))` 里有**嵌套括号**，`[^)]*` 那种写法会在
     * `Color(` 的右括号处断掉、漏判（第一版本就是这么漏掉 3 处的）。所以这里按括号配平
     * 取出实参，再只看**顶层**的 `color = …` / `textColor = …` 两个值（`disabledColor`
     * 之类同后缀参数不会被误当 `color`）。
     */
    private fun dangerTextButtonViolations(text: String): List<Pair<Int, String>> {
        // 与 S1D 同一口径：先剥注释再找调用，注释里的 `textButtonColors(color = …)`
        // 不算调用（假红盲区与 S1D 同批修掉）。
        val code = stripKotlinComments(text)
        val hits = mutableListOf<Pair<Int, String>>()
        var from = 0
        while (true) {
            val start = code.indexOf(TEXT_BUTTON_CALL, from)
            if (start < 0) break
            val openParen = start + TEXT_BUTTON_CALL.length - 1
            val close = matchingParen(code, openParen)
            if (close < 0) break
            val args = code.substring(openParen + 1, close)
            val fill = namedArgument(args, "color")
            val ink = namedArgument(args, "textColor")
            val dangerFill = fill != null && DANGER_COLOR.containsMatchIn(fill)
            val dangerInk = ink != null && DANGER_COLOR.containsMatchIn(ink)
            if (dangerFill || dangerInk) {
                val wash = dangerFill && isWash(fill)
                val why = when {
                    // ① 饱和红底：整颗红底 + 默认灰字，对比度坏，也不是发布版形态。
                    dangerFill && !wash ->
                        "`textButtonColors(color = 危险色)` 没做成水洗（`alpha` 缺省或 > $WASH_ALPHA_MAX）：" +
                            "会是整颗饱和红底，发布版 destructive 是淡红水洗底"
                    // ② 水洗底没染字：淡红底 + 默认灰字，对比度同样不够。
                    dangerFill && !dangerInk ->
                        "给了淡红水洗底却没给 `textColor = 危险色`：淡红底配默认灰字"
                    // ③ 纯红字没水洗底：中性灰底 + 红字，比发布版少一层水洗。
                    !dangerFill && dangerInk ->
                        "只把字染红、没给淡红水洗底（`color = 危险色.copy(alpha = 0.10f/0.14f)`）：" +
                            "发布版 destructive = 红字 + 水洗底"
                    // ④ 水洗底 + 红字（`dangerFill && wash && dangerInk`）= 唯一合法形态。
                    else -> null
                }
                if (why != null) hits += (code.take(start).count { it == '\n' } + 1) to why
            }
            from = close
        }
        return hits
    }

    /**
     * 顶层 `color = …` 的值是不是「水洗」：显式 `.copy(alpha = …)` 且 alpha ≤ [WASH_ALPHA_MAX]。
     *
     * 只认**写在同一个表达式里**的 alpha 字面量（`if (dark) 0.14f else 0.10f` 取最大那个）；
     * alpha 走常量/变量时判不出来 ⇒ 按「没做成水洗」处理（宁可报红让人把值写出来，
     * 也不静默放行整颗红底）。
     */
    private fun isWash(colorExpr: String): Boolean {
        val marker = ALPHA_NAMED_ARG.find(colorExpr) ?: return false
        var i = marker.range.last + 1
        var depth = 0
        val start = i
        while (i < colorExpr.length) {
            when (colorExpr[i]) {
                '(' -> depth++
                ')' -> {
                    if (depth == 0) break
                    depth--
                }
                ',' -> if (depth == 0) break
            }
            i++
        }
        val alpha = ALPHA_NUMBER.findAll(colorExpr.substring(start, i))
            .mapNotNull { it.value.toFloatOrNull() }
            .maxOrNull()
        return alpha != null && alpha <= WASH_ALPHA_MAX
    }

    /**
     * 找出 `OverlayDialog(` 调用**没显式传 `insideMargin`** 的行号（规则 S1D）。
     *
     * 2026-11-02 弹窗审计 S13：守卫原本只拦 `OverlayBottomSheet`，对话框全走官方默认
     * 24dp 而守卫看不见。只卡「有没有显式传」这一个判据：数值是否凑够本仓口径
     *（横 16，或横 0/8 + 内容自带 padding 补齐）由评审把关——文本层判数值会误伤
     * `DpSize(0.dp, 16.dp)` 这类合理写法。
     *
     * ## 假绿盲区（2026-11-03 另一路探针踩中后补的）
     *
     * 第一版判据是裸 `args.contains("insideMargin")`：实参区里只要有一行**注释**写了
     * 这四个字（比如「`insideMargin` 的口径见套件文档」），真没传也会放行。所以先
     * [stripKotlinComments] 剥掉 `//` 与 `/* */`（块注释按 Kotlin 语义**可嵌套**），
     * 再按命名参数形态 `\binsideMargin\s*=` 匹配——注释即使没剥干净也写不出带 `=`
     * 的实参位。剥注释对**字符串字面量**感知（`"https://…"` 里的 `//` 不会被当成
     * 行注释吃掉后半段实参）。是否有专用测试钉这条盲区，见
     * `S1D 判据必须剥掉注释`。
     */
    private fun dialogInsideMarginViolations(text: String): List<Int> {
        // 判据看的是**代码**，不是「代码+注释」：整篇先剥注释、再找调用。注释里写的
        // `OverlayDialog(show = true)`（讲历史的注释 / KDoc 示例）不算调用——否则守卫会
        // 被注释骗出**假红**（2026-11-03 弹层审计第二批踩中：同步域两份注释里引用了
        // 旧的条件挂载写法，守卫对着注释里的假调用报 S1D）。da6d312f 只修了
        // 「实参区注释写 insideMargin 的假绿」，没修「注释里写假调用的假红」。
        // 「旧版假绿盲区」与「新版假红盲区」都靠先剥注释堵上。
        val code = stripKotlinComments(text)
        val hits = mutableListOf<Int>()
        var from = 0
        while (true) {
            val start = code.indexOf(DIALOG_CALL, from)
            if (start < 0) break
            // `XxxOverlayDialog(` 这类自定义名字的尾巴也是 `OverlayDialog(` —— 卡词边界。
            if (start > 0 && (code[start - 1].isLetterOrDigit() || code[start - 1] == '_')) {
                from = start + DIALOG_CALL.length
                continue
            }
            val openParen = start + DIALOG_CALL.length - 1
            val close = matchingParen(code, openParen)
            if (close < 0) break
            if (!INSIDE_MARGIN_NAMED_ARG.containsMatchIn(code.substring(openParen + 1, close))) {
                hits += code.take(start).count { it == '\n' } + 1
            }
            from = close
        }
        return hits
    }

    /**
     * 剥掉 Kotlin 源码里的注释，供「只看代码」的判据用（与样式守卫 `Get-CodeLines`
     * 的「只看代码行」同一目的，但按字符状态机做，不依赖行首形状）。
     *
     * - `//` 行注释：剥到行尾（换行符保留，不影响别的按行数落点的逻辑）。
     * - 斜杠星块注释：按 Kotlin 语义**可嵌套**（`/* /* */ */` 才算完，写在这里都
     *   得逐字配平，否则本文件自己就先被注释吞了）。
     * - 字符串字面量（`"…"` / `'…'`）内容原样保留且其中的注释标记不算注释；
     *   转义（`\"`）不终结字符串——否则 `"https://…"` 会把同行后面的真实参一起吃掉。
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
                        // 块注释里的换行要保留：判据报的是「第几行」，剥注释把行吞了
                        // 行号就会整体上漂（KDoc 越长的文件漂得越多）。
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
        // 与 S1D 同一口径：先剥注释再找调用，注释里的 `buttonColors(color = error)` 不算调用。
        val code = stripKotlinComments(text)
        val hits = mutableListOf<Int>()
        var from = 0
        while (true) {
            val start = code.indexOf(BUTTON_COLORS_CALL, from)
            if (start < 0) break
            // `textButtonColors(` 的尾巴也是 `buttonColors(` —— 必须卡词边界，否则 S4 会
            // 把 S3 那些文字按钮当成实心按钮重复报一次。
            if (start > 0 && (code[start - 1].isLetterOrDigit() || code[start - 1] == '_')) {
                from = start + BUTTON_COLORS_CALL.length
                continue
            }
            val openParen = start + BUTTON_COLORS_CALL.length - 1
            val close = matchingParen(code, openParen)
            if (close < 0) break
            val args = code.substring(openParen + 1, close)
            val color = namedArgument(args, "color")
            if (color != null && DANGER_COLOR.containsMatchIn(color) && !args.contains("contentColor")) {
                hits += code.take(start).count { it == '\n' } + 1
            }
            from = close
        }
        return hits
    }

    /**
     * 取顶层命名参数 `keyword = …` 的实参文本（到同层逗号为止）；没有则 null。
     *
     * 关键词按**完整名字**匹配并卡左边界：`textColor` 的 `Color` 是大写、`disabledColor`
     * 的 `color` 前面是字母，两者都不会被当成 `color`（S4 与 S3 共用这一个提取器）。
     */
    private fun namedArgument(args: String, keyword: String): String? {
        var i = 0
        while (i <= args.length - keyword.length) {
            if (args.startsWith(keyword, i)) {
                val boundary = i == 0 || args[i - 1] in " ,(\n\r\t"
                val after = args.substring(i + keyword.length)
                if (boundary && after.trimStart().startsWith("=")) {
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

        /**
         * S1D 的「真传了」判据：命名参数形态 `\binsideMargin\s*=`。
         * 裸 `contains("insideMargin")` 会被实参区**注释**里的这四个字骗成假绿
         *（2026-11-03 另一路探针踩中）；剥注释之后再要求带 `=`，双保险。
         */
        val INSIDE_MARGIN_NAMED_ARG = Regex("""\binsideMargin\s*=""")

        const val TEXT_BUTTON_CALL = "textButtonColors("

        /** 实心按钮配色的入口（规则 S4）。 */
        const val BUTTON_COLORS_CALL = "buttonColors("

        /**
         * 危险色「水洗」的上限 alpha（规则 S3）。
         *
         * 发布版 `destructive` 磨砂钮：`tint = error @ 深色 0.14 / 浅色 0.10`、禁用 `@0.06`
         * （`v2.1.4.1:lib/ui/hyperos/hyperos_controls.dart:846-859`）。取 0.2 留一档余量，
         * 既放得下发布版的三档，又拦得住「0.3+ 已经看得出是红块」的写法。
         */
        const val WASH_ALPHA_MAX = 0.2f

        /** `alpha = …` 命名参数（规则 S3 判水洗）。 */
        val ALPHA_NAMED_ARG = Regex("""alpha\s*=""")

        /**
         * alpha 表达式里的数值（`if (dark) 0.14f else 0.10f` 两个都要，取最大那个；
         * 深色那一档更亮，用最大值判才不会把深色档当成没水洗）。
         */
        val ALPHA_NUMBER = Regex("""\d+(?:\.\d+)?""")

        /** 危险色的写法（本仓是 `QingyuTheme.error(…)` / `destructive`）。 */
        val DANGER_COLOR = Regex("""(error|Error|destructive|Destructive)""")
    }
}
