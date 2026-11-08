package com.mutx163.qingyu.pages.live

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 全仓「行间横线」守卫（2026-11-03）。
 *
 * ## 它防的是哪一类事故
 *
 * 2026-11-03 用户实报超级岛「上课前提醒显示」页一张卡里 6 个开关行每两行之间都有细横线，
 * 要求全软件清掉。排查结论（证据见 `docs/reference/miuix-demo/CHEATSHEET-Demo范例.md` §5.3
 * 与 `docs/reference/miuix-demo/我们的差距与修法.md`）：
 * - miuix 官方 `*Preference` 组件**不画**行间线（`basic/Component.kt` 无任何 Divider）；
 * - 官方 demo 全仓只有 BlurSection（块级分节，横向 16dp）与 TextStylePage（内容行间，纵向 2dp）
 *   两处文件用 `HorizontalDivider`，**同卡多 Preference 行之间一处都没有**；
 * - 本仓的线全部是各页面手插的 ⇒ 已逐页删除（提交 8ff8edd2 / fd3a3057 / 02c14d75 / e9d7f2d7）。
 *
 * 行与行的分隔由官方行组件自带内边距 / `spacedBy` 承担，删线不需要补线。
 *
 * ## 判据
 *
 * `android/app/src/composeP1` 下所有 Kotlin 源码（**剥掉注释与字符串后**）中
 * `HorizontalDivider(` 调用数不得超过 [ALLOWANCE] 白名单上限（未列文件为 0）。
 * 匹配前剥离行注释、**可嵌套**块注释与字符串字面量——注释里提到组件名不触发判据
 * （`注释与字符串里的关键字不触发判据` 用例钉住）。
 *
 * ## 白名单（豁免必须写原因，加条目先过用户）
 *
 * - 块级分节（官方 BlurSection 形态：内容块 ↔ Preference 组之间）：
 *   ExamListPage、AddExamPage、ScheduleDateRulePage、AddScheduleItemPage；
 * - 语义内容：ReleaseNotesMarkdownView（markdown `---` 语法渲染）；
 * - 表格语义：ProfileCompareCard（双档案对比表，无行线不可读）；
 * - 分享图设计参数：StatisticsExportCards（品牌区上下边线，`showTopDivider/showBottomDivider`）；
 * - 在途避让：import/warehouse 三页（版面重排会话在改，待其落地后清理并删白名单）。
 *
 * ⚠️ 文本判据对格式敏感；文件改名/移动后必须同步 [ALLOWANCE]，否则空跑假绿
 * （哨兵用例会先红）。
 */
class RowDividerGuardTest {

    /** 白名单：composeP1 相对路径 → 允许的 `HorizontalDivider(` 调用数上限。 */
    private val allowance: Map<String, Int> = mapOf(
        // 卡内「考试信息块 ↔ 提醒块」分节线（官方 BlurSection 式块级分节，非行间）。
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/exam/ExamListPage.kt" to 1,
        // ExamCardDivider：课程名输入块 ↔ 设置行组分节（用法 A）。
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/exam/AddExamPage.kt" to 1,
        // 条目内「匹配信息 ↔ 操作按钮行」分节。
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/ScheduleDateRulePage.kt" to 2,
        // 表单内「提示文本 ↔ 颜色小节」分节。
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/AddScheduleItemPage.kt" to 1,
        // markdown `---` 语法渲染（RULE 块），语义内容不是布局分隔。
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/ReleaseNotesMarkdownView.kt" to 1,
        // 双档案对比**表格**行线：无行线表格不可读，表格语义豁免。
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/charts/ProfileCompareCard.kt" to 1,
        // 分享图品牌区上下边线（showTopDivider/showBottomDivider 设计参数，非页面列表）。
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/charts/StatisticsExportCards.kt" to 2,
        // 应用日志：**一批日志并进一张卡**，行间用一条细线分条（2026-11-08 用户明确要求
        // 「同批日志并进一张卡加分隔线」）。这是日志流内部的条目分隔，不是被清掉的
        // 「设置卡里每两行都画线」，已获用户同意后登记。
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/diagnostics/LiveDiagnosticsLogPage.kt" to 1,
        // ── 在途避让：warehouse 版面重排会话在改，其落地后清理并删掉这三行白名单 ──
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/AiImageCourseImportPage.kt" to 1,
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseAdapterDetailPage.kt" to 1,
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseCustomDebugPage.kt" to 1,
        // ── 2026-11-08 三页版式重新设计后新增的块级分隔线（已按用户口径登记）──
        // 版本更新页：发布说明正文 ↔ 计数/更新时间行、以及卡内各小节之间；用户明确要求
        // 「分类容器 + 分隔线」的卡内分节，不是设置卡里每两行都画线。
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/AboutUpdatePage.kt" to 3,
        // 赞助页：鸣谢名单 ↔ 卡尾元信息（更新时间 / 同步说明）之间的一条分节线。
        // 2026-11-08 版式重排后，卡头不再画线（副标题与首行名单靠行内边距分隔），
        // 唯一这条线用来挡住「浅灰小字被读成最后一位支持者的备注」。
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/SupportCreatorPage.kt" to 1,
        // 学习会话统计：会话明细是**表格语义**（每条一行、多列对齐），无行线不可读。
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/statistics/StatisticsSessionPage.kt" to 1,
        // 数据迁移页：「当前可迁移内容」概览的堆叠行，与同卡「导出日历」可点行视觉统一。
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/DataTransferPage.kt" to 1,
    )

    private val scanRoot = "android/app/src/composeP1"
    private val token = "HorizontalDivider("

    @Test
    fun `行间横线不得超出白名单上限`() {
        val root = File(repoRoot(), scanRoot)
        assertTrue("扫描根目录不存在：${root.absolutePath}", root.isDirectory)
        val violations = mutableListOf<String>()
        var scanned = 0
        var whitelistedHits = 0
        root.walkTopDown().filter { it.isFile && it.extension == "kt" }.forEach { file ->
            scanned++
            val relative = file.invariantSeparatorsPath
                .substringAfter(repoRoot().replace('\\', '/') + "/")
            val stripped = stripCommentsAndStrings(file.readText())
            val count = callsAt(stripped, token).size
            if (count == 0) return@forEach
            val max = allowance[relative]
            if (max == null) {
                violations += "$relative：出现 $count 处（白名单外禁止）"
            } else {
                whitelistedHits += minOf(count, max)
                if (count > max) {
                    violations += "$relative：出现 $count 处，超过白名单上限 $max"
                }
            }
        }
        assertTrue(
            "扫描不到任何 Kotlin 文件，判据已失效（空跑假绿）", scanned > 100,
        )
        assertTrue(
            "白名单文件里一处 HorizontalDivider( 都扫不到，判据已失效（空跑假绿）",
            whitelistedHits >= 5,
        )
        assertTrue(
            "行间横线守卫：列表条目之间禁止 HorizontalDivider（官方 demo 同卡多行之间" +
                "一处都没有，行距由行内边距/spacedBy 承担）。新增白名单必须先写明豁免原因" +
                "并经用户同意。违规位置：\n" + violations.joinToString("\n") { "    $it" },
            violations.isEmpty(),
        )
    }

    @Test
    fun `注释与字符串里的关键字不触发判据`() {
        val code = """
            class Sample {
                // HorizontalDivider() 这行是注释，不算行间线
                /* 块注释里 HorizontalDivider( 也不算（含 /* 嵌套 */ 的情况） */
                val doc = "文档里写的 HorizontalDivider( 不算"
                val width = 1
            }
        """.trimIndent()
        assertTrue("注释/字符串里的关键字被误判", callsAt(stripCommentsAndStrings(code), token).isEmpty())
        val live = """
            class Sample {
                fun render() {
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 16.dp),
                    )
                }
            }
        """.trimIndent()
        assertTrue(
            "真实调用没被扫到，判据失效",
            callsAt(stripCommentsAndStrings(live), token).size == 1,
        )
    }

    // ── 以下判据工具与 SettingsButtonStyleGuardTest 同家法 ──

    private data class SourceCall(val line: Int, val arguments: String)

    /** 剥掉行注释、可嵌套块注释与字符串字面量（普通 + `"""` 原始串），保留换行防行号漂移。 */
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
            val quote = rawStringLength(text, i)
            if (quote > 0) {
                repeat(quote) { out.append(' ') }
                i += quote
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

    /** `i` 处若是字符串开头，返回整串长度（含引号）；否则 0。支持 `"""` 原始串。 */
    private fun rawStringLength(text: String, i: Int): Int {
        if (text.startsWith("\"\"\"", i)) {
            var j = i + 3
            while (j < text.length && !text.startsWith("\"\"\"", j)) j++
            return if (j >= text.length) text.length - i else j + 3 - i
        }
        if (i < text.length && text[i] == '"') {
            var j = i + 1
            while (j < text.length) {
                when {
                    text[j] == '\\' -> j += 2
                    text[j] == '\n' -> return j - i
                    text[j] == '"' -> return j + 1 - i
                    else -> j++
                }
            }
            return text.length - i
        }
        return 0
    }

    /** 取所有 `token` 调用（词边界排除前缀同名，如 `FooHorizontalDivider(`）。 */
    private fun callsAt(text: String, tok: String): List<SourceCall> {
        val result = mutableListOf<SourceCall>()
        var from = 0
        while (true) {
            val start = text.indexOf(tok, from)
            if (start < 0) break
            val prevOk = start == 0 || !(text[start - 1].isLetterOrDigit() || text[start - 1] == '_')
            if (!prevOk) {
                from = start + tok.length
                continue
            }
            val openParen = start + tok.length - 1
            val close = matching(text, openParen, '(', ')')
            if (close < 0) break
            result += SourceCall(
                line = text.take(start).count { it == '\n' } + 1,
                arguments = text.substring(openParen + 1, close),
            )
            from = close
        }
        return result
    }

    /** 配平取 [openIndex] 对应闭括号下标；找不到返回 -1。 */
    private fun matching(text: String, openIndex: Int, open: Char, close: Char): Int {
        var depth = 0
        var i = openIndex
        while (i < text.length) {
            when (text[i]) {
                open -> depth++
                close -> {
                    depth--
                    if (depth == 0) return i
                }
            }
            i++
        }
        return -1
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
        throw AssertionError("找不到仓库根（含 android/app/src 与 pubspec.yaml 的目录）")
    }
}
