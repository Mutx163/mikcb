package com.mutx163.qingyu.core

import java.time.LocalDateTime

/**
 * 课程任务（移植自 lib/models/course_task.dart）。
 *
 * isUserEdited 语义（course_task.dart:33-45）：用户亲手改过这条作业可被课程
 * 备注推导的字段。没有它，用户在编辑页写的标题会在下一次课程改动时被打回
 * 备注原文。toJson 只在 true 时写出（保持旧档案字节不变，course_task.dart:98-100）。
 */
enum class CourseTaskSource(val value: String) {
    MANUAL("manual"),
    HOMEWORK_MARK("homework_mark");

    companion object {
        /** 未知值回落 manual（Dart fromValue orElse）。 */
        fun fromValue(value: String?): CourseTaskSource =
            entries.firstOrNull { it.value == value } ?: MANUAL
    }
}

data class CourseTask(
    val id: String,
    val title: String,
    val courseId: String? = null,
    val sourceWeek: Long? = null,
    /** 构造时按 dateOnly 归一（去掉时分秒）。 */
    val dueDate: LocalDateTime? = null,
    val note: String? = null,
    val isCompleted: Boolean = false,
    val source: CourseTaskSource = CourseTaskSource.MANUAL,
    val isUserEdited: Boolean = false,
    val createdAt: LocalDateTime,
    val updatedAt: LocalDateTime,
) {
    val hasDueDate: Boolean get() = dueDate != null

    fun isDueOn(date: LocalDateTime): Boolean {
        val due = dueDate ?: return false
        return dateOnly(due) == dateOnly(date)
    }

    fun isOverdue(now: LocalDateTime? = null): Boolean {
        val due = dueDate ?: return false
        return !isCompleted && dateOnly(due).isBefore(dateOnly(now ?: LocalDateTime.now()))
    }

    fun toJson(): Map<String, Any?> {
        val map = linkedMapOf<String, Any?>(
            "id" to id,
            "title" to title,
            "courseId" to courseId,
            "sourceWeek" to sourceWeek,
            // Dart 构造函数保证 dueDate 恒为本地零点（course_task.dart:62）。
            // 解析侧已归一，这里再兜一层：UI 侧若带时分秒构造，写出的字节仍与 Dart 一致。
            "dueDate" to dueDate?.let { DartTime.toIso(dateOnly(it)) },
            "note" to note,
            "isCompleted" to isCompleted,
            "source" to source.value,
        )
        // 只在 true 时写出：保持旧档案与既有导出文件的字节不变（缺键读回 false）。
        if (isUserEdited) map["isUserEdited"] = true
        map["createdAt"] = DartTime.toIso(createdAt)
        map["updatedAt"] = DartTime.toIso(updatedAt)
        return map
    }

    fun toJsonString(): String = MiniJson.encode(toJson())

    companion object {
        /** Dart dateOnly：本地零点。 */
        fun dateOnly(value: LocalDateTime): LocalDateTime =
            LocalDateTime.of(value.year, value.monthValue, value.dayOfMonth, 0, 0)

        /**
         * Dart fromJson（course_task.dart:117-166）：id 缺失/空白抛
         * （身份字段，坏条目留档机制依赖）；其余字段类型不对但有值 → toString，
         * 确实没有 → 默认值。bool 不猜（'true' 退 false）。
         */
        fun fromJson(json: Map<String, Any?>): CourseTask {
            val now = LocalDateTime.now()

            val rawId = json["id"] ?: throw DartFormatException("CourseTask.id is missing")
            val idValue = if (rawId is String) rawId else rawId.toString()
            if (idValue.trim().isEmpty()) throw DartFormatException("CourseTask.id is blank")

            fun readStringOrNull(key: String): String? {
                val raw = json[key] ?: return null
                return if (raw is String) raw else raw.toString()
            }

            val rawSourceWeek = json["sourceWeek"]
            val sourceWeek: Long? = when (rawSourceWeek) {
                is Number -> rawSourceWeek.toLong()
                null -> null
                else -> rawSourceWeek.toString().trim().toLongOrNull()
            }

            return CourseTask(
                id = idValue,
                title = readStringOrNull("title") ?: "",
                courseId = readStringOrNull("courseId"),
                sourceWeek = sourceWeek,
                // Dart 构造函数把 dueDate 归一到本地零点（course_task.dart:62），
                // 解析侧必须同步归一，否则读入 "…T13:00" 后原样写回，产出与 Dart 不同的 JSON。
                dueDate = DartTime.tryParseIso(json["dueDate"]?.toString())?.let { dateOnly(it) },
                note = readStringOrNull("note"),
                // 类型不对没有合理真值，按缺省 false 收下，不让标记字段丢整条任务。
                isCompleted = json["isCompleted"] is Boolean && json["isCompleted"] as Boolean,
                source = CourseTaskSource.fromValue(json["source"] as? String),
                isUserEdited = json["isUserEdited"] is Boolean && json["isUserEdited"] as Boolean,
                createdAt = DartTime.tryParseIso(json["createdAt"]?.toString()) ?: now,
                updatedAt = DartTime.tryParseIso(json["updatedAt"]?.toString()) ?: now,
            )
        }

        fun fromJsonString(text: String): CourseTask {
            val decoded = MiniJson.parse(text)
            if (decoded !is Map<*, *>) throw DartFormatException("course task json must be an object")
            @Suppress("UNCHECKED_CAST")
            return fromJson(decoded as Map<String, Any?>)
        }

        /** 排序（course_task.dart:210-236）：截止日 → 完成态 → 标题 → id；无截止日垫底。 */
        fun compareByDueDate(left: CourseTask, right: CourseTask): Int {
            val leftDue = left.dueDate
            val rightDue = right.dueDate
            if (leftDue == null && rightDue != null) return 1
            if (leftDue != null && rightDue == null) return -1
            if (leftDue != null && rightDue != null) {
                val dueCompare = dateOnly(leftDue).compareTo(dateOnly(rightDue))
                if (dueCompare != 0) return dueCompare
            }
            val completionCompare =
                (if (left.isCompleted) 1 else 0).compareTo(if (right.isCompleted) 1 else 0)
            if (completionCompare != 0) return completionCompare
            val titleCompare = left.title.compareTo(right.title)
            if (titleCompare != 0) return titleCompare
            return left.id.compareTo(right.id)
        }
    }
}
