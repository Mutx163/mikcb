package com.mutx163.qingyu.core

import java.time.LocalDateTime
import java.util.Locale

/**
 * TimetableSettings 的时间/周次核心子集（移植自 lib/models/timetable_settings.dart）。
 *
 * ## 移植边界（本族泳道裁定）
 *
 * Dart 侧 TimetableSettings 有 250+ 字段、依赖 settings/ 子目录约 30 个枚举与
 * 液态玻璃 / 壁纸 / 直播 / 更新镜像等模型（合计 4000+ 行），那些属于其他业务族。
 * 本族只移植**时间/周次核心消费的字段**：
 * - [sections]（节次表，位置下标契约的另一半）
 * - [activeTimeSchemeId]（默认作息路由）
 * - [semesterWeekCount]（周次钳制）
 * - [semesterStartDate]（课次日期锚定，双键读写）
 * - [classReminders]（单节课提醒数据源，统计「设过提醒」与课卡铃铛的唯一来源）
 *
 * toJson 只下发这五个键（键名与 Dart 逐字一致）；fromJson 对这五个键按 Dart
 * 口径解析，其余键忽略。**完整设置模型的合并/回写语义由设置族移植时补齐**——
 * 在那之前，Compose 侧不得用本类整体覆盖设置存档（会丢其余字段），只应按键读。
 */
data class TimetableSettings(
    val sections: List<SectionTime> = DEFAULT_SECTIONS,
    val activeTimeSchemeId: String? = null,
    val semesterWeekCount: Int = 20,
    val semesterStartDate: LocalDateTime? = null,
    /**
     * 单节课提醒（Dart `timetable_settings.dart:615` / `:1749`）。
     *
     * 按「课程 × 真实日期」记录是否设过提醒；条目格式与校验见 [ClassReminderEntry]。
     * 空表 = 真的没设过（不是「拿不到」）：数据源已接，统计与课卡都按它判。
     */
    val classReminders: List<ClassReminderEntry> = emptyList(),
) {

    fun toJson(): Map<String, Any?> = linkedMapOf(
        "sections" to sections.map { it.toJson() },
        "activeTimeSchemeId" to activeTimeSchemeId,
        "semesterWeekCount" to semesterWeekCount,
        // 开学日是**日历日期**不是时刻：文本键优先读（换时区不挪天），
        // 毫秒键继续写给旧版本与旧存档（timetable_settings.dart:1069-1075）。
        "semesterStartDate" to semesterStartDate?.let { DartTime.toEpochMillis(it) },
        "semesterStartDateText" to formatSemesterStartDateText(semesterStartDate),
        // 单节课提醒：条数少、结构固定，写侧与 Dart `timetable_settings.dart:1246` 同形。
        "classReminders" to classReminders.map { it.toJson() },
    )

    fun toJsonString(): String = MiniJson.encode(toJson())

    companion object {
        /** Dart `TimetableSettings.defaults()` 的节次表（timetable_settings.dart:945-960）。 */
        val DEFAULT_SECTIONS: List<SectionTime> = listOf(
            SectionTime("08:00", "08:45"),
            SectionTime("08:55", "09:40"),
            SectionTime("10:00", "10:45"),
            SectionTime("10:55", "11:40"),
            SectionTime("14:00", "14:45"),
            SectionTime("14:55", "15:40"),
            SectionTime("16:00", "16:45"),
            SectionTime("16:55", "17:40"),
            SectionTime("19:00", "19:45"),
            SectionTime("19:55", "20:40"),
        )

        fun defaults(): TimetableSettings = TimetableSettings()

        /**
         * Dart fromJson 的时间/周次核心键（timetable_settings.dart:1312-1395）：
         * - sections 空 → 整套回落内置模板；非空 → parseListAligned 按位补，
         *   **整表皆坏**（healedCount == size）才整套回落（timetable_settings.dart:1320-1333）；
         * - semesterWeekCount：lenientInt ?: 20，再 _atLeastOneWeek（<1 → 1）；
         * - semesterStartDate：文本键优先、畸形文本返回 null **不**回落毫秒；
         *   文本键缺失才回落毫秒（归一到本地零点）；
         * - classReminders：走 [ClassReminderEntry.listFromJson]，坏条目逐条丢弃。
         */
        fun fromJson(json: Map<String, Any?>): TimetableSettings {
            val rawSections = json["sections"] as? List<*> ?: emptyList<Any?>()
            val resolvedSections: List<SectionTime> = if (rawSections.isEmpty()) {
                DEFAULT_SECTIONS
            } else {
                val (parsed, healedCount) = SectionTime.parseListAligned(rawSections) { DEFAULT_SECTIONS }
                if (healedCount == parsed.size) DEFAULT_SECTIONS else parsed
            }
            return TimetableSettings(
                sections = resolvedSections,
                activeTimeSchemeId = LenientJson.string(json["activeTimeSchemeId"]),
                semesterWeekCount = atLeastOneWeek(LenientJson.int(json["semesterWeekCount"]) ?: 20),
                semesterStartDate = parseSemesterStartDate(
                    text = json["semesterStartDateText"],
                    millis = json["semesterStartDate"],
                ),
                // 坏条目逐条丢弃（Dart `ClassReminderEntry.listFromJson`），
                // 单条脏数据不许把整份设置打回默认。
                classReminders = ClassReminderEntry.listFromJson(json["classReminders"]),
            )
        }

        fun fromJsonString(text: String): TimetableSettings {
            val decoded = MiniJson.parse(text)
            if (decoded !is Map<*, *>) throw DartFormatException("settings json must be an object")
            @Suppress("UNCHECKED_CAST")
            return fromJson(decoded as Map<String, Any?>)
        }

        /** `_atLeastOneWeek`：学期周数下限 1（Dart timetable_settings.dart:1389）。 */
        private fun atLeastOneWeek(value: Long): Int = if (value < 1) 1 else value.toInt()

        /**
         * 开学日的文本（`yyyy-MM-dd`）形态（timetable_settings.dart:1004-1011）。
         */
        fun formatSemesterStartDateText(date: LocalDateTime?): String? {
            if (date == null) return null
            return String.format(Locale.ROOT, "%04d-%02d-%02d", date.year, date.monthValue, date.dayOfMonth)
        }

        /**
         * 读回开学日：**文本键优先**，毫秒只作为旧存档的回落
         * （timetable_settings.dart:1026-1059）。
         *
         * - 文本存在但畸形（含 2026-02-31 这类顺延日）→ 返回 null，**不**回落毫秒：
         *   两份键出自同一次写入，文本坏了说明这份存档不可信；
         * - 文本键缺失 → 毫秒回落，并把结果归一到**本地零点**（毫秒瞬时隐含写入方
         *   时区，换时区恢复会挪天 → 整学期周次 +1、单双周翻转的历史事故）；
         * - 都没有 → null。
         */
        fun parseSemesterStartDate(text: Any?, millis: Any?): LocalDateTime? {
            if (text is String) {
                val trimmed = text.trim()
                if (trimmed.isEmpty()) return null
                val m = Regex("""^(\d{4})-(\d{1,2})-(\d{1,2})$""").find(trimmed) ?: return null
                val year = m.groupValues[1].toInt()
                val month = m.groupValues[2].toInt()
                val day = m.groupValues[3].toInt()
                if (month < 1 || month > 12 || day < 1 || day > 31) return null
                // Dart DateTime(2026, 4, 31) 会顺延成 5 月 1 日；判「这天真的存在」
                // 要靠 round-trip（仓库口径）。
                val built = try {
                    LocalDateTime.of(year, month, day, 0, 0)
                } catch (_: Exception) {
                    return null
                }
                if (built.year != year || built.monthValue != month || built.dayOfMonth != day) {
                    return null
                }
                return built
            }
            val millisValue = LenientJson.int(millis) ?: return null
            // Dart: DateTime.fromMillisecondsSinceEpoch(ms) → 归一本地零点。
            val restored = DartTime.fromEpochMillis(millisValue)
            return LocalDateTime.of(restored.year, restored.monthValue, restored.dayOfMonth, 0, 0)
        }
    }
}
