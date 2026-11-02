package com.mutx163.qingyu.pages.course

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 加课「自定义周」网格**每格必须占权重**守卫（2026-11-02 建立）。
 *
 * ## 它防的是哪一类事故
 *
 * `AddCourseWeekGridTile` 内部的 Box 是 `fillMaxWidth()`。把它放进 `Row` 却**不给 weight**
 * 时，第一格会先吃掉整行宽度，后四格被压成 0 宽——用户只能点到每行第 1 周，而代码不报错、
 * 单测也全绿，只有真机盯屏才看得出（审核报告 2026-11-02 的 P0）。
 *
 * 现有测试设施（JUnit + compose runtime，无 compose-ui-test / Robolectric）跑不了真实布局，
 * 所以这里沿用仓库已有的源码文本守卫做法（`ComposeSheetGuardTest` / `PickupCodesPageGuardTest`
 * 同一套路）：按括号配平取出每个 `AddCourseWeekGridTile(...)` 的实参，要求带 `Modifier.weight`。
 *
 * **代价写清**：文本判据对格式敏感。真把调用改成别的写法时这条会先红——那是**故意的**，
 * 提醒改接线的人同时更新判据，而不是静默失效。
 */
class WeekGridWeightGuardTest {

    private val pageSource: String by lazy { readAndroidSource(PAGE_PATH) }

    @Test
    fun `周网格每格必须传 Modifier weight`() {
        val calls = gridTileCalls(pageSource)
        assertTrue(
            "一个 AddCourseWeekGridTile( 调用都没扫到，判据已失效（门禁空跑会假绿）。" +
                "user.dir=${System.getProperty("user.dir")}",
            calls.isNotEmpty(),
        )

        val missing = calls.filterNot { (_, args) -> WEIGHT_ARGUMENT.containsMatchIn(args) }
        assertTrue(
            "AddCourseWeekGridTile 在 Row 里必须传 Modifier.weight(1f)，" +
                "否则 fillMaxWidth 会吃掉整行，后 4 格宽度为 0：\n" +
                missing.joinToString("\n") { (line, _) -> "    第 $line 行的调用没有 weight" },
            missing.isEmpty(),
        )
    }

    // ------------------------------------------------------------------
    // 判据
    // ------------------------------------------------------------------

    /** 按括号配平取出所有调用：`行号 to 实参文本`。 */
    private fun gridTileCalls(text: String): List<Pair<Int, String>> {
        val hits = mutableListOf<Pair<Int, String>>()
        var from = 0
        while (true) {
            val start = text.indexOf(TILE_CALL, from)
            if (start < 0) break
            // 卡词边界：避免把 `FakeAddCourseWeekGridTile(` 之类当成真调用。
            if (start > 0 && (text[start - 1].isLetterOrDigit() || text[start - 1] == '_')) {
                from = start + TILE_CALL.length
                continue
            }
            val openParen = start + TILE_CALL.length - 1
            val close = matchingParen(text, openParen)
            if (close < 0) break
            val line = text.take(start).count { it == '\n' } + 1
            hits += line to text.substring(openParen + 1, close)
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

    private fun readAndroidSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir.parentFile
        }
        // 找不到就失败，不静默跳过——跳过等于守卫不存在。
        throw AssertionError("找不到 $relative —— 守卫无法验证，按失败处理")
    }

    private companion object {
        const val TILE_CALL = "AddCourseWeekGridTile("

        /**
         * 实参里出现了 `modifier = Modifier...weight(`。
         * 不写正则 `[^)]*`：`Modifier.weight(1f)` 自身带括号，硬抠会在第一个右括号处断掉。
         */
        val WEIGHT_ARGUMENT = Regex("""\bmodifier\s*=\s*Modifier\b[\s\S]*?\.weight\s*\(""")

        const val PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/course/AddCoursePage.kt"
    }
}
