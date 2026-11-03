package com.mutx163.qingyu.calendar

/**
 * 周表达式解析（移植自 lib/services/week_expression_parser.dart 的纯函数部分）。
 *
 * 服务消息编码（Dart `encodeServiceMessage` 的本族子集）：`code` 或
 * `code|key=value|...`，错误/警告都以这个载荷形状离开本层，由上层 localize。
 *
 * 语法（与 Dart/WakeUp 习惯一致）：
 * - token 分隔符：半角逗号 `,`、全角逗号 `，`、顿号 `、`（Dart 正则 `[\uff0c,\u3001]`）；
 * - token 形态：`a-b` 区间、裸数字；
 * - token 级奇偶后缀：`7-11单` / `1-5双`；
 * - 全局括号模式：`(全部)` / `(单)` / `(双)`（全角/半角括号皆可），
 *   只对**单 token、token 无自身后缀**的表达式整体过滤；
 * - 节次方括号后缀 `[01-02节]` / `【01-02节】` 剥除；
 * - 空格在解析前剥除。
 */
object WeekExpressionParser {

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
     * 解析失败抛 [WeekExpressionException]（载荷 = Dart encodeServiceMessage 形状，
     * message 逐字对照 Dart 的 code 与 args 键名）；
     * 超出 [semesterWeekCount] 的周被钳掉并往 [warnings] 追加一条载荷。
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

        val result = linkedSetOf<Int>()
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
                val start = rangeMatch.groupValues[1].toInt()
                val end = rangeMatch.groupValues[2].toInt()
                if (start < 1) {
                    throw WeekExpressionException(
                        ServiceMessagePayload.encode(
                            "week_start_invalid",
                            mapOf("itemName" to itemName),
                        ),
                    )
                }
                if (start > end) {
                    throw WeekExpressionException(
                        ServiceMessagePayload.encode(
                            "week_range_invalid",
                            mapOf("itemName" to itemName),
                        ),
                    )
                }
                if (end > 30) {
                    throw WeekExpressionException(
                        ServiceMessagePayload.encode(
                            "week_range_too_large",
                            mapOf("itemName" to itemName),
                        ),
                    )
                }
                val weeks = (start..end).toList()
                result.addAll(applyParity(weeks, tokenParity))
                continue
            }

            val parsed = token.toIntOrNull()
            if (parsed == null || parsed < 1) {
                throw WeekExpressionException(
                    ServiceMessagePayload.encode(
                        "week_token_unrecognized",
                        mapOf("itemName" to itemName, "token" to token),
                    ),
                )
            }
            result.addAll(applyParity(listOf(parsed), tokenParity))
        }

        var weeks = result.sorted()
        // Global (单)/(双) only applies to a single token expression, so multi-range
        // strings like "1-5、7-11(单)" are not incorrectly filtered as a whole.
        val applyGlobalParity = modeMatch != null && !anyTokenParity && nonEmptyTokenCount <= 1
        if (applyGlobalParity && modeMatch == PARITY_ODD) {
            weeks = weeks.filter { it % 2 == 1 }
        } else if (applyGlobalParity && modeMatch == PARITY_EVEN) {
            weeks = weeks.filter { it % 2 == 0 }
        }

        return clampToSemesterWeekCount(
            weeks,
            semesterWeekCount = semesterWeekCount,
            itemName = itemName,
            warnings = warnings,
        )
    }

    /**
     * Dart `lan_edit_provider_host.dart:447-480 applyWeekExpressionFields`：
     * 在 slot JSON map 上应用 `weekExpression` / `suspendedWeekExpression`。
     *
     * - `weekExpression` 非空：剥键 → 解析 → 写 `customWeeks`（Long 列表，与
     *   Dart int 列表经 JSON 往返的形状一致）；非空结果再写
     *   `startWeek`/`endWeek`（首/末周）并把 `isOddWeek`/`isEvenWeek` 置 false；
     * - `suspendedWeekExpression` 非空：剥键 → 解析 → 写 `suspendedWeeks`
     *   （不碰 start/end/单双开关）；
     * - 两个输入键（`weekExpression` / `suspendedWeekExpression`）**总是先被 remove**；
     *   空白表达式只是不写任何派生字段（Dart: remove 后 isNotEmpty 为 false）。
     */
    fun applyWeekExpressionFields(
        slotMap: MutableMap<String, Any?>,
        courseName: String,
        semesterWeekCount: Int,
        warnings: MutableList<String>? = null,
    ) {
        val weekExpression = slotMap.remove("weekExpression")?.toString()?.trim() ?: ""
        if (weekExpression.isNotEmpty()) {
            val weeks = parse(
                weekExpression,
                itemName = courseName,
                semesterWeekCount = semesterWeekCount,
                warnings = warnings,
            )
            slotMap["customWeeks"] = weeks.map { it.toLong() }
            if (weeks.isNotEmpty()) {
                slotMap["startWeek"] = weeks.first().toLong()
                slotMap["endWeek"] = weeks.last().toLong()
            }
            slotMap["isOddWeek"] = false
            slotMap["isEvenWeek"] = false
        }
        val suspendedExpression = slotMap.remove("suspendedWeekExpression")?.toString()?.trim() ?: ""
        if (suspendedExpression.isNotEmpty()) {
            slotMap["suspendedWeeks"] = parse(
                suspendedExpression,
                itemName = "$courseName 停课周",
                semesterWeekCount = semesterWeekCount,
                warnings = warnings,
            ).map { it.toLong() }
        }
    }

    private fun clampToSemesterWeekCount(
        weeks: List<Int>,
        semesterWeekCount: Int?,
        itemName: String,
        warnings: MutableList<String>?,
    ): List<Int> {
        if (semesterWeekCount == null || semesterWeekCount < 1 || weeks.isEmpty()) {
            return weeks
        }
        val over = weeks.filter { it > semesterWeekCount }
        if (over.isEmpty()) {
            return weeks
        }
        warnings?.add(
            ServiceMessagePayload.encode(
                "weeks_exceed_semester_clamped",
                mapOf(
                    "itemName" to itemName,
                    "semesterWeekCount" to semesterWeekCount,
                    "weeks" to over.joinToString("、"),
                ),
            ),
        )
        return weeks.filter { it <= semesterWeekCount }
    }

    private fun applyParity(weeks: List<Int>, parity: String?): List<Int> = when (parity) {
        PARITY_ODD -> weeks.filter { it % 2 == 1 }
        PARITY_EVEN -> weeks.filter { it % 2 == 0 }
        else -> weeks
    }
}

/**
 * Dart `throw FormatException(encodeServiceMessage(...))` 的本族对应物：
 * message 就是 `code|key=value|...` 载荷。
 */
class WeekExpressionException(message: String) : IllegalArgumentException(message)

/** Dart encodeServiceMessage 的纯形状（与 core/TimeScheme.kt 的 ServiceMessage 同口径，本族自持）。 */
private object ServiceMessagePayload {
    private const val SEPARATOR = "|"

    fun encode(code: String, args: Map<String, Any?>): String {
        if (args.isEmpty()) return code
        val parts = mutableListOf(code)
        for ((k, v) in args) parts.add("$k=$v")
        return parts.joinToString(SEPARATOR)
    }
}
