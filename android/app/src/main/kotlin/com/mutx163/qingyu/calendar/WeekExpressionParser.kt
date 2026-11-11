package com.mutx163.qingyu.calendar

import com.mutx163.qingyu.core.FormatException
import com.mutx163.qingyu.core.WeekExpressionParsing

/**
 * 周表达式解析的**局域网编辑入口**。
 *
 * 实现在 [WeekExpressionParsing]（core，全仓唯一一份；对齐 Dart 64 位 int 口径）。
 * 本对象只保留本包的对外契约：抛 [WeekExpressionException]（本包调用方按它 catch，
 * 见 `LanEditApiRouter` 的 400 分支），其余行为逐字转发。
 *
 * ## 2026-11-11 审计 P1-9（双入口分歧）
 *
 * 这里原先是第二份实现，裸 token 用 `toIntOrNull`：输入 `3000000000` 判
 * `week_token_unrecognized`；同一串走表格导入（`toLongOrNull`）却收下、按学期周数钳掉。
 * 发布版 Dart 的 `int` 是 64 位，`int.tryParse('3000000000')` 解得出来 ⇒ **表格那边是对的**。
 * 现在两个入口共用 core 的实现，口径不会再分岔；
 * `WeekExpressionEntryPointEquivalenceTest` 用同一批输入钉住两边结果一致。
 */
object WeekExpressionParser {

    /**
     * Dart `WeekExpressionParser.parse`（错误载荷 = `code|k=v|...`，由上层 localize）。
     *
     * 超出 [semesterWeekCount] 的周被钳掉并往 [warnings] 追加一条载荷。
     */
    fun parse(
        raw: String,
        itemName: String,
        semesterWeekCount: Int? = null,
        warnings: MutableList<String>? = null,
    ): List<Int> = try {
        WeekExpressionParsing.parse(
            raw = raw,
            itemName = itemName,
            semesterWeekCount = semesterWeekCount,
            warnings = warnings,
        )
    } catch (error: FormatException) {
        // 载荷原文逐字透传，只换异常类型（本包的 catch 只认 WeekExpressionException）。
        throw WeekExpressionException(error.message ?: "")
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
}

/**
 * Dart `throw FormatException(encodeServiceMessage(...))` 在本包的对外类型：
 * message 就是 `code|key=value|...` 载荷。
 *
 * 保留它而不是直接抛 `core.FormatException`：局域网编辑路由只 catch 这个类型，
 * 换类型会让非法表达式从 400 漏成 500。
 */
class WeekExpressionException(message: String) : IllegalArgumentException(message)
