package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 底栏/菜单编辑器拖动区**源码守卫**：长按整行拖动 + 抬升反馈 + 官方图标。
 *
 * 钉在 [DockMenuEditors] 上（源码级，如同 WarehouseLoadIssueRenderingGuardTest）：
 *
 * 1. 手势挂在**整行卡片**上（提示句「按住条目可排序」要求按下条目即拖，
 *    只挂在某个小图标上、图标以外的地方不动是假承诺）；
 * 2. 起拖触发官方触觉（拖动已进入时要有触感确认）；
 * 3. 抬lift有官方阴影与让位指示（阴影不能静默消失）；
 * 4. 行首**不再放拖动手柄图标**（Sort 与 MoveFile 都被用户否决），且行内保留 16dp 左缘；
 * 5. 提示句「按住条目可排序」必须排在「已启用」标题之前（先给规则再看图标）；
 * 6. 让位位移由父的 `dragTargetIndex` 算式驱动（other 行的 graphicsLayer 有消费）。
 */
class DockMenuDragGuardTest {

    private val editorsSource: String by lazy {
        stripKotlinComments(
            readComposeSource(
                "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/DockMenuEditors.kt",
            ),
        )
    }

    /**
     * 行区锚点：`DockSlotRow` 的**函数体**（到下一个 `private fun` 为止）。
     *
     * 2026-11-10 复核退回后收紧：原先第一条断言用跨文件的 `fillMaxWidth()[\s\S]*?pointerInput`
     * 非贪婪匹配，把手势挪回行内小盒的旧版也照样绿——判据不是锚在这行的卡片上，而是锚在
     * 「同一个文件里某处出现两个片段」。现在所有判据只在 [rowZone] 内取，且按卡片 / 行内
     * 两段切开（见 [rowCardZone] / [rowInnerZone]）。
     */
    private val rowZone: String by lazy {
        val start = editorsSource.indexOf("private fun DockSlotRow")
        assertTrue("找不到 DockSlotRow 函数——守卫按线索断言对不齐", start >= 0)
        val end = editorsSource.indexOf("private fun CandidateRow", start)
        editorsSource.substring(start, if (end < 0) editorsSource.length else end)
    }

    /** 卡片调用段：`QingyuCard(` 到行内容 `Row(` 之前（只含卡片自身的 modifier 链）。 */
    private val rowCardZone: String by lazy {
        val cardStart = rowZone.indexOf("QingyuCard(")
        assertTrue("DockSlotRow 里找不到卡片调用 `QingyuCard(`", cardStart >= 0)
        val rowStart = rowZone.indexOf("\n        Row(", cardStart)
        assertTrue("找不到卡片内的行内容 `Row(`——卡片/行内两段切不开，判据失效", rowStart > cardStart)
        rowZone.substring(cardStart, rowStart)
    }

    /** 行内段：卡片内容那层 `Row(` 到函数结尾（图标徽章、标题、移除按钮都在这段）。 */
    private val rowInnerZone: String by lazy {
        val cardZoneLength = rowCardZone.length + rowZone.indexOf("QingyuCard(")
        rowZone.substring(cardZoneLength)
    }

    @Test
    fun `拖动手势必须挂在整行卡片的修饰链上`() {
        // ① 手势只在卡片修饰链里（不是行内某个小盒 / 图标上）。
        assertTrue(
            "整行卡片的修饰链里没有 `pointerInput(index, itemCount)`——按住条目不能拖，假承诺。",
            "pointerInput(index, itemCount)" in rowCardZone,
        )
        assertTrue(
            "卡片修饰链里没有 `detectDragGesturesAfterLongPress(`——长按拖动不在整行上。",
            "detectDragGesturesAfterLongPress(" in rowCardZone,
        )
        // ② 行内子元素（图标徽章 / 标题 / 移除按钮）不许再挂拖动手势：
        //    旧版把 pointerInput 放手柄小盒里，按住别处不动，正是这次要钉死的东西。
        assertFalse(
            "行内子元素上又出现了 `pointerInput`——手势被挪回小盒/图标上，整行拖动失效。",
            "pointerInput" in rowInnerZone,
        )
        // ③ 整行只能有一处长按手势：多一处就有两套拖动状态互相打断。
        assertEquals(
            "DockSlotRow 里 `detectDragGesturesAfterLongPress(` 应恰好 1 处（整行卡片），实际为：",
            1,
            occurrences(rowZone, "detectDragGesturesAfterLongPress("),
        )
    }

    @Test
    fun `抬起阴影与让位指示必須 존재`() {
        assertTrue(
            "起拖必须有官方阴影（graphicsLayer 的 shadowElevation）。",
            "shadowElevation" in editorsSource,
        )
        assertTrue(
            "父层算出 dragTargetIndex 驱动让位（shiftPx 在修饰里服用）。",
            "dragTargetIndex" in editorsSource && "shiftPx" in editorsSource,
        )
    }

    @Test
    fun `起拖触发官方触觉反馈`() {
        assertTrue(
            "起拖必须有官方触觉确认（HapticFeedbackType.LongPress）。",
            "performHapticFeedback(HapticFeedbackType.LongPress)" in editorsSource,
        )
    }

    @Test
    fun `行首不再放拖动手柄图标，图标徽章保留 16dp 左缘`() {
        // 行区 = DockSlotRow 函数体（排除了 dockGlyph 图标映射表里的条目）。
        val rowStart = editorsSource.indexOf("private fun DockSlotRow")
        assertTrue("找不到 DockSlotRow 函数——守卫按线索断言对不齐", rowStart >= 0)
        val rowEnd = editorsSource.indexOf("private fun CandidateRow", rowStart)
        val rowZone = editorsSource.substring(rowStart, indexOfEnd(rowEnd))
        assertFalse(
            "行首手柄已删：MoveFile 被读成「方框 + 外指箭头」，与行尾红色移除同族。",
            "MiuixIcons.MoveFile" in rowZone,
        )
        assertFalse(
            "≡ 形的 Sort 仍不许出现（用户早前已否决）。",
            "MiuixIcons.Sort" in rowZone,
        )
        assertTrue(
            "删手柄后行内要补 16dp 左缘，图标徽章才落在 12+16=28dp 轴线上。",
            "padding(start = 16.dp)" in rowZone,
        )
    }

    @Test
    fun `提示句排在「已启用」标题之前`() {
        val hint = editorsSource.indexOf("item(key = \"editor.hint\")")
        val title = editorsSource.indexOf("item(key = \"editor.enabled.title\")")
        assertTrue("找不到提示句节点——守卫线索对不齐", hint >= 0)
        assertTrue("找不到「已启用」标题节点——守卫线索对不齐", title >= 0)
        assertTrue(
            "「按住条目可排序」必须先于列表出现，用户才知道能拖。",
            hint < title,
        )
    }

    private fun indexOfEnd(end: Int): Int = if (end < 0) editorsSource.length else end

    /** 数一个片段在给定区间里出现几次（不做正则，避免 `[\\s\\S]*?` 这类跨段匹配再次放水）。 */
    private fun occurrences(haystack: String, needle: String): Int {
        var count = 0
        var from = 0
        while (true) {
            val i = haystack.indexOf(needle, from)
            if (i < 0) return count
            count++
            from = i + 1
        }
    }

    /** 判据自检：剥注释后注释里的关键字不计。 */
    @Test
    fun `判据自检——注释里出现也不算`() {
        val sample = "// MiuixIcons.Sort 在这里提一句\nfun x() {}"
        assertFalse(stripKotlinComments(sample).contains("MiuixIcons.Sort"))
    }

    // ------------------------------------------------------------------ 工具

    private fun readComposeSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到源码 $relative（当前目录 ${File("").absolutePath}）")
    }

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
                    i += 2
                }
                ch == '/' && next == '*' -> {
                    inBlockComment = true
                    blockDepth = 1
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
}
