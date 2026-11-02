package com.mutx163.qingyu.pages.exam

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ExamReminderPreset
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * 考试提醒排程计算层测试。
 *
 * 期望值来源：
 * - `test/services/exam_reminder_service_test.dart` 的考试 fires 分组；
 * - `lib/services/exam_reminder_service.dart:101-142 / :363-454`
 *   （assignDistinctRequestCodes / buildFires / _buildBody）。
 */
class ExamReminderLogicTest {

    private val zone = ZoneId.of("Asia/Shanghai")

    private fun exam(
        id: String = "exam-1",
        name: String = "高等数学期末",
        dateTime: LocalDateTime = LocalDateTime.of(2026, 7, 10, 0, 0),
        startTime: String = "09:00",
        endTime: String = "11:00",
        location: String? = "教学楼 A101",
        seatNumber: String? = null,
        preset: ExamReminderPreset = ExamReminderPreset.MIN_30,
        customMinutes: List<Int> = emptyList(),
    ) = Exam(
        id = id,
        courseId = "course-1",
        name = name,
        dateTime = dateTime,
        startTime = startTime,
        endTime = endTime,
        location = location,
        seatNumber = seatNumber,
        reminderPreset = preset,
        customReminderMinutes = customMinutes,
        createdAt = LocalDateTime.of(2026, 7, 1, 0, 0),
        updatedAt = LocalDateTime.of(2026, 7, 1, 0, 0),
    )

    private fun course(location: String = "课程默认地点") = Course(
        id = "course-1",
        name = "高等数学",
        teacher = "张老师",
        location = location,
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
        color = "#3482FF",
        startWeek = 1,
        endWeek = 16,
    )

    @Test
    fun `builds one fire per future exam with preset offsets`() {
        val fires = ExamReminderLogic.buildFires(
            exams = listOf(exam(preset = ExamReminderPreset.HOUR_1_AND_MIN_30)),
            now = LocalDateTime.of(2026, 7, 10, 6, 0),
            zone = zone,
        )

        // 09:00 开考：60 / 30 两个提前量都严格在未来 → 8:00 与 8:30 各一条（按响点升序）。
        assertEquals(2, fires.size)
        assertEquals(listOf(60, 30), fires.map { it.offsetMinutes })
        assertEquals("2026-07-10", fires.first().localDate)
        assertEquals(9 * 60, fires.first().localTimeMinutes)
        assertEquals(
            LocalDateTime.of(2026, 7, 10, 8, 30).atZone(zone).toInstant().toEpochMilli(),
            fires.first { it.offsetMinutes == 30 }.fireAtEpochMillis,
        )
    }

    @Test
    fun `skips finished exams and past offsets`() {
        val fires = ExamReminderLogic.buildFires(
            exams = listOf(
                exam(id = "done", endTime = "11:00"),
                exam(id = "upcoming", startTime = "23:30", endTime = "23:59"),
            ),
            now = LocalDateTime.of(2026, 7, 10, 11, 0),
            zone = zone,
        )

        // done 的 30 分钟提前量是 10:30（已过）→ 不排；upcoming 23:00 仍未来 → 排。
        assertEquals(listOf("upcoming"), fires.map { it.examId })
        // 结束时刻（11:00）不晚于 now 的考试，即便提醒点还没到也整场跳过。
        val finishedWithFutureOffset = ExamReminderLogic.buildFires(
            exams = listOf(exam(id = "half-done", startTime = "11:30", endTime = "11:00")),
            now = LocalDateTime.of(2026, 7, 10, 11, 0),
            zone = zone,
        )
        // endTime(11:00) < startTime(11:30)：考试按「结束即过期」判——endTime 不晚于 now ⇒ 整场跳过。
        assertTrue(finishedWithFutureOffset.isEmpty())
    }

    @Test
    fun `includePastOffsets keeps overdue fires for planned keys only`() {
        val now = LocalDateTime.of(2026, 7, 10, 8, 45)
        val delivery = ExamReminderLogic.buildFires(
            exams = listOf(exam()),
            now = now,
            zone = zone,
        )
        val planned = ExamReminderLogic.buildPlannedFireKeys(
            exams = listOf(exam()),
            now = now,
            zone = zone,
        )

        // 08:30 的响点已过：投递列表不收，计划键必须收（原生逾期重试通道靠它判「仍在计划里」）。
        assertTrue(delivery.isEmpty())
        assertTrue("exam-1#30" in planned)
    }

    @Test
    fun `body joins time location fallback and seat`() {
        val fires = ExamReminderLogic.buildFires(
            exams = listOf(
                exam(location = null, seatNumber = " 12号 ", name = "  线性代数  "),
            ),
            resolveCourse = { course() },
            now = LocalDateTime.of(2026, 7, 10, 6, 0),
            zone = zone,
        )

        // 地点缺考次取课程地点兜底；标题 trim；座位号 trim 后拼在末尾。
        assertEquals("线性代数", fires.single().title)
        assertEquals("09:00-11:00 · 课程默认地点 · 12号", fires.single().body)
    }

    @Test
    fun `custom preset uses customReminderMinutes and drops nonpositive`() {
        val fires = ExamReminderLogic.buildFires(
            exams = listOf(
                exam(preset = ExamReminderPreset.CUSTOM, customMinutes = listOf(90, 0, -5, 90)),
            ),
            now = LocalDateTime.of(2026, 7, 10, 6, 0),
            zone = zone,
        )

        // 去重 + 丢非正数：只留 90。
        assertEquals(listOf(90), fires.map { it.offsetMinutes })
    }

    @Test
    fun `request codes are stable and namespace prefixed`() {
        val first = ExamReminderLogic.stableRequestCode("exam-1", 30)
        val second = ExamReminderLogic.stableRequestCode("exam-1", 30)
        val otherOffset = ExamReminderLogic.stableRequestCode("exam-1", 60)

        assertEquals(first, second)
        assertNotEquals(first, otherOffset)
        // Dart requestCodeNamespace = 0x46000000：高 8 位命名空间，取消才找得回。
        assertEquals(0x46000000, first and 0xFF000000.toInt())
    }

    @Test
    fun `assignDistinctRequestCodes resolves collisions deterministically`() {
        // 同一散列键只占 24 位：构造 20000 个 id 的批次必然出现碰撞（实测口径来自 Dart 注释）。
        val fires = (0 until 20000).map { index ->
            ExamReminderFire(
                examId = "schedule:$index@2026-07-10",
                offsetMinutes = 30,
                fireAtEpochMillis = 1_000_000L + index,
                examStartEpochMillis = 2_000_000L + index,
                title = "t",
                body = "b",
                requestCode = ExamReminderLogic.stableRequestCode(
                    "schedule:$index@2026-07-10",
                    30,
                ),
                localDate = "2026-07-10",
                localTimeMinutes = 540,
            )
        }
        val resolved = ExamReminderLogic.assignDistinctRequestCodes(fires)

        assertEquals(fires.size, resolved.size)
        assertEquals(fires.size, resolved.map { it.requestCode }.toSet().size)
        // 排序口径：结果按 fireAt 升序，与输入拼装顺序无关。
        assertEquals(resolved.map { it.fireAtEpochMillis }.sorted(), resolved.map { it.fireAtEpochMillis })
        // 碰撞被改码的条目保持其余字段原样。
        val byKey = resolved.associateBy { it.fireKey }
        assertTrue(fires.all { byKey[it.fireKey]?.examStartEpochMillis == it.examStartEpochMillis })
    }

    @Test
    fun `payload carries native maps active ids and planned keys`() {
        val payload = ExamReminderLogic.buildPayload(
            exams = listOf(exam(), exam(id = "expired", endTime = "08:00")),
            resolveCourse = { null },
            now = LocalDateTime.of(2026, 7, 10, 9, 0),
            zone = zone,
        )

        // expired 在 now（09:00，考试已结束）被排除；活着的 exam-1 仍在。
        assertFalse(payload.activeExamIds.contains("expired"))
        assertTrue("exam-1" in payload.activeExamIds)
        // 投递列表此刻只剩严格未来的响点（exam-1 的 30 分钟响点 08:30 已过）→ 空。
        assertTrue(payload.fires.isEmpty())
        assertTrue("exam-1#30" in payload.activeFireKeys)
    }

    @Test
    fun `native map round trips through scheduler key names`() {
        val fire = ExamReminderFire(
            examId = "e1",
            offsetMinutes = 30,
            fireAtEpochMillis = 1000L,
            examStartEpochMillis = 2000L,
            title = "T",
            body = "B",
            requestCode = 7,
            localDate = "2026-07-10",
            localTimeMinutes = 540,
        )
        val map = fire.toNativeMap()

        // 键名必须与 ExamReminderScheduler.parseFires 的读侧逐字一致。
        assertEquals("e1", map["examId"])
        assertEquals(30, map["offsetMinutes"])
        assertEquals(1000L, map["fireAtMillis"])
        assertEquals(2000L, map["examStartMillis"])
        assertEquals(7, map["requestCode"])
        assertEquals("2026-07-10", map["localDate"])
        assertEquals(540, map["localTimeMinutes"])
    }
}
