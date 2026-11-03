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

    // ==========================================
    // 8. Dart 2026-10-27 修复的导出格式（Sections / 显式前缀）
    // ==========================================

    private fun rawEvent(vararg lines: String): String = buildString {
        append("BEGIN:VEVENT\r\n")
        for (line in lines) append(line).append("\r\n")
        append("END:VEVENT\r\n")
    }

    @Test
    fun `本 App 导出的 Sections 前缀课可导入且前缀行归位`() {
        // 对应 Dart `64284a2c`：导出侧 `Sections: 3-4` 在第 2 行，旧实现只认中文首行 → 整课丢弃
        val content = calendar(
            event(
                description = "Teacher: 张老师\\nSections: 3-4\\nLocation: 教三-201\\n" +
                    "Description: 线性系统\\nNote: 带计算器",
            ),
        )
        val course = parse(content).courses.single()
        assertEquals("高等数学", course.name)
        assertEquals("张老师", course.teacher)
        assertEquals("教三-201", course.location)
        assertEquals("线性系统", course.description)
        assertEquals("带计算器", course.note)
        assertEquals(3, course.startSection)
        assertEquals(4, course.endSection)
    }

    @Test
    fun `Period 前缀与裸区间节次同样可识别`() {
        val period = calendar(
            event(description = "Period 5-6\\nA101\\n李老师"),
        )
        val periodCourse = parse(period).courses.single()
        assertEquals(5, periodCourse.startSection)
        assertEquals(6, periodCourse.endSection)
        assertEquals("A101", periodCourse.location)
        assertEquals("李老师", periodCourse.teacher)

        val bare = calendar(event(description = "9-10节\\nB202\\n王老师"))
        val bareCourse = parse(bare).courses.single()
        assertEquals(9, bareCourse.startSection)
        assertEquals(10, bareCourse.endSection)
        assertEquals("B202", bareCourse.location)
        assertEquals("王老师", bareCourse.teacher)
    }

    @Test
    fun `显式 Location 是纯地点，不再从地点串里拆教师`() {
        // Dart 注释的反例：Location: 教三-201 若按旧口径拆末段，教师会变成 教三-201
        val content = calendar(event(description = "Sections: 1-2\\nLocation: 教三-201"))
        val course = parse(content).courses.single()
        assertEquals("教三-201", course.location)
        assertEquals("", course.teacher)
    }

    @Test
    fun `节次行被剔除后教师地点位移不再错位`() {
        // 中文三行：节次 + 地点 + 教师；旧实现把 descriptionLines[1] 当教师
        val content = calendar(event(description = "第1 - 2节\\nA101\\n张老师"))
        val course = parse(content).courses.single()
        assertEquals("A101", course.location)
        assertEquals("张老师", course.teacher)
    }

    // ==========================================
    // 9. RRULE 展开口径（COUNT / BYDAY / EXDATE 与 Dart 同为不展开）
    // ==========================================

    @Test
    fun `COUNT 与 UNTIL 同时存在时 UNTIL 决定结束周、COUNT 被忽略`() {
        val content = calendar(event(rrule = "FREQ=WEEKLY;COUNT=3;UNTIL=20260427T080000"))
        val course = parse(content).courses.single()
        // 与 `UNTIL=20260427T080000` 单独存在同解：第 9 周
        assertEquals(9, course.endWeek)
    }

    @Test
    fun `只有 COUNT 时不展开、结束周回落起始周`() {
        // Dart 的 _parseEndWeek 只认 UNTIL；COUNT 不参与周次计算
        val content = calendar(event(rrule = "FREQ=WEEKLY;COUNT=10"))
        val course = parse(content).courses.single()
        assertEquals(course.startWeek, course.endWeek)
    }

    @Test
    fun `BYDAY 被忽略，不改变周次区间`() {
        val content = calendar(event(rrule = "FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20260427T080000"))
        val course = parse(content).courses.single()
        assertEquals(9, course.endWeek)
    }

    @Test
    fun `EXDATE 不拆分课程也不排除实例`() {
        val content = calendar(
            event(rrule = "FREQ=WEEKLY;UNTIL=20260427T080000", extra = "EXDATE:20260316T080000\r\n"),
        )
        val course = parse(content).courses.single()
        assertEquals(1, course.startWeek)
        assertEquals(9, course.endWeek)
    }

    // ==========================================
    // 10. 时间语义：TZID / 跨天 / 全天 / 非法日期
    // ==========================================

    @Test
    fun `TZID 参数被丢弃，时间按墙上时刻不换算`() {
        // 对应 Dart test：TZID=/Asia/Shanghai 时 08:20 就是 08:20（不按 tz 转 UTC）
        val content = calendar(
            rawEvent(
                "SUMMARY:时区课",
                "DTSTART;TZID=/Asia/Shanghai:20260302T082000",
                "DTEND;TZID=/Asia/Shanghai:20260302T100000",
                "DESCRIPTION:第 1-2 节\\nA101\\n张老师",
                "LOCATION:A101 张老师",
            ),
        )
        val course = parse(content).courses.single()
        assertEquals("08:20", course.startTime)
        assertEquals("10:00", course.endTime)
        assertEquals(1, course.dayOfWeek)
        assertEquals(1, course.startWeek)
    }

    @Test
    fun `跨天 DTEND 只取结束时刻，日归属仍看 DTSTART`() {
        // Dart 不做跨日归一：dayOfWeek/startTime 取 DTSTART，endTime 取 DTEND 的墙钟
        val content = calendar(event(dtStart = "20260302T220000", dtEnd = "20260303T010000"))
        val course = parse(content).courses.single()
        assertEquals(1, course.dayOfWeek)
        assertEquals("22:00", course.startTime)
        assertEquals("01:00", course.endTime)
        assertEquals(1, course.startWeek)
        assertEquals(1, course.endWeek)
    }

    @Test
    fun `VALUE=DATE 的全天事件因缺 T 时刻被跳过`() {
        val allDay = calendar(
            rawEvent(
                "SUMMARY:全天课",
                "DTSTART;VALUE=DATE:20260302",
                "DTEND;VALUE=DATE:20260303",
                "DESCRIPTION:第 1-2 节",
            ),
        )
        val alone = parse(allDay)
        assertTrue(alone.courses.isEmpty())
        assertEquals(fixedNow, alone.semesterStart)

        // 与正常事件混排时只丢全天那条，其余照常导入
        val mixed = parse(calendar(event(summary = "正常课"), rawEvent(
            "SUMMARY:全天课",
            "DTSTART;VALUE=DATE:20260303",
            "DTEND;VALUE=DATE:20260304",
            "DESCRIPTION:第 1-2 节",
        )))
        assertEquals(1, mixed.courses.size)
        assertEquals("正常课", mixed.courses[0].name)
    }

    @Test
    fun `非法日历日期按 Dart 字段顺延而非丢弃`() {
        // 20260231 不存在：Dart DateTime(...) 顺延到 2026-03-03（周二）
        val content = calendar(event(dtStart = "20260231T080000", dtEnd = "20260231T094000"))
        val course = parse(content).courses.single()
        assertEquals(2, course.dayOfWeek)
        assertEquals("08:00", course.startTime)
    }

    // ==========================================
    // 11. 失败粒度 / id 下标
    // ==========================================

    @Test
    fun `坏事件逐条跳过，后续好事件照常导入且下标不前移`() {
        // 第一条缺 SUMMARY → 丢弃；第二条的 id 后缀应为已收课程数 0（Dart rawCourses.length）
        val content = calendar(event(summary = ""), event(summary = "正常课"))
        val result = parse(content)
        assertEquals(1, result.courses.size)
        assertEquals("正常课", result.courses[0].name)
        assertTrue(result.courses[0].id.endsWith("-0"))
        // 学期起点仍取最早 DTSTART（坏事件也带 DTSTART）
        assertEquals(LocalDateTime.of(2026, 3, 2, 0, 0), result.semesterStart)
    }

    // ==========================================
    // 12. 合并：偶周 + description 不进合并键
    // ==========================================

    @Test
    fun `偶周单周课合并为双周课`() {
        // 基准课锚定学期起点为 03-02（第 1 周），双周课落在第 2、4 周
        val anchor = event(summary = "基准课", dtStart = "20260302T100000", dtEnd = "20260302T114000")
        val week2 = event(dtStart = "20260309T080000", dtEnd = "20260309T094000")
        val week4 = event(dtStart = "20260323T080000", dtEnd = "20260323T094000")
        val courses = parse(calendar(anchor, week2, week4)).courses
        assertEquals(2, courses.size)
        val merged = courses.single { it.name == "高等数学" }
        assertEquals(2, merged.startWeek)
        assertEquals(4, merged.endWeek)
        assertTrue(!merged.isOddWeek)
        assertTrue(merged.isEvenWeek)
    }

    @Test
    fun `description 不进合并键，note 进`() {
        val week1 = event(
            dtStart = "20260302T080000", dtEnd = "20260302T094000",
            description = "第 1-2 节\\nDescription: A",
        )
        val week3 = event(
            dtStart = "20260316T080000", dtEnd = "20260316T094000",
            description = "第 1-2 节\\nDescription: B",
        )
        val course = parse(calendar(week1, week3)).courses.single()
        assertEquals(1, course.startWeek)
        assertEquals(3, course.endWeek)
        assertEquals("A", course.description)
    }
}
