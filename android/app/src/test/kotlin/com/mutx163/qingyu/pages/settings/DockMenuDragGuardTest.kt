package com.mutx163.qingyu.pages.settings

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

    @Test
    fun `拖动手势挂在整行卡片上而不是手柄小盒上`() {
        // 挂整行：复位后指针的 Down 事件应直接落在卡片修饰链上（padding+pointerInput+zIndex）。
        assertTrue(
            "手势必须挂在整行卡片的 Modifier 上，不是手柄小盒里——按住条目不动就是假承诺。",
            editorsSource.contains("detectDragGesturesAfterLongPress("),
        )
        assertTrue(
            "手势必须挂在整行卡片的 Modifier 上（.fillMaxWidth 链里出现 pointerInput）。",
            Regex(
                "fillMaxWidth\\(\\)[\\s\\S]*?pointerInput\\(index, itemCount\\)\\s*\\{",
            ).containsMatchIn(editorsSource),
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
