package com.mutx163.qingyu.pages.import

import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * ICS 课表解析模型测试（P3-G1 · ics_course_import_screen.dart + ics_import_service.dart）。
 *
 * 期望值全部按 Dart 源**手推**（不跑 Dart、不抄实现），并按 TEST-POLICY 的
 * 「导入/解析」定向反例覆盖：空文件、超长、格式错、字段缺失、重复课。
 *
 * 时间基准：2026-03-02 是周一（从 2026-01-01 周四 + 60 天手推），
 * 所以 `startOfWeek(2026-03-02T08:00) == 2026-03-02T00:00`，即校历第 1 周。
 */
class IcsImportModelTest {

    private val fixedNow = LocalDateTime.of(2026, 10, 27, 12, 0)

    /** WakeUp 风格单事件模板。 */
    private fun event(
        summary: String = "高等数学",
        description: String = "第 1-2 节\\n教学楼101\\n李老师",
        dtStart: String? = "20260302T080000",
        dtEnd: String? = "20260302T094000",
        rrule: String? = null,
        location: String? = null,
        extra: String = "",
    ): String {
        val sb = StringBuilder()
        sb.append("BEGIN:VEVENT\r\n")
        if (summary.isNotEmpty()) sb.append("SUMMARY:").append(summary).append("\r\n")
        if (dtStart != null) sb.append("DTSTART:").append(dtStart).append("\r\n")
        if (dtEnd != null) sb.append("DTEND:").append(dtEnd).append("\r\n")
        if (description != null && description.isNotEmpty()) {
            sb.append("DESCRIPTION:").append(description).append("\r\n")
        }
        if (location != null) sb.append("LOCATION:").append(location).append("\r\n")
        if (rrule != null) sb.append("RRULE:").append(rrule).append("\r\n")
        sb.append(extra)
        sb.append("END:VEVENT\r\n")
        return sb.toString()
    }

    private fun calendar(vararg events: String): String {
        val sb = StringBuilder("BEGIN:VCALENDAR\r\n")
        for (e in events) sb.append(e)
        sb.append("END:VCALENDAR\r\n")
        return sb.toString()
    }

    private fun parse(content: String) = IcsImportModel.parseWakeUpSchedule(content, now = fixedNow)

    // ==========================================
    // 1. 空文件 / 无事件内容
    // ==========================================

    @Test
    fun `空文件解析为空课表且学期起点回落当前时间`() {
        val result = parse("")
        assertTrue(result.courses.isEmpty())
        // Dart: events.isEmpty → IcsImportResult(courses: const [], semesterStart: DateTime.now())
        assertEquals(fixedNow, result.semesterStart)
    }

    @Test
    fun `没有 VEVENT 的杂乱文本解析为空`() {
        val result = parse("hello world\r\nnot a calendar\r\n")
        assertTrue(result.courses.isEmpty())
        assertEquals(fixedNow, result.semesterStart)
    }

    @Test
    fun `只有 VEVENT 却都没有 DTSTART 时解析为空`() {
        val content = calendar(event(dtStart = null))
        val result = parse(content)
        assertTrue(result.courses.isEmpty())
        assertEquals(fixedNow, result.semesterStart)
    }

    // ==========================================
    // 2. 基本解析：VEVENT → 课程
    // ==========================================

    @Test
    fun `单个事件解析出完整课程字段`() {
        val content = calendar(
            event(rrule = "FREQ=WEEKLY;UNTIL=20260427T080000"),
        )
        val result = parse(content)
        assertEquals(1, result.courses.size)
        // 学期起点 = 最早 DTSTART 所在周的周一 00:00
        assertEquals(LocalDateTime.of(2026, 3, 2, 0, 0), result.semesterStart)

        val course = result.courses[0]
        assertEquals("高等数学", course.name)
        assertEquals("李老师", course.teacher)
        assertEquals("教学楼101", course.location)
        assertEquals(1, course.dayOfWeek) // 周一
        assertEquals(1, course.startSection)
        assertEquals(2, course.endSection)
        assertEquals("08:00", course.startTime)
        assertEquals("09:40", course.endTime)
        // 手推：UNTIL=20260427T080000 与 DTSTART 恰差 56 天 = 8 个 7 天 → 第 9 周
        assertEquals(1, course.startWeek)
        assertEquals(9, course.endWeek)
        assertTrue(!course.isOddWeek && !course.isEvenWeek)
        assertTrue(course.id.startsWith("ics-"))
        assertTrue(course.id.endsWith("-0"))
    }

    @Test
    fun `星期按 DTSTART 推算周日为 7`() {
        val content = calendar(event(dtStart = "20260308T100000", dtEnd = "20260308T114000"))
        val course = parse(content).courses.single()
        assertEquals(7, course.dayOfWeek) // 2026-03-08 周日
    }

    @Test
    fun `UNTIL 只有日期时按绝对时长语义落在第 8 周`() {
        // 手推：UNTIL=20260427（当天 00:00）− DTSTART(03-02 08:00) = 55 天 16 小时
        // 55.67 天 / 7 天 = 7.95 → ~/ 7 → 最后一次实例 = 03-02 + 49 天 = 04-20 → 第 8 周
        // （这正是 Dart 侧注释钉的「日历日跨度会多算一周」的边界）
        val content = calendar(event(rrule = "FREQ=WEEKLY;UNTIL=20260427"))
        val course = parse(content).courses.single()
        assertEquals(8, course.endWeek)
    }

    @Test
    fun `UNTIL 早于 DTSTART 时结束周回落起始周`() {
        val content = calendar(event(rrule = "FREQ=WEEKLY;UNTIL=20260301T080000"))
        val course = parse(content).courses.single()
        assertEquals(1, course.startWeek)
        assertEquals(1, course.endWeek)
    }

    @Test
    fun `INTERVAL=2 按首周奇偶落单双周标志`() {
        // DTSTART 第 1 周（奇数），INTERVAL=2 → 单周课
        val content = calendar(event(rrule = "FREQ=WEEKLY;INTERVAL=2;UNTIL=20260427T080000"))
        val course = parse(content).courses.single()
        assertTrue(course.isOddWeek)
        assertTrue(!course.isEvenWeek)
        // UNTIL 差 56 天 = 4 个 14 天跨度 → 第 9 周
        assertEquals(9, course.endWeek)
    }

    @Test
    fun `无 RRULE 时结束周回落起始周`() {
        val content = calendar(event())
        val course = parse(content).courses.single()
        assertEquals(1, course.startWeek)
        assertEquals(1, course.endWeek)
    }

    // ==========================================
    // 3. 多行文本 / 转义 / 折行
    // ==========================================

    @Test
    fun `RFC5545 文本转义还原逗号与换行`() {
        // 手推：\, → ,；\n → 真换行；单趟扫描不吃二次转义
        assertEquals("高等数学, 实验", IcsImportModel.unescapeIcsText("高等数学\\, 实验"))
        assertEquals("第1节\n教学楼", IcsImportModel.unescapeIcsText("第1节\\n教学楼"))
        assertEquals("a\\b", IcsImportModel.unescapeIcsText("a\\\\b"))
        // \x 不是已知转义：反斜杠原样保留
        assertEquals("a\\x", IcsImportModel.unescapeIcsText("a\\x"))
        // 无反斜杠原样返回
        assertEquals("普通文本", IcsImportModel.unescapeIcsText("普通文本"))
    }

    @Test
    fun `转义后的课程名不再带反斜杠`() {
        // Dart 注释里的反例：SUMMARY:高等数学\, 实验 原先会把 \, 留在名字里
        val content = calendar(event(summary = "高等数学\\, 实验"))
        val course = parse(content).courses.single()
        assertEquals("高等数学, 实验", course.name)
    }

    @Test
    fun `空格折行展开为单行`() {
        val content = "BEGIN:VCALENDAR\r\n" +
            "BEGIN:VEVENT\r\n" +
            "SUMMARY:高等\r\n 数学\r\n" + // 折行：以空格开头 → 拼回上一行
            "DESCRIPTION:第 1-2 节\\n教学楼101\\n李老师\r\n" +
            "DTSTART:20260302T080000\r\n" +
            "DTEND:20260302T094000\r\n" +
            "END:VEVENT\r\n" +
            "END:VCALENDAR\r\n"
        val course = parse(content).courses.single()
        assertEquals("高等数学", course.name)
    }

    @Test
    fun `VALARM 块内的属性不进事件`() {
        // 事件本身没有 DESCRIPTION，闹钟块里有 → 事件仍缺字段 → 整条跳过
        val content = calendar(
            event(description = "", extra = "BEGIN:VALARM\r\nDESCRIPTION:第 9-10 节\\n楼\\n师\r\nEND:VALARM\r\n"),
        )
        assertTrue(parse(content).courses.isEmpty())
    }

    @Test
    fun `同名属性首见优先`() {
        val content = "BEGIN:VCALENDAR\r\n" +
            "BEGIN:VEVENT\r\n" +
            "SUMMARY:第一节课名\r\n" +
            "SUMMARY:第二节课名\r\n" +
            "DESCRIPTION:第 1-2 节\\n楼\\n师\r\n" +
            "DTSTART:20260302T080000\r\n" +
            "DTEND:20260302T094000\r\n" +
            "END:VEVENT\r\n" +
            "END:VCALENDAR\r\n"
        val course = parse(content).courses.single()
        assertEquals("第一节课名", course.name)
    }

    @Test
    fun `SUMMARY 尾部的方括号标记被清除`() {
        // _cleanSummary: 去掉 [数字][任意非]] 结尾
        val content = calendar(event(summary = "高等数学[1][星期一]"))
        val course = parse(content).courses.single()
        assertEquals("高等数学", course.name)
    }

    // ==========================================
    // 4. 地点/教师两种行序 + 组合地点字段
    // ==========================================

    @Test
    fun `DESCRIPTION 两行时教师回落 LOCATION 组合字段`() {
        // Format: line[1]=location, teacher 从 LOCATION 拆尾段
        val content = calendar(event(description = "第 1-2 节\\n教学楼101", location = "教学楼101 李老师"))
        val course = parse(content).courses.single()
        assertEquals("教学楼101", course.location)
        assertEquals("李老师", course.teacher)
    }

    @Test
    fun `DESCRIPTION 单行时地点教师都从 LOCATION 拆`() {
        val content = calendar(event(description = "第 1-2 节", location = "教学楼101 李老师"))
        val course = parse(content).courses.single()
        assertEquals("教学楼101", course.location)
        assertEquals("李老师", course.teacher)
    }

    @Test
    fun `三行且第二行匹配 LOCATION 时按教师在前解析`() {
        // Format B: line[1]=teacher, line[2]=location
        val content = calendar(
            event(description = "第 1-2 节\\n张老师\\n教学楼201", location = "教学楼201"),
        )
        val course = parse(content).courses.single()
        assertEquals("张老师", course.teacher)
        assertEquals("教学楼201", course.location)
    }

    @Test
    fun `三行且无 LOCATION 时按地点在前解析`() {
        val content = calendar(event(description = "第 1-2 节\\n教学楼201\\n张老师"))
        val course = parse(content).courses.single()
        assertEquals("教学楼201", course.location)
        assertEquals("张老师", course.teacher)
    }

    // ==========================================
    // 5. 字段缺失（定向反例）
    // ==========================================

    @Test
    fun `缺 SUMMARY 或 DESCRIPTION 或 DTEND 的事件整条跳过`() {
        val noSummary = calendar(event(summary = ""))
        assertTrue(parse(noSummary).courses.isEmpty())

        val noDescription = calendar(event(description = ""))
        assertTrue(parse(noDescription).courses.isEmpty())

        val noDtEnd = calendar(event(dtEnd = null))
        assertTrue(parse(noDtEnd).courses.isEmpty())
    }

    @Test
    fun `DESCRIPTION 不含第几节判据或格式错时整条跳过`() {
        val noSection = calendar(event(description = "只有一段说明文字"))
        assertTrue(parse(noSection).courses.isEmpty())

        val emptyLines = calendar(event(description = "\\n\\n"))
        assertTrue(parse(emptyLines).courses.isEmpty())
    }

    @Test
    fun `DTSTART 格式非法时事件被丢弃`() {
        // ISO 风格时间不符合 ICS ^\d{8}T\d{4,6}(Z)?$ 形状
        val content = calendar(event(dtStart = "2026-03-02T08:00:00"))
        assertTrue(parse(content).courses.isEmpty())
    }

    @Test
    fun `带 Z 后缀的 UTC 时间可解析`() {
        // UTC → 本地时刻随机器时区，墙钟不进断言；只钉「能解析出课」
        val content = calendar(event(dtStart = "20260302T080000Z", dtEnd = "20260302T094000Z"))
        assertEquals(1, parse(content).courses.size)
    }

    // ==========================================
    // 6. 超长内容（定向反例）
    // ==========================================

    @Test
    fun `超长 SUMMARY 不炸解析且名字完整保留`() {
        val longName = "数".repeat(100_000)
        val content = calendar(event(summary = longName))
        val result = parse(content)
        assertEquals(1, result.courses.size)
        assertEquals(100_000, result.courses[0].name.length)
    }

    @Test
    fun `超远 UNTIL 被周次钳制到 30 周`() {
        // Dart 注释里的反例：RRULE:UNTIL=99991231 会推出 ~416k 周，
        // Course.normalizeWeeks 钳到 1..30 才允许入库
        val content = calendar(event(rrule = "FREQ=WEEKLY;UNTIL=99991231T235959"))
        val course = parse(content).courses.single()
        assertEquals(1, course.startWeek)
        assertEquals(30, course.endWeek)
    }

    // ==========================================
    // 7. 重复课 / 单双周合并（定向反例）
    // ==========================================

    private fun eventAtWeek1() = event(rrule = null) // DTSTART 03-02 → 第 1 周

    private fun eventAtWeek3() = event(
        dtStart = "20260316T080000",
        dtEnd = "20260316T094000",
    ) // 03-16 → 第 3 周

    @Test
    fun `同键单周课隔两周合并为一条并带单周标志`() {
        // 两次事件同课程同地点同节次，分别在第 1、3 周 → 合并 1..3 单周
        val content = calendar(eventAtWeek1(), eventAtWeek3())
        val result = parse(content)
        assertEquals(1, result.courses.size)
        val course = result.courses[0]
        assertEquals(1, course.startWeek)
        assertEquals(3, course.endWeek)
        assertTrue(course.isOddWeek)
        assertTrue(!course.isEvenWeek)
    }

    @Test
    fun `完全相同的两条事件不合并`() {
        // 间隔 0 ≠ 2 → 各自保留
        val content = calendar(eventAtWeek1(), eventAtWeek1())
        val result = parse(content)
        assertEquals(2, result.courses.size)
    }

    @Test
    fun `相邻两周的单周课不合并`() {
        // 第 1、2 周：间隔 1 ≠ 2
        val week2 = event(dtStart = "20260309T080000", dtEnd = "20260309T094000")
        val content = calendar(eventAtWeek1(), week2)
        val result = parse(content)
        assertEquals(2, result.courses.size)
    }

    @Test
    fun `不同课程名的两条事件不合并`() {
        val other = event(summary = "大学英语", dtStart = "20260316T080000", dtEnd = "20260316T094000")
        val content = calendar(eventAtWeek1(), other)
        val result = parse(content)
        assertEquals(2, result.courses.size)
    }

    @Test
    fun `合并结果按星期节次周次排序`() {
        // 周三的事件在前、周一的在后，解析后应按 dayOfWeek 升序
        val monday = event(dtStart = "20260302T080000", dtEnd = "20260302T094000")
        val wednesday = event(dtStart = "20260304T100000", dtEnd = "20260304T114000", summary = "大学英语")
        val result = parse(calendar(wednesday, monday))
        assertEquals(2, result.courses.size)
        assertEquals(1, result.courses[0].dayOfWeek)
        assertEquals(3, result.courses[1].dayOfWeek)
    }
}
