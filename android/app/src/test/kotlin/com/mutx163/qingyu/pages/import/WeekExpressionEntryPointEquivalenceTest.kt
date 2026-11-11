package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.calendar.WeekExpressionException
import com.mutx163.qingyu.core.FormatException
import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import com.mutx163.qingyu.calendar.WeekExpressionParser as LanWeekExpressionParser

/**
 * 周次表达式**双入口一致性**（2026-11-11 审计 P1-9）。
 *
 * 同一串表达式有两条真实入口：
 * - 表格导入：`pages/import/SpreadsheetImportModel` 的 `WeekExpressionParser`（逐行解析单元格）；
 * - 局域网编辑：`calendar.WeekExpressionParser`（`applyWeekExpressionFields` → LAN 路由）。
 *
 * 修前两边各写一份实现，口径已经分岔：裸 token `3000000000` 在表格入口被收下、按学期周数
 * 钳制并出警告（**与发布版 Dart 的 64 位 int 一致**），在局域网入口却判 `week_token_unrecognized`。
 * 现在两边都转发到 `core.WeekExpressionParsing` 的唯一实现；本测试用同一批输入钉住
 * 「结果、警告、错误载荷」三样逐字一致，并守住「入口里不许再长出第二套解析规则」。
 */
class WeekExpressionEntryPointEquivalenceTest {

    private data class Outcome(
        val weeks: List<Int>,
        val warnings: List<String>,
        val error: String?,
    )

    /** 两条入口的共同结果形状：正常时记周次与警告，抛错时记载荷。 */
    private fun outcomeOf(parse: (MutableList<String>) -> List<Int>): Outcome {
        val warnings = mutableListOf<String>()
        return try {
            Outcome(weeks = parse(warnings), warnings = warnings.toList(), error = null)
        } catch (error: IllegalArgumentException) {
            Outcome(weeks = emptyList(), warnings = warnings.toList(), error = error.message)
        }
    }

    private fun spreadsheet(raw: String, weekCount: Int?): Outcome =
        outcomeOf { warnings ->
            WeekExpressionParser.parse(raw, itemName = ITEM, semesterWeekCount = weekCount, warnings = warnings)
        }

    private fun lan(raw: String, weekCount: Int?): Outcome =
        outcomeOf { warnings ->
            LanWeekExpressionParser.parse(raw, itemName = ITEM, semesterWeekCount = weekCount, warnings = warnings)
        }

    @Test
    fun `同一批表达式在两个入口得到完全相同的周次 警告与错误载荷`() {
        val inputs = listOf(
            // 正常形状
            "1-16", "1、3、5", "1,3、5", "2", "7单", "8双", "1-4单", "1-5双", "(单)1-4", "(双)1-5",
            "1-5、7-11(单)", "1-5、7-11(全部)", "1-2[3节]", "1-2【3节】", "14-15(全部)[01-02节]",
            " 1-2 、 10 ",
            // 需要钳制的
            "1-30", "25、26、27",
            // 超 Int 但仍在 Dart int64 内的裸 token（本次修复的核心分歧点）
            "3000000000", "2147483648",
            // 非法形状
            "0", "abc", "5-3", "1-31", "0-5", "-3-5", "2-99999999999", "99999999999999999999999",
            // 空
            "", "   ",
        )
        for (weekCount in listOf<Int?>(20, null)) {
            for (raw in inputs) {
                assertEquals(
                    "入口分歧：'$raw'（semesterWeekCount=$weekCount）",
                    spreadsheet(raw, weekCount),
                    lan(raw, weekCount),
                )
            }
        }
    }

    @Test
    fun `裸 token 3000000000 两个入口都收下并钳制 不出无法识别`() {
        // 发布版 Dart：int.tryParse('3000000000') 解得出来（64 位）→ 收下 → 超学期被钳掉。
        // 修前局域网入口用 toIntOrNull → null → week_token_unrecognized，是错的。
        val expectedWarnings = listOf(
            "weeks_exceed_semester_clamped|itemName=$ITEM|semesterWeekCount=20|weeks=3000000000",
        )
        for ((label, outcome) in listOf(
            "表格导入入口" to spreadsheet("3000000000", 20),
            "局域网编辑入口" to lan("3000000000", 20),
        )) {
            assertEquals("$label 不应报错", null, outcome.error)
            assertTrue("$label 的周次应被钳空", outcome.weeks.isEmpty())
            assertEquals("$label 的钳制警告不符", expectedWarnings, outcome.warnings)
        }
    }

    @Test
    fun `连 Long 都装不下的数字在两个入口都按范围过大报错 不抛 NumberFormatException`() {
        // 修前局域网入口对区间用 `.toInt()`：超出 Int 直接抛 NumberFormatException，
        // 不是本族任何类型 ⇒ 行级 catch(FormatException) 接不住、路由也只 catch
        // WeekExpressionException，会漏成 500 / 整表崩。
        val expected = "week_range_too_large|itemName=$ITEM"
        assertEquals(expected, spreadsheet("2-99999999999999999999999", 20).error)
        assertEquals(expected, lan("2-99999999999999999999999", 20).error)
    }

    @Test
    fun `局域网入口保留 WeekExpressionException 类型 路由的 400 分支才接得住`() {
        // LanEditApiRouter 只 catch WeekExpressionException（换类型会让非法表达式从 400 漏成 500）。
        val error = assertThrows(WeekExpressionException::class.java) {
            LanWeekExpressionParser.parse("abc", itemName = ITEM, semesterWeekCount = 20, warnings = null)
        }
        assertEquals("week_token_unrecognized|itemName=$ITEM|token=abc", error.message)

        // 表格入口的契约仍是 core.FormatException（行级 catch(FormatException) 依赖它）。
        val formatError = assertThrows(FormatException::class.java) {
            WeekExpressionParser.parse("abc", itemName = ITEM, semesterWeekCount = 20, warnings = null)
        }
        assertEquals("week_token_unrecognized|itemName=$ITEM|token=abc", formatError.message)
    }

    /**
     * 源码守卫：两个入口都必须转发到 core，且入口里不许再出现解析规则的名字。
     *
     * 防的是「下次又有人把 core 的实现抄回去改一处」——那正是本次分歧的成因。
     */
    @Test
    fun `两个入口必须转发到 core 唯一实现 不许再各写一份解析规则`() {
        // 剥注释再判：两处 KDoc 都在讲这次分岔（会提到 toLongOrNull / toIntOrNull），
        // 不剥注释的判据会被说明文字自己弄红。
        val lanSource = readKotlinSourceNormalized(
            "android/app/src/main/kotlin/com/mutx163/qingyu/calendar/WeekExpressionParser.kt",
        )
        val importSource = readKotlinSourceNormalized(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/import/SpreadsheetImportModel.kt",
        )
        assertTrue(
            "局域网入口必须转发 WeekExpressionParsing.parse(（唯一实现在 core）",
            lanSource.contains("WeekExpressionParsing.parse("),
        )
        assertTrue(
            "表格导入入口必须转发 WeekExpressionParsing.parse(（唯一实现在 core）",
            importSource.contains("WeekExpressionParsing.parse("),
        )
        // 解析规则的私有常量名：core 里才有，入口里出现即说明又抄了一份。
        val ruleMarkers = listOf("tokenSeparatorPattern", "TOKEN_SEPARATOR", "bracketSectionSuffixPattern", "rangePattern")
        for ((label, source) in listOf("局域网入口" to lanSource, "表格导入入口" to importSource)) {
            for (marker in ruleMarkers) {
                assertFalse(
                    "$label 里出现了 `$marker`：解析规则只许留在 core/WeekExpressionParsing.kt",
                    source.contains(marker),
                )
            }
        }
    }

    private companion object {
        const val ITEM = "周数"
    }
}
