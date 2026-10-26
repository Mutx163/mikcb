package com.mutx163.qingyu.core

/**
 * 解析失败信号：与 Dart `FormatException` 同名同义（course.dart 的
 * fromJson 必填缺失抛它，坏条目留档机制靠这个异常类型接住）。
 * Kotlin 标准库没有同名类，移植层自定义；消息文案与 Dart 逐字一致，
 * 供两侧日志对拍。
 */
class FormatException(message: String) : IllegalArgumentException(message)

/**
 * 课程模型（Compose 迁移 Phase 2 · 族 1）。
 *
 * 移植自 lib/models/course.dart（2026-10-26 快照，630 行）。
 * **序列化契约**：toJson/fromJson 的键名与解析行为与 Dart 逐字逐行等价——
 * Compose 版读写 flutter.timetable_profiles 时两侧共用同一份 JSON，
 * 键名或语义漂移 = 数据丢失（契约见 docs/plans/2026-10-26-data-contract.md）。
 *
 * Dart 端的注释里钉着历史决策（必填/可选分类、坏数据钳制口径），全部保留：
 * - 必填字段缺失 → 抛 FormatException（让 Dart 侧「坏条目留档」机制能接住）；
 *   类型不对但有值 → toString 收下。
 * - 可选字段缺失/类型不对 → 默认值收下。
 * - bool 字段**不接受**字符串 "true"/"false"（按缺省 false，不替用户猜真值）。
 */
enum class CourseNature(val value: String) {
    REQUIRED("required"),
    ELECTIVE("elective");

    companion object {
        /** 与 Dart CourseNatureX.fromValue 同口径：未知值回落 required。 */
        fun fromValue(value: String?): CourseNature =
            entries.firstOrNull { it.value == value } ?: REQUIRED
    }
}

/** 单周课程备注（course.dart:20-69）。 */
data class CourseSessionNote(
    val text: String = "",
    val hasHomework: Boolean = false,
) {
    val isEmpty: Boolean get() = text.trim().isEmpty() && !hasHomework
    val isNotEmpty: Boolean get() = !isEmpty
    val trimmedText: String get() = text.trim()

    val normalizedOrNull: CourseSessionNote?
        get() = if (trimmedText.isEmpty() && !hasHomework) {
            null
        } else {
            copy(text = trimmedText)
        }

    companion object {
        fun fromJson(json: Map<String, Any?>): CourseSessionNote = CourseSessionNote(
            text = json["text"] as? String ?: "",
            hasHomework = json["hasHomework"] as? Boolean ?: false,
        )
    }
}

data class Course(
    val id: String,
    val name: String,
    val shortName: String? = null,
    val teacher: String,
    val location: String,
    /** 1-7，周一到周日。 */
    val dayOfWeek: Int,
    val startSection: Int,
    val endSection: Int,
    /** 格式 HH:mm。 */
    val startTime: String,
    val endTime: String,
    val color: String = "#2196F3",
    /** 课程卡片文字颜色（hex），null = 跟随全局设置。 */
    val textColor: String? = null,
    val startWeek: Int = 1,
    val endWeek: Int = 16,
    val isOddWeek: Boolean = false,
    val isEvenWeek: Boolean = false,
    val customWeeks: List<Int>? = null,
    val suspendedWeeks: List<Int>? = null,
    val courseNature: CourseNature = CourseNature.REQUIRED,
    /** 课程简介（同名课程共享）。 */
    val description: String? = null,
    /** legacy 单条自由文本；导入/兼容保留，UI 不再写新值。 */
    val note: String? = null,
    /** 按教学周（1-based）的单周备注。 */
    val sessionNotes: Map<Int, CourseSessionNote>? = null,
    /** 课程级时间模板覆盖。 */
    val timeSchemeIdOverride: String? = null,
    val hasCustomTime: Boolean = false,
) {

    // ------------------------------------------------------------------
    // 派生 getter（course.dart:109-115, 505-629）
    // ------------------------------------------------------------------

    /**
     * 超级岛/提醒通知「备注」行实际下发的取值：旧 [note] 优先，其次回落共享
     * [description]。原生端快照只认 `note` 键，两侧必须同步这条回落规则。
     */
    val liveNote: String?
        get() {
            note?.let { if (it.trim().isNotEmpty()) return it }
            description?.let { if (it.trim().isNotEmpty()) return it }
            return null
        }

    val sectionCount: Int get() = endSection - startSection + 1

    val normalizedSessionNotesMap: Map<Int, CourseSessionNote>?
        get() = normalizeSessionNotes(sessionNotes)

    fun sessionNoteForWeek(week: Int): CourseSessionNote? =
        normalizedSessionNotesMap?.get(week)

    fun hasHomeworkInWeek(week: Int): Boolean =
        sessionNoteForWeek(week)?.hasHomework == true

    fun hasSessionNoteInWeek(week: Int): Boolean = sessionNoteForWeek(week) != null

    /** 返回按 [week] upsert/移除后的新备注表（course.dart:522-535）。 */
    fun withSessionNote(week: Int, note: CourseSessionNote?): Map<Int, CourseSessionNote>? {
        val next = normalizedSessionNotesMap.orEmpty().toMutableMap()
        val normalized = note?.normalizedOrNull
        if (normalized == null) {
            next.remove(week)
        } else {
            next[week] = normalized
        }
        return normalizeSessionNotes(next)
    }

    /** 移除某周的备注（如删除该次课）。 */
    fun withoutSessionNote(week: Int): Map<Int, CourseSessionNote>? =
        withSessionNote(week, null)

    /** 把备注从 [fromWeek] 挪到 [toWeek]（调课）。同周为 no-op。 */
    fun relocatingSessionNote(fromWeek: Int, toWeek: Int): Map<Int, CourseSessionNote>? {
        if (fromWeek == toWeek) return normalizedSessionNotesMap
        val source = sessionNoteForWeek(fromWeek)
        val next = normalizedSessionNotesMap.orEmpty().toMutableMap()
        next.remove(fromWeek)
        if (source != null) next[toWeek] = source
        return normalizeSessionNotes(next)
    }

    /** 多周课被挪走一周后剩余的备注表。 */
    fun sessionNotesExcludingWeek(week: Int): Map<Int, CourseSessionNote>? =
        withoutSessionNote(week)

    /** 调课/拆分出的单周课应带的备注表。 */
    fun sessionNotesForSingleWeek(sourceWeek: Int, targetWeek: Int): Map<Int, CourseSessionNote>? {
        val source = sessionNoteForWeek(sourceWeek) ?: return null
        return normalizeSessionNotes(mapOf(targetWeek to source))
    }

    val hasAnyHomework: Boolean
        get() = normalizedSessionNotesMap?.values?.any { it.hasHomework } ?: false

    val normalizedCustomWeeks: List<Int>? get() = normalizeWeekList(customWeeks)
    val hasCustomWeeks: Boolean get() = normalizedCustomWeeks != null
    val normalizedSuspendedWeeks: List<Int>? get() = normalizeWeekList(suspendedWeeks)

    fun isSuspendedInWeek(week: Int): Boolean = suspendedWeeks?.contains(week) == true

    /** 周次展开：custom 优先，否则 start..end 按单双周过滤，最后剔除停课。 */
    val activeWeeks: List<Int>
        get() {
            val custom = normalizedCustomWeeks
            val weeks = mutableListOf<Int>()
            if (custom != null) {
                weeks.addAll(custom)
            } else {
                for (week in startWeek..endWeek) {
                    if (isOddWeek && week % 2 == 0) continue
                    if (isEvenWeek && week % 2 != 0) continue
                    weeks.add(week)
                }
            }
            val suspended = normalizedSuspendedWeeks
            if (suspended.isNullOrEmpty()) return weeks
            return weeks.filter { !suspended.contains(it) }
        }

    fun isInWeek(week: Int): Boolean {
        val custom = normalizedCustomWeeks
        if (custom != null) return custom.contains(week)
        if (week < startWeek || week > endWeek) return false
        if (isOddWeek && week % 2 == 0) return false
        if (isEvenWeek && week % 2 != 0) return false
        return true
    }

    /** 是否在指定周有效（排除停课）。 */
    fun isActiveInWeek(week: Int): Boolean {
        if (suspendedWeeks?.contains(week) == true) return false
        return isInWeek(week)
    }

    /** 该周及以后是否仍有上课周（排除停课）；false = 已结课。 */
    fun hasActiveWeekOnOrAfter(week: Int): Boolean =
        activeWeeks.any { it >= week }

    // ------------------------------------------------------------------
    // 序列化（course.dart:218-252）——键名是跨端契约，逐字冻结
    // ------------------------------------------------------------------

    fun toJson(): Map<String, Any?> {
        val map = LinkedHashMap<String, Any?>()
        map["id"] = id
        map["name"] = name
        map["shortName"] = shortName
        map["teacher"] = teacher
        map["location"] = location
        map["dayOfWeek"] = dayOfWeek
        map["startSection"] = startSection
        map["endSection"] = endSection
        map["startTime"] = startTime
        map["endTime"] = endTime
        map["hasCustomTime"] = hasCustomTime
        map["color"] = color
        map["textColor"] = textColor
        map["startWeek"] = startWeek
        map["endWeek"] = endWeek
        map["isOddWeek"] = isOddWeek
        map["isEvenWeek"] = isEvenWeek
        map["customWeeks"] = customWeeks
        map["suspendedWeeks"] = suspendedWeeks
        map["courseNature"] = courseNature.value
        map["description"] = description
        // 原生端快照只认 note 键：下发合并后的取值（liveNote），description 原样。
        map["note"] = liveNote
        val notes = normalizedSessionNotesMap
        if (notes != null) {
            map["sessionNotes"] = notes.entries.associate { (week, note) ->
                week.toString() to note.toJson()
            }
        }
        map["timeSchemeIdOverride"] = timeSchemeIdOverride
        return map
    }

    // ------------------------------------------------------------------
    // 静态归一化（course.dart:155-216, 379-429）——伴生对象
    // ------------------------------------------------------------------

    companion object {
        /** 周次数量级上限：钳制后最多 30 项（maxWeek），超出即判畸形。 */
        const val MAX_WEEK_LIST_ENTRIES = 512

        fun normalizeDayOfWeek(dayOfWeek: Int): Int =
            dayOfWeek.coerceIn(1, 7)

        fun normalizeSections(startSection: Int, endSection: Int, maxSection: Int = 24): Pair<Int, Int> {
            val safeMax = if (maxSection < 1) 1 else maxSection
            val start = startSection.coerceIn(1, safeMax)
            val end = endSection.coerceIn(start, safeMax)
            return start to end
        }

        fun normalizeWeeks(startWeek: Int, endWeek: Int, maxWeek: Int = 30): Pair<Int, Int> {
            val safeMax = if (maxWeek < 1) 1 else maxWeek
            val start = startWeek.coerceIn(1, safeMax)
            val end = endWeek.coerceIn(start, safeMax)
            return start to end
        }

        /** 周次列表归一：丢弃越界项、去重、升序；空/超量级返回 null。 */
        fun normalizeWeekList(weeks: List<Int>?, maxWeek: Int = 30): List<Int>? {
            if (weeks.isNullOrEmpty() || weeks.size > MAX_WEEK_LIST_ENTRIES) return null
            val safeMax = if (maxWeek < 1) 1 else maxWeek
            val normalized = sortedSetOf<Int>()
            for (week in weeks) {
                if (week < 1 || week > safeMax) continue
                normalized.add(week)
            }
            if (normalized.isEmpty()) return null
            return normalized.toList()
        }

        /** 解析按周备注：week 键为字符串或数字；非法键/空备注跳过。 */
        fun parseSessionNotes(raw: Any?): Map<Int, CourseSessionNote>? {
            if (raw !is Map<*, *>) return null
            val parsed = sortedMapOf<Int, CourseSessionNote>()
            for ((key, value) in raw) {
                val week = when (key) {
                    is Number -> key.toInt()
                    is String -> key.toIntOrNull()
                    else -> null
                }
                if (week == null || week < 1) continue
                if (value !is Map<*, *>) continue
                val note = CourseSessionNote.fromJson(value as Map<String, Any?>).normalizedOrNull
                if (note != null) parsed[week] = note
            }
            if (parsed.isEmpty()) return null
            return java.util.Collections.unmodifiableMap(parsed)
        }

        fun normalizeSessionNotes(source: Map<Int, CourseSessionNote>?): Map<Int, CourseSessionNote>? {
            if (source.isNullOrEmpty()) return null
            val normalized = sortedMapOf<Int, CourseSessionNote>()
            for ((week, note) in source) {
                if (week < 1) continue
                val n = note.normalizedOrNull
                if (n != null) normalized[week] = n
            }
            if (normalized.isEmpty()) return null
            return java.util.Collections.unmodifiableMap(normalized)
        }

        // --------------------------------------------------------------
        // fromJson（course.dart:254-376）——必填抛 / 可选收的解析契约
        // --------------------------------------------------------------

        fun fromJson(json: Map<String, Any?>): Course {
            fun readInt(key: String, fallback: Int? = null): Int {
                val raw = json[key]
                if (raw is Number) return raw.toInt()
                if (raw is String) return raw.toIntOrNull() ?: fallback ?: 0
                return fallback ?: throw FormatException("Course.$key must be a number")
            }

            fun readIntList(key: String): List<Int>? {
                val raw = json[key] as? List<*> ?: return null
                if (raw.size > MAX_WEEK_LIST_ENTRIES) return null
                val values = mutableListOf<Int>()
                for (item in raw) {
                    if (item is Number) {
                        values.add(item.toInt())
                    } else if (item is String) {
                        item.toIntOrNull()?.let(values::add)
                    }
                    // 其他类型忽略（旧实现记作 0 会让脏数据伪装成「第 0 周」）。
                }
                return values
            }

            fun readRequired(key: String): String {
                val raw = json[key] ?: throw FormatException("Course.$key is missing")
                return if (raw is String) raw else raw.toString()
            }

            fun readStringOrNull(key: String): String? {
                val raw = json[key] ?: return null
                return if (raw is String) raw else raw.toString()
            }

            val (startSection, endSection) = normalizeSections(
                startSection = readInt("startSection", 1),
                endSection = readInt("endSection", 1),
            )
            val (startWeek, endWeek) = normalizeWeeks(
                startWeek = readInt("startWeek", 1),
                endWeek = readInt("endWeek", 16),
            )

            return Course(
                id = readRequired("id"),
                name = readRequired("name"),
                shortName = readStringOrNull("shortName"),
                teacher = readRequired("teacher"),
                location = readRequired("location"),
                dayOfWeek = normalizeDayOfWeek(readInt("dayOfWeek", 1)),
                startSection = startSection,
                endSection = endSection,
                startTime = readRequired("startTime"),
                endTime = readRequired("endTime"),
                // bool 字段不接受字符串 "true"/"false"：字符串无法安全映射成真值
                //（不替用户猜），按缺省 false 收下（course.dart:352-365）。
                hasCustomTime = json["hasCustomTime"] is Boolean && json["hasCustomTime"] as Boolean,
                color = readStringOrNull("color") ?: "#2196F3",
                textColor = readStringOrNull("textColor"),
                startWeek = startWeek,
                endWeek = endWeek,
                isOddWeek = json["isOddWeek"] is Boolean && json["isOddWeek"] as Boolean,
                isEvenWeek = json["isEvenWeek"] is Boolean && json["isEvenWeek"] as Boolean,
                customWeeks = normalizeWeekList(readIntList("customWeeks")),
                suspendedWeeks = normalizeWeekList(readIntList("suspendedWeeks")),
                courseNature = CourseNature.fromValue(readStringOrNull("courseNature")),
                description = readStringOrNull("description") ?: readStringOrNull("note"),
                note = readStringOrNull("note"),
                sessionNotes = parseSessionNotes(json["sessionNotes"]),
                timeSchemeIdOverride = readStringOrNull("timeSchemeIdOverride"),
            )
        }
    }
}

/** 备注的 JSON 形态（与 Dart CourseSessionNote.toJson 键序一致）。 */
fun CourseSessionNote.toJson(): Map<String, Any?> =
    linkedMapOf("text" to text, "hasHomework" to hasHomework)
