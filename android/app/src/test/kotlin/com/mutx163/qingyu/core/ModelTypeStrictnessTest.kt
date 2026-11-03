package com.mutx163.qingyu.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `core` 模型 `fromJson` 的类型严格性对拍（Dart `lib/models/{course,exam,course_task,schedule_item}.dart`）。
 *
 * 口径：
 * - Dart 用**裸强制转换**（`as String?` / `as bool?`）的字段，非对应类型必须**抛**，
 *   由上层把整条实体判为无效（严格导入 = 拒绝整包；宽松档案 = 丢弃并留档）。
 *   Kotlin 不许用 `as?` 静默吞掉，否则会出现「导入成功但字段丢了」。
 * - Dart 用 `is String ? … : …`（`readStringOrNull` / `readRequired`）的字段，是**宽松**的：
 *   缺失（或显式 `null`）时必填字段抛，`toString()` 兜底的可选字段会收下。
 *   这些行为 Kotlin 已同解，本文件用断言钉住，防止以后被「优化」成抛。
 */
class ModelTypeStrictnessTest {

    // -----------------------------------------------------------------------
    // CourseSessionNote：Dart 裸转换 → 必须抛
    // -----------------------------------------------------------------------

    @Test
    fun `sessionNotes text 为数字时整条课程被拒收而不是静默丢备注`() {
        val json = courseJson("sessionNotes" to mapOf("1" to mapOf("text" to 123)))
        val error = assertThrows(DartFormatException::class.java) { Course.fromJson(json) }
        assertTrue(error.message.orEmpty(), error.message.orEmpty().contains("text"))
    }

    @Test
    fun `sessionNotes hasHomework 非布尔时同样拒收`() {
        val json = courseJson("sessionNotes" to mapOf("1" to mapOf("text" to "带作业", "hasHomework" to "true")))
        val error = assertThrows(DartFormatException::class.java) { Course.fromJson(json) }
        assertTrue(error.message.orEmpty(), error.message.orEmpty().contains("hasHomework"))
    }

    @Test
    fun `sessionNotes 周次键为小数时按 Dart 丢弃而不是截断`() {
        val course = Course.fromJson(courseJson("sessionNotes" to mapOf(2.5 to mapOf("text" to "备注"))))
        assertTrue(course.sessionNotes.isNullOrEmpty())
    }

    // -----------------------------------------------------------------------
    // Course：Dart 的宽松字段行为（保持现状，钉住）
    // -----------------------------------------------------------------------

    @Test
    fun `name 为 null 时按 Dart 抛必填缺失`() {
        val json = courseJson("name" to null)
        // Dart 抛的是 FormatException（core 里两套异常并存：必填缺失 = FormatException，
        // 严格类型不符 = DartFormatException），两种都必须让整条实体失效。
        val error = assertThrows(FormatException::class.java) { Course.fromJson(json) }
        assertTrue(error.message.orEmpty(), error.message.orEmpty().contains("Course.name is missing"))
    }

    @Test
    fun `startSection 字符串按 Dart 解析成数字`() {
        val course = Course.fromJson(courseJson("startSection" to "3"))
        assertEquals(3, course.startSection)
    }

    @Test
    fun `color 非字符串时按 Dart 的 toString 兜底收下`() {
        val course = Course.fromJson(courseJson("color" to true))
        assertEquals("true", course.color)
    }

    // -----------------------------------------------------------------------
    // CourseTask：sourceWeek 走 int.tryParse 语义
    // -----------------------------------------------------------------------

    @Test
    fun `sourceWeek 数字按 Dart num toInt 截断，数字字符串按 tryParse`() {
        assertEquals(3L, CourseTask.fromJson(taskJson("sourceWeek" to 3)).sourceWeek)
        assertEquals(3L, CourseTask.fromJson(taskJson("sourceWeek" to 3.5)).sourceWeek)
        assertEquals(3L, CourseTask.fromJson(taskJson("sourceWeek" to "3")).sourceWeek)
        assertNull(CourseTask.fromJson(taskJson("sourceWeek" to "3.5")).sourceWeek)
    }

    @Test
    fun `id 缺失或空白时按 Dart 抛必填缺失`() {
        assertThrows(DartFormatException::class.java) { CourseTask.fromJson(taskJson("id" to null)) }
        assertThrows(DartFormatException::class.java) { CourseTask.fromJson(taskJson("id" to "  ")) }
    }

    @Test
    fun `Exam 与 ScheduleItem 的 id 缺失同样抛`() {
        assertThrows(DartFormatException::class.java) {
            Exam.fromJson(linkedMapOf("id" to null, "courseId" to "c1", "name" to "期中", "date" to "2026-11-10"))
        }
        assertThrows(DartFormatException::class.java) {
            ScheduleItem.fromJson(linkedMapOf("id" to null, "title" to "答疑"))
        }
    }

    // -----------------------------------------------------------------------
    // 工具
    // -----------------------------------------------------------------------

    private fun courseJson(vararg extras: Pair<String, Any?>): Map<String, Any?> = linkedMapOf(
        "id" to "c1",
        "name" to "高等数学",
        "teacher" to "张老师",
        "location" to "A101",
        "dayOfWeek" to 1,
        "startSection" to 1,
        "endSection" to 2,
        "startTime" to "08:00",
        "endTime" to "09:40",
    ) + extras.toMap()

    private fun taskJson(vararg extras: Pair<String, Any?>): Map<String, Any?> = linkedMapOf(
        "id" to "t1",
        "title" to "作业",
    ) + extras.toMap()
}
