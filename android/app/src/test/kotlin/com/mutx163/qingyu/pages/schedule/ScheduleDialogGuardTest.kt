package com.mutx163.qingyu.pages.schedule

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 日程族弹窗 / 按钮守卫（2026-11-02 建立）。
 *
 * ## 防的是什么
 *
 * 审核报告 P1 抓到两件事：
 *
 * 1. 四个「确认 / 编辑」框其实是裸 `QingyuCard` 直接画在页面里——没有遮罩、点外部不关、
 *    返回键会退掉整页（编辑页还会丢未保存内容）。它们必须是官方 `OverlayDialog`。
 * 2. 三个页面各抄了一份 `private fun MiuixActionButton`，正文写死
 *    `color = MiuixTheme.colorScheme.onPrimary`（白），而 `Button` 默认是浅灰底
 *    ⇒ 白字落灰底，几乎看不见。现在统一走共享 `ScheduleActionButton`，
 *    颜色交给按钮配色的 `contentColor`。
 *
 * 这是源码文本守卫：编译能过、单测也能过，只有真机盯屏才看得出「不可读」，
 * 所以把可判的形态钉死。文本判据对格式敏感，只钉「必须/不得出现的最小集合」。
 *
 * ⚠️ 范围只限日程族这四个文件（多 Agent 并行，别把别人在途的代码记到本守卫头上）。
 * 文件改名/移动后必须同步更新本守卫——`扫描器必须真的扫到…` 会先红，避免空跑假绿。
 */
class ScheduleDialogGuardTest {

    // ───────────────────────── 0. 守卫自己不能空跑 ─────────────────────────

    @Test
    fun `扫描器必须真的扫到三个页面与共享按钮`() {
        val sources = GUARDED_FILES.associateWith { path ->
            val file = File(repoRoot(), path)
            assertTrue(
                "守卫目标文件不存在：${file.absolutePath}（user.dir=${System.getProperty("user.dir")}）。" +
                    "文件改名/移动后必须同步更新本守卫，否则它会空跑假绿。",
                file.isFile,
            )
            file.readText()
        }
        assertTrue(
            "三个页面里扫到的 ScheduleActionButton 调用少于 3 处，判据已失效",
            sources.filterKeys { it != SHARED_BUTTON }
                .values.sumOf { it.windowed(SHARED_CALL.length) { w -> w }.count { it == SHARED_CALL } } >= 3,
        )
        assertTrue(
            "共享按钮文件里没有 ButtonDefaults 配色，判据已失效",
            sources.getValue(SHARED_BUTTON).contains("ButtonDefaults."),
        )
    }

    // ───────────────────────── 1. 白字落灰底不许回来 ─────────────────────────

    @Test
    fun `三个页面不再出现写死 onPrimary 的旧按钮`() {
        val offenders = mutableListOf<String>()
        for (path in PAGE_FILES) {
            val text = File(repoRoot(), path).readText()
            if (text.contains(LEGACY_WHITE_TEXT)) {
                offenders += path.replace('\\', '/')
            }
        }
        assertTrue(
            "旧写法 `color = MiuixTheme.colorScheme.onPrimary` 出现在日程页面里：\n" +
                offenders.joinToString("\n") { "    $it" } +
                "\n\n按钮文字颜色应交给 Button 的 contentColor；" +
                "请改用共享 `ScheduleActionButton`（primary / destructive / 默认三种变体）。",
            offenders.isEmpty(),
        )
    }

    @Test
    fun `三个页面都不再自带私有 MiuixActionButton`() {
        val offenders = PAGE_FILES.filter { path ->
            File(repoRoot(), path).readText().contains("private fun MiuixActionButton")
        }
        assertTrue(
            "以下页面还留着私有 MiuixActionButton 副本（应改用共享 ScheduleActionButton）：\n" +
                offenders.joinToString("\n") { "    ${it.replace('\\', '/')}" },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `共享按钮不把颜色写在文字上`() {
        val text = File(repoRoot(), SHARED_BUTTON).readText()
        // 允许 `color = MiuixTheme.colorScheme.error`（这是按钮**底色**），
        // 只禁按钮正文 `Text(...)` 里写 color——那会盖掉 Button 的 contentColor。
        val textCallStart = text.indexOf("Text(")
        val textCall = if (textCallStart >= 0) {
            val close = matchingParen(text, textCallStart + "Text".length)
            if (close > 0) text.substring(textCallStart, close + 1) else ""
        } else {
            ""
        }
        assertTrue(
            "ScheduleActionButton 里找不到 Text(...) 正文，判据已失效",
            textCall.isNotBlank(),
        )
        assertFalse(
            "ScheduleActionButton 的按钮正文又写死了颜色；" +
                "Button 会用配色的 contentColor 自动着色，写死会再次出现白字落灰底。",
            textCall.contains("color ="),
        )
        assertTrue(
            "共享按钮缺少 primary 变体（ButtonDefaults.buttonColorsPrimary()）",
            text.contains("ButtonDefaults.buttonColorsPrimary()"),
        )
        assertTrue(
            "共享按钮缺少 destructive 变体（colorScheme.error + onError）",
            text.contains("MiuixTheme.colorScheme.error") &&
                text.contains("MiuixTheme.colorScheme.onError"),
        )
    }

    // ───────────────────────── 2. 四个弹窗必须是官方 OverlayDialog ─────────────────────────

    @Test
    fun `四个确认编辑弹窗都走 OverlayDialog 且横向留白 16dp`() {
        val expectedDialogCount = mapOf(
            SCHEDULE_LIST to 1, // 删除确认
            RULE_PAGE to 2, // 规则编辑 + 规则删除确认
            // 2 = 重复日程「本次 / 全部」范围框 + 一次性删除确认
            //     （2026-11-05 补齐：发布版 `_confirmDelete` 会先问一句，此前是直接删）。
            ADD_SCHEDULE to 2,
        )
        val offenders = mutableListOf<String>()
        for ((path, expected) in expectedDialogCount) {
            val text = File(repoRoot(), path).readText()
            val dialogs = text.windowed(OVERLAY_CALL.length) { it }.count { it == OVERLAY_CALL } +
                text.windowed("OverlayDialog {".length) { it }.count { it == "OverlayDialog {" }
            if (dialogs != expected) {
                offenders += "${path.replace('\\', '/')}：OverlayDialog $dialogs 处，期望 $expected 处"
            }
            val insets = text.windowed(INSIDE_MARGIN.length) { it }.count { it == INSIDE_MARGIN }
            if (insets < expected) {
                offenders += "${path.replace('\\', '/')}：insideMargin = DpSize(16.dp, 16.dp) $insets 处，期望 $expected 处"
            }
        }
        assertTrue(
            "日程族四个确认/编辑弹窗必须都是官方 OverlayDialog（show 驱动 + 16dp 横向留白）：\n" +
                offenders.joinToString("\n") { "    $it" },
            offenders.isEmpty(),
        )
    }

    @Test
    fun `旧的裸卡删除确认函数已经删除`() {
        val text = File(repoRoot(), SCHEDULE_LIST).readText()
        assertFalse(
            "ScheduleListPage 还留着 ConfirmDeleteDialog（裸 QingyuCard 弹层），应改由 OverlayDialog 承载",
            text.contains("ConfirmDeleteDialog"),
        )
    }

    // ───────────────────────── 3. 规则编辑框必须可滚 ─────────────────────────

    @Test
    fun `规则编辑框用官方 LazyColumn 滚动而不是 Column 加 verticalScroll`() {
        val text = File(repoRoot(), RULE_PAGE).readText()
        assertTrue(
            "规则编辑框缺少 LazyColumn（字段多，矮屏/键盘下必须能滚）",
            text.contains("LazyColumn("),
        )
        assertTrue(
            "规则编辑框缺少 scrollEndHaptic()（官方滚动三件套之一）",
            text.contains("scrollEndHaptic()"),
        )
        assertTrue(
            "规则编辑框缺少 overScrollVertical()（官方过度滚动）",
            text.contains("overScrollVertical()"),
        )
        assertFalse(
            "规则编辑框又用 Column + verticalScroll 当滚动容器（R2 守卫判红、且非惰性）",
            text.contains("verticalScroll(rememberScrollState())"),
        )
    }

    @Test
    fun `规则编辑框的动作行留在滚动区外`() {
        val text = File(repoRoot(), RULE_PAGE).readText()
        val editor = text.substringAfter("private fun RuleEditorDialog(", missingDelimiterValue = "")
        assertTrue(
            "RuleEditorDialog 内容为空或函数被改名，守卫会空跑",
            editor.isNotBlank(),
        )
        // 动作行（取消 / 保存）必须出现在 LazyColumn 的花括号之外。
        val lazyClose = editor.indexOf("\n                }")
        assertTrue(
            "RuleEditorDialog 里找不到 LazyColumn 的结束位置，判据已失效",
            lazyClose > 0,
        )
        val afterScroll = editor.substring(lazyClose)
        assertTrue(
            "RuleEditorDialog 的「取消 / 保存」动作行必须放在滚动区外，否则矮屏上会被表单顶出屏幕",
            afterScroll.contains("ScheduleActionButton(") &&
                afterScroll.contains("TextButton("),
        )
    }

    // ------------------------------------------------------------------
    // 判据
    // ------------------------------------------------------------------

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
        const val SCHEDULE_LIST =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/ScheduleListPage.kt"
        const val RULE_PAGE =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/ScheduleDateRulePage.kt"
        const val ADD_SCHEDULE =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/AddScheduleItemPage.kt"
        const val SHARED_BUTTON =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/ScheduleActionButton.kt"

        val PAGE_FILES = listOf(SCHEDULE_LIST, RULE_PAGE, ADD_SCHEDULE)
        val GUARDED_FILES = PAGE_FILES + SHARED_BUTTON

        const val LEGACY_WHITE_TEXT = "color = MiuixTheme.colorScheme.onPrimary"
        const val SHARED_CALL = "ScheduleActionButton("
        const val OVERLAY_CALL = "OverlayDialog("
        const val INSIDE_MARGIN = "insideMargin = DpSize(16.dp, 16.dp)"
    }
}
