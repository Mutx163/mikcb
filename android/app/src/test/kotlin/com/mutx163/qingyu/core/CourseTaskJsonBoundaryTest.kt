package com.mutx163.qingyu.core

import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [CourseTask] JSON 解析的**边界**用例。
 *
 * 期望值来源：lib/models/course_task.dart。
 * - dueDate 构造即归一到本地零点（:62）；
 * - id 缺失/空白抛（:117-166）；
 * - toJson 只在 isUserEdited=true 时写出该键（:98-100）；
 * - compareByDueDate：截止日 → 完成态 → 标题 → id，无截止日垫底（:210-236）。
 */
class CourseTaskJsonBoundaryTest {

    private fun parse(json: String): CourseTask = CourseTask.fromJsonString(json)

    @Test
    fun `dueDate 带时分秒读入即归一到本地零点`() {
        // 本次修复的回归锚点：解析侧不归一，read→write 会产出 "…T13:45" 而不是 Dart 的 "…T00:00"。
        val task = parse(
            """{"id":"t1","title":"第三章习题","dueDate":"2026-03-05T13:45:00.000",
               "createdAt":"2026-03-01T00:00:00.000","updatedAt":"2026-03-01T00:00:00.000"}""",
        )

        assertEquals(LocalDateTime.of(2026, 3, 5, 0, 0), task.dueDate)
        assertEquals("2026-03-05T00:00:00.000", task.toJson()["dueDate"])
        assertTrue(task.isDueOn(LocalDateTime.of(2026, 3, 5, 23, 59)))
        assertTrue(task.isOverdue(LocalDateTime.of(2026, 3, 6, 0, 0)))
    }

    @Test
    fun `dueDate 缺失或不可解析都保持 null 不补今日`() {
        assertNull(parse("""{"id":"t1","title":"x"}""").dueDate)
        assertNull(parse("""{"id":"t1","title":"x","dueDate":"not-a-date"}""").dueDate)
        // 没有截止日时 toJson 写 null，旧档案字节不变。
        assertNull(parse("""{"id":"t1","title":"x"}""").toJson()["dueDate"])
    }

    @Test
    fun `id 缺失空白整条拒收且非字符串可转`() {
        assertThrows(DartFormatException::class.java) { parse("""{"title":"x"}""") }
        assertThrows(DartFormatException::class.java) { parse("""{"id":"  ","title":"x"}""") }
        assertEquals("7", parse("""{"id":7,"title":"x"}""").id)
    }

    @Test
    fun `完成态与用户编辑标记类型错按 false 且字符串 true 不猜`() {
        val stringTrue = parse(
            """{"id":"t1","title":"x","isCompleted":"true","isUserEdited":"true"}""",
        )
        assertFalse(stringTrue.isCompleted)
        assertFalse(stringTrue.isUserEdited)
        assertNull("false 不写出该键", stringTrue.toJson()["isUserEdited"])

        val realTrue = parse("""{"id":"t1","title":"x","isCompleted":true,"isUserEdited":true}""")
        assertTrue(realTrue.isCompleted)
        assertEquals(true, realTrue.toJson()["isUserEdited"])
    }

    @Test
    fun `sourceWeek 文本数字可读坏文本回落 null`() {
        assertEquals(6L, parse("""{"id":"t1","title":"x","sourceWeek":"6"}""").sourceWeek ?: -1L)
        assertNull(parse("""{"id":"t1","title":"x","sourceWeek":"6周"}""").sourceWeek)
    }

    @Test
    fun `createdAt 损坏时回落 now 而不是整条丢弃`() {
        val task = parse("""{"id":"t1","title":"x","createdAt":"13月32日"}""")
        assertEquals("t1", task.id)
        // 回落 now()：与当前时刻的差不超过一个宽容窗口。
        val drift = java.time.Duration.between(task.createdAt, LocalDateTime.now()).abs()
        assertTrue("createdAt 应回落 now()，实际漂移 $drift", drift.toMinutes() < 5)
    }

    @Test
    fun `compareByDueDate 无截止日垫底并列按 id 稳定`() {
        val now = LocalDateTime.of(2026, 3, 1, 0, 0)
        fun task(id: String, due: LocalDateTime?, completed: Boolean = false, title: String = "x") =
            CourseTask(
                id = id,
                title = title,
                dueDate = due,
                isCompleted = completed,
                createdAt = now,
                updatedAt = now,
            )

        val list = listOf(
            task("b", null),
            task("c", LocalDateTime.of(2026, 3, 5, 0, 0)),
            task("a", LocalDateTime.of(2026, 3, 5, 0, 0)),
            task("d", LocalDateTime.of(2026, 3, 5, 0, 0), completed = true),
        )
        val sorted = list.sortedWith { l, r -> CourseTask.compareByDueDate(l, r) }

        assertEquals(listOf("a", "c", "d", "b"), sorted.map { it.id })
    }

    @Test
    fun `超长标题原样保留且 round trip 稳定`() {
        val longTitle = "作".repeat(20_000)
        val task = parse(
            MiniJson.encode(
                linkedMapOf(
                    "id" to "t1",
                    "title" to longTitle,
                    "createdAt" to "2026-03-01T00:00:00.000",
                    "updatedAt" to "2026-03-01T00:00:00.000",
                ),
            ),
        )

        assertEquals(longTitle, task.title)
        assertEquals(task, parse(MiniJson.encode(task.toJson())))
    }
}
