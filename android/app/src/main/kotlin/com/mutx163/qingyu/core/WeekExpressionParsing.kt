package com.mutx163.qingyu.core

/**
 * 周表达式解析的**唯一实现**（移植 `lib/services/week_expression_parser.dart`）。
 *
 * ## 为什么放在 core
 *
 * 同一个语法有两个入口：表格导入（`pages/import`，`SpreadsheetImportModel` 行解析）与
 * 局域网编辑（`transfer/lan` → `calendar.WeekExpressionParser.applyWeekExpressionFields`）。
 * 两处曾各写一份，**口径已经分了岔**：局域网那份用 `toIntOrNull` 解析裸 token，
 * 输入 `3000000000` 直接判「无法识别」；表格那份用 `toLongOrNull` 收下再由学期周数钳掉。
 * 发布版 Dart 的 `int` 是 64 位，`int.tryParse('3000000000')` 解得出来 ⇒ 表格那份是对的，
 * 局域网那份是错的。所以把实现提到 core 只留一份，两个入口都只做转发（口径再分岔就是守卫失守）。
 *
 * ## 语法（与 Dart / WakeUp 习惯一致）
 *
 * - token 分隔符：半角逗号 `,`、全角逗号 `，`、顿号 `、`（Dart 正则 `[，,、]`）；
 * - token 形态：`a-b` 区间、裸数字；
 * - token 级奇偶后缀：`7-11单` / `1-5双`；
 * - 全局括号模式：`(全部)` / `(单)` / `(双)`（全角/半角括号皆可），
 *   只对**单 token、且 token 无自身后缀**的表达式整体过滤；
 * - 节次方括号后缀 `[01-02节]` / `【01-02节】` 剥除；空格在解析前剥除。
 *
 * ## 数值口径（对齐 Dart 64 位 int）
 *
 * 周次一律按 `Long` 累积：`3000000000` 这类「能解析但远大于学期周数」的裸 token 要收下、
 * 由 [semesterWeekCount] 钳掉并写警告，**不是** `week_token_unrecognized`。
 * 连 Long 都装不下的数字必然远大于 30 周，按同一族 `week_range_too_large` 报错——不抛
 * `NumberFormatException`，否则行级只有 `catch (FormatException)` 的调用方会整表崩。
 * 返回 `List<Int>`：钳制走完后的周次都不超过学期周数；**没有**学期周数可钳时，
 * 超出 Int 表示范围的值只能丢弃（`List<Int>` 契约放不下，Dart 侧会原样带出）。
 *
 * ## 错误与警告的载荷
 *
 * 抛 [FormatException]，message = `code|k=v|...`（service message 载荷，由上层 localize）：
 * `week_start_invalid` / `week_range_invalid` / `week_range_too_large` / `week_token_unrecognized`。
 * 超学期周数不抛错，写 [warnings] 一条 `weeks_exceed_semester_clamped`。
 */
object WeekExpressionParsing {

    // Dart 正则逐条对照：
    // _bracketSectionSuffixPattern: \[[^\]]*节\]
    // _fullWidthBracketSectionSuffixPattern: 【[^】]*节】
    // _parityModePattern: [（(](全部|单|双)[)）]
    // _parentheticalPattern: [（(][^)）]*[)）]
    // _tokenSeparatorPattern: [，,、]
    private val bracketSectionSuffixPattern = Regex("""\[[^\]]*节]""")
    private val fullWidthBracketSectionSuffixPattern = Regex("""【[^】]*节】""")
    private val parityModePattern = Regex("""[（(](全部|单|双)[)）]""")
    private val parentheticalPattern = Regex("""[（(][^)）]*[)）]""")
    private val tokenSeparatorPattern = Regex("""[，,、]""")
    private val rangePattern = Regex("""^(\d+)-(\d+)$""")

    private const val PARITY_ODD = "单"
    private const val PARITY_EVEN = "双"

    /**
     * Dart `WeekExpressionParser.parse`。
     *
     * @param raw 用户输入（文件单元格或局域网编辑请求里的字符串）
     * @param itemName 出错/警告载荷里的定位名（「第 2 行周数」/「数据结构 停课周」）
     * @param semesterWeekCount 学期周数；`null`/`<= 0` = 不钳制
     * @param warnings 钳制警告的收集处；`null` = 丢弃警告
     */
    fun parse(
        raw: String,
        itemName: String,
        semesterWeekCount: Int? = null,
        warnings: MutableList<String>? = null,
    ): List<Int> {
        var normalized = raw.trim()
        if (normalized.isEmpty()) {
            return emptyList()
        }

        normalized = normalized
            .replace(" ", "")
            .replace(bracketSectionSuffixPattern, "")
            .replace(fullWidthBracketSectionSuffixPattern, "")

        val modeMatch = parityModePattern.find(normalized)?.groupValues?.get(1)
        normalized = normalized.replace(parentheticalPattern, "")

        val result = sortedSetOf<Long>()
        val parts = tokenSeparatorPattern.split(normalized)
        var nonEmptyTokenCount = 0
        var anyTokenParity = false
        for (part in parts) {
            var token = part.trim()
            if (token.isEmpty()) {
                continue
            }
            nonEmptyTokenCount += 1

            var tokenParity: String? = null
            if (token.endsWith(PARITY_ODD)) {
                tokenParity = PARITY_ODD
                token = token.substring(0, token.length - 1)
                anyTokenParity = true
            } else if (token.endsWith(PARITY_EVEN)) {
                tokenParity = PARITY_EVEN
                token = token.substring(0, token.length - 1)
                anyTokenParity = true
            }

            val rangeMatch = rangePattern.find(token)
            if (rangeMatch != null) {
                val start = rangeMatch.groupValues[1].toLongOrNull()
                val end = rangeMatch.groupValues[2].toLongOrNull()
                if (start == null || end == null) {
                    throw FormatException(
                        ServiceMessage.encode("week_range_too_large", mapOf("itemName" to itemName)),
                    )
                }
                if (start < 1) {
                    throw FormatException(
                        ServiceMessage.encode("week_start_invalid", mapOf("itemName" to itemName)),
                    )
                }
                if (start > end) {
                    throw FormatException(
                        ServiceMessage.encode("week_range_invalid", mapOf("itemName" to itemName)),
                    )
                }
                if (end > 30) {
                    throw FormatException(
                        ServiceMessage.encode("week_range_too_large", mapOf("itemName" to itemName)),
                    )
                }
                result.addAll(applyParity((start..end).toList(), tokenParity))
                continue
            }

            val parsed = token.toLongOrNull()
            if (parsed == null || parsed < 1) {
                throw FormatException(
                    ServiceMessage.encode(
                        "week_token_unrecognized",
                        mapOf("itemName" to itemName, "token" to token),
                    ),
                )
            }
            result.addAll(applyParity(listOf(parsed), tokenParity))
        }

        var weeks = result.toList()
        // 全局（单）/（双）只作用于单 token、且 token 自身没有后缀的表达式：
        // `1-5、7-11(单)` 这种多区间不能被整体过滤。
        val applyGlobalParity = modeMatch != null && !anyTokenParity && nonEmptyTokenCount <= 1
        if (applyGlobalParity && modeMatch == PARITY_ODD) {
            weeks = weeks.filter { it % 2 != 0L }
        } else if (applyGlobalParity && modeMatch == PARITY_EVEN) {
            weeks = weeks.filter { it % 2 == 0L }
        }

        return clampToSemesterWeekCount(
            weeks = weeks,
            semesterWeekCount = semesterWeekCount,
            itemName = itemName,
            warnings = warnings,
        )
    }

    private fun clampToSemesterWeekCount(
        weeks: List<Long>,
        semesterWeekCount: Int?,
        itemName: String,
        warnings: MutableList<String>?,
    ): List<Int> {
        if (semesterWeekCount == null || semesterWeekCount < 1 || weeks.isEmpty()) {
            // 没有学期周数可钳时，超出 Int 表示范围的周（只可能来自天文数字裸 token）
            // 在 List<Int> 契约里放不下，丢弃；Dart 的 int 是 64 位会原样带出。
            return weeks.filter { it <= Int.MAX_VALUE }.map { it.toInt() }
        }
        val over = weeks.filter { it > semesterWeekCount }
        if (over.isEmpty()) {
            return weeks.map { it.toInt() }
        }
        warnings?.add(
            ServiceMessage.encode(
                "weeks_exceed_semester_clamped",
                mapOf(
                    "itemName" to itemName,
                    "semesterWeekCount" to semesterWeekCount,
                    "weeks" to over.joinToString("、"),
                ),
            ),
        )
        return weeks.filter { it <= semesterWeekCount }.map { it.toInt() }
    }

    private fun applyParity(weeks: List<Long>, parity: String?): List<Long> = when (parity) {
        PARITY_ODD -> weeks.filter { it % 2 != 0L }
        PARITY_EVEN -> weeks.filter { it % 2 == 0L }
        else -> weeks
    }
}
