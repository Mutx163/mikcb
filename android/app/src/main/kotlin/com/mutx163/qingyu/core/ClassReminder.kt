package com.mutx163.qingyu.core

import java.time.LocalDate
import java.util.Locale

/**
 * 单节课提醒条目（移植 `lib/models/class_reminder.dart:1-114`）。
 *
 * 语义是「**某门课在某个真实日期的这一次课**」设过提醒，不是「每周这门课都提醒」：
 * 假期、单双周、调休都不会误响。条目随 `timetable_settings` JSON 的 `classReminders`
 * 键持久化（合并写，键名与 Dart 逐字一致），**不另造存储**。
 *
 * [date] 是 `yyyy-MM-dd` 文本而不是毫秒：与 Dart 同口径，跨时区读写不挪天。
 *
 * 非法条目（空课号 / 坏日期 / 分钟越界）在 [fromJson] 里返回 null，由
 * [listFromJson] 逐条丢弃——设置 JSON 可能来自旧版本或手改备份，单条坏值
 * 不许把整份设置打回默认。
 */
data class ClassReminderEntry(
    /** 所属课程 id；课程被删后条目自然失效（统计与卡片都按 id 匹配）。 */
    val courseId: String,
    /** 上课真实日期，格式 `yyyy-MM-dd`（[formatDate] 是唯一格式化入口）。 */
    val date: String,
    /** 提醒响点在该日内的分钟数（0..1439），不跨午夜。 */
    val minuteOfDay: Int,
) {

    /**
     * 统计 / 课卡共用的匹配键 `courseId|yyyy-MM-dd`（Dart `statistics_session_screen.dart:69-70`）。
     *
     * 与 [CourseSessionStatsCalculator] 的 `reminderKeys` 口径必须逐字一致。
     */
    val key: String get() = "$courseId|$date"

    /** 全局唯一身份（Dart `id`）；只用于日志与原生侧去重，不参与统计匹配。 */
    val id: String get() = "classreminder:$courseId@$date"

    /** 与 Dart `ClassReminderEntry.isValid` 同一判据。 */
    val isValid: Boolean
        get() = courseId.trim().isNotEmpty() &&
            isValidDate(date) &&
            minuteOfDay in MIN_MINUTE_OF_DAY..MAX_MINUTE_OF_DAY

    /** 落盘：三个短键，与 Dart `toJson` 顺序一致。 */
    fun toJson(): Map<String, Any?> = linkedMapOf(
        "courseId" to courseId,
        "date" to date,
        "minuteOfDay" to minuteOfDay,
    )

    companion object {

        const val MIN_MINUTE_OF_DAY = 0
        const val MAX_MINUTE_OF_DAY = 1439

        /**
         * 统一的 `yyyy-MM-dd` 格式化（Dart `ClassReminderEntry.formatDate`）：
         * UI、落盘与匹配键共用，避免各处手写漂移。
         */
        fun formatDate(date: LocalDate): String =
            String.format(Locale.ROOT, "%04d-%02d-%02d", date.year, date.monthValue, date.dayOfMonth)

        /**
         * 单条解析（Dart `fromJson`）：非 Map / 字段类型不对 / 条目非法 ⇒ null。
         *
         * 分钟数**只认 Number**（Dart `minuteOfDay is! num` 直接丢）——不学
         * `LenientJson.int` 的「字符串数字也收」，否则脏数据会被当成合法提醒。
         */
        fun fromJson(raw: Any?): ClassReminderEntry? {
            val map = raw as? Map<*, *> ?: return null
            val courseId = map["courseId"] as? String ?: return null
            val date = map["date"] as? String ?: return null
            val minuteOfDay = (map["minuteOfDay"] as? Number)?.toInt() ?: return null
            val entry = ClassReminderEntry(courseId = courseId, date = date, minuteOfDay = minuteOfDay)
            return if (entry.isValid) entry else null
        }

        /** 列表解析（Dart `listFromJson`）：非 List ⇒ 空表；坏条目逐条丢弃。 */
        fun listFromJson(raw: Any?): List<ClassReminderEntry> {
            val list = raw as? List<*> ?: return emptyList()
            return list.mapNotNull { fromJson(it) }
        }

        /**
         * Dart `_isValidDate`：必须是四位年 / 两位月 / 两位日，且那一天真实存在
         *（`2026-02-31` 这类顺延日按无效处理）。
         */
        fun isValidDate(value: String): Boolean {
            val match = DATE_PATTERN.matchEntire(value) ?: return false
            val year = match.groupValues[1].toInt()
            val month = match.groupValues[2].toInt()
            val day = match.groupValues[3].toInt()
            return runCatching { LocalDate.of(year, month, day) }.isSuccess
        }

        private val DATE_PATTERN = Regex("""^(\d{4})-(\d{2})-(\d{2})$""")
    }
}

/**
 * 单节课提醒列表的增删规则（移植 `lib/services/timetable_reminder_service.dart:42-85`）。
 *
 * 写入口（Flutter 侧 / 备份导入）负责落盘；本对象只管「列表怎么变」，
 * 因此可以在 JVM 单测里直接钉住，不碰存储也不碰 UI。
 */
object ClassReminderLogic {

    /**
     * 设置（或覆盖）一次提醒：**同课同日只保留一条**，再按「日期 → 分钟」排序。
     *
     * 与 Dart `setClassReminder` 同口径（`:43-61`）；排序保证设置页 / 导出顺序稳定。
     */
    fun upsert(
        entries: List<ClassReminderEntry>,
        entry: ClassReminderEntry,
    ): List<ClassReminderEntry> {
        val rest = entries.filterNot { it.courseId == entry.courseId && it.date == entry.date }
        return (rest + entry).sortedWith(compareBy({ it.date }, { it.minuteOfDay }))
    }

    /** 取消某课某天的提醒（Dart `removeClassReminder`，`:66-85`）：不存在时静默幂等。 */
    fun remove(
        entries: List<ClassReminderEntry>,
        courseId: String,
        date: String,
    ): List<ClassReminderEntry> =
        entries.filterNot { it.courseId == courseId && it.date == date }

    /** 统计与课卡共用的匹配键集合（格式见 [ClassReminderEntry.key]）。 */
    fun keysOf(entries: List<ClassReminderEntry>): Set<String> =
        entries.mapTo(LinkedHashSet()) { it.key }

}
